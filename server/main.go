package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/coder/websocket"
)

func main() {
	key, err := signingKey(env("SIGNING_KEY_FILE", "data/signing.key"))
	if err != nil {
		log.Fatal(err)
	}
	h := newHub(key)
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("/ws", h.serve)
	srv := &http.Server{Addr: env("LISTEN_ADDR", "127.0.0.1:8080"), Handler: mux, ReadHeaderTimeout: 5 * time.Second, IdleTimeout: 60 * time.Second, MaxHeaderBytes: 8192}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				h.expire()
			case <-ctx.Done():
				return
			}
		}
	}()
	go func() {
		<-ctx.Done()
		h.close()
		shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutdown)
	}()
	listener, err := net.Listen("tcp", srv.Addr)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("Purrimeter relay listening on %s", listener.Addr())
	if err := srv.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

func env(name, fallback string) string {
	if s := os.Getenv(name); s != "" {
		return s
	}
	return fallback
}

func signingKey(path string) ([]byte, error) {
	if b, err := os.ReadFile(path); err == nil {
		if len(b) != 32 {
			return nil, errors.New("signing key must contain 32 bytes")
		}
		return b, nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return nil, err
	}
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return nil, err
	}
	_, err = f.Write(b)
	closeErr := f.Close()
	if err != nil {
		return nil, err
	}
	return b, closeErr
}

func randomID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b[:])
}

func (h *hub) serve(w http.ResponseWriter, r *http.Request) {
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		http.Error(w, "Invalid address", 400)
		return
	}
	// Enable only behind the supplied private reverse proxy, which overwrites this header.
	if os.Getenv("TRUST_PROXY") == "true" {
		if forwarded := strings.TrimSpace(strings.Split(r.Header.Get("X-Forwarded-For"), ",")[0]); net.ParseIP(forwarded) != nil {
			ip = forwarded
		}
	}
	if !h.admit(ip) {
		http.Error(w, "Server busy; try again shortly", 429)
		return
	}
	defer h.release(ip)
	// Native clients send no Origin. Reject browser origins unless explicitly configured.
	opts := &websocket.AcceptOptions{OriginPatterns: strings.Fields(os.Getenv("ALLOWED_ORIGINS")), CompressionMode: websocket.CompressionDisabled}
	c, err := websocket.Accept(w, r, opts)
	if err != nil {
		return
	}
	defer c.CloseNow()
	c.SetReadLimit(maxMessage)
	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()
	p := newPeer(c, cancel)
	defer h.disconnected(p)
	deadline, done := context.WithTimeout(ctx, 8*time.Second)
	kind, raw, err := c.Read(deadline)
	done()
	if err != nil || kind != websocket.MessageText {
		return
	}
	if !h.authenticate(p, raw) {
		select {
		case reply := <-p.queue:
			deadline, done := context.WithTimeout(ctx, time.Second)
			_ = c.Write(deadline, websocket.MessageText, reply)
			done()
		default:
		}
		return
	}
	go p.writeLoop(ctx)
	for {
		deadline, done = context.WithTimeout(ctx, 35*time.Second)
		kind, raw, err = c.Read(deadline)
		done()
		if err != nil {
			return
		}
		if kind != websocket.MessageText {
			return
		}
		if !h.handle(p, raw) {
			return
		}
	}
}
