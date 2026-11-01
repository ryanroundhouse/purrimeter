package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"purrimeter/server/internal/releases"
	"strings"
	"testing"
	"time"
)

func releasePeer(t *testing.T, h *hub, id, token string) *peer {
	t.Helper()
	p := newPeer(nil, func() {})
	b, _ := json.Marshal(message{"type": "hello", "version": 1, "release": id, "name": "Player", "token": token})
	if !h.authenticate(p, b) {
		t.Fatalf("release %s rejected: %v", id, drain(p))
	}
	drain(p)
	return p
}
func TestReleaseAdmissionAndGrandfathering(t *testing.T) {
	h := fixtureHub()
	h.allowDevelopment = false
	h.currentRelease = releases.Release{ID: "one", Version: "1"}
	now := time.Unix(100, 0)
	h.now = func() time.Time { return now }
	for _, id := range []string{"", "old", "new", "development"} {
		p := newPeer(nil, func() {})
		b, _ := json.Marshal(message{"type": "hello", "version": 1, "release": id, "name": "Player"})
		code := "release"
		if id == "" {
			code = "hello"
		}
		if h.authenticate(p, b) || !hasError(p, code) {
			t.Fatalf("unexpected admission for %q", id)
		}
	}
	owner := releasePeer(t, h, "one", "")
	browser := releasePeer(t, h, "one", "")
	room := create(t, h, owner, "")
	h.currentRelease = releases.Release{ID: "two", Version: "2"}
	command(t, h, owner, message{"type": "chat", "text": "still here"})
	if !hasType(drain(owner), "chat") {
		t.Fatal("existing session interrupted")
	}
	command(t, h, browser, message{"type": "create", "name": "new"})
	if !hasError(browser, "release") {
		t.Fatal("stale browser created a game")
	}
	join(t, h, browser, room, "")
	if !hasError(browser, "release") {
		t.Fatal("stale browser joined")
	}
	h.disconnected(owner)
	now = now.Add(59 * time.Second)
	returning := releasePeer(t, h, "one", h.token(owner.id))
	command(t, h, returning, message{"type": "resume", "game": room})
	if returning.game != room {
		t.Fatal("reservation not restored")
	}
	command(t, h, returning, message{"type": "leave"})
	h.disconnected(returning)
	p := newPeer(nil, func() {})
	b, _ := json.Marshal(message{"type": "hello", "version": 1, "release": "one", "name": "Player", "token": h.token(owner.id)})
	if h.authenticate(p, b) {
		t.Fatal("token alone exempted stale client")
	}
}
func TestReleaseReservationBoundary(t *testing.T) {
	for _, expireBeforeHello := range []bool{true, false} {
		h := fixtureHub()
		h.allowDevelopment = false
		h.currentRelease = releases.Release{ID: "one"}
		now := time.Unix(100, 0)
		h.now = func() time.Time { return now }
		p := releasePeer(t, h, "one", "")
		room := create(t, h, p, "")
		h.disconnected(p)
		h.currentRelease.ID = "two"
		if expireBeforeHello {
			now = now.Add(60 * time.Second)
		} else {
			now = now.Add(59 * time.Second)
		}
		q := newPeer(nil, func() {})
		b, _ := json.Marshal(message{"type": "hello", "version": 1, "release": "one", "name": "Player", "token": h.token(p.id)})
		ok := h.authenticate(q, b)
		if expireBeforeHello {
			if ok {
				t.Fatal("expired reservation admitted")
			}
			continue
		}
		if !ok {
			t.Fatal("valid reservation rejected")
		}
		now = now.Add(time.Second)
		command(t, h, q, message{"type": "resume", "game": room})
		if q.game != "" || !hasError(q, "expired") {
			t.Fatal("resume extended expired reservation")
		}
	}
}

func TestReloadRetainsLastValidAndNotifiesOnce(t *testing.T) {
	pub, key, _ := ed25519.GenerateKey(rand.Reader)
	oldKey := releases.PublicKey
	releases.PublicKey = base64.StdEncoding.EncodeToString(pub)
	defer func() { releases.PublicKey = oldKey }()
	p := releases.Package{URL: "https://example.com/game.zip", SHA256: strings.Repeat("a", 64), Size: 100}
	r := releases.Release{ID: "one", Sequence: 1, Version: "1", Packages: map[string]releases.Package{"macos": p, "windows": p}}
	path := filepath.Join(t.TempDir(), "release.json")
	raw, _ := releases.Sign(r, key)
	os.WriteFile(path, raw, 0600)
	h := fixtureHub()
	if e := h.reloadRelease(path); e != nil {
		t.Fatal(e)
	}
	peer := releasePeer(t, h, "one", "")
	r.ID = "two"
	r.Sequence = 2
	raw, _ = releases.Sign(r, key)
	os.WriteFile(path, raw, 0600)
	if e := h.reloadRelease(path); e != nil {
		t.Fatal(e)
	}
	if !hasType(drain(peer), "release_changed") {
		t.Fatal("no release notification")
	}
	h.reloadRelease(path)
	if len(drain(peer)) != 0 {
		t.Fatal("unchanged release notified repeatedly")
	}
	os.WriteFile(path, []byte("broken"), 0600)
	if h.reloadRelease(path) == nil || h.currentRelease.ID != "two" {
		t.Fatal("invalid release replaced current policy")
	}
}
