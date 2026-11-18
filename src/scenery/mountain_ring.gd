class_name MountainRing
extends MultiMeshInstance3D
## A ring of low-poly peaks far around the arena, standing on the venue's floor. Each one is
## a unit cone scaled up, so the mountain shader can color it by height (rock, then snow,
## glowing lava or cap rock at the top). Seeded, so a venue always looks the same. Presentation only.

@export var count := 24
## Distance from the arena's center to the ring (m). Each peak varies by 15%.
@export var distance := 1400.0
## Where the peaks stand (m): the venue's floor.
@export var base_height := -420.0
@export var min_height := 300.0
@export var max_height := 650.0
## Radius at the base (m).
@export var min_width := 200.0
@export var max_width := 400.0
## 0 for a pointed peak. More than 0 cuts the top off, as a fraction of the base: a crater,
## or a flat-topped mesa when it is large.
@export_range(0.0, 0.9) var top_fraction := 0.0
@export var seed_value := 1


func _ready() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = top_fraction
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	cone.cap_bottom = false

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var peaks := MultiMesh.new()
	peaks.transform_format = MultiMesh.TRANSFORM_3D
	peaks.mesh = cone
	peaks.instance_count = count
	for i: int in count:
		var angle := TAU * (i + rng.randf_range(-0.3, 0.3)) / count
		var reach := distance * rng.randf_range(0.85, 1.15)
		var height := rng.randf_range(min_height, max_height)
		var width := rng.randf_range(min_width, max_width)
		var peak_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(width, height, width))
		var origin := Vector3(cos(angle) * reach, base_height + height * 0.5, sin(angle) * reach)
		peaks.set_instance_transform(i, Transform3D(peak_basis, origin))
	multimesh = peaks
	# The ring is huge and always around you: never cull it.
	custom_aabb = AABB(Vector3(-1.0, -1.0, -1.0) * (distance * 1.5 + max_width),
			Vector3(2.0, 2.0, 2.0) * (distance * 1.5 + max_width))
