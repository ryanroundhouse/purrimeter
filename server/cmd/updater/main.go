// The updater runs outside the game so Windows can release executable locks.
package main

import (
	"archive/zip"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"purrimeter/server/internal/releases"
	"runtime"
	"strings"
	"time"
)

type options struct {
	work, url, executable string
	parent                int
}
type item struct {
	Target    string `json:"target"`
	Source    string `json:"source"`
	Backup    string `json:"backup"`
	Existed   bool   `json:"existed"`
	Installed bool   `json:"installed"`
}
type transaction struct {
	Items      []item `json:"items"`
	Data       string `json:"data"`
	Executable string `json:"executable"`
	Phase      string `json:"phase"`
}

var dataFiles = []string{"save.json", "settings.cfg", "multiplayer.cfg", "achievements.json"}
var resultPath string

func emit(value any) error {
	b, e := json.Marshal(value)
	if e != nil {
		return e
	}
	if resultPath != "" {
		return atomicWrite(resultPath, b)
	}
	_, e = os.Stdout.Write(append(b, '\n'))
	return e
}
func main() {
	err := run()
	if err != nil {
		_ = emit(map[string]any{"ok": false, "error": err.Error()})
		os.Exit(1)
	}
}
func run() error {
	if len(os.Args) < 2 {
		return errors.New("missing updater command")
	}
	mode := os.Args[1]
	fs := flag.NewFlagSet(mode, flag.ContinueOnError)
	o := options{}
	fs.StringVar(&resultPath, "result", "", "result file")
	fs.StringVar(&o.work, "work", "", "update workspace")
	fs.StringVar(&o.url, "url", "", "release endpoint")
	fs.StringVar(&o.executable, "executable", "", "installed game")
	fs.IntVar(&o.parent, "parent", 0, "game PID")
	if err := fs.Parse(os.Args[2:]); err != nil {
		return err
	}
	if o.work == "" {
		return errors.New("missing workspace")
	}
	var err error
	o.work, err = filepath.Abs(o.work)
	if err != nil {
		return err
	}
	if err = os.MkdirAll(o.work, 0700); err != nil {
		return err
	}
	var result any = map[string]any{"ok": true}
	switch mode {
	case "check":
		raw, r, e := releases.Fetch(o.url)
		if e != nil {
			return e
		}
		if e = atomicWrite(filepath.Join(o.work, "release.json"), raw); e != nil {
			return e
		}
		platform := "windows"
		if runtime.GOOS == "darwin" {
			platform = "macos"
		}
		cached := verifyFile(filepath.Join(o.work, "package.zip"), r.Packages[platform]) == nil
		if !cached {
			_ = os.Remove(filepath.Join(o.work, "package.zip"))
		}
		result = map[string]any{"ok": true, "release": r, "cached": cached}
	case "download":
		err = download(o)
	case "prepare":
		err = prepare(o)
	case "install":
		err = install(o)
		if err != nil {
			_ = atomicWrite(filepath.Join(o.work, "error.txt"), []byte(err.Error()))
		}
	default:
		return errors.New("unknown updater command")
	}
	if err != nil {
		return err
	}
	return emit(result)
}
func atomicWrite(path string, b []byte) error {
	temp := path + ".tmp"
	if err := os.WriteFile(temp, b, 0600); err != nil {
		return err
	}
	return os.Rename(temp, path)
}
func packageInfo(o options) (releases.Package, error) {
	raw, e := os.ReadFile(filepath.Join(o.work, "release.json"))
	if e != nil {
		return releases.Package{}, e
	}
	r, e := releases.Verify(raw)
	if e != nil {
		return releases.Package{}, e
	}
	platform := "windows"
	if runtime.GOOS == "darwin" {
		platform = "macos"
	}
	if runtime.GOOS != "windows" && runtime.GOOS != "darwin" {
		return releases.Package{}, errors.New("automatic updates support macOS and Windows")
	}
	return r.Packages[platform], nil
}
func download(o options) error {
	p, e := packageInfo(o)
	if e != nil {
		return e
	}
	resp, e := releases.Client(30 * time.Minute).Get(p.URL)
	if e != nil {
		return e
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("download returned %d", resp.StatusCode)
	}
	path := filepath.Join(o.work, "package.zip.part")
	f, e := os.Create(path)
	if e != nil {
		return e
	}
	n, e := io.Copy(f, io.LimitReader(resp.Body, p.Size+1))
	ce := f.Close()
	if e != nil {
		return e
	}
	if ce != nil {
		return ce
	}
	if n != p.Size {
		return errors.New("download size does not match signed release")
	}
	if e = verifyFile(path, p); e != nil {
		return e
	}
	return os.Rename(path, filepath.Join(o.work, "package.zip"))
}
func verifyFile(path string, p releases.Package) error {
	f, e := os.Open(path)
	if e != nil {
		return e
	}
	defer f.Close()
	s, e := f.Stat()
	if e != nil {
		return e
	}
	if s.Size() != p.Size {
		return errors.New("package size mismatch")
	}
	digest, e := releases.Digest(f)
	if e != nil {
		return e
	}
	if digest != p.SHA256 {
		return errors.New("package checksum mismatch")
	}
	return nil
}
func extract(path, destination string) error {
	z, e := zip.OpenReader(path)
	if e != nil {
		return e
	}
	defer z.Close()
	var total int64
	for _, f := range z.File {
		name := strings.ReplaceAll(f.Name, "\\", "/")
		clean := filepath.Clean(filepath.FromSlash(name))
		if clean == "." || filepath.IsAbs(clean) || clean == ".." || strings.HasPrefix(clean, ".."+string(filepath.Separator)) || strings.Contains(name, ":") {
			return errors.New("unsafe archive path")
		}
		if f.Mode()&os.ModeSymlink != 0 {
			return errors.New("archive symlinks are not supported")
		}
		if f.Mode()&os.ModeType != 0 && !f.FileInfo().IsDir() {
			return errors.New("unsupported archive entry")
		}
		total += int64(f.UncompressedSize64)
		if total > 4<<30 || total < 0 {
			return errors.New("expanded package is too large")
		}
		target := filepath.Join(destination, clean)
		if f.FileInfo().IsDir() {
			if e = os.MkdirAll(target, 0755); e != nil {
				return e
			}
			continue
		}
		if e = os.MkdirAll(filepath.Dir(target), 0755); e != nil {
			return e
		}
		reader, e := f.Open()
		if e != nil {
			return e
		}
		out, e := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, f.Mode().Perm()|0600)
		if e != nil {
			reader.Close()
			return e
		}
		_, e = io.Copy(out, io.LimitReader(reader, int64(f.UncompressedSize64)+1))
		ce := out.Close()
		reader.Close()
		if e != nil {
			return e
		}
		if ce != nil {
			return ce
		}
	}
	return nil
}
func prepare(o options) error {
	p, e := packageInfo(o)
	if e != nil {
		return e
	}
	if e = verifyFile(filepath.Join(o.work, "package.zip"), p); e != nil {
		return e
	}
	exe, e := filepath.Abs(o.executable)
	if e != nil {
		return e
	}
	exe, e = filepath.EvalSymlinks(exe)
	if e != nil {
		return e
	}
	var targets []item
	parent := filepath.Dir(exe)
	if runtime.GOOS == "darwin" {
		if filepath.Base(exe) != "Purrimeter" || filepath.Base(parent) != "MacOS" || filepath.Base(filepath.Dir(parent)) != "Contents" {
			return errors.New("run the installed Purrimeter app to update")
		}
		app := filepath.Dir(filepath.Dir(parent))
		parent = filepath.Dir(app)
		targets = []item{{Target: app, Source: "macos/Purrimeter.app"}}
	} else {
		if !strings.EqualFold(filepath.Base(exe), "Purrimeter.exe") {
			return errors.New("run the installed Purrimeter game to update")
		}
		for _, name := range []string{"Purrimeter.pck", "PurrimeterUpdater.exe", "Purrimeter.exe"} {
			targets = append(targets, item{Target: filepath.Join(parent, name), Source: name})
		}
	}
	stage, e := os.MkdirTemp(parent, ".purrimeter-update-")
	if e != nil {
		return fmt.Errorf("cannot replace this installation; extract the verified package manually: %w", e)
	}
	good := false
	defer func() {
		if !good {
			os.RemoveAll(stage)
		}
	}()
	if e = extract(filepath.Join(o.work, "package.zip"), filepath.Join(stage, "new")); e != nil {
		return e
	}
	for i := range targets {
		targets[i].Source = filepath.Join(stage, "new", targets[i].Source)
		if _, e = os.Stat(targets[i].Source); e != nil {
			return e
		}
		targets[i].Backup = filepath.Join(stage, fmt.Sprintf("previous-%d", i))
		_, e = os.Lstat(targets[i].Target)
		targets[i].Existed = e == nil
		if e != nil && !os.IsNotExist(e) {
			return e
		}
	}
	if runtime.GOOS == "darwin" {
		cmd := exec.Command("/usr/bin/codesign", "--verify", "--deep", "--strict", targets[0].Source)
		if b, e := cmd.CombinedOutput(); e != nil {
			return fmt.Errorf("app verification failed: %s", b)
		}
	}
	self, e := os.Executable()
	if e != nil {
		return e
	}
	runner := filepath.Join(o.work, "runner")
	if runtime.GOOS == "windows" {
		runner += ".exe"
	}
	if e = copyFile(self, runner, 0700); e != nil {
		return e
	}
	tx := transaction{Items: targets, Data: filepath.Dir(o.work), Executable: exe, Phase: "prepared"}
	if e = saveTransaction(o, tx); e != nil {
		return e
	}
	_ = os.Remove(filepath.Join(o.work, "healthy"))
	_ = os.Remove(filepath.Join(o.work, "error.txt"))
	good = true
	return nil
}
func saveTransaction(o options, t transaction) error {
	b, e := json.Marshal(t)
	if e != nil {
		return e
	}
	return atomicWrite(filepath.Join(o.work, "transaction.json"), b)
}
func copyFile(source, dest string, mode os.FileMode) error {
	in, e := os.Open(source)
	if e != nil {
		return e
	}
	defer in.Close()
	out, e := os.OpenFile(dest, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
	if e != nil {
		return e
	}
	_, e = io.Copy(out, in)
	ce := out.Close()
	if e != nil {
		return e
	}
	return ce
}
func install(o options) error {
	raw, e := os.ReadFile(filepath.Join(o.work, "transaction.json"))
	if e != nil {
		return e
	}
	var tx transaction
	if e = json.Unmarshal(raw, &tx); e != nil {
		return e
	}
	if tx.Phase != "prepared" {
		return errors.New("update is not prepared")
	}
	if o.parent <= 0 {
		return errors.New("missing game process")
	}
	if e = atomicWrite(filepath.Join(o.work, "ready"), []byte("ready")); e != nil {
		return e
	}
	deadline := time.Now().Add(45 * time.Second)
	for processAlive(o.parent) {
		if time.Now().After(deadline) {
			return errors.New("game did not exit; update cancelled")
		}
		time.Sleep(100 * time.Millisecond)
	}
	backup := filepath.Join(filepath.Dir(tx.Items[0].Backup), "player-data")
	if e = os.Mkdir(backup, 0700); e != nil {
		return e
	}
	for _, name := range dataFiles {
		path := filepath.Join(tx.Data, name)
		if _, e = os.Stat(path); os.IsNotExist(e) {
			continue
		}
		if e != nil {
			return e
		}
		if e = copyFile(path, filepath.Join(backup, name), 0600); e != nil {
			return e
		}
	}
	tx.Phase = "installing"
	if e = saveTransaction(o, tx); e != nil {
		return e
	}
	rollback := func(cause error) error {
		var failures []string
		for i := len(tx.Items) - 1; i >= 0; i-- {
			it := tx.Items[i]
			if it.Installed {
				if e := os.RemoveAll(it.Target); e != nil {
					failures = append(failures, e.Error())
					continue
				}
			}
			if _, e := os.Stat(it.Backup); e == nil {
				if e = os.Rename(it.Backup, it.Target); e != nil {
					failures = append(failures, e.Error())
				}
			}
		}
		for _, name := range dataFiles {
			src := filepath.Join(backup, name)
			dest := filepath.Join(tx.Data, name)
			if _, e := os.Stat(src); e == nil {
				if e = copyFile(src, dest, 0600); e != nil {
					failures = append(failures, e.Error())
				}
			} else if os.IsNotExist(e) {
				_ = os.Remove(dest)
			}
		}
		tx.Phase = "recovered"
		_ = saveTransaction(o, tx)
		if len(failures) > 0 {
			return fmt.Errorf("%v; recovery needs help: %s; backups: %s", cause, strings.Join(failures, "; "), backup)
		}
		_ = exec.Command(tx.Executable, "--", "--update-recovered").Start()
		return fmt.Errorf("%v; previous game and garden restored", cause)
	}
	for i := range tx.Items {
		it := &tx.Items[i]
		if it.Existed {
			if e = os.Rename(it.Target, it.Backup); e != nil {
				return rollback(e)
			}
		}
		if e = os.Rename(it.Source, it.Target); e != nil {
			return rollback(e)
		}
		it.Installed = true
		if e = saveTransaction(o, tx); e != nil {
			return rollback(e)
		}
	}
	cmd := exec.Command(tx.Executable, "--", "--update-ack", filepath.Join(o.work, "healthy"))
	if e = cmd.Start(); e != nil {
		return rollback(e)
	}
	finished := make(chan error, 1)
	go func() { finished <- cmd.Wait() }()
	deadline = time.Now().Add(60 * time.Second)
	for time.Now().Before(deadline) {
		if _, e = os.Stat(filepath.Join(o.work, "healthy")); e == nil {
			tx.Phase = "complete"
			return saveTransaction(o, tx)
		}
		select {
		case e := <-finished:
			if _, ackErr := os.Stat(filepath.Join(o.work, "healthy")); ackErr == nil {
				tx.Phase = "complete"
				return saveTransaction(o, tx)
			}
			return rollback(fmt.Errorf("new game exited before startup completed: %v", e))
		default:
		}
		time.Sleep(100 * time.Millisecond)
	}
	_ = cmd.Process.Kill()
	<-finished
	return rollback(errors.New("new game did not complete startup"))
}
