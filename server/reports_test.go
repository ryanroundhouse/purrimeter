package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestReportCarriesRecentMessagesAndIsRateLimited(t *testing.T) {
	h := fixtureHub()
	var stored []report
	h.report = func(r report) { stored = append(stored, r) }
	a, b, c := fixturePeer(t, h, "Alice"), fixturePeer(t, h, "Bob"), fixturePeer(t, h, "Cara")
	command(t, h, a, message{"type": "create", "name": "Garden"})
	room := ""
	for id := range h.rooms {
		room = id
	}
	command(t, h, b, message{"type": "join", "game": room})
	drain(a)
	drain(b)
	for i := 0; i < 12; i++ {
		h.now = func() time.Time { return time.Unix(1_800_000_000+int64(i)*10, 0) }
		command(t, h, b, message{"type": "chat", "text": "line " + strings.Repeat("x", i)})
	}
	command(t, h, a, message{"type": "report", "player": b.id})
	replies := drain(a)
	if !hasType(replies, "reported") {
		t.Fatalf("expected acknowledgement, got %v", replies)
	}
	if len(stored) != 1 || stored[0].Player != b.id || stored[0].PlayerName != "Bob" || stored[0].Reporter != a.id || stored[0].Game != room {
		t.Fatalf("unexpected report %+v", stored)
	}
	if len(stored[0].Messages) != recentMessages || stored[0].Messages[0].Text != "line xx" {
		t.Fatalf("expected the last %d messages, got %+v", recentMessages, stored[0].Messages)
	}
	if hasType(drain(b), "reported") {
		t.Fatal("the reported player must not be notified")
	}
	// Self reports and outsiders are rejected; bursts are limited.
	command(t, h, a, message{"type": "report", "player": a.id})
	if !hasError(a, "report") {
		t.Fatal("self report should fail")
	}
	command(t, h, c, message{"type": "report", "player": b.id})
	if !hasError(c, "report") {
		t.Fatal("outsider report should fail")
	}
	for i := 0; i < 3; i++ {
		command(t, h, a, message{"type": "report", "player": b.id})
	}
	if !hasError(a, "rate") {
		t.Fatal("expected report rate limit")
	}
	if len(stored) != 3 {
		t.Fatalf("expected 3 stored reports, got %d", len(stored))
	}
}

func TestReportLogWritesDailyFilesAndPrunes(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "reports")
	l := newReportLog(dir)
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	l.now = func() time.Time { return now }
	old := filepath.Join(dir, "reports-2026-07-01.jsonl")
	edge := filepath.Join(dir, "reports-2026-08-03.jsonl")
	unrelated := filepath.Join(dir, "notes.txt")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{old, edge, unrelated} {
		if err := os.WriteFile(name, []byte("x\n"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	l.record(report{At: now, Game: "g", Reporter: "a", Player: "b", Messages: []chatLine{{At: now, Text: "hi"}}})
	l.record(report{At: now.Add(time.Hour), Game: "g", Reporter: "a", Player: "b"})
	data, err := os.ReadFile(filepath.Join(dir, "reports-2026-11-01.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) != 2 {
		t.Fatalf("expected two lines, got %q", data)
	}
	var first report
	if err := json.Unmarshal([]byte(lines[0]), &first); err != nil || first.Messages[0].Text != "hi" {
		t.Fatalf("unexpected first line %q: %v", lines[0], err)
	}
	if info, err := os.Stat(filepath.Join(dir, "reports-2026-11-01.jsonl")); err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("report file should be owner-only: %v %v", info, err)
	}
	if _, err := os.Stat(old); !os.IsNotExist(err) {
		t.Fatal("files older than the retention window must be removed")
	}
	if _, err := os.Stat(edge); err != nil {
		t.Fatal("files inside the retention window must be kept")
	}
	if _, err := os.Stat(unrelated); err != nil {
		t.Fatal("unrelated files are never removed")
	}
}
