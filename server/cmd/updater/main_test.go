package main

import (
	"archive/zip"
	"fmt"
	"os"
	"path/filepath"
	"purrimeter/server/internal/releases"
	"runtime"
	"strings"
	"testing"
)

func TestArchiveTraversalRejected(t *testing.T) {
	for _, name := range []string{"../outside", "/absolute", "C:/escape", "a/../../escape", "..\\escape"} {
		dir := t.TempDir()
		path := filepath.Join(dir, "test.zip")
		f, _ := os.Create(path)
		z := zip.NewWriter(f)
		w, _ := z.Create(name)
		w.Write([]byte("bad"))
		z.Close()
		f.Close()
		if e := extract(path, filepath.Join(dir, "out")); e == nil {
			t.Fatal("accepted", name)
		}
	}
}
func TestPackageIntegrity(t *testing.T) {
	path := filepath.Join(t.TempDir(), "package")
	os.WriteFile(path, []byte("actual bytes"), 0600)
	if e := verifyFile(path, releases.Package{Size: 12, SHA256: strings.Repeat("0", 64)}); e == nil {
		t.Fatal("accepted wrong hash")
	}
	if e := verifyFile(path, releases.Package{Size: 5}); e == nil {
		t.Fatal("accepted wrong size")
	}
}

func TestInstallRestoresGameAndSaveOnFailedStartup(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("shell fixture runs on Unix; Windows helper is cross-compiled separately")
	}
	root := t.TempDir()
	work := filepath.Join(root, "updates")
	os.Mkdir(work, 0700)
	stage := filepath.Join(root, "stage")
	os.Mkdir(stage, 0700)
	old := filepath.Join(root, "game")
	oldBytes := []byte("#!/bin/sh\nexit 0\n")
	os.WriteFile(old, oldBytes, 0700)
	save := filepath.Join(root, "save.json")
	os.WriteFile(save, []byte("original garden"), 0600)
	achievements := filepath.Join(root, "achievements.json")
	os.WriteFile(achievements, []byte("earned badges"), 0600)
	next := filepath.Join(stage, "new")
	os.WriteFile(next, []byte(fmt.Sprintf("#!/bin/sh\nprintf changed > %q\nprintf changed > %q\nexit 1\n", save, achievements)), 0700)
	o := options{work: work, parent: 999999}
	tx := transaction{Items: []item{{Target: old, Source: next, Backup: filepath.Join(stage, "previous"), Existed: true}}, Data: root, Executable: old, Phase: "prepared"}
	saveTransaction(o, tx)
	if err := install(o); err == nil {
		t.Fatal("failed startup accepted")
	}
	got, _ := os.ReadFile(save)
	if string(got) != "original garden" {
		t.Fatal("garden was not restored")
	}
	got, _ = os.ReadFile(achievements)
	if string(got) != "earned badges" {
		t.Fatal("achievements were not restored")
	}
	got, _ = os.ReadFile(old)
	if string(got) != string(oldBytes) {
		t.Fatal("previous game was not restored")
	}
}
func TestInstallAcknowledgesHealthyStartup(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("Unix shell fixture")
	}
	root := t.TempDir()
	work := filepath.Join(root, "updates")
	os.Mkdir(work, 0700)
	stage := filepath.Join(root, "stage")
	os.Mkdir(stage, 0700)
	old := filepath.Join(root, "game")
	os.WriteFile(old, []byte("#!/bin/sh\nexit 0\n"), 0700)
	next := filepath.Join(stage, "new")
	os.WriteFile(next, []byte("#!/bin/sh\nprintf ready > \"$3\"\nsleep 0.3\n"), 0700)
	o := options{work: work, parent: 999999}
	saveTransaction(o, transaction{Items: []item{{Target: old, Source: next, Backup: filepath.Join(stage, "previous"), Existed: true}}, Data: root, Executable: old, Phase: "prepared"})
	if e := install(o); e != nil {
		t.Fatal(e)
	}
	raw, _ := os.ReadFile(filepath.Join(work, "transaction.json"))
	if !strings.Contains(string(raw), "complete") {
		t.Fatal("healthy startup not committed")
	}
}
