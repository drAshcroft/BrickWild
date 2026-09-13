extends RefCounted
## Voxel aperture checks must accept a real hole and reject invented opening
## logs or missing surrounds. Large openings separate the four support probes
## despite the voxel grid's deliberate one-cell dilation.

static func run() -> SuiteResult:
	var res := SuiteResult.new("castle apertures")
	for yaw in [0.0, PI * 0.5, 0.37]:
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(13, 2, -7))
		var qa := _fixture(xf)
		qa._check_openings()
		_want(res, qa.failures.is_empty(), "real aperture rejected at yaw %s: %s" % [yaw, qa.failures])
		_want(res, qa.stats.openings_checked == 1, "planned aperture not counted")
		qa.builder.part_log[0].pos += Vector3(100, 0, 100)
		qa.failures.clear()
		qa._check_openings()
		_want(res, qa.failures.size() == 4, "moved window borrowed boundary masonry")
	for missing in ["left jamb", "right jamb", "head", "sill"]:
		var qa := _fixture(Transform3D.IDENTITY, missing)
		qa._check_openings()
		_want(res, _contains(qa.failures, missing), "missing %s was accepted" % missing)
	var invalid := _fixture(Transform3D.IDENTITY)
	invalid.builder.part_log[0].facing = Vector3.ZERO
	invalid._check_openings()
	_want(res, _contains(invalid.failures, "invalid"), "zero facing accepted")
	# Recesses still require backing; the real-aperture branch must not make
	# the existing painted slit rule accept a floating overlay.
	var legacy := CastleQA.new()
	legacy.builder = CastleBuilder.new()
	legacy.builder.begin(1)
	legacy.builder.box(Vector3(4, 4, 1), Vector3.ZERO, 0)
	legacy.builder.part_log.append({"kind": "window", "tag": "legacy", "pos": Vector3(0, 0, -0.5)})
	legacy._grid = VoxelGrid.new()
	legacy._grid.rasterize(legacy.builder.commit(), -1, 0.25)
	legacy._check_openings()
	_want(res, legacy.failures.is_empty(), "embedded legacy slit rejected")
	legacy.builder.part_log[-1].pos = Vector3(0, 10, 0)
	legacy.failures.clear()
	legacy._check_openings()
	_want(res, not legacy.failures.is_empty(), "floating legacy slit accepted")
	return res


static func _fixture(xf: Transform3D, missing := "") -> CastleQA:
	var kit := MeshKit.new(2)
	var pieces := {
		"left jamb": [Vector3(0.5, 5, 0.6), Vector3(-3.25, 0, 0)],
		"right jamb": [Vector3(0.5, 5, 0.6), Vector3(3.25, 0, 0)],
		"head": [Vector3(6, 0.5, 0.6), Vector3(0, 2.25, 0)],
		"sill": [Vector3(6, 0.5, 0.6), Vector3(0, -2.25, 0)],
	}
	for side in pieces:
		if side != missing:
			kit.oriented_box(pieces[side][0], xf * Transform3D(Basis(), pieces[side][1]), 0)
	# The glass cannot supply masonry where a surround was removed.
	kit.oriented_box(Vector3(6, 4, 0.04), xf, 1)
	var qa := CastleQA.new()
	qa.builder = CastleBuilder.new()
	qa.builder.part_log.append({"kind": "window", "tag": "fixture", "planned_opening": true,
		"pos": xf.origin, "size": Vector3(6, 4, 0), "facing": xf.basis * Vector3.BACK})
	qa._grid = VoxelGrid.new()
	qa._grid.rasterize(kit.commit(), 1, 0.25)
	return qa


static func _contains(messages: Array, text: String) -> bool:
	for message in messages:
		if text in String(message):
			return true
	return false


static func _want(res: SuiteResult, condition: bool, message: String) -> void:
	res.checked += 1
	if not condition:
		res.fail(message)
