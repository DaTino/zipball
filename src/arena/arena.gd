class_name Arena
extends AnimatableBody3D
## The tumbling pipe-lattice cube. Builds its pipes (collision and visuals) and goal spheres
## at startup, then rotates one step each time Match calls step().
## See docs/design.md, "Arena geometry".

const PIPE_COLOR := Color(0.82, 0.83, 0.85)

@export_group("Lattice")
@export var pipes_per_side := 10
@export var spacing := 24.0
@export var pipe_radius := 0.5
@export var joint_radius := 0.8
@export var goal_radius := 6.0

@export_group("Spin")
@export var spin_enabled := true
@export var spin_seed := 1
@export var spin_min_degrees_per_second := 2.0
@export var spin_max_degrees_per_second := 6.0
@export var spin_change_min_seconds := 6.0
@export var spin_change_max_seconds := 12.0
@export var spin_blend_seconds := 3.0

var lattice: Lattice
var spin: ArenaSpin
## Angular velocity applied during the last step (world space, radians per second).
var angular_velocity := Vector3.ZERO


func _ready() -> void:
	lattice = Lattice.new(pipes_per_side, spacing, pipe_radius)
	spin = ArenaSpin.new(spin_seed, spin_min_degrees_per_second, spin_max_degrees_per_second,
			spin_change_min_seconds, spin_change_max_seconds, spin_blend_seconds)
	_build_collision()
	_build_pipe_visuals()
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


## Grapple ray against the pipes. The hit's anchor is in arena-local space.
func raycast_pipes(origin: Vector3, direction: Vector3, max_distance: float, assist_angle: float) -> Lattice.Hit:
	var local_direction := global_basis.inverse() * direction
	return lattice.raycast(to_local(origin), local_direction, max_distance, assist_angle)


func distance_outside(world_point: Vector3) -> float:
	return lattice.distance_outside(to_local(world_point))


func closest_point_inside(world_point: Vector3) -> Vector3:
	return to_global(lattice.clamp_inside(to_local(world_point)))


## Goal cells sit on the cube's main diagonal, two pipe layers in from opposite corners.
func goal_cell(team: int) -> Vector3i:
	var cell := 1 if team == 0 else pipes_per_side - 3
	return Vector3i(cell, cell, cell)


func goal_local_position(team: int) -> Vector3:
	return lattice.cell_center(goal_cell(team))


## Spawn cells sit on the same diagonal, one cell from the center on each team's side.
func spawn_local_position(team: int) -> Vector3:
	var cell := 3 if team == 0 else pipes_per_side - 5
	return lattice.cell_center(Vector3i(cell, cell, cell))


func _build_collision() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = pipe_radius
	shape.height = lattice.pipe_length()
	for i: int in lattice.pipe_count():
		var owner_id := create_shape_owner(self)
		shape_owner_add_shape(owner_id, shape)
		shape_owner_set_transform(owner_id, _pipe_transform(i))


func _build_pipe_visuals() -> void:
	var silver := _silver_material()

	var pipe_mesh := CylinderMesh.new()
	pipe_mesh.top_radius = pipe_radius
	pipe_mesh.bottom_radius = pipe_radius
	pipe_mesh.height = lattice.pipe_length()
	pipe_mesh.radial_segments = 8
	pipe_mesh.rings = 0
	pipe_mesh.material = silver

	var pipes := MultiMesh.new()
	pipes.transform_format = MultiMesh.TRANSFORM_3D
	pipes.mesh = pipe_mesh
	pipes.instance_count = lattice.pipe_count()
	for i: int in lattice.pipe_count():
		pipes.set_instance_transform(i, _pipe_transform(i))
	_add_multimesh("Pipes", pipes)

	var joint_mesh := SphereMesh.new()
	joint_mesh.radius = joint_radius
	joint_mesh.height = joint_radius * 2.0
	joint_mesh.radial_segments = 8
	joint_mesh.rings = 4
	joint_mesh.material = silver

	var n := pipes_per_side
	var joints := MultiMesh.new()
	joints.transform_format = MultiMesh.TRANSFORM_3D
	joints.mesh = joint_mesh
	joints.instance_count = n * n * n
	var index := 0
	for x: int in n:
		for y: int in n:
			for z: int in n:
				var joint_position := Vector3(lattice.coordinate(x), lattice.coordinate(y), lattice.coordinate(z))
				joints.set_instance_transform(index, Transform3D(Basis.IDENTITY, joint_position))
				index += 1
	_add_multimesh("Joints", joints)


func _build_goal_visuals() -> void:
	for team: int in Teams.COLORS.size():
		var mesh := SphereMesh.new()
		mesh.radius = goal_radius
		mesh.height = goal_radius * 2.0
		mesh.radial_segments = 16
		mesh.rings = 8
		var material := StandardMaterial3D.new()
		var color := Teams.COLORS[team]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(color, 0.6)
		mesh.material = material
		var goal := MeshInstance3D.new()
		goal.name = "Goal%d" % team
		goal.mesh = mesh
		goal.position = goal_local_position(team)
		add_child(goal)


func _add_multimesh(node_name: String, multimesh: MultiMesh) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	add_child(instance)


## Cylinders are built along Y; this turns each one onto its pipe's axis.
func _pipe_transform(index: int) -> Transform3D:
	var axis := lattice.pipe_axis(index)
	var pipe_basis := Basis.IDENTITY
	if axis == 0:
		pipe_basis = Basis(Vector3.BACK, -PI / 2.0)
	elif axis == 2:
		pipe_basis = Basis(Vector3.RIGHT, PI / 2.0)
	return Transform3D(pipe_basis, lattice.pipe_center(index))


## Silver with Gouraud (per-vertex) shading, for the Dreamcast-era look. Deliberately not
## metallic: metallic pipes reflected mostly blue sky, and sun glare on distant ones left
## black specks once MSAA was on.
func _silver_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = PIPE_COLOR
	material.roughness = 0.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return material
