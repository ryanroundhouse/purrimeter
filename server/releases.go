package main

import (
	"bytes"
	"fmt"
	"log"
	"net/http"
	"os"
	"purrimeter/server/internal/releases"
)

// Called at startup and each tick. Invalid replacements retain the last valid release.
func (h *hub) reloadRelease(path string) error {
	raw, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	h.mu.Lock()
	same := bytes.Equal(raw, h.releaseEnvelope)
	h.mu.Unlock()
	if same {
		return nil
	}
	r, err := releases.Verify(raw)
	if err != nil {
		return err
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.currentRelease.ID == r.ID && !bytes.Equal(raw, h.releaseEnvelope) {
		return fmt.Errorf("release identity cannot be reused for different content")
	}
	h.currentRelease = r
	h.releaseEnvelope = raw
	for _, p := range h.peers {
		p.send(message{"type": "release_changed", "release": r.ID, "version": r.Version})
	}
	log.Printf("Current game release: %s", r.ID)
	return nil
}
func (h *hub) serveRelease(w http.ResponseWriter, r *http.Request) {
	h.mu.Lock()
	raw := append([]byte(nil), h.releaseEnvelope...)
	h.mu.Unlock()
	w.Header().Set("Cache-Control", "no-store")
	if len(raw) == 0 {
		http.Error(w, "No published release configured", 503)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write(raw)
}
func (h *hub) current(id string) bool {
	return (h.allowDevelopment && id == "development") || (h.currentRelease.ID != "" && id == h.currentRelease.ID)
}
func (h *hub) reserved(id, release string) bool {
	for _, r := range h.rooms {
		m := h.find(r, id)
		if m != nil && m.release == release && m.peer == nil && !m.expires.IsZero() && h.now().Before(m.expires) && !r.banned[id] {
			return true
		}
	}
	return false
}
func (h *hub) requireCurrent(p *peer) bool {
	if h.current(p.release) {
		return true
	}
	h.fail(p, "release", "This server requires game release "+h.currentRelease.Version+". Check for updates or download the current game from purrimeter.graham.pub. Your garden is safe.")
	return false
}
