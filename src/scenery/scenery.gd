class_name Scenery
extends Node3D
## One venue's look: sky, sunlight, fog, floor, far-off peaks and weather, plus the color of
## the zip points. Each venue is its own scene in src/scenery/ (MatchSettings.VENUE_SCENES)
## with a WorldEnvironment and a DirectionalLight3D named Sun. Presentation only: nothing here
## touches the simulation.

## Particles that fill the air around the camera.
enum Weather {
	NONE,
	SNOW, ## Snowflakes drifting down.
	EMBERS, ## Glowing sparks rising from below.
	DUST, ## Sand blowing past on the wind.
}

## Which way the desert wind blows the dust. The sand floor's ripples and slip faces match it.
const DUST_WIND := Vector3(-0.5, 0.0, 0.87)

## How far around the camera the weather fills (m, half the size of the box).
const WEATHER_EXTENTS := Vector3(45.0, 30.0, 45.0)

## Zip point color in this venue.
@export var zip_color := Color(0.82, 0.83, 0.85)
## Glow on the zip points (black for none).
@export var zip_glow := Color.BLACK
@export var weather := Weather.NONE

var _weather: GPUParticles3D

@onready var world: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun


func _ready() -> void:
	_aim_shaders_at_the_sun()
	if weather != Weather.NONE:
		_weather = _make_weather(weather)
		add_child(_weather)


## For the menu's preview: no fog, so the whole cube shows from far away. The environment is
## copied first, so other instances of this venue keep their fog.
func use_as_preview() -> void:
	world.environment = world.environment.duplicate() as Environment
	world.environment.fog_enabled = false


## The weather fills a box around whichever camera is drawing. Flakes and sparks stay where
## they are in the world, so they stream past as you fly.
func _process(_delta: float) -> void:
	if _weather == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_weather.global_position = camera.global_position


## The floor and mountain shaders light themselves (so they can fade into their own haze),
## so they need to know where the sun is.
func _aim_shaders_at_the_sun() -> void:
	var toward_sun := sun.global_basis.z # A light shines along its -Z.
	for geometry: Node in find_children("*", "GeometryInstance3D", true, false):
		var material := (geometry as GeometryInstance3D).material_override as ShaderMaterial
		if material != null:
			material.set_shader_parameter("light_direction", toward_sun)


func _make_weather(kind: Weather) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = WEATHER_EXTENTS
	process.turbulence_enabled = true
	process.turbulence_noise_scale = 6.0

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot()
	var quad := QuadMesh.new()
	quad.material = material

	var particles := GPUParticles3D.new()
	particles.name = "Weather"
	particles.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	particles.local_coords = false
	particles.visibility_aabb = AABB(-WEATHER_EXTENTS * 2.0, WEATHER_EXTENTS * 4.0)
	particles.process_material = process
	particles.draw_pass_1 = quad

	if kind == Weather.SNOW:
		particles.amount = 1600
		particles.lifetime = 10.0
		process.direction = Vector3.DOWN
		process.spread = 25.0
		process.initial_velocity_min = 2.0
		process.initial_velocity_max = 4.0
		process.gravity = Vector3(0.0, -0.4, 0.0)
		process.turbulence_noise_strength = 0.6
		process.scale_min = 0.7
		process.scale_max = 1.3
		process.color = Color(1.0, 1.0, 1.0, 0.9)
		quad.size = Vector2(0.2, 0.2)
	elif kind == Weather.DUST:
		particles.amount = 900
		particles.lifetime = 7.0
		process.direction = DUST_WIND
		process.spread = 12.0
		process.initial_velocity_min = 7.0
		process.initial_velocity_max = 12.0
		process.gravity = Vector3(0.0, -0.1, 0.0)
		process.turbulence_noise_strength = 1.2
		process.scale_min = 0.4
		process.scale_max = 1.4
		var dust_fade := Gradient.new() # Fades in and out, so grains don't pop.
		dust_fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		dust_fade.colors = PackedColorArray([Color(0.95, 0.8, 0.58, 0.0), Color(0.95, 0.8, 0.58, 0.6),
				Color(0.9, 0.74, 0.52, 0.0)])
		var dust_ramp := GradientTexture1D.new()
		dust_ramp.gradient = dust_fade
		process.color_ramp = dust_ramp
		quad.size = Vector2(0.14, 0.14)
	else:
		particles.amount = 500
		particles.lifetime = 6.0
		process.direction = Vector3.UP
		process.spread = 35.0
		process.initial_velocity_min = 1.5
		process.initial_velocity_max = 4.0
		process.gravity = Vector3(0.0, 1.2, 0.0) # Hot air carries them up.
		process.turbulence_noise_strength = 1.5
		process.scale_min = 0.5
		process.scale_max = 1.2
		var fade := Gradient.new()
		fade.set_color(0, Color(1.0, 0.85, 0.35, 1.0))
		fade.set_color(1, Color(0.9, 0.15, 0.0, 0.0))
		var ramp := GradientTexture1D.new()
		ramp.gradient = fade
		process.color_ramp = ramp
		quad.size = Vector2(0.18, 0.18)
	particles.preprocess = particles.lifetime # Start with the air already full.
	return particles


## A white dot that fades out at the edge, for round flakes and sparks.
func _soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture
