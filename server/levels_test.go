package main

import (
	"encoding/json"
	"testing"
)

func TestLevelProgressionVisibleState(t *testing.T) {
	for _, tc := range []struct {
		name   string
		fields message
		valid  bool
	}{
		{"legacy endless", message{}, true},
		{"finite wave", message{"garden_level": 2, "completed": false, "level": 12}, true},
		{"victory", message{"garden_level": 4, "completed": true, "level": 40, "best": 40, "run_best": 40}, true},
		{"endless", message{"garden_level": 5, "completed": false, "level": 100}, true},
		{"invalid choice", message{"garden_level": 6, "completed": false}, false},
		{"fractional choice", message{"garden_level": 1.5, "completed": false}, false},
		{"past final wave", message{"garden_level": 1, "completed": false, "level": 11}, false},
		{"unfinished victory", message{"garden_level": 1, "completed": true, "level": 10}, false},
		{"active victory", message{"garden_level": 1, "completed": true, "level": 10, "best": 10, "run_best": 10, "active": true}, false},
		{"endless victory", message{"garden_level": 5, "completed": true, "level": 50, "best": 50, "run_best": 50}, false},
		{"missing choice", message{"completed": true}, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			state := fieldFixture()
			for key, value := range tc.fields {
				state["garden"].(message)[key] = value
			}
			raw, err := json.Marshal(state)
			if err != nil {
				t.Fatal(err)
			}
			_, err = validateState(raw)
			if (err == nil) != tc.valid {
				t.Fatalf("validation error = %v, expected valid = %v", err, tc.valid)
			}
		})
	}
}
