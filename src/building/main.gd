extends Node3D
## Main scene: generates N procedural buildings on a grid, free orbit camera.

const GRID := 8              # grid x grid buildings
const SPACING := 14.0

var cam_yaw := 0.6
var cam_pitch := -0.55
var cam_dist := 60.0
var cam_target := Vector3(0, 4, 0)

func _ready() -> void:
	_place_all()

func _place_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for gx in range(8):
		for gz in range(8):
			var seed_i: int = rng.randi()
			var spec := SpecGenerator.generate(seed_i)
			var builder := BuildingBuilder.new()
			var mesh: ArrayMesh = builder.build(spec)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.position = Vector3((gx - 3.5) * SPACING, 0, (gz - 3.5) * SPACING)
			add_child(mi)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cam_yaw += event.relative.x * 0.005
		cam_pitch = clampf(cam_pitch + event.relative.y * 0.005, -1.4, -0.05)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(cam_dist * 0.9, 5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(cam_dist * 1.1, 200.0)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cos(cam_pitch)
	var pos := cam_target + Vector3(sin(cam_yaw) * cp, sin(-cam_pitch), cos(cam_yaw) * cp) * cam_dist
	cam.position = pos
	cam.look_at(cam_target, Vector3.UP)
