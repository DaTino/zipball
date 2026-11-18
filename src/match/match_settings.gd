class_name MatchSettings
extends Resource
## Choices made on the main menu before a match: the arena's grid and zip points, gravity,
## the ball and goal sizes, how the grapple behaves, and the venue. The defaults are the game
## as it was before the menu existed. The menu remembers the last choices in user:// (see
## save() and load_saved()).

enum Size { SMALL, MEDIUM, LARGE }
## Reel: once the hook lands, the line pulls you in and you hang (D21). Swing: it holds its
## length and you swing on it, like the first prototype.
enum GrappleMode { REEL, SWING }
## Where the match takes place: the sky, floor, weather and zip point colors (see VENUE_SCENES).
enum Venue { CLASSIC, SPACE, SNOW, LAVA, DESERT }

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
	var gravity_value: Variant = config.get_value(SECTION, "gravity", settings.gravity)
	if gravity_value is bool:
		settings.gravity = gravity_value
	return settings


static func _load_choice(config: ConfigFile, key: String, fallback: int, count: int) -> int:
	var value: Variant = config.get_value(SECTION, key, fallback)
	if value is int and value >= 0 and value < count:
		return value
	return fallback
