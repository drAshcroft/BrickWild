class_name WorldUncheckedSubkindsSuite
extends RefCounted
## LIVE-FAMILY-STYLES: the three world sub-kinds that no suite named
## (octagonal_pagoda, dodecagonal_pagoda, two_court_compound; see
## docs/FAMILY_STYLE_LEDGER.md). Each is built twice through the public path
## and must generate, carry a non-empty mesh, stay inside the family's
## published envelope, and be deterministic (same vertices both times).

const ROWS: Array[Dictionary] = [
	{"family": &"pagoda", "kind": &"octagonal_pagoda", "width": 30.0, "length": 30.0, "height": 65.0},
	{"family": &"pagoda", "kind": &"dodecagonal_pagoda", "width": 30.0, "length": 30.0, "height": 65.0},
	{"family": &"siheyuan", "kind": &"two_court_compound", "width": 22.0, "length": 70.0, "height": 5.0},
]
const SEED := 8102
## The mesh may overhang the footprint (eaves, finial); this much is allowed.
const OVERHANG := 1.35


static func run() -> SuiteResult:
	var res := SuiteResult.new("world unchecked subkinds")
	for row in ROWS:
		var who := String(row["kind"])
		var first := _build(row)
		res.checked += 1
		if first.is_empty():
			res.fail("%s: did not generate" % who)
			continue
		var bounds: AABB = first["bounds"]
		if first["vertices"] == 0 or bounds.size == Vector3.ZERO:
			res.fail("%s: empty mesh" % who)
			continue
		if not WorldFamilies.kinds_of(row["family"]).has(row["kind"]):
			res.fail("%s: not published by family %s" % [who, row["family"]])
		var env: Dictionary = WorldFamilies.envelope(row["family"])
		for axis in [["width", bounds.size.x], ["length", bounds.size.z]]:
			var limit: float = float(env[axis[0]]["max"]) * OVERHANG
			if axis[1] > limit:
				res.fail("%s: mesh %s %.1f m exceeds %.1f m" % [who, axis[0], axis[1], limit])
		if bounds.size.y > float(env["height"]["max"]) * OVERHANG:
			res.fail("%s: mesh height %.1f m exceeds the family maximum" % [who, bounds.size.y])
		var second := _build(row)
		if second.is_empty() or second["hash"] != first["hash"]:
			res.fail("%s: two builds of seed %d differ" % [who, SEED])
		res.note("  %-20s %d vertices, bounds %s" % [who, first["vertices"], str(bounds.size)])
	return res


static func _build(row: Dictionary) -> Dictionary:
	var request := BuildingRequest.new()
	request.kind = &"world"
	request.seed = SEED
	request.style = row["family"]
	request.purpose = row["kind"]
	request.width = row["width"]
	request.length = row["length"]
	request.height = row["height"]
	var building: GeneratedBuilding = BrickWild.generate(request)
	if building == null or not building.is_ok():
		return {}
	var mesh: ArrayMesh = BrickWild.build_mesh(building)
	if mesh == null:
		return {}
	var count := 0
	var h := 0
	for s in mesh.get_surface_count():
		var v: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		count += v.size()
		h = hash([h, v])
	return {"vertices": count, "bounds": mesh.get_aabb(), "hash": h}
