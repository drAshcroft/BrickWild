extends SceneTree
## C2: --site site.json --building-id site:city/b-000 --out building.json
## Requires the retained request/transform emitted by C1. No meshes or assets.

const SCHEMA := "dmv.building.plan"

func _init() -> void:
	var opts := {}
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size(), 2):
		if i + 1 >= args.size() or args[i] not in ["--site", "--building-id", "--out"]:
			_finish(_error("usage", "Expected --site site.json --building-id ID --out building.json."), "")
			return
		opts[args[i].trim_prefix("--")] = args[i + 1]
	if not opts.has("site") or not opts.has("building-id") or not opts.has("out"):
		_finish(_error("usage", "--site, --building-id and --out are required."), "")
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(opts["site"])) != OK or not parser.data is Dictionary:
		_finish(_error("invalid_json", "SitePlan must be a JSON object."), opts["out"])
		return
	_finish(building_plan(parser.data, opts["building-id"]), opts["out"])


static func building_plan(site: Dictionary, building_id: String) -> Dictionary:
	if site.get("schema") != "dmv.site.plan" or site.get("schema_version") != 1:
		return _error("unsupported_schema", "Expected dmv.site.plan schema 1.")
	if not site.get("buildings") is Array:
		return _error("invalid_site", "SitePlan buildings must be an array.")
	var record := {}
	for row in site.get("buildings", []):
		if not row is Dictionary:
			return _error("invalid_site", "Every building record must be an object.")
		if row.get("building_id") == building_id:
			record = row
			break
	if record.is_empty():
		return _error("building_not_found", "SitePlan has no building '%s'." % building_id)
	var rect_data: Variant = record.get("rect_m")
	if not rect_data is Array or rect_data.size() != 4:
		return _error("invalid_bounds", "C1 building requires a four-number rect_m.")
	for number in rect_data:
		if not (number is int or number is float) or not is_finite(float(number)):
			return _error("invalid_bounds", "Building bounds must be finite numbers.")
	if not record.get("request") is Dictionary or not record.get("transform") is Dictionary:
		return _error("missing_generation_data", "Re-export C1 with request and transform fields; exact interiors cannot be recovered from a bounding box.")
	var request := BuildingRequest.from_dict(record["request"])
	var made := BigGlade.generate(request)
	if not made.is_ok():
		return {"ok": false, "errors": made.errors}
	if made.plan == null:
		return _error("unsupported_interior", "Family '%s' has no HousePlan to export for '%s'." % [request.kind, building_id])
	var plan: HousePlan = made.plan
	var transform_data: Dictionary = record["transform"]
	var basis_rows: Variant = transform_data.get("basis")
	var origin: Variant = transform_data.get("origin")
	if not basis_rows is Array or basis_rows.size() != 3 or not _vector(origin):
		return _error("invalid_transform", "Transform requires three basis columns and an origin.")
	for column in basis_rows:
		if not _vector(column):
			return _error("invalid_transform", "Basis columns must contain three finite numbers.")
	var xf := Transform3D(Basis(_v3(basis_rows[0]), _v3(basis_rows[1]), _v3(basis_rows[2])), _v3(origin))
	if not xf.basis.is_conformal() or absf(xf.basis.determinant() - 1.0) > 0.001:
		return _error("invalid_transform", "C1 placement must be a rigid rotation and translation.")
	var rooms: Array = []
	var doors: Array = []
	var windows: Array = []
	var stairs: Array = []
	var furniture: Array = []
	for i in range(plan.rooms.size()):
		var r: Dictionary = plan.rooms[i]
		var polygon := PackedVector2Array()
		for p in r.get("outline", _corners(r["rect"])):
			polygon.append(_point(p, xf))
		var bound := Poly.bounding_rect(polygon)
		var room := {"room_id": _room_id(plan, building_id, i), "storey": int(r.get("storey", 0)),
			"purpose": String(r["kind"]).replace("_", "-"), "rect_m": _rect(bound),
			"poly_m": _points(polygon)}
		if plan.focus_room() == i:
			var facing := xf.basis * (Basis(Vector3.UP, plan.focus_facing()) * Vector3.FORWARD)
			room["focus"] = {"kind": plan.focus_cat(), "at_m": _p2(_point(plan.focus_pos(), xf)),
				"facing": [_n(facing.x), _n(facing.z)], "faces_door": plan.focus_faces_door()}
		room["privacy"] = "private" if r["kind"] in [&"bedroom", &"guest_room", &"suite"] else "service" if r["kind"] in [&"kitchen", &"store", &"laundry"] else "public"
		rooms.append(room)
	for i in range(plan.doors.size()):
		var d: Dictionary = plan.doors[i]
		doors.append({"door_id": "%s/d-%03d" % [building_id, i],
			"between": [_room_id(plan, building_id, int(d["a"])), _room_id(plan, building_id, int(d["b"]))],
			"kind": "exterior" if d["exterior"] else "door", "at_m": _p2(_point(d["pos"], xf)),
			"normal": _p2(_direction(d["normal"], xf)), "width_m": _n(d["width"]),
			"storey": int(d.get("storey", 0))})
	for i in range(plan.windows.size()):
		var w: Dictionary = plan.windows[i]
		var normal := _direction(w["normal"], xf)
		windows.append({"window_id": "%s/w-%03d" % [building_id, i],
			"room_id": _room_id(plan, building_id, int(w["room"])), "at_m": _p2(_point(w["pos"], xf)),
			"wall": ("east" if normal.x > 0 else "west") if absf(normal.x) > absf(normal.y) else ("south" if normal.y > 0 else "north"),
			"width_m": _n(w["width"]), "sill_m": _n(w["sill"]), "head_m": _n(w["head"])})
	for i in range(plan.stairs.size()):
		var s: Dictionary = plan.stairs[i]
		stairs.append({"stair_id": "%s/st-%03d" % [building_id, i],
			"between": [_room_id(plan, building_id, s["a"]), _room_id(plan, building_id, s["b"])],
			"from_storey": s["storey"], "to_storey": s["to_storey"], "width_m": _n(s["width"])})
	for i in range(plan.furniture.size()):
		var f: Dictionary = plan.furniture[i]
		var position: Vector3 = xf * f["pos"]
		var facing: Vector3 = xf.basis * (Basis(Vector3.UP, float(f["yaw"])) * Vector3.FORWARD)
		furniture.append({"prop_id": "%s/p-%03d" % [building_id, i],
			"room_id": _room_id(plan, building_id, f["room"]), "kind": str(f.get("cat", f["key"])).replace("_", "-"),
			"key": f["key"], "at_m": [_n(position.x), _n(position.z)],
			"elevation_m": _n(position.y), "facing": [_n(facing.x), _n(facing.z)]})
	var out := {"schema": SCHEMA, "schema_version": 1, "building_id": building_id,
		"kind": record.get("kind", String(request.kind)), "generator": "bigglade-0.3", "seed": str(request.seed),
		"rooms": rooms, "doors": doors, "windows": windows, "stairs": stairs, "furniture": furniture,
		"compromises": BuildingDocument._plain(plan.compromises),
		"entrance_door_id": "%s/d-%03d" % [building_id, plan.entrance()]}
	var failures := validate(out, record)
	return out if failures.is_empty() else {"ok": false, "errors": failures}


static func validate(plan: Dictionary, building: Dictionary) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var bounds_data: Array = building.get("rect_m", [])
	if bounds_data.size() != 4:
		errors.append({"code": "invalid_bounds", "field": "rect_m", "message": "C1 building requires rect_m."})
		return errors
	var bounds := Rect2(bounds_data[0], bounds_data[1], bounds_data[2], bounds_data[3]).grow(0.003)
	var graph := {"outside": []}
	var levels := {}
	for room in plan["rooms"]:
		var r: Array = room["rect_m"]
		if not bounds.encloses(Rect2(r[0], r[1], r[2], r[3])):
			errors.append({"code": "room_outside", "field": room["room_id"], "message": "Room lies outside the C1 building rectangle."})
		graph[room["room_id"]] = []
		levels[int(room["storey"])] = true
	for edge in plan["doors"] + plan["stairs"]:
		var pair: Array = edge["between"]
		# A back door must not make a room disconnected from the FRONT seem
		# reachable by treating all of outdoors as an interior corridor.
		if "outside" in pair and edge.get("door_id", "") != plan.get("entrance_door_id", ""):
			continue
		if not graph.has(pair[0]) or not graph.has(pair[1]):
			errors.append({"code": "invalid_link", "field": "between", "message": "Door or stair references an unknown room."})
			continue
		graph[pair[0]].append(pair[1])
		graph[pair[1]].append(pair[0])
	var seen := {"outside": true}
	var pending: Array = ["outside"]
	while not pending.is_empty():
		for next in graph[pending.pop_back()]:
			if not seen.has(next):
				seen[next] = true
				pending.append(next)
	for room in plan["rooms"]:
		if not seen.has(room["room_id"]):
			errors.append({"code": "unreachable_room", "field": room["room_id"], "message": "Room has no door/stair route from outside."})
	for level in levels:
		if not levels.has(level + 1):
			continue
		var linked := false
		for stair in plan["stairs"]:
			linked = linked or (int(stair["from_storey"]) == level and int(stair["to_storey"]) == level + 1)
		if not linked:
			errors.append({"code": "missing_stair", "field": "stairs", "message": "Consecutive storeys lack a stair."})
	return errors


static func _room_id(plan: HousePlan, id: String, room: int) -> String:
	return "outside" if room < 0 else "%s/s%d-r%d" % [id, plan.rooms[room].get("storey", 0), room]

static func _point(p: Vector2, xf: Transform3D) -> Vector2:
	var v := xf * Vector3(p.x, 0.0, p.y)
	return Vector2(v.x, v.z)

static func _direction(p: Vector2, xf: Transform3D) -> Vector2:
	var v := xf.basis * Vector3(p.x, 0.0, p.y)
	return Vector2(v.x, v.z)

static func _corners(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

static func _vector(v: Variant) -> bool:
	if not v is Array or v.size() != 3:
		return false
	for n in v:
		if not (n is float or n is int) or not is_finite(float(n)):
			return false
	return true

static func _v3(v: Array) -> Vector3:
	return Vector3(v[0], v[1], v[2])

static func _n(v: float) -> float:
	return snappedf(v, 0.001)

static func _p2(p: Vector2) -> Array:
	return [_n(p.x), _n(p.y)]

static func _rect(r: Rect2) -> Array:
	return [_n(r.position.x), _n(r.position.y), _n(r.size.x), _n(r.size.y)]

static func _points(poly: PackedVector2Array) -> Array:
	var out: Array = []
	for p in poly:
		out.append(_p2(p))
	return out

static func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "errors": [{"code": code, "field": "building", "message": message}]}

func _finish(result: Dictionary, path: String) -> void:
	var text := JSON.stringify(result, "\t", true, true) + "\n"
	if path != "":
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			print(JSON.stringify(_error("write_failed", "Cannot write output file.")))
			quit(2)
			return
		file.store_string(text)
		file.close()
	print(JSON.stringify({"ok": not result.has("errors"), "out": path, "errors": result.get("errors", [])}))
	quit(3 if result.has("errors") else 0)
