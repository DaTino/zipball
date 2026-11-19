class_name MatchSettings
extends Resource
## Choices made on the main menu before a match: the arena's grid and zip points, gravity,
## the ball and goal sizes, how the grapple behaves, the venue, and how the match is won (time or
## points). The defaults are the game
## as it was before the menu existed. The menu remembers the last choices in user:// (see
## save() and load_saved()).

enum Size { SMALL, MEDIUM, LARGE }
## Reel: once the hook lands, the line pulls you in and you hang (D21). Swing: it holds its
## length and you swing on it, like the first prototype.
enum GrappleMode { REEL, SWING }
## Where the match takes place: the sky, floor, weather and zip point colors (see VENUE_SCENES).
enum Venue { CLASSIC, SPACE, SNOW, LAVA, DESERT }
## How a match ends (D15). Timed: after time_limit_minutes of play, or in sudden-death
## overtime on a tie. Points: when a team reaches points_to_win.
enum MatchRule { TIMED, POINTS }

## Beams per side. Always even, so an open cell sits at the center for the faceoff.
const GRID_SIZES: Array[int] = [4, 6, 8, 10]
## Radius (m) for each Size. Small beams are the original 1 m thick pipes.
const BEAM_RADII: Array[float] = [0.5, 1.0, 1.5]
const ORB_RADII: Array[float] = [1.0, 2.0, 3.0]
## Medium is the original 3 m ball.
const BALL_RADII: Array[float] = [1.0, 1.5, 2.5]
## Medium is the original 12 m goal.
const GOAL_RADII: Array[float] = [4.0, 6.0, 9.0]

## One scene per Venue, in the same order.
const VENUE_SCENES: Array[String] = [
	"res://src/scenery/classic.tscn",
	"res://src/scenery/space.tscn",
	"res://src/scenery/snow.tscn",
	"res://src/scenery/lava.tscn",
	"res://src/scenery/desert.tscn",
]

## The range the menu allows for a timed match's length, and for a points match's target.
const MIN_MINUTES := 1
const MAX_MINUTES := 30
const MIN_POINTS := 1
const MAX_POINTS := 25

const SAVE_PATH := "user://match_settings.cfg"
const SECTION := "match"

@export var pipes_per_side := 10
@export var zip_points: Lattice.ZipPoints = Lattice.ZipPoints.BEAMS
@export var zip_size := Size.SMALL
@export var gravity := true
@export var ball_size := Size.MEDIUM
@export var goal_size := Size.MEDIUM
@export var grapple_mode := GrappleMode.REEL
@export var venue := Venue.CLASSIC
@export var match_rule := MatchRule.TIMED
## Length of a timed match (minutes of play; the clock stops between goals).
@export_range(MIN_MINUTES, MAX_MINUTES) var time_limit_minutes := 5
## Points a team needs to win a points match.
@export_range(MIN_POINTS, MAX_POINTS) var points_to_win := 5


## Beam or orb radius (m).
func zip_radius() -> float:
	var radii := ORB_RADII if zip_points == Lattice.ZipPoints.ORBS else BEAM_RADII
	return radii[zip_size]


func ball_radius() -> float:
	return BALL_RADII[ball_size]


func goal_radius() -> float:
	return GOAL_RADII[goal_size]


## A new instance of the venue's scenery.
func make_scenery() -> Scenery:
	return (load(VENUE_SCENES[venue]) as PackedScene).instantiate() as Scenery


func save(path := SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION, "pipes_per_side", pipes_per_side)
	config.set_value(SECTION, "zip_points", zip_points)
	config.set_value(SECTION, "zip_size", zip_size)
	config.set_value(SECTION, "gravity", gravity)
	config.set_value(SECTION, "ball_size", ball_size)
	config.set_value(SECTION, "goal_size", goal_size)
	config.set_value(SECTION, "grapple_mode", grapple_mode)
	config.set_value(SECTION, "venue", venue)
	config.set_value(SECTION, "match_rule", match_rule)
	config.set_value(SECTION, "time_limit_minutes", time_limit_minutes)
	config.set_value(SECTION, "points_to_win", points_to_win)
	return config.save(path)


## The settings last saved at `path`, or the defaults if there are none. Values that aren't
## valid choices (an old or hand-edited file) fall back to their defaults.
static func load_saved(path := SAVE_PATH) -> MatchSettings:
	var settings := MatchSettings.new()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return settings
	var grid: Variant = config.get_value(SECTION, "pipes_per_side", settings.pipes_per_side)
	if grid is int and GRID_SIZES.has(grid):
		settings.pipes_per_side = grid
	settings.zip_points = _load_choice(config, "zip_points", settings.zip_points, Lattice.ZipPoints.size()) as Lattice.ZipPoints
	settings.zip_size = _load_choice(config, "zip_size", settings.zip_size, Size.size()) as Size
	settings.ball_size = _load_choice(config, "ball_size", settings.ball_size, Size.size()) as Size
	settings.goal_size = _load_choice(config, "goal_size", settings.goal_size, Size.size()) as Size
	settings.grapple_mode = _load_choice(config, "grapple_mode", settings.grapple_mode, GrappleMode.size()) as GrappleMode
	settings.venue = _load_choice(config, "venue", settings.venue, Venue.size()) as Venue
	settings.match_rule = _load_choice(config, "match_rule", settings.match_rule, MatchRule.size()) as MatchRule
	settings.time_limit_minutes = _load_int(config, "time_limit_minutes", settings.time_limit_minutes,
			MIN_MINUTES, MAX_MINUTES)
	settings.points_to_win = _load_int(config, "points_to_win", settings.points_to_win, MIN_POINTS, MAX_POINTS)
	var gravity_value: Variant = config.get_value(SECTION, "gravity", settings.gravity)
	if gravity_value is bool:
		settings.gravity = gravity_value
	return settings


## An enum value: an int from 0 to `count` - 1.
static func _load_choice(config: ConfigFile, key: String, fallback: int, count: int) -> int:
	return _load_int(config, key, fallback, 0, count - 1)


## An int from `low` to `high`, or `fallback` if the saved value is missing or isn't one.
static func _load_int(config: ConfigFile, key: String, fallback: int, low: int, high: int) -> int:
	var value: Variant = config.get_value(SECTION, key, fallback)
	if value is int and value >= low and value <= high:
		return value
	return fallback
