extends RefCounted

class ShiftedRoof extends HouseBuilder:
	func _roof_face(xf: Transform3D, local: PackedVector3Array, surface: int,
			role: String, vertical := true, depth := RoofShape.DEPTH) -> void:
		if role.begins_with("roof_face_"):
			xf.origin.y += 0.3
		super._roof_face(xf, local, surface, role, vertical, depth)

class MissingSlope extends HouseBuilder:
	func _roof_face(xf: Transform3D, local: PackedVector3Array, surface: int,
			role: String, vertical := true, depth := RoofShape.DEPTH) -> void:
		if role == "roof_face_0":
			return
		super._roof_face(xf, local, surface, role, vertical, depth)

class LoweredGable extends HouseBuilder:
	func _roof_face(xf: Transform3D, local: PackedVector3Array, surface: int,
			role: String, vertical := true, depth := RoofShape.DEPTH) -> void:
		var changed := local.duplicate()
		if role == "roof_wall":
			for i in changed.size():
				if changed[i].y > 0.3:
					changed[i].y -= 0.25
		super._roof_face(xf, changed, surface, role, vertical, depth)

class DuplicateSlope extends HouseBuilder:
	func _build_roof() -> void:
		super._build_roof()
		var layout := HouseGeometry.roof_layout(plan)
		_roof_face(layout["transform"], layout["faces"][0], SURF_ROOF, "roof_face_0")

class BlockedDoor extends HouseBuilder:
	func _build_timber_frame() -> void:
		super._build_timber_frame()
		var d: Dictionary = plan.doors[plan.entrance()]
		var p: Vector2 = d["pos"] + d["normal"] * 0.2
		component_box("faulty_door_sill", Vector3(d["width"], 0.18, 0.16),
			Transform3D(Basis(), Vector3(p.x, 0.62, p.y)), SURF_TRIM)


static func run() -> SuiteResult:
	var res := SuiteResult.new("house envelope")
	for i in 22:
		var s := HouseSpec.new()
		# `% 5` was the style count when this suite was written, so adding a
		# sixth style would have left it covering five and said nothing. Ask the
		# table how many there are instead of counting them here.
		s.style = HouseSweep.styles()[i % HouseSweep.styles().size()]
		var size_id := (i + i / 3) % 3
		s.width = [5.5, 8.0, 14.0][size_id]
		s.length = [12.0, 8.1, 7.0][size_id]
		if i >= 9:
			var width := s.width
			s.width = s.length
			s.length = width
		s.storeys = 1 + (i / 3) % 3
		s.exterior_props = false
		var p := HouseGenerator.generate(s, 4400 + i, false)
		s.roof_type = [&"gable", &"half_hipped", &"hipped", &"conical"][i % 4]
		s.roof_pitch = [0.7, 1.1, 1.6][(i / 3 + i) % 3]
		s.dormers = i % 2 == 0
		s.dormer_count = 2 if s.dormers else 0
		s.chimney = i % 2 == 0
		s.jetty = s.storeys > 1 and i % 2 == 1
		# Explicit geometry matrix: replanning after feature overrides keeps
		# the room footprint and emitted shell on the same requested envelope.
		s.rng.seed = s.seed
		p = HousePlanner.plan(s)
		var b := HouseBuilder.new()
		b.build(p)
		var errors := HouseQA.check_exterior_geometry(p, b)
		res.checked += 1
		for f in errors:
			res.fail(f)
		b.build(p, false)
		for f in HouseQA.check_exterior_geometry(p, b):
			res.fail("cutaway " + f)
	var s := HouseSpec.new()
	s.width = 10
	s.length = 13
	s.exterior_props = false
	var p := HouseGenerator.generate(s, 4413, false)
	s.roof_type = &"gable"
	for pair in [[ShiftedRoof.new(), "roof_host:"], [MissingSlope.new(), "roof_envelope:"],
		[LoweredGable.new(), "roof_wall:"], [DuplicateSlope.new(), "roof_overlap:"],
		[BlockedDoor.new(), "door_trim:"]]:
		var b: HouseBuilder = pair[0]
		b.build(p)
		var errors := "\n".join(HouseQA.check_exterior_geometry(p, b))
		res.checked += 1
		if not errors.contains(pair[1]):
			res.fail("emitted mutation escaped " + pair[1])
	var good := HouseBuilder.new()
	good.build(p)
	good.emitted_mesh = MeshKit.translated(good.emitted_mesh, Vector3(0, 0.3, 0))
	var displaced_errors := "\n".join(HouseQA.check_exterior_geometry(p, good))
	res.checked += 1
	if not displaced_errors.contains("components:"):
		res.fail("actual mesh shifted away from component log escaped")
	res.checked += 1
	if not displaced_errors.contains("bounds:"):
		res.fail("actual mesh outside planned exterior bounds escaped")
	return res
