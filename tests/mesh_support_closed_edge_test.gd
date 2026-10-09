extends SceneTree
## Emitted floor edges are closed sets. Removing their actual triangles removes support.
var failures: Array[String] = []
var checked := 0

func _initialize() -> void:
	for width in [1.0, 11.67208, 80.0]:
		for shift in [Vector3.ZERO, Vector3(500.0, 3.25, -300.0), Vector3(2000.0, 4.5, -2000.0)]:
			_check_split_floor(width, shift)
	_check_orientations_and_height()
	for message in failures:
		printerr("FAIL ", message)
	print("mesh closed-edge support: %d checks, %d failures" % [checked, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _assert(condition: bool, message: String) -> void:
	checked += 1
	if not condition:
		failures.append(message)

func _check_split_floor(width: float, shift: Vector3) -> void:
	var kit := MeshKit.new(1)
	kit.box(Vector3(width, 0.30, 0.43), shift + Vector3(width * 0.5, -0.15, -0.215), 0)
	kit.box(Vector3(width, 0.30, 0.45), shift + Vector3(width * 0.5, -0.15, 0.225), 0)
	var mesh := kit.commit()
	var triangles: Array = MeshProbe.surface_triangles(null, mesh, 0)
	var samples: Array[Vector2] = [Vector2(width - 0.12, 0.0), Vector2(width * 0.5, 0.0),
		Vector2(0.0, 0.0), Vector2(width, 0.0), Vector2(width * 0.25, -0.215),
		Vector2(width * 0.5, 0.225), Vector2(width, 0.45)]
	for local in samples:
		var point := Vector2(shift.x, shift.z) + local
		_assert(MeshProbe.has_upward_support(triangles, point, shift.y, 0.003),
			"actual slab edge or vertex unsupported width=%.3f shift=%s point=%s" % [width, shift, point])
		var removed := MeshProbe.remove_triangles(mesh, 0,
			func(a: Vector3, b: Vector3, c: Vector3) -> bool:
				return MeshProbe.upward_triangle_contains_point([a, b, c], point, shift.y, 0.003))
		_assert(int(removed.get("removed_triangles", 0)) > 0,
			"support mutation did not remove real slab top at %s" % point)
		_assert(not MeshProbe.has_upward_support(MeshProbe.surface_triangles(null, removed.mesh, 0), point, shift.y, 0.003),
			"removed actual support triangles still count as floor at %s" % point)
	for local in [Vector2(-0.001, 0.0), Vector2(width + 0.001, 0.0), Vector2(width * 0.5, -0.431), Vector2(width * 0.5, 0.451)]:
		_assert(not MeshProbe.has_upward_support(triangles, Vector2(shift.x, shift.z) + local, shift.y, 0.003),
			"point one millimetre beyond emitted floor accepted width=%.3f local=%s" % [width, local])
	_assert(not MeshProbe.has_upward_support(triangles, Vector2(shift.x + width * 0.5, shift.z), shift.y + 0.05, 0.003),
		"floor at wrong height accepted")
	mesh.clear_surfaces()

func _check_orientations_and_height() -> void:
	var upward: Array = [Vector3.ZERO, Vector3(2.0, 0.20, 0.0), Vector3(2.0, 0.20, 2.0)]
	_assert(MeshProbe.has_upward_support([upward], Vector2(1.5, 0.5), 0.15, 0.001),
		"actual gentle triangle plane height unsupported")
	_assert(not MeshProbe.has_upward_support([upward], Vector2(1.5, 0.5), 0.20, 0.001),
		"wrong interpolated triangle height accepted")
	_assert(not MeshProbe.has_upward_support([[upward[0], upward[2], upward[1]]], Vector2(1.5, 0.5), 0.15, 0.001),
		"downward triangle accepted as supporting floor")
	_assert(not MeshProbe.has_upward_support([[Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]], Vector2.ZERO, 0.0, 0.01),
		"degenerate triangle accepted")
	_assert(not MeshProbe.has_upward_support([[Vector3.ZERO, Vector3(1.0, 2.0, 0.0), Vector3(1.0, 2.0, 1.0)]], Vector2(0.5, 0.1), 1.0, 0.01),
		"steep obstruction accepted as walk floor")
