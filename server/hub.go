package main

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/coder/websocket"
	"purrimeter/server/internal/releases"
)

const maxMessage = 512 * 1024
const grace = 60 * time.Second
const protocolVersion = 1

type message map[string]any
type request struct {
	Type     string          `json:"type"`
	Release  string          `json:"release"`
	Version  int             `json:"version"`
	Token    string          `json:"token"`
	Name     string          `json:"name"`
	Game     string          `json:"game"`
	Password string          `json:"password"`
	Text     string          `json:"text"`
	Player   string          `json:"player"`
	State    json.RawMessage `json:"state"`
}

type limiter struct {
	tokens float64
	at     time.Time
}

func (l *limiter) allow(now time.Time, rate, burst float64) bool {
	if l.at.IsZero() {
		l.tokens = burst
	} else {
		l.tokens = min(burst, l.tokens+now.Sub(l.at).Seconds()*rate)
	}
	l.at = now
	if l.tokens < 1 {
		return false
	}
	l.tokens--
	return true
}

type peer struct {
	conn                         *websocket.Conn
	cancel                       context.CancelFunc
	id, name, game               string
	release                      string
	queue                        chan []byte
	wake                         chan struct{}
	mu                           sync.Mutex
	states                       map[string][]byte
	general, chat, joins, frames limiter
	reports                      limiter
}

func newPeer(c *websocket.Conn, cancel context.CancelFunc) *peer {
	return &peer{conn: c, cancel: cancel, queue: make(chan []byte, 64), wake: make(chan struct{}, 1), states: map[string][]byte{}}
}
func (p *peer) send(m message) {
	b, _ := json.Marshal(m)
	select {
	case p.queue <- b:
	default:
		p.cancel()
	}
}
func (p *peer) state(id string, m message) {
	b, _ := json.Marshal(m)
	p.mu.Lock()
	p.states[id] = b
	p.mu.Unlock()
	select {
	case p.wake <- struct{}{}:
	default:
	}
}
func (p *peer) writeLoop(ctx context.Context) {
	defer p.cancel()
	write := func(b []byte) error {
		deadline, cancel := context.WithTimeout(ctx, 5*time.Second)
		defer cancel()
		return p.conn.Write(deadline, websocket.MessageText, b)
	}
	for {
		// Control and chat messages get priority over replaceable field updates.
		select {
		case b := <-p.queue:
			if write(b) != nil {
				return
			}
			continue
		default:
		}
		select {
		case <-ctx.Done():
			return
		case b := <-p.queue:
			if write(b) != nil {
				return
			}
		case <-p.wake:
			p.mu.Lock()
			states := p.states
			p.states = map[string][]byte{}
			p.mu.Unlock()
			for _, b := range states {
				if write(b) != nil {
					return
				}
			}
		}
	}
}

type member struct {
	id, name           string
	release            string
	order              uint64
	peer               *peer
	expires            time.Time
	state              json.RawMessage
	revision, sequence int64
	recent             []chatLine
}
type room struct {
	id, name, owner string
	password        [32]byte
	locked          bool
	members         []*member
	banned          map[string]bool
}
type ipEntry struct {
	active   int
	attempts limiter
	touched  time.Time
}
type hub struct {
	currentRelease   releases.Release
	releaseEnvelope  []byte
	allowDevelopment bool
	mu               sync.Mutex
	key              []byte
	peers            map[string]*peer
	rooms            map[string]*room
	ips              map[string]*ipEntry
	connections      int
	order            uint64
	now              func() time.Time
	report           func(report)
}

func newHub(key []byte) *hub {
	return &hub{key: key, peers: map[string]*peer{}, rooms: map[string]*room{}, ips: map[string]*ipEntry{}, now: time.Now}
}
func (h *hub) admit(ip string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	now := h.now()
	e := h.ips[ip]
	if e == nil {
		if len(h.ips) >= 4096 {
			return false
		}
		e = &ipEntry{}
		h.ips[ip] = e
	}
	e.touched = now
	if h.connections >= 600 || e.active >= 30 || !e.attempts.allow(now, 1, 20) {
		return false
	}
	e.active++
	h.connections++
	return true
}
func (h *hub) release(ip string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if e := h.ips[ip]; e != nil {
		e.active--
		h.connections--
	}
}
func (h *hub) token(id string) string {
	mac := hmac.New(sha256.New, h.key)
	_, _ = mac.Write([]byte(id))
	return id + "." + base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
func (h *hub) identity(token string) string {
	pieces := strings.Split(token, ".")
	if len(pieces) != 2 || len(pieces[0]) != 32 {
		return ""
	}
	if !hmac.Equal([]byte(token), []byte(h.token(pieces[0]))) {
		return ""
	}
	return pieces[0]
}
func validText(s string, maxLen int, empty bool) bool {
	if !utf8.ValidString(s) || (!empty && strings.TrimSpace(s) == "") || utf8.RuneCountInString(s) > maxLen {
		return false
	}
	for _, r := range s {
		if unicode.IsControl(r) {
			return false
		}
	}
	return true
}
func (h *hub) authenticate(p *peer, raw []byte) bool {
	var q request
	if len(raw) > 4096 || json.Unmarshal(raw, &q) != nil || q.Type != "hello" || q.Version != protocolVersion || !validText(q.Name, 24, false) {
		p.send(message{"type": "error", "code": "hello", "message": "Use a compatible game version and a name of 1–24 characters."})
		return false
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	id := h.identity(q.Token)
	if q.Token != "" && id == "" {
		p.send(message{"type": "error", "code": "identity", "message": "This server cannot verify your saved identity. Reset it in Connection settings."})
		return false
	}
	if id == "" {
		id = randomID()
	}
	if h.peers[id] != nil {
		p.send(message{"type": "error", "code": "duplicate", "message": "This installation is already connected. Close its other connection first."})
		return false
	}
	p.release = q.Release
	if q.Release == "" {
		h.fail(p, "hello", "Download the current Purrimeter game from https://purrimeter.graham.pub to play multiplayer. Your saved garden is safe.")
		return false
	}
	if !h.current(q.Release) && !h.reserved(id, q.Release) {
		h.requireCurrent(p)
		return false
	}
	p.id = id
	p.name = strings.TrimSpace(q.Name)
	h.peers[id] = p
	p.send(message{"type": "welcome", "version": protocolVersion, "id": id, "token": h.token(id)})
	h.list(p)
	return true
}
func (h *hub) fail(p *peer, code, text string) {
	p.send(message{"type": "error", "code": code, "message": text})
}
func (h *hub) handle(p *peer, raw []byte) bool {
	var q request
	if json.Unmarshal(raw, &q) != nil {
		return false
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.peers[p.id] != p || !p.general.allow(h.now(), 30, 60) {
		return false
	}
	switch q.Type {
	case "ping":
		p.send(message{"type": "pong"})
	case "list":
		h.list(p)
	case "create":
		if !h.requireCurrent(p) {
			break
		}
		if !p.joins.allow(h.now(), 0.5, 5) {
			h.fail(p, "rate", "Please wait before creating another game.")
			break
		}
		if p.game != "" || len(h.rooms) >= 200 || !validText(q.Name, 40, false) || !validText(q.Password, 64, true) {
			h.fail(p, "create", "Use a game name of 1–40 characters and a password up to 64 characters, or try again later.")
			break
		}
		r := &room{id: randomID(), name: strings.TrimSpace(q.Name), owner: p.id, locked: q.Password != "", banned: map[string]bool{}}
		r.password = sha256.Sum256([]byte(r.id + q.Password))
		h.rooms[r.id] = r
		h.add(r, p)
	case "join":
		if !h.requireCurrent(p) {
			break
		}
		if !p.joins.allow(h.now(), 0.5, 5) {
			h.fail(p, "rate", "Too many join attempts. Wait a moment and try again.")
			break
		}
		r := h.rooms[q.Game]
		if p.game != "" || r == nil {
			h.fail(p, "join", "That game is no longer available. Refresh the list.")
			break
		}
		if r.banned[p.id] {
			h.fail(p, "banned", "You were removed from this game.")
			break
		}
		if r.locked && r.password != sha256.Sum256([]byte(r.id+q.Password)) {
			h.fail(p, "password", "That password is incorrect. Try again.")
			break
		}
		if h.find(r, p.id) != nil {
			h.fail(p, "reserved", "Your place is reserved. Reconnect or leave it first.")
			break
		}
		if len(r.members) >= 3 {
			h.fail(p, "full", "That game is full. Choose another game.")
			break
		}
		h.add(r, p)
	case "resume":
		r := h.rooms[q.Game]
		var m *member
		if r != nil {
			m = h.find(r, p.id)
		}
		if p.game != "" || m == nil || m.release != p.release || r.banned[p.id] || m.expires.IsZero() || !h.now().Before(m.expires) {
			h.fail(p, "expired", "Your reserved place has expired. Join a game again.")
			break
		}
		m.peer = p
		m.expires = time.Time{}
		p.game = r.id
		p.name = m.name
		h.joined(r, p)
		h.broadcast(r)
	case "leave":
		r := h.rooms[p.game]
		if r == nil && q.Game != "" {
			r = h.rooms[q.Game]
		}
		if r != nil {
			h.remove(r, p.id)
		}
		p.game = ""
		p.send(message{"type": "left"})
		h.list(p)
	case "kick":
		r := h.rooms[p.game]
		if r == nil || r.owner != p.id || q.Player == p.id {
			h.fail(p, "permission", "Only the game owner can remove another player.")
			break
		}
		if m := h.find(r, q.Player); m != nil {
			r.banned[m.id] = true
			if m.peer != nil {
				m.peer.game = ""
				m.peer.send(message{"type": "kicked", "message": "The owner removed you from this game."})
			}
			h.remove(r, m.id)
		}
	case "chat":
		r := h.rooms[p.game]
		if r == nil || !validText(q.Text, 400, false) {
			h.fail(p, "chat", "Messages must contain 1–400 characters.")
			break
		}
		if !p.chat.allow(h.now(), 1, 5) {
			h.fail(p, "rate", "Please slow down before sending another message.")
			break
		}
		text := strings.TrimSpace(q.Text)
		if m := h.find(r, p.id); m != nil {
			m.recent = append(m.recent, chatLine{At: h.now().UTC(), Text: text})
			if len(m.recent) > recentMessages {
				m.recent = m.recent[len(m.recent)-recentMessages:]
			}
		}
		for _, m := range r.members {
			if m.peer != nil {
				m.peer.send(message{"type": "chat", "player": p.id, "name": h.label(r, p.id), "text": text})
			}
		}
	case "report":
		r := h.rooms[p.game]
		var m *member
		if r != nil && q.Player != p.id {
			m = h.find(r, q.Player)
		}
		if m == nil {
			h.fail(p, "report", "Choose another player in this game to report.")
			break
		}
		if !p.reports.allow(h.now(), 1.0/30, 3) {
			h.fail(p, "rate", "Please wait before sending another report.")
			break
		}
		if h.report != nil {
			h.report(report{At: h.now().UTC(), Game: r.id, GameName: r.name, Reporter: p.id, ReporterName: p.name,
				Player: m.id, PlayerName: m.name, Messages: append([]chatLine(nil), m.recent...)})
		}
		p.send(message{"type": "reported", "player": m.id})
	case "state":
		r := h.rooms[p.game]
		if r == nil || !p.frames.allow(h.now(), 12, 20) {
			break
		}
		state, err := validateState(q.State)
		if err != nil {
			h.fail(p, "state", "Invalid field update.")
			break
		}
		m := h.find(r, p.id)
		if m == nil {
			break
		}
		if int64(state.Revision) < m.revision || (int64(state.Revision) == m.revision && int64(state.Sequence) <= m.sequence) {
			break
		}
		m.state = append(json.RawMessage(nil), q.State...)
		m.revision = int64(state.Revision)
		m.sequence = int64(state.Sequence)
		for _, other := range r.members {
			if other.peer != nil && other.id != p.id {
				other.peer.state(p.id, message{"type": "state", "game": r.id, "player": p.id, "state": m.state})
			}
		}
	default:
		h.fail(p, "protocol", "Unsupported message. Update your game.")
	}
	return true
}
func (h *hub) find(r *room, id string) *member {
	for _, m := range r.members {
		if m.id == id {
			return m
		}
	}
	return nil
}
func (h *hub) add(r *room, p *peer) {
	// Abandon any old reservation before taking a new place.
	for _, old := range h.rooms {
		if old.id != r.id && h.find(old, p.id) != nil {
			h.remove(old, p.id)
		}
	}
	h.order++
	r.members = append(r.members, &member{id: p.id, name: p.name, release: p.release, order: h.order, peer: p, revision: -1, sequence: -1})
	p.game = r.id
	h.joined(r, p)
	h.broadcast(r)
}
func (h *hub) joined(r *room, p *peer) {
	p.send(message{"type": "joined", "game": h.describe(r)})
	for _, m := range r.members {
		if m.id != p.id && len(m.state) > 0 {
			p.state(m.id, message{"type": "state", "game": r.id, "player": m.id, "state": m.state})
		}
	}
}
func (h *hub) label(r *room, id string) string {
	m := h.find(r, id)
	if m == nil {
		return "Player"
	}
	count := 0
	for _, other := range r.members {
		if other.name == m.name {
			count++
		}
	}
	if count > 1 {
		return m.name + " · " + m.id[:6]
	}
	return m.name
}
func (h *hub) describe(r *room) message {
	players := []message{}
	for _, m := range r.members {
		players = append(players, message{"id": m.id, "name": h.label(r, m.id), "connected": m.peer != nil, "owner": r.owner == m.id})
	}
	return message{"id": r.id, "name": r.name, "locked": r.locked, "owner": r.owner, "players": players, "count": len(r.members)}
}
func (h *hub) list(p *peer) {
	games := []message{}
	for _, r := range h.rooms {
		if len(r.members) < 3 && !r.banned[p.id] {
			games = append(games, message{"id": r.id, "name": r.name, "locked": r.locked, "count": len(r.members)})
		}
	}
	p.send(message{"type": "games", "games": games})
}
func (h *hub) broadcast(r *room) {
	for _, m := range r.members {
		if m.peer != nil {
			m.peer.send(message{"type": "room", "game": h.describe(r)})
		}
	}
}
func (h *hub) remove(r *room, id string) {
	for i, m := range r.members {
		if m.id == id {
			if m.peer != nil {
				m.peer.game = ""
			}
			r.members = append(r.members[:i], r.members[i+1:]...)
			break
		}
	}
	if len(r.members) == 0 {
		delete(h.rooms, r.id)
		return
	}
	if r.owner == id {
		r.owner = ""
		for _, m := range r.members {
			if m.peer != nil {
				r.owner = m.id
				break
			}
		}
		if r.owner == "" {
			r.owner = r.members[0].id
		}
	}
	h.broadcast(r)
}
func (h *hub) disconnected(p *peer) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.peers[p.id] != p {
		return
	}
	delete(h.peers, p.id)
	if r := h.rooms[p.game]; r != nil {
		if m := h.find(r, p.id); m != nil && m.peer == p {
			m.peer = nil
			m.expires = h.now().Add(grace)
			h.broadcast(r)
		}
	}
}
func (h *hub) expire() {
	h.mu.Lock()
	defer h.mu.Unlock()
	now := h.now()
	for _, r := range h.rooms {
		for _, m := range append([]*member(nil), r.members...) {
			if m.peer == nil && !m.expires.IsZero() && !now.Before(m.expires) {
				h.remove(r, m.id)
			}
		}
	}
	for ip, e := range h.ips {
		if e.active == 0 && now.Sub(e.touched) > 5*time.Minute {
			delete(h.ips, ip)
		}
	}
}
func (h *hub) close() {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, p := range h.peers {
		p.cancel()
	}
}

func (h *hub) String() string { return fmt.Sprintf("relay protocol %d", protocolVersion) }
