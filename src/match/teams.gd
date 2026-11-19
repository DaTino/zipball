class_name Teams
extends RefCounted
## Team constants shared by the arena (goal colors), players (body colors) and the HUD.

const COLORS: Array[Color] = [
	Color(0.15, 0.85, 0.8), # Team 0: teal
	Color(1.0, 0.5, 0.15), # Team 1: orange
]
const NAMES: Array[String] = ["Teal", "Orange"]


static func opponent(team: int) -> int:
	return 1 - team
