// Explicit post-deployment probe; creates and removes a private verification room.
package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"github.com/coder/websocket"
	"os"
	"purrimeter/server/internal/releases"
	"strings"
	"time"
)

func main() {
	if e := run(); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
func run() error {
	if len(os.Args) != 2 {
		return fmt.Errorf("usage: verify-release https://host/updates")
	}
	endpoint := os.Args[1]
	_, r, e := releases.Fetch(endpoint)
	if e != nil {
		return e
	}
	ws := strings.Replace(strings.Replace(strings.TrimSuffix(endpoint, "/updates")+"/ws", "https://", "wss://", 1), "http://", "ws://", 1)
	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()
	write := func(c *websocket.Conn, m map[string]any) error {
		b, _ := json.Marshal(m)
		return c.Write(ctx, websocket.MessageText, b)
	}
	read := func(c *websocket.Conn) (map[string]any, error) {
		_, b, e := c.Read(ctx)
		if e != nil {
			return nil, e
		}
		var m map[string]any
		e = json.Unmarshal(b, &m)
		return m, e
	}
	connect := func(id string) (*websocket.Conn, map[string]any, error) {
		c, _, e := websocket.Dial(ctx, ws, nil)
		if e != nil {
			return nil, nil, e
		}
		e = write(c, map[string]any{"type": "hello", "version": 1, "release": id, "name": "Release check"})
		if e != nil {
			c.CloseNow()
			return nil, nil, e
		}
		reply, e := read(c)
		return c, reply, e
	}
	for _, id := range []string{"", "development", "older-release", r.ID + "-newer"} {
		c, reply, e := connect(id)
		if c != nil {
			c.CloseNow()
		}
		if e != nil {
			return e
		}
		if reply["type"] != "error" {
			return fmt.Errorf("non-current release accepted: %q", id)
		}
		if id == "" && reply["code"] != "hello" {
			return fmt.Errorf("legacy upgrade message would be lost")
		}
	}
	a, reply, e := connect(r.ID)
	if e != nil {
		return e
	}
	defer a.CloseNow()
	if reply["type"] != "welcome" {
		return fmt.Errorf("current release rejected: %v", reply)
	}
	if _, e = read(a); e != nil {
		return e
	}
	var random [16]byte
	rand.Read(random[:])
	password := hex.EncodeToString(random[:])
	if e = write(a, map[string]any{"type": "create", "name": "Release verification", "password": password}); e != nil {
		return e
	}
	reply, e = read(a)
	if e != nil {
		return e
	}
	if reply["type"] != "joined" {
		return fmt.Errorf("create failed: %v", reply)
	}
	game := reply["game"].(map[string]any)["id"]
	b, reply, e := connect(r.ID)
	if e != nil {
		return e
	}
	defer b.CloseNow()
	if reply["type"] != "welcome" {
		return fmt.Errorf("second current client rejected")
	}
	read(b)
	write(b, map[string]any{"type": "join", "game": game, "password": password})
	reply, e = read(b)
	if e != nil {
		return e
	}
	if reply["type"] != "joined" {
		return fmt.Errorf("join failed: %v", reply)
	}
	for _, c := range []*websocket.Conn{b, a} {
		if e = write(c, map[string]any{"type": "leave", "game": game}); e != nil {
			return e
		}
		for {
			reply, e = read(c)
			if e != nil {
				return e
			}
			if reply["type"] == "left" {
				break
			}
		}
	}
	fmt.Printf("Verified signed release %s; current clients create/join successfully; legacy, development, older and newer mismatches rejected.\n", r.ID)
	return nil
}
