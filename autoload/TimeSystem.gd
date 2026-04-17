extends Node

const ACTION_COSTS := {
	"scan": 3,
	"repair": 5,
	"reflect": 2,
	"move": 8,
	"stabilize": 4
}

func spend_for_action(action_id: String) -> int:
	var spent: int = int(ACTION_COSTS.get(action_id, 1))
	GameState.advance_cycles(spent, action_id)
	return spent
