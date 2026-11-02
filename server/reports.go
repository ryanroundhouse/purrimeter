package main

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"time"
)

// Reports are the only chat content the relay ever writes down. Each report
// carries the reported player's most recent messages so the operator can judge
// it without the relay retaining a general chat history.
const recentMessages = 10
const reportRetention = 90 * 24 * time.Hour

type chatLine struct {
	At   time.Time `json:"at"`
	Text string    `json:"text"`
}
type report struct {
	At           time.Time  `json:"at"`
	Game         string     `json:"game"`
	GameName     string     `json:"game_name"`
	Reporter     string     `json:"reporter"`
	ReporterName string     `json:"reporter_name"`
	Player       string     `json:"player"`
	PlayerName   string     `json:"player_name"`
	Messages     []chatLine `json:"messages"`
}

var reportFile = regexp.MustCompile(`^reports-(\d{4}-\d{2}-\d{2})\.jsonl$`)

// reportLog appends one JSON line per report to a daily file and removes files
// older than the retention period. Failures are logged without any chat content.
type reportLog struct {
	dir  string
	keep time.Duration
	now  func() time.Time
}

func newReportLog(dir string) *reportLog {
	return &reportLog{dir: dir, keep: reportRetention, now: time.Now}
}

func (l *reportLog) record(r report) {
	if err := l.write(r); err != nil {
		log.Printf("Report could not be stored: %v", err)
	}
	l.prune()
}

func (l *reportLog) write(r report) error {
	if err := os.MkdirAll(l.dir, 0o700); err != nil {
		return err
	}
	line, err := json.Marshal(r)
	if err != nil {
		return err
	}
	name := filepath.Join(l.dir, "reports-"+r.At.UTC().Format("2006-01-02")+".jsonl")
	f, err := os.OpenFile(name, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0o600)
	if err != nil {
		return err
	}
	_, err = f.Write(append(line, '\n'))
	if closeErr := f.Close(); err == nil {
		err = closeErr
	}
	return err
}

func (l *reportLog) prune() {
	entries, err := os.ReadDir(l.dir)
	if err != nil {
		return
	}
	cutoff := l.now().UTC().Add(-l.keep)
	for _, entry := range entries {
		match := reportFile.FindStringSubmatch(entry.Name())
		if match == nil || entry.IsDir() {
			continue
		}
		day, err := time.Parse("2006-01-02", match[1])
		// A file is kept through the whole retention window after its last possible entry.
		if err == nil && day.Add(24*time.Hour).Before(cutoff) {
			if err := os.Remove(filepath.Join(l.dir, entry.Name())); err != nil {
				log.Printf("Report file could not be removed: %v", err)
			}
		}
	}
}
