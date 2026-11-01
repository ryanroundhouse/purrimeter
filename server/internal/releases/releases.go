// Package releases is the trust boundary shared by publication, relay and updater.
package releases

import (
	"crypto/ed25519"
	"crypto/sha256"
	_ "embed"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

//go:embed public.key
var PublicKey string

type Package struct {
	URL    string `json:"url"`
	SHA256 string `json:"sha256"`
	Size   int64  `json:"size"`
}
type Release struct {
	ID       string             `json:"id"`
	Sequence int64              `json:"sequence"`
	Version  string             `json:"version"`
	Packages map[string]Package `json:"packages"`
}
type Envelope struct {
	Payload   string `json:"payload"`
	Signature string `json:"signature"`
}

func Verify(raw []byte) (Release, error) { return VerifyWithKey(raw, PublicKey) }
func VerifyWithKey(raw []byte, key string) (Release, error) {
	var r Release
	var e Envelope
	if len(raw) > 65536 || json.Unmarshal(raw, &e) != nil {
		return r, errors.New("invalid release metadata")
	}
	pub, err := base64.StdEncoding.DecodeString(strings.TrimSpace(key))
	if err != nil || len(pub) != ed25519.PublicKeySize {
		return r, errors.New("invalid official public key")
	}
	body, err := base64.StdEncoding.DecodeString(e.Payload)
	if err != nil {
		return r, err
	}
	sig, err := base64.StdEncoding.DecodeString(e.Signature)
	if err != nil || !ed25519.Verify(pub, body, sig) {
		return r, errors.New("release signature is not trusted")
	}
	if json.Unmarshal(body, &r) != nil || r.ID == "" || r.Sequence <= 0 || r.Version == "" {
		return r, errors.New("invalid release identity")
	}
	for _, platform := range []string{"macos", "windows"} {
		p, ok := r.Packages[platform]
		hash, err := hex.DecodeString(p.SHA256)
		if !ok || p.Size <= 0 || p.Size > 2<<30 || err != nil || len(hash) != 32 || !SafeURL(p.URL) {
			return r, fmt.Errorf("invalid %s package", platform)
		}
	}
	return r, nil
}
func Sign(r Release, key ed25519.PrivateKey) ([]byte, error) {
	body, err := json.Marshal(r)
	if err != nil {
		return nil, err
	}
	return json.Marshal(Envelope{base64.StdEncoding.EncodeToString(body), base64.StdEncoding.EncodeToString(ed25519.Sign(key, body))})
}
func SafeURL(s string) bool {
	u, e := url.Parse(s)
	return e == nil && u.User == nil && u.Host != "" && u.Fragment == "" && (u.Scheme == "https" || (u.Scheme == "http" && (u.Hostname() == "localhost" || u.Hostname() == "127.0.0.1" || u.Hostname() == "::1")))
}
func Client(timeout time.Duration) *http.Client {
	return &http.Client{Timeout: timeout, CheckRedirect: func(req *http.Request, via []*http.Request) error {
		if len(via) >= 5 || !SafeURL(req.URL.String()) {
			return errors.New("unsafe update redirect")
		}
		return nil
	}}
}
func Fetch(address string) ([]byte, Release, error) {
	if !SafeURL(address) {
		return nil, Release{}, errors.New("updates require HTTPS (HTTP is allowed only on loopback)")
	}
	resp, err := Client(12 * time.Second).Get(address)
	if err != nil {
		return nil, Release{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, Release{}, fmt.Errorf("release server returned %d", resp.StatusCode)
	}
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 65537))
	if err != nil {
		return nil, Release{}, err
	}
	r, err := Verify(raw)
	return raw, r, err
}
func Digest(reader io.Reader) (string, error) {
	h := sha256.New()
	_, err := io.Copy(h, reader)
	return hex.EncodeToString(h.Sum(nil)), err
}
