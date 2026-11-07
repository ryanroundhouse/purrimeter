package main

import (
	"encoding/json"
	"testing"
)

func TestTerrainVisibleState(t *testing.T) {
	for _, tc := range []struct {
		name    string
		terrain any
		valid   bool
	}{
		{"legacy", nil, true},
		{"empty", []any{}, true},
		{"rocks and water", []any{message{"cell": 40, "kind": 0, "style": 2}, message{"cell": 41, "kind": 1, "style": 1}}, true},
		{"wrong type", message{}, false},
		{"duplicate", []any{message{"cell": 40, "kind": 0, "style": 0}, message{"cell": 40, "kind": 1, "style": 0}}, false},
		{"gate", []any{message{"cell": 128, "kind": 0, "style": 0}}, false},
		{"approach", []any{message{"cell": 129, "kind": 0, "style": 0}}, false},
		{"fractional", []any{message{"cell": 40.5, "kind": 0, "style": 0}}, false},
		{"unknown style", []any{message{"cell": 40, "kind": 0, "style": 3}}, false},
		{"unknown kind", []any{message{"cell": 40, "kind": 2, "style": 0}}, false},
		{"unbounded", make([]any, 65), false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			state := fieldFixture()
			if tc.terrain != nil {
				state["garden"].(message)["terrain"] = tc.terrain
			}
			raw, _ := json.Marshal(state)
			if _, err := validateState(raw); (err == nil) != tc.valid {
				t.Fatalf("valid=%v err=%v", tc.valid, err)
			}
		})
	}
	state := fieldFixture()
	g := state["garden"].(message)
	g["terrain"] = []any{message{"cell": 40, "kind": 0, "style": 0}}
	g["towers"] = []any{message{"cell": 40, "kind": 0, "tier": 1, "hp": 1, "spent": 1, "cooldown": 0, "flash": 0}}
	raw, _ := json.Marshal(state)
	if _, err := validateState(raw); err == nil {
		t.Fatal("tower overlaps terrain")
	}
}
