class_name Arena
extends AnimatableBody3D
## The tumbling cube of zip points: beams (solid pipes along all three axes) or orbs (one
## wherever beams would cross, which you can grapple but never bump into). Builds the zip
## points, their collision and the goal spheres, rebuilds them when the match settings change,
## and rotates one step each time Match calls step(). See docs/design.md, "Arena geometry".

## Beam joints are this much wider than the beams.
const JOINT_SCALE := 1.6
## Goals sit in the open cell nearest this far from the center toward a corner.
const GOAL_FRACTION := 2.0 / 3.0

@export_group("Lattice")
## Distance between the outermost beam lines (m). The same for every grid size.
@export var cube_size := 216.0
## Beams per side (for orbs, orbs per row). Keep it even, so an open cell sits at the center.
@export var pipes_per_side := 10
@export var zip_points: Lattice.ZipPoints = Lattice.ZipPoints.BEAMS
## Beam radius, or orb radius (m).
@export var zip_radius := 0.5
@export var goal_radius := 6.0
## Zip point color and glow (black for none). The venue's Scenery sets them.
@export var zip_color := Color(0.82, 0.83, 0.85)
@export var zip_glow := Color.BLACK

@export_group("Spin")
@export var spin_enabled := true
@export var spin_seed := 1
@export var spin_min_degrees_per_second := 2.0
@export var spin_max_degrees_per_second := 6.0
@export var spin_change_min_seconds := 6.0
@export var spin_change_max_seconds := 12.0
@export var spin_blend_seconds := 3.0

## Distance between neighboring beam lines (m).
var spacing: float:
	get:
		return cube_size / (pipes_per_side - 1)
var lattice: Lattice
var spin: ArenaSpin
## Angular velocity applied during the last step (world space, radians per second).
var angular_velocity := Vector3.ZERO

## Holds everything build() makes, so a rebuild can throw it all away.
var _geometry: Node3D


func _ready() -> void:
	spin = ArenaSpin.new(spin_seed, spin_min_degrees_per_second, spin_max_degrees_per_second,
			spin_change_min_seconds, spin_change_max_seconds, spin_blend_seconds)
	build()


## Takes the grid, zip points and goal size from the menu's settings, and the zip point colors
## from the venue's scenery if given, then rebuilds.
func apply_settings(settings: MatchSettings, scenery: Scenery = null) -> void:
	if scenery != null:
		zip_color = scenery.zip_color
		zip_glow = scenery.zip_glow
	pipes_per_side = settings.pipes_per_side
	zip_points = settings.zip_points
	zip_radius = settings.zip_radius()
	goal_radius = settings.goal_radius()
	if is_node_ready():
		build()


## (Re)builds the zip points, their collision and the goals from the exported settings.
func build() -> void:
	lattice = Lattice.new(pipes_per_side, spacing, zip_radius, zip_points)
	for owner_id: int in get_shape_owners():
		remove_shape_owner(owner_id)
	if _geometry != null:
		remove_child(_geometry)
		_geometry.queue_free()
	_geometry = Node3D.new()
	_geometry.name = "Geometry"
	add_child(_geometry)

	if zip_points == Lattice.ZipPoints.BEAMS:
		_build_beam_collision()
		_build_beam_visuals()
	else:
		_build_orb_visuals() # Orbs have no collision: nothing bumps into them.
	_build_goal_visuals()


## Advances the arena's rotation by one simulation tick.
func step(delta: float) -> void:
	if not spin_enabled:
		angular_velocity = Vector3.ZERO
		return
	angular_velocity = spin.step(delta)
	var angle := angular_velocity.length() * delta
	if angle > 0.0:
		global_basis = (Basis(angular_velocity.normalized(), angle) * global_basis).orthonormalized()


## Velocity of a point attached to the arena (from the rotation).
func velocity_at(world_point: Vector3) -> Vector3:
	return angular_velocity.cross(world_point - global_position)


## Grapple ray against the zip points. The hit's anchor is in arena-local space.
func raycast_zip_points(origin: Vector3, direction: Vector3, max_distance: float, assist_angle: float) -> Lattice.Hit:
	var local_direction := global_basis.inverse() * direction
	return lattice.raycast(to_local(origin), local_direction, max_distance, assist_angle)


func distance_outside(world_point: Vector3) -> float:
	return lattice.distance_outside(to_local(world_point))


func closest_point_inside(world_point: Vector3) -> Vector3:
	return to_global(lattice.clamp_inside(to_local(world_point)))


## Goals sit on the cube's main diagonal, toward opposite corners, in the open cell nearest
## two-thirds of the way from the center to the corner. With 10 per side, that's two beam
## layers in from the corner.
func goal_cell(team: int) -> Vector3i:
	var cells := pipes_per_side - 1
	var target := GOAL_FRACTION * lattice.half_extent
	var cell := clampi(roundi((target + lattice.half_extent) / spacing - 0.5), 0, cells - 1)
	if team == 0:
		cell = cells - 1 - cell
	return Vector3i(cell, cell, cell)


func goal_local_position(team: int) -> Vector3:
	return lattice.cell_center(goal_cell(team))


## Spawns sit on the same diagonal, in the cell next to the center cell on the team's own
## side. With 4 per side, that cell holds the goal, so the spawn is in the center cell
## instead, a quarter of a cell out from the center.
@warning_ignore("integer_division")
func spawn_local_position(team: int) -> Vector3:
	var center := (pipes_per_side - 2) / 2
	var cell := center - 1 if team == 0 else center + 1
	if cell == goal_cell(team).x:
		var side := -1.0 if team == 0 else 1.0
		return Vector3.ONE * side * spacing * 0.25
	return lattice.cell_center(Vector3i(cell, cell, cell))


func _build_beam_collision() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = zip_radius
	shape.height = lattice.pipe_length()
	for i: int in lattice.pipe_count():
		var owner_id := create_shape_owner(self)
		shape_owner_add_shape(owner_id, shape)
		shape_owner_set_transform(owner_id, _pipe_transform(i))


func _build_beam_visuals() -> void:
	var zip_material := _zip_material()

	var pipe_mesh := CylinderMesh.new()
	pipe_mesh.top_radius = zip_radius
	pipe_mesh.bottom_radius = zip_radius
	pipe_mesh.height = lattice.pipe_length()
	pipe_mesh.radial_segments = 8
	pipe_mesh.rings = 0
	pipe_mesh.material = zip_material

	var pipes := MultiMesh.new()
	pipes.transform_format = MultiMesh.TRANSFORM_3D
	pipes.mesh = pipe_mesh
	pipes.instance_count = lattice.pipe_count()
	for i: int in lattice.pipe_count():
		pipes.set_instance_transform(i, _pipe_transform(i))
	_add_multimesh("Pipes", pipes)

	var joint_radius := zip_radius * JOINT_SCALE
	_add_multimesh("Joints", _orb_multimesh(_sphere_mesh(joint_radius, 8, 4, zip_material)))


func _build_orb_visuals() -> void:
	_add_multimesh("Orbs", _orb_multimesh(_sphere_mesh(zip_radius, 12, 6, _zip_material())))


## One instance of `mesh` at every spot where beams cross.
func _orb_multimesh(mesh: Mesh) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = lattice.orb_count()
	for i: int in lattice.orb_count():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, lattice.orb_center(i)))
	return multimesh


func _build_goal_visuals() -> void:
	for team: int in Teams.COLORS.size():
		var material := StandardMaterial3D.new()
		var color := Teams.COLORS[team]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(color, 0.6)
		var goal := MeshInstance3D.new()
		goal.name = "Goal%d" % team
		goal.mesh = _sphere_mesh(goal_radius, 16, 8, material)
		goal.position = goal_local_position(team)
		_geometry.add_child(goal)


func _sphere_mesh(radius: float, radial_segments: int, rings: int, material: Material) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	mesh.material = material
	return mesh


func _add_multimesh(node_name: String, multimesh: MultiMesh) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	_geometry.add_child(instance)


## Cylinders are built along Y; this turns each one onto its beam's axis.
func _pipe_transform(index: int) -> Transform3D:
	var axis := lattice.pipe_axis(index)
	var pipe_basis := Basis.IDENTITY
	if axis == 0:
		pipe_basis = Basis(Vector3.BACK, -PI / 2.0)
	elif axis == 2:
		pipe_basis = Basis(Vector3.RIGHT, PI / 2.0)
	return Transform3D(pipe_basis, lattice.pipe_center(index))


## The venue's zip color (silver by default) with Gouraud (per-vertex) shading, for the
## Dreamcast-era look, plus the venue's glow if it has one. Deliberately not metallic: metallic
## pipes reflected mostly blue sky, and sun glare on distant ones left black specks once MSAA
## was on.
func _zip_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = zip_color
	material.roughness = 0.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if zip_glow != Color.BLACK:
		material.emission_enabled = true
		material.emission = zip_glow
	return material
