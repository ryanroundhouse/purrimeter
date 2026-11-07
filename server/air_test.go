package main

import (
	"encoding/json"
	"testing"
)

func TestAirVisibleState(t *testing.T) {
	for _, tc := range []struct {
		name  string
		edit  message
		valid bool
	}{
		{"flight over rock", message{}, true},
		{"ground enemy in rock", message{"kind": 0}, false},
		{"unknown species", message{"kind": 5}, false},
		{"fractional species", message{"kind": 4.5}, false},
		{"off flight line", message{"cell": 118}, false},
		{"reverse flight", message{"next": 133}, false},
		{"flying boss", message{"boss": 0}, false},
		{"frenzied flyer", message{"frenzied": true}, false},
		{"burning flyer", message{"burn_left": 1}, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			state := fieldFixture()
			g := state["garden"].(message)
			g["cat_milestones"] = []int{0, 0, 0, 1}
			g["wave_roster_level"] = 2
			g["unlocked_level"] = 2
			g["terrain"] = []any{message{"cell": 134, "kind": 0, "style": 0}}
			g["towers"] = []any{message{"cell": 135, "kind": 3, "tier": 1, "hp": 1, "spent": 2, "cooldown": 0, "flash": 0}}
			enemy := message{"id": 1, "kind": 4, "boss": -1, "cell": 134, "next": 135, "progress": .5, "hp": 1, "hp_power": 2, "bounty_power": 1, "slow": 0, "attack": 0, "frustration": 0, "frenzied": false, "stun": 0, "burn_left": 0}
			for k, v := range tc.edit {
				enemy[k] = v
			}
			g["enemies"] = []any{enemy}
			state["shots"] = []any{message{"from": []float64{7, 8}, "to": []float64{6.5, 8}, "kind": 3, "tier": 1, "life": .2}}
			raw, _ := json.Marshal(state)
			if _, err := validateState(raw); (err == nil) != tc.valid {
				t.Fatalf("valid=%v err=%v", tc.valid, err)
			}
		})
	}
}
