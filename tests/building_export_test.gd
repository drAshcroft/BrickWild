extends SceneTree
const Exporter = preload("res://tools/export_building_plan.gd")
var failures: Array[String] = []

func _init() -> void:
	var request := BuildingRequest.house(313, &"townhouse", &"none", 10.0, 12.0, 2.6, 2)
	var spec := HouseSpec.new(313)
	spec.style = request.style
	spec.width = request.width
	spec.length = request.length
	spec.height = request.height
	spec.storeys = request.storeys
	HouseGenerator.generate(spec, 313, false)
	var rect := HouseGeometry.site_rect(spec, 1)
	var xf := Transform3D(Basis(Vector3.UP, PI / 2), Vector3(50, 0, -30))
	var polygon := PackedVector2Array()
	for p in Exporter._corners(rect): polygon.append(Exporter._point(p, xf))
	var id := "site:rotated/b-000"
	var record := {"building_id": id, "kind": "house", "request": request.to_dict(),
		"rect_m": Exporter._rect(Poly.bounding_rect(polygon)),
		"transform": {"origin": [50, 0, -30], "basis": [[0, 0, -1], [0, 1, 0], [1, 0, 0]]}}
	var site := {"schema": "dmv.site.plan", "schema_version": 1, "buildings": [record]}
	var output: Dictionary = Exporter.building_plan(site, id)
	if output.has("errors"):
		failures.append(str(output["errors"]))
	else:
		if output["stairs"].is_empty(): failures.append("two storeys have no exported stair")
		if not output["rooms"].any(func(room): return room.has("focus")):
			failures.append("hearth focus was not carried into the room")
		for room in output["rooms"]:
			if room["rect_m"][0] < 40: failures.append("room retained local coordinates")
			if room.has("focus") and room["focus"]["at_m"][0] < 40:
				failures.append("focus retained local coordinates")
	var file := FileAccess.open("res://artifacts/p1p2_api/rotated_interior.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t", true, true))
	file.close()
	for fail in failures: print("FAIL " + fail)
	print("building_export: rotated two-storey townhouse, %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
