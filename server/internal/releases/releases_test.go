package releases

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"strings"
	"testing"
)

func TestTrustAndCompleteRelease(t *testing.T) {
	pub, key, _ := ed25519.GenerateKey(rand.Reader)
	public := base64.StdEncoding.EncodeToString(pub)
	p := Package{URL: "https://example.com/game.zip", SHA256: strings.Repeat("a", 64), Size: 100}
	r := Release{ID: "one", Sequence: 1, Version: "1.0", Packages: map[string]Package{"macos": p, "windows": p}}
	raw, _ := Sign(r, key)
	if _, e := VerifyWithKey(raw, public); e != nil {
		t.Fatal(e)
	}
	var env Envelope
	json.Unmarshal(raw, &env)
	env.Payload = base64.StdEncoding.EncodeToString([]byte(`{"id":"tampered"}`))
	bad, _ := json.Marshal(env)
	if _, e := VerifyWithKey(bad, public); e == nil {
		t.Fatal("tampering accepted")
	}
	delete(r.Packages, "windows")
	raw, _ = Sign(r, key)
	if _, e := VerifyWithKey(raw, public); e == nil {
		t.Fatal("partial platform release accepted")
	}
	for _, url := range []string{"http://example.com/a", "file:///tmp/a", "https://user:pass@example.com/a"} {
		if SafeURL(url) {
			t.Fatal("unsafe URL accepted", url)
		}
	}
}
