extends SceneTree
## Bounded mechanical regression for the actual Witch camera selector.
## No viewport, renderer stage, image output, or second navigation grid is made.

class NonProcessingRenderer:
	extends "res://tools/render_witch_personality.gd"
	func _init() -> void:
		pass


const REQUESTS_PATH := "res://tests/fixtures/witch_family_requests.json"
const POSITIVE_CASES := ["witch_small_1", "witch_small_8102", "witch_small_21325", "control_cottage_small"]
var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REQUESTS_PATH))
	if not parsed is Dictionary:
		printerr("CAMERA_REGRESSION_FAIL request fixture parse")
		quit(2)
		return
	var entries: Dictionary = {}
	for row in parsed.get("cases", []):
		entries[String(row.get("id", ""))] = row
	var renderer := NonProcessingRenderer.new()
	for case_id in POSITIVE_CASES:
		if not entries.has(case_id):
			_fail("missing frozen request " + case_id)
			continue
		_probe_positive(renderer, case_id, entries[case_id].get("request", {}))
	if entries.has("witch_small_8102"):
		_probe_blocked_room(renderer, entries["witch_small_8102"].get("request", {}))
	else:
		_fail("missing frozen request witch_small_8102 for negative control")
	renderer.free()
	print("CAMERA_REGRESSION failed=", _failed)
	quit(1 if _failed else 0)


func _probe_positive(renderer: Object, case_id: String, request_data: Dictionary) -> void:
	var request := BuildingRequest.from_dict(request_data)
	var generated: GeneratedBuilding = BrickWild.generate(request)
	if not generated.is_ok() or generated.plan == null:
		_fail(case_id + " public generation failed: " + str(generated.errors))
		return
	var plan: HousePlan = generated.plan
	var witch_case := String(request.style) == "witch_hut"
	var room: int = renderer._workshop_room(plan) if witch_case else renderer._ordinary_control_room(plan)
	if room < 0:
		_fail(case_id + " required activity room missing")
		return
	var pieces: Array[Dictionary] = renderer._room_focus_pieces(plan, room, witch_case)
	var anchor: Vector2 = renderer._pieces_anchor(pieces)
	var station: Dictionary = {}
	for piece in pieces:
		if String(piece.get("cat", "")) == "workbench" \
				and (not witch_case or String(piece.get("activity_group", "")) == "witchwork"):
			station = piece
			anchor = Rect2(piece.get("rect", Rect2())).get_center()
			break
	var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var floor_y: float = HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
	var camera: Dictionary = renderer._find_eye_camera(plan, room, pieces, anchor,
		floor_y, room_rect, station)
	var nav_report: Dictionary = HouseNavCheck.new().check(plan)
	if not bool(nav_report.get("ok", false)):
		_fail(case_id + " HouseNavCheck failed: " + str(nav_report.get("failures", [])))
	if not bool(camera.get("body_clear", false)) or not bool(camera.get("reachable", false)) \
			or int(camera.get("candidate_count", 0)) <= 0:
		_fail(case_id + " camera search found no reached clear body position")
		return
	var eye: Vector3 = camera["eye"]
	var p := Vector2(eye.x, eye.z)
	if p.x < room_rect.position.x + 0.34 or p.x > room_rect.end.x - 0.34 \
			or p.y < room_rect.position.y + 0.34 or p.y > room_rect.end.y - 0.34:
		_fail(case_id + " selected body is outside wall-clear room bounds: " + str(p))
	print("CAMERA_POSITIVE case=", case_id, " candidates=", camera.get("candidate_count"),
		" eye=", str(eye), " nav_cells=", nav_report.get("stats", {}).get("reached_cells", -1))


func _probe_blocked_room(renderer: Object, request_data: Dictionary) -> void:
	var request := BuildingRequest.from_dict(request_data)
	var generated: GeneratedBuilding = BrickWild.generate(request)
	if not generated.is_ok() or generated.plan == null:
		_fail("blocked negative control public generation failed")
		return
	var plan: HousePlan = generated.plan
	var room: int = renderer._workshop_room(plan)
	if room < 0:
		_fail("blocked negative control workshop missing")
		return
	var pieces: Array[Dictionary] = renderer._room_focus_pieces(plan, room, true)
	var anchor: Vector2 = renderer._pieces_anchor(pieces)
	var station: Dictionary = {}
	for piece in pieces:
		if String(piece.get("cat", "")) == "workbench" and String(piece.get("activity_group", "")) == "witchwork":
			station = piece
			anchor = Rect2(piece.get("rect", Rect2())).get_center()
			break
	var room_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var floor_y: float = HouseFurnishGeometry.storey_base(plan, room) + HouseGeometry.FLOOR_T
	# A real catalogue workbench with a deliberately room-wide measured footprint.
	# Its standing height remains measured and ordinary; only its extent is enlarged.
	plan.furniture.append({"room": room, "key": "Workbench", "cat": "workbench",
		"activity_group": "test_blocker", "pos": Vector3(room_rect.get_center().x, floor_y,
		room_rect.get_center().y), "scale": 100.0, "height_scale": 1.0,
		"yaw": 0.0, "rect": room_rect, "mounted": false, "host": -1, "storey": 0})
	var camera: Dictionary = renderer._find_eye_camera(plan, room, pieces, anchor,
		floor_y, room_rect, station)
	var nav_report: Dictionary = HouseNavCheck.new().check(plan)
	if bool(camera.get("body_clear", false)) or bool(camera.get("reachable", false)) \
			or int(camera.get("candidate_count", 0)) != 0:
		_fail("whole-room measured body blocker was accepted: " + str(camera))
	if bool(nav_report.get("ok", true)):
		_fail("whole-room blocker did not affect the existing navigation grid")
	print("CAMERA_NEGATIVE whole_room_body_blocker rejected=true candidates=",
		camera.get("candidate_count"), " nav_ok=", nav_report.get("ok", false))


func _fail(message: String) -> void:
	_failed = true
	printerr("CAMERA_REGRESSION_FAIL ", message)
