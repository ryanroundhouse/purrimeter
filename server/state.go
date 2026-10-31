package main

import (
	"encoding/json"
	"errors"
	"math"
)

// This is a bounded visual representation, not a save file or proof of fair play.
type fieldState struct {
	Revision float64          `json:"revision"`
	Sequence float64          `json:"sequence"`
	Garden   map[string]any   `json:"garden"`
	Paused   *bool            `json:"paused"`
	Speed    float64          `json:"speed"`
	Shots    []map[string]any `json:"shots"`
	Sounds   []map[string]any `json:"sounds,omitempty"`
}

func number(v any, low, high float64, integer bool) bool {
	n, ok := v.(float64)
	return ok && !math.IsNaN(n) && !math.IsInf(n, 0) && n >= low && n <= high && (!integer || n == math.Floor(n))
}
func boolean(v any) bool                 { _, ok := v.(bool); return ok }
func array(v any, max int) ([]any, bool) { a, ok := v.([]any); return a, ok && len(a) <= max }
func validateState(raw []byte) (*fieldState, error) {
	bad := errors.New("invalid visible state")
	s := fieldState{Revision: -1, Sequence: -1}
	if len(raw) > maxMessage-1024 || json.Unmarshal(raw, &s) != nil || !number(s.Revision, 0, 1e9, true) || !number(s.Sequence, 0, 9e15, true) || !number(s.Speed, 1, 2, true) || s.Paused == nil || s.Shots == nil || len(s.Shots) > 1024 {
		return nil, bad
	}
	g := s.Garden
	if len(s.Sounds) > 128 {
		return nil, bad
	}
	lastSoundID := float64(0)
	for _, sound := range s.Sounds {
		if !number(sound["id"], 1, 9e15, true) || !number(sound["tier"], 1, 6, true) || sound["id"].(float64) <= lastSoundID {
			return nil, bad
		}
		switch sound["name"] {
		case "bolt", "cannon", "frost", "coin", "build", "upgrade", "wave", "clear", "escape", "break", "win", "lose", "boss", "rebirth":
		default:
			return nil, bad
		}
		lastSoundID = sound["id"].(float64)
	}
	if g == nil {
		return nil, bad
	}
	for _, k := range []string{"level", "best", "run_best", "rebirths", "spawned"} {
		if !number(g[k], 0, 1e9, true) {
			return nil, bad
		}
	}
	if g["level"].(float64) < 1 {
		return nil, bad
	}
	for _, k := range []string{"training", "kills"} {
		if !number(g[k], 0, 9e15, true) {
			return nil, bad
		}
	}
	for _, k := range []string{"coins", "bonus_points", "elapsed"} {
		if !number(g[k], -1e100, 1e16, false) {
			return nil, bad
		}
	}
	if !boolean(g["active"]) || !boolean(g["auto_start"]) || !number(g["auto_start_remaining"], 0, 3, false) {
		return nil, bad
	}
	for _, key := range []string{"powerups", "discovered"} {
		m, ok := g[key].(map[string]any)
		if !ok || len(m) > 30 {
			return nil, bad
		}
		for id, v := range m {
			if !validText(id, 24, false) || (key == "powerups" && !number(v, 0, 1e4, true)) || (key == "discovered" && !boolean(v)) {
				return nil, bad
			}
		}
	}
	levels, ok := array(g["cat_milestones"], 3)
	if !ok || len(levels) != 3 {
		return nil, bad
	}
	for _, v := range levels {
		if !number(v, 0, 6, true) {
			return nil, bad
		}
	}
	towers, ok := array(g["towers"], 254)
	if !ok {
		return nil, bad
	}
	cells := map[float64]bool{}
	for _, value := range towers {
		t, ok := value.(map[string]any)
		if !ok || !number(t["cell"], 0, 255, true) || !number(t["kind"], 0, 2, true) || !number(t["tier"], 1, 6, true) || !number(t["hp"], 0, 1, false) {
			return nil, bad
		}
		for _, k := range []string{"spent", "cooldown", "flash"} {
			if !number(t[k], -1e100, 1e16, false) {
				return nil, bad
			}
		}
		cell := t["cell"].(float64)
		if cells[cell] {
			return nil, bad
		}
		cells[cell] = true
	}
	enemies, ok := array(g["enemies"], 100)
	if !ok {
		return nil, bad
	}
	ids := map[float64]bool{}
	for _, value := range enemies {
		e, ok := value.(map[string]any)
		if !ok {
			return nil, bad
		}
		for k, high := range map[string]float64{"id": 1e9, "kind": 3, "cell": 255} {
			if !number(e[k], 0, high, true) {
				return nil, bad
			}
		}
		if !number(e["boss"], -1, 3, true) || !number(e["next"], -1, 255, true) || !number(e["hp"], 0, 1, false) || !number(e["progress"], 0, 1, false) || !boolean(e["frenzied"]) {
			return nil, bad
		}
		for _, k := range []string{"hp_power", "bounty_power", "slow", "attack", "frustration", "stun", "burn_left"} {
			if !number(e[k], -1e100, 1e16, false) {
				return nil, bad
			}
		}
		id := e["id"].(float64)
		if ids[id] {
			return nil, bad
		}
		ids[id] = true
	}
	for _, shot := range s.Shots {
		if !number(shot["kind"], 0, 2, true) || !number(shot["tier"], 1, 6, true) || !number(shot["life"], 0, 0.25, false) {
			return nil, bad
		}
		for _, key := range []string{"from", "to"} {
			a, ok := array(shot[key], 2)
			if !ok || len(a) != 2 || !number(a[0], 0, 15, false) || !number(a[1], 0, 15, false) {
				return nil, bad
			}
		}
	}
	return &s, nil
}
