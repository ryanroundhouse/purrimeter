package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func fixtureHub() *hub {
	h := newHub([]byte("01234567890123456789012345678901"))
	h.allowDevelopment = true
	return h
}
func fixturePeer(t *testing.T, h *hub, name string) *peer {
	t.Helper()
	p := newPeer(nil, func() {})
	b, _ := json.Marshal(message{"type": "hello", "version": 1, "release": "development", "name": name})
	if !h.authenticate(p, b) {
		t.Fatal("authentication failed")
	}
	drain(p)
	return p
}
func command(t *testing.T, h *hub, p *peer, m message) {
	t.Helper()
	b, err := json.Marshal(m)
	if err != nil || !h.handle(p, b) {
		t.Fatalf("command failed: %v %v", m, err)
	}
}
func drain(p *peer) []message {
	out := []message{}
	for {
		select {
		case raw := <-p.queue:
			var m message
			_ = json.Unmarshal(raw, &m)
			out = append(out, m)
		default:
			return out
		}
	}
}
func hasType(messages []message, kind string) bool {
	for _, m := range messages {
		if m["type"] == kind {
			return true
		}
	}
	return false
}
func hasError(p *peer, code string) bool {
	for _, m := range drain(p) {
		if m["type"] == "error" && m["code"] == code {
			return true
		}
	}
	return false
}
func create(t *testing.T, h *hub, p *peer, password string) string {
	t.Helper()
	command(t, h, p, message{"type": "create", "name": "Garden", "password": password})
	if p.game == "" {
		t.Fatal("no room created")
	}
	drain(p)
	return p.game
}
func join(t *testing.T, h *hub, p *peer, id, password string) {
	t.Helper()
	command(t, h, p, message{"type": "join", "game": id, "password": password})
}

func TestAdmissionPasswordAndOwnership(t *testing.T) {
	h := fixtureHub()
	a := fixturePeer(t, h, "Alex")
	b := fixturePeer(t, h, "Alex")
	c := fixturePeer(t, h, "Casey")
	d := fixturePeer(t, h, "Dee")
	id := create(t, h, a, "secret")
	join(t, h, b, id, "wrong")
	if !hasError(b, "password") || b.game != "" {
		t.Fatal("wrong password admitted")
	}
	join(t, h, b, id, "secret")
	join(t, h, c, id, "secret")
	join(t, h, d, id, "secret")
	if !hasError(d, "full") || len(h.rooms[id].members) != 3 {
		t.Fatal("capacity violated")
	}
	if h.label(h.rooms[id], a.id) == h.label(h.rooms[id], b.id) {
		t.Fatal("duplicate display names not distinguished")
	}
	command(t, h, d, message{"type": "list"})
	for _, m := range drain(d) {
		if m["type"] == "games" && len(m["games"].([]any)) != 0 {
			t.Fatal("full room listed")
		}
	}
	command(t, h, a, message{"type": "leave"})
	if h.rooms[id].owner != b.id || len(h.rooms[id].members) != 2 {
		t.Fatal("creator departure disrupted room")
	}
	join(t, h, d, id, "secret")
	if d.game != id {
		t.Fatal("vacated place unavailable")
	}
}

func TestReservationsReconnectAndExpiry(t *testing.T) {
	h := fixtureHub()
	now := time.Unix(1000, 0)
	h.now = func() time.Time { return now }
	a := fixturePeer(t, h, "Owner")
	b := fixturePeer(t, h, "Guest")
	id := create(t, h, a, "")
	join(t, h, b, id, "")
	h.disconnected(a)
	if h.rooms[id].owner != a.id || len(h.rooms[id].members) != 2 {
		t.Fatal("disconnect prematurely released ownership or place")
	}
	returning := newPeer(nil, func() {})
	raw, _ := json.Marshal(message{"type": "hello", "version": 1, "release": "development", "name": "Renamed", "token": h.token(a.id)})
	if !h.authenticate(returning, raw) {
		t.Fatal("authenticated reconnect failed")
	}
	command(t, h, returning, message{"type": "resume", "game": id})
	if returning.game != id || returning.name != "Owner" || h.rooms[id].owner != a.id {
		t.Fatal("resume failed to preserve membership")
	}
	h.disconnected(returning)
	now = now.Add(grace)
	h.expire()
	if h.rooms[id].owner != b.id || len(h.rooms[id].members) != 1 {
		t.Fatal("expired owner not transferred")
	}
	h.disconnected(b)
	now = now.Add(grace - time.Second)
	h.expire()
	if h.rooms[id] == nil {
		t.Fatal("all-disconnected room expired early")
	}
	now = now.Add(time.Second)
	h.expire()
	if h.rooms[id] != nil {
		t.Fatal("empty room leaked")
	}
}

func TestKickPermissionsAndIdentity(t *testing.T) {
	h := fixtureHub()
	a := fixturePeer(t, h, "Owner")
	b := fixturePeer(t, h, "Guest")
	id := create(t, h, a, "")
	join(t, h, b, id, "")
	drain(b)
	command(t, h, b, message{"type": "kick", "player": a.id})
	if !hasError(b, "permission") {
		t.Fatal("guest could kick owner")
	}
	command(t, h, a, message{"type": "kick", "player": b.id})
	if b.game != "" || !hasType(drain(b), "kicked") {
		t.Fatal("kick did not remove member")
	}
	join(t, h, b, id, "")
	if !hasError(b, "banned") {
		t.Fatal("kicked identity rejoined")
	}
	command(t, h, b, message{"type": "resume", "game": id})
	if !hasError(b, "expired") {
		t.Fatal("kick bypassed via resume")
	}
	duplicate := newPeer(nil, func() {})
	raw, _ := json.Marshal(message{"type": "hello", "version": 1, "release": "development", "name": "Imposter", "token": h.token(a.id)})
	if h.authenticate(duplicate, raw) || !hasError(duplicate, "duplicate") {
		t.Fatal("duplicate installation admitted")
	}
	if h.identity(h.token(a.id)+"x") != "" {
		t.Fatal("forged identity accepted")
	}
}

func TestChatIsolationNoHistoryAndRateLimit(t *testing.T) {
	h := fixtureHub()
	a := fixturePeer(t, h, "A")
	b := fixturePeer(t, h, "B")
	outsider := fixturePeer(t, h, "Other")
	id := create(t, h, a, "")
	create(t, h, outsider, "")
	command(t, h, a, message{"type": "chat", "text": "before arrival"})
	drain(a)
	join(t, h, b, id, "")
	if hasType(drain(b), "chat") {
		t.Fatal("new arrival received old chat")
	}
	drain(a)
	command(t, h, a, message{"type": "chat", "text": "hello"})
	if !hasType(drain(b), "chat") || hasType(drain(outsider), "chat") {
		t.Fatal("chat audience incorrect")
	}
	for i := 0; i < 7; i++ {
		command(t, h, a, message{"type": "chat", "text": "spam"})
	}
	if !hasError(a, "rate") {
		t.Fatal("chat rate limit missing")
	}
}

func fieldFixture() message {
	return message{"revision": 0, "sequence": 1, "paused": true, "speed": 1, "shots": []any{}, "garden": message{
		"level": 1, "best": 0, "run_best": 0, "rebirths": 0, "training": 0, "kills": 0, "spawned": 0, "coins": 2.3, "bonus_points": 0, "elapsed": 0, "active": false, "auto_start": false, "auto_start_remaining": 0,
		"powerups": message{}, "discovered": message{"training": true}, "cat_milestones": []int{0, 0, 0}, "towers": []any{}, "enemies": []any{},
	}}
}
func TestFieldRelayRevisionAndBounds(t *testing.T) {
	h := fixtureHub()
	a := fixturePeer(t, h, "A")
	b := fixturePeer(t, h, "B")
	outsider := fixturePeer(t, h, "Other")
	id := create(t, h, a, "")
	join(t, h, b, id, "")
	create(t, h, outsider, "")
	state := fieldFixture()
	command(t, h, a, message{"type": "state", "state": state, "player": outsider.id})
	if len(b.states) != 1 || len(outsider.states) != 0 {
		t.Fatal("incorrect state routing")
	}
	var received message
	_ = json.Unmarshal(b.states[a.id], &received)
	if received["player"] != a.id {
		t.Fatal("sender identity not bound by server")
	}
	state["revision"] = 1
	state["sequence"] = 2
	command(t, h, a, message{"type": "state", "state": state})
	state["revision"] = 0
	state["sequence"] = 3
	command(t, h, a, message{"type": "state", "state": state})
	if h.find(h.rooms[id], a.id).revision != 1 {
		t.Fatal("old garden revision replaced current field")
	}
	state["garden"].(message)["towers"] = []any{message{"cell": 10, "kind": 99, "tier": 1, "hp": 1, "spent": 1, "cooldown": 0, "flash": 0}}
	command(t, h, a, message{"type": "state", "state": state})
	if !hasError(a, "state") {
		t.Fatal("malformed art index relayed")
	}
	if len(b.states) != 1 {
		t.Fatal("field updates were queued instead of coalesced")
	}
}

func TestFinalSlotConcurrentJoins(t *testing.T) {
	h := fixtureHub()
	a := fixturePeer(t, h, "A")
	b := fixturePeer(t, h, "B")
	c := fixturePeer(t, h, "C")
	d := fixturePeer(t, h, "D")
	id := create(t, h, a, "")
	join(t, h, b, id, "")
	var wg sync.WaitGroup
	for _, p := range []*peer{c, d} {
		wg.Add(1)
		go func(p *peer) { defer wg.Done(); command(t, h, p, message{"type": "join", "game": id}) }(p)
	}
	wg.Wait()
	if len(h.rooms[id].members) != 3 || (c.game == id) == (d.game == id) {
		t.Fatal("last place was not atomic")
	}
}

func TestActualWebSocketHandshakeAndProtocol(t *testing.T) {
	h := fixtureHub()
	server := httptest.NewServer(http.HandlerFunc(h.serve))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	c, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer c.CloseNow()
	write := func(m message) {
		b, _ := json.Marshal(m)
		if err := c.Write(ctx, websocket.MessageText, b); err != nil {
			t.Fatal(err)
		}
	}
	read := func() message {
		_, b, err := c.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		var m message
		if json.Unmarshal(b, &m) != nil {
			t.Fatal("bad JSON")
		}
		return m
	}
	write(message{"type": "hello", "version": 1, "release": "development", "name": "Native client"})
	if read()["type"] != "welcome" || read()["type"] != "games" {
		t.Fatal("handshake out of order")
	}
	write(message{"type": "create", "name": "Network game"})
	if read()["type"] != "joined" || read()["type"] != "room" {
		t.Fatal("create flow failed")
	}
	write(message{"type": "ping"})
	if read()["type"] != "pong" {
		t.Fatal("heartbeat failed")
	}
}

func TestRestartPreservesIdentityWithoutRestoringGames(t *testing.T) {
	h := fixtureHub()
	p := fixturePeer(t, h, "Gardener")
	id := create(t, h, p, "")
	restarted := newHub(h.key)
	restarted.allowDevelopment = true
	returning := newPeer(nil, func() {})
	raw, _ := json.Marshal(message{"type": "hello", "version": 1, "release": "development", "name": "Gardener", "token": h.token(p.id)})
	if !restarted.authenticate(returning, raw) || returning.id != p.id {
		t.Fatal("identity did not survive server restart")
	}
	command(t, restarted, returning, message{"type": "resume", "game": id})
	if !hasError(returning, "expired") || len(restarted.rooms) != 0 {
		t.Fatal("restart should expire old rooms")
	}
}

func TestStateEnvelopeRejectsMissingFieldsAndAcceptsIntegralJSONFloats(t *testing.T) {
	for _, key := range []string{"revision", "sequence", "paused", "speed", "shots"} {
		state := fieldFixture()
		delete(state, key)
		raw, _ := json.Marshal(state)
		if _, err := validateState(raw); err == nil {
			t.Fatalf("accepted missing %s", key)
		}
	}
	state := fieldFixture()
	raw, _ := json.Marshal(state)
	raw = []byte(strings.ReplaceAll(string(raw), `"revision":0`, `"revision":0.0`))
	if _, err := validateState(raw); err != nil {
		t.Fatal("equivalent JSON number notation rejected", err)
	}
}

func TestFieldSoundEvents(t *testing.T) {
	for _, test := range []struct {
		name   string
		sounds any
		valid  bool
	}{
		{"empty", []any{}, true},
		{"valid", []any{message{"id": 1, "name": "cannon", "tier": 4}, message{"id": 2, "name": "rebirth", "tier": 6}}, true},
		{"unknown effect", []any{message{"id": 1, "name": "arbitrary.wav", "tier": 1}}, false},
		{"invalid tier", []any{message{"id": 1, "name": "bolt", "tier": 7}}, false},
		{"duplicate", []any{message{"id": 1, "name": "bolt", "tier": 1}, message{"id": 1, "name": "bolt", "tier": 1}}, false},
		{"fractional identity", []any{message{"id": 1.5, "name": "bolt", "tier": 1}}, false},
		{"oversized", make([]any, 129), false},
		{"wrong shape", "sounds", false},
	} {
		t.Run(test.name, func(t *testing.T) {
			state := fieldFixture()
			state["sounds"] = test.sounds
			raw, _ := json.Marshal(state)
			_, err := validateState(raw)
			if (err == nil) != test.valid {
				t.Fatalf("valid = %v, error = %v", test.valid, err)
			}
		})
	}
}
