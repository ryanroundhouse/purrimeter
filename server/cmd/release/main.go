package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"purrimeter/server/internal/releases"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
func run() error {
	if len(os.Args) < 3 {
		return fmt.Errorf("usage: release keygen KEYFILE | release sign KEYFILE MANIFEST OUTFILE")
	}
	path := os.Args[2]
	if os.Args[1] == "verify" {
		raw, e := os.ReadFile(path)
		if e != nil {
			return e
		}
		r, e := releases.Verify(raw)
		if e != nil {
			return e
		}
		return json.NewEncoder(os.Stdout).Encode(r)
	}
	if os.Args[1] == "keygen" {
		pub, key, err := ed25519.GenerateKey(rand.Reader)
		if err != nil {
			return err
		}
		if err = os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			return err
		}
		f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
		if err != nil {
			return err
		}
		_, err = f.Write(key)
		f.Close()
		if err == nil {
			fmt.Println(base64.StdEncoding.EncodeToString(pub))
		}
		return err
	}
	if len(os.Args) != 5 || os.Args[1] != "sign" {
		return fmt.Errorf("invalid command")
	}
	key, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if len(key) != ed25519.PrivateKeySize {
		return fmt.Errorf("invalid signing key")
	}
	raw, err := os.ReadFile(os.Args[3])
	if err != nil {
		return err
	}
	var r releases.Release
	if err = json.Unmarshal(raw, &r); err != nil {
		return err
	}
	signed, err := releases.Sign(r, key)
	if err != nil {
		return err
	}
	if _, err = releases.Verify(signed); err != nil {
		return err
	}
	return os.WriteFile(os.Args[4], signed, 0644)
}
