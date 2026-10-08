extends SceneTree
## LIVE-SURFACES contract: architectural hosts and measured fittings are
## checked separately. Phase selectors retain the complete fixture.

var failures: Array[String] = []
var six_case_positive: Dictionary = {}
var six_case_unsatisfied: Dictionary = {}

var selected_phase := "all"
const PHASES := ["all", "style_farmhouse", "style_cottage", "style_witch_hut", "controls", "cases_farmhouse", "cases_cottage", "cases_witch_hut"]

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("phase="):
			selected_phase = String(arg).substr(6)
	if not PHASES.has(selected_phase):
		printerr("Unknown surface contract phase: ", selected_phase)
		quit(2)
		return
	for style in [&"farmhouse", &"cottage", &"witch_hut"]:
		if selected_phase != "all" and selected_phase != "style_" + String(style):
			continue
		print("SURFACE_STYLE_START ", style)
		var spec := HouseSpec.new()
		spec.style = style
		spec.width = 11.0
		spec.length = 14.0
		var plan := HouseGenerator.generate(spec, 7441, true)
		HousePlanFeatures.compose_wall_hosts(plan, spec)
		_check_composition_idempotence(plan, spec)
		_check_relations(plan, style)
		_check_displaced_mounted_control(plan, style)
		_check_sleep_reading_station(plan, style)
		_check_hearth_recess(plan, style)
		_check_structural_gate(plan, style)
		_check_aperture_and_route_negatives(style)
		print("SURFACE_STYLE_END ", style)
	if selected_phase in ["all", "controls"]:
		_check_missing_groups_is_safe_empty()
		_check_family_exclusion()
		_check_vertical_mount_collision()
		_check_existing_task_light_reuse()
		_check_reused_shelf_book()
		_check_partition_timber_control()
		_check_exterior_timber_control()
		_check_door_aperture_mesh_control()
		print("SURFACE_CONTROLS_END")
	if selected_phase == "all" or selected_phase.begins_with("cases_"):
		_check_six_renderer_cases()
	if selected_phase == "all":
		for group_name in ["cooking", "sleep", "witchwork"]:
			if six_case_positive.get(group_name, 0) == 0:
				failures.append("six-case %s station coverage is all UNSAT; no successful design case" % group_name)
	for failure in failures:
		printerr("FAIL ", failure)
	print("surface host contract phase=", selected_phase, ": %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)




func _check_six_renderer_cases() -> void:
	var cases := [
		{"id": "farmhouse_small_8102", "style": &"farmhouse", "width": 9.0, "length": 12.0, "seed": 8102},
		{"id": "farmhouse_ample_1", "style": &"farmhouse", "width": 11.0, "length": 14.0, "seed": 1},
		{"id": "cottage_small_8102", "style": &"cottage", "width": 9.0, "length": 12.0, "seed": 8102},
		{"id": "cottage_ample_1", "style": &"cottage", "width": 11.0, "length": 14.0, "seed": 1},
		{"id": "witch_hut_small_8102", "style": &"witch_hut", "width": 9.0, "length": 12.0, "seed": 8102},
		{"id": "witch_hut_ample_1", "style": &"witch_hut", "width": 11.0, "length": 14.0, "seed": 1},
	]
	for row in cases:
		if selected_phase != "all" and selected_phase != "cases_" + String(row["style"]):
			continue
		print("SURFACE_CASE_START ", row["id"])
		var spec := HouseSpec.new()
		spec.style = row["style"]
		spec.width = float(row["width"])
		spec.length = float(row["length"])
		spec.height = 2.6
		spec.storeys = 1
		var plan := HouseGenerator.generate(spec, int(row["seed"]), true)
		if plan == null:
			failures.append("%s did not generate a house plan" % row["id"])
			continue
		var source_cooking_torch: Dictionary = {}
		var source_cooking_light: Dictionary = {}
		if String(row["id"]) == "farmhouse_ample_1":
			source_cooking_torch = _source_cooking_torch(plan)
			source_cooking_light = _source_cooking_task_light(plan)
		HousePlanFeatures.compose_wall_hosts(plan, spec)
		var activities: Array[String] = ["cooking", "sleep"]
		if spec.style == &"witch_hut":
			activities.append("witchwork")
		for activity in activities:
			_check_renderer_activity_station(plan, String(row["id"]), activity)
			if String(row["id"]) == "farmhouse_ample_1" and activity == "cooking":
				_check_cooking_prep_heat(plan, source_cooking_torch, source_cooking_light)
		_check_composition_idempotence(plan, spec)
		_check_ordinary_bedside_profile(plan, String(row["id"]))
		print("SURFACE_CASE_END ", row["id"])


func _measured_mounted_body_rect(item: Dictionary) -> Rect2:
	var key := String(item.get("key", ""))
	var yaw := float(item.get("yaw", 0.0)) + PropCatalog.face_offset(key)
	var origin := PropCatalog.house_origin(item)
	var center := PropCatalog.plan_centre(key, origin, yaw, float(item.get("scale", 1.0)))
	var dims := PropCatalog.footprint_rotated(key, yaw) * float(item.get("scale", 1.0))
	return Rect2(center - dims * 0.5, dims)


func _source_cooking_torch(plan: HousePlan) -> Dictionary:
	var kitchen_room := -1
	for item in plan.furniture:
		if String(item.get("activity_group", "")) == "cooking" \
				and String(item.get("cat", "")) == "hearth":
			kitchen_room = int(item.get("room", -1))
			break
	for item in plan.furniture:
		if int(item.get("room", -1)) == kitchen_room \
				and String(item.get("key", "")) == "Torch_Metal" \
				and bool(item.get("mounted", false)) \
				and not bool(item.get("surface_generated", false)):
			return item.duplicate(true)
	return {}


func _source_cooking_task_light(plan: HousePlan) -> Dictionary:
	var kitchen_room := -1
	for item in plan.furniture:
		if String(item.get("activity_group", "")) == "cooking" \
				and String(item.get("cat", "")) == "hearth":
			kitchen_room = int(item.get("room", -1))
			break
	var lamp_count := 0
	var source: Dictionary = {}
	for item in plan.furniture:
		if int(item.get("room", -1)) != kitchen_room or not bool(item.get("mounted", false)) \
				or PropCatalog.category(String(item.get("key", ""))) != "sconce":
			continue
		lamp_count += 1
		if source.is_empty() and not bool(item.get("surface_generated", false)):
			source = item.duplicate(true)
	if not source.is_empty():
		source["fixture_initial_lamp_count"] = lamp_count
	return source


func _check_cooking_prep_heat(plan: HousePlan, source_torch: Dictionary,
		source_light: Dictionary) -> void:
	var room := -1
	for item in plan.furniture:
		if String(item.get("activity_group", "")) == "cooking":
			room = int(item.get("room", -1))
			break
	if room < 0:
		failures.append("farmhouse_ample_1 has no cooking room for heat/prep test")
		return
	var hearth: Dictionary = {}
	var prep: Dictionary = {}
	var hearth_index := -1
	var prep_index := -1
	var role_counts: Dictionary = {}
	var authored_kitchen_torch := false
	for index in range(plan.furniture.size()):
		var piece: Dictionary = plan.furniture[index]
		if int(piece.get("room", -1)) != room:
			continue
		if not source_torch.is_empty() \
				and String(piece.get("key", "")) == String(source_torch.get("key", "")) \
				and bool(piece.get("mounted", false)) == bool(source_torch.get("mounted", false)) \
				and Vector3(piece.get("pos", Vector3.ZERO)).is_equal_approx(Vector3(source_torch.get("pos", Vector3.ZERO))) \
				and absf(float(piece.get("yaw", 0.0)) - float(source_torch.get("yaw", 0.0))) < 0.001 \
				and absf(float(piece.get("scale", 1.0)) - float(source_torch.get("scale", 1.0))) < 0.001:
			authored_kitchen_torch = true
		if String(piece.get("activity_group", "")) != "cooking":
			continue
		var category := String(piece.get("cat", ""))
		role_counts[category] = int(role_counts.get(category, 0)) + 1
		if category == "hearth":
			hearth = piece
			hearth_index = index
		elif category == "workbench":
			prep = piece
			prep_index = index
	for category in ["hearth", "storage", "workbench", "cookware", "bucket"]:
		if int(role_counts.get(category, 0)) < 1:
			failures.append("farmhouse_ample_1 cooking proximity fixture lacks required %s role" % category)
	if source_torch.is_empty() or not authored_kitchen_torch:
		failures.append("farmhouse_ample_1 authored kitchen Torch_Metal moved or lost its source pose through composition")
	if hearth.is_empty() or prep.is_empty():
		failures.append("farmhouse_ample_1 cooking heat/prep pair is missing")
		return
	var heat_use := Rect2(hearth.get("zone", Rect2()))
	if not heat_use.has_area():
		heat_use = Rect2(hearth.get("rect", Rect2()))
	var prep_use := Rect2(prep.get("zone", Rect2()))
	if not prep_use.has_area():
		prep_use = Rect2(prep.get("rect", Rect2()))
	var measured_gap := HouseFurnishPlacement._cooking_prep_heat_gap(plan, room, prep)
	var independent_gap := HousePlanFeatures._rect_distance(prep_use, heat_use)
	if not is_finite(measured_gap) or absf(measured_gap - independent_gap) > 0.001:
		failures.append("farmhouse_ample_1 cooking heat/prep scorer differs from independent measured use-zone gap")
	# Keep prep within the compositor's measured task relationship distance.
	if measured_gap > 1.9:
		failures.append("farmhouse_ample_1 cooking prep use zone is more than 1.9 m from heat use")
	var away := (prep_use.get_center() - heat_use.get_center()).normalized()
	if away.length_squared() < 0.5:
		away = Vector2.RIGHT
	var displaced := prep.duplicate(true)
	var delta := away * 4.5
	var original_rect := Rect2(prep["rect"])
	displaced["rect"] = Rect2(original_rect.position + delta, original_rect.size)
	displaced["zone"] = Rect2(prep_use.position + delta, prep_use.size)
	var displaced_gap := HouseFurnishPlacement._cooking_prep_heat_gap(plan, room, displaced)
	if displaced_gap <= maxf(1.9, measured_gap + 0.5):
		failures.append("displaced cooking prep negative remains within the accepted heat-use relation")
	var actual_option := {"heat_gap": measured_gap, "score": -1000.0}
	var displaced_option := {"heat_gap": displaced_gap, "score": 10000.0}
	if not HouseFurnishPlacement._cooking_option_precedes(actual_option, displaced_option):
		failures.append("cooking option scorer lets distant prep outrank the closer heat-side pair")
	var dim_near := {"heat_gap": 0.8, "score": -100.0}
	var bright_near := {"heat_gap": 1.5, "score": 100.0}
	if not HouseFurnishPlacement._cooking_option_precedes(bright_near, dim_near):
		failures.append("heat proximity erased daylight/affinity preference among legal prep candidates")
	var source_light_preserved := false
	var final_cooking_lamp_count := 0
	for piece in plan.furniture:
		if int(piece.get("room", -1)) == room and bool(piece.get("mounted", false)) \
				and PropCatalog.category(String(piece.get("key", ""))) == "sconce":
			final_cooking_lamp_count += 1
	var task_light: Dictionary = {}
	var cooking_light_hosts := 0
	for host_variant in plan.wall_hosts:
		var host: Dictionary = host_variant
		if int(host.get("room", -1)) == room \
				and String(host.get("activity_group", "")) == "cooking" \
				and String(host.get("role", "")) == "lighting":
			cooking_light_hosts += 1
			for piece in plan.furniture:
				if String(piece.get("wall_host_id", "")) == String(host.get("id", "")) \
						and String(piece.get("mount_relation", "")) == "lights_activity" \
						and String(piece.get("activity_anchor_id", "")) == String(host.get("anchor_id", "")):
					task_light = piece
					break
	if source_light.is_empty():
		failures.append("farmhouse_ample_1 generated no pre-composition cooking task lamp")
	else:
		var initial_lamp_body := _measured_mounted_body_rect(source_light)
		if not initial_lamp_body.has_area() or HousePlanFeatures._rect_distance(initial_lamp_body, prep_use) > 1.9:
			failures.append("initial cooking lamp body is outside the 1.9 m prep-use relation")
		var imported_lamp_bounds := _actual_imported_triangle_bounds(source_light)
		if imported_lamp_bounds.size == Vector3.ZERO:
			failures.append("initial cooking lamp has no imported mesh triangles")
		else:
			var imported_xz := Rect2(Vector2(imported_lamp_bounds.position.x, imported_lamp_bounds.position.z),
				Vector2(imported_lamp_bounds.size.x, imported_lamp_bounds.size.z))
			if HousePlanFeatures._rect_distance(imported_xz, prep_use) > 1.9:
				failures.append("actual initial lamp mesh exceeds the 1.9 m prep-use reach")
		var source_pose: Vector3 = source_light.get("pos", Vector3.ZERO)
		var source_body := _measured_mounted_body_rect(source_light)
		var source_wall_index := HouseFurnishScore._back_wall_index(plan, room, source_body, source_light)
		if source_wall_index < 0:
			failures.append("initial cooking lamp does not resolve to an actual wall")
		else:
			var source_wall: Dictionary = HouseGeometry.room_walls(plan, room)[source_wall_index]
			var source_horizontal := absf(Vector2(source_wall["normal"]).y) > 0.5
			var source_along := source_body.get_center().x if source_horizontal else source_body.get_center().y
			var remeasured_pose := HousePlanFeatures._wall_fixture_pose(String(source_light.get("key", "")),
				source_wall, source_along, source_pose.y, float(source_light.get("scale", 1.0)))
			if not Vector3(remeasured_pose["pos"]).is_equal_approx(source_pose) \
					or absf(float(remeasured_pose["yaw"]) - float(source_light.get("yaw", 0.0))) > 0.001:
				failures.append("committed first cooking lamp pose differs from the wall pose that was validated")
		for piece in plan.furniture:
			if int(piece.get("room", -1)) != room \
					or String(piece.get("key", "")) != String(source_light.get("key", "")):
				continue
			if bool(piece.get("mounted", false)) == bool(source_light.get("mounted", false)) \
					and Vector3(piece.get("pos", Vector3.ZERO)).is_equal_approx(Vector3(source_light.get("pos", Vector3.ZERO))) \
					and absf(float(piece.get("yaw", 0.0)) - float(source_light.get("yaw", 0.0))) < 0.001 \
					and absf(float(piece.get("scale", 1.0)) - float(source_light.get("scale", 1.0))) < 0.001:
				source_light_preserved = true
	if not source_light_preserved:
		failures.append("cooking task lamp pose changed or was replaced during surface composition")
	if not source_light.is_empty() and final_cooking_lamp_count != int(source_light.get("fixture_initial_lamp_count", -1)):
		failures.append("cooking surface composition duplicated or removed a mounted lamp")
	if cooking_light_hosts != 1 or task_light.is_empty():
		failures.append("cooking compositor did not reuse exactly one mounted task lamp")
	elif not task_light.is_empty():
		if source_light.is_empty() \
				or String(task_light.get("key", "")) != String(source_light.get("key", "")) \
				or not Vector3(task_light.get("pos", Vector3.ZERO)).is_equal_approx(Vector3(source_light.get("pos", Vector3.ZERO))) \
				or absf(float(task_light.get("yaw", 0.0)) - float(source_light.get("yaw", 0.0))) >= 0.001:
			failures.append("cooking task-light host did not bind the original mounted lamp pose")
		var lamp_body := _measured_mounted_body_rect(task_light)
		if not lamp_body.has_area() or HousePlanFeatures._rect_distance(lamp_body, prep_use) > 1.9:
			failures.append("reused cooking task lamp body exceeds 1.9 m from actual prep use zone")
	var nav_report: Dictionary = HouseNavCheck.new().check(plan)
	var unreachable: Array = nav_report.get("unreachable_items", [])
	if hearth_index < 0 or prep_index < 0 or hearth_index in unreachable or prep_index in unreachable:
		failures.append("farmhouse_ample_1 cooking heat/prep pair is not reachable on body-eroded nav")


func _check_ordinary_bedside_profile(plan: HousePlan, case_id: String) -> void:
	var room := -1
	var bed: Dictionary = {}
	var bed_count := 0
	for item in plan.furniture:
		if String(item.get("activity_group", "")) == "sleep" and String(item.get("cat", "")) == "bed":
			if room < 0:
				room = int(item.get("room", -1))
			if int(item.get("room", -1)) == room:
				bed = item
				bed_count += 1
	var candidate: Dictionary = {}
	var count := 0
	for item in plan.furniture:
		if int(item.get("room", -1)) != room:
			continue
		if String(item.get("activity_group", "")) == "sleep" and String(item.get("cat", "")) == "nightstand" and String(item.get("key", "")) == "Nightstand_Shelf":
			candidate = item
			count += 1
	if bed_count != 1 or count != 1 or bed.is_empty() or candidate.is_empty():
		failures.append("%s needs one generated sleep bed and one ordinary nightstand, found beds=%d nightstands=%d" % [case_id, bed_count, count])
		return
	if not HouseFurnishArrangementCheck._backs_bed_head(plan, candidate):
		failures.append("%s ordinary nightstand does not face the foot while its back meets the bed head-wall" % case_id)
	var reversed: Dictionary = candidate.duplicate(true)
	reversed["yaw"] = wrapf(float(reversed["yaw"]) + PI, -PI, PI)
	if HouseFurnishArrangementCheck._backs_bed_head(plan, reversed):
		failures.append("%s reversed nightstand facing incorrectly passes head-wall contract" % case_id)
	var nav_check := HouseNavCheck.new()
	var nav_report := nav_check.check(plan)
	var nightstand_index := plan.furniture.find(candidate)
	if nightstand_index < 0 or nightstand_index in nav_report.get("unreachable_items", []):
		failures.append("%s generated nightstand use-zone is not human-reachable" % case_id)
	var bed_host := {"rect": bed["rect"], "yaw": float(bed["yaw"]), "cat": "bed"}
	var floor_rect := HouseGeometry.room_floor_rect(plan, room)
	var blocked: Array[Rect2] = [floor_rect.grow(1.0)]
	var zones: Array[Rect2] = []
	var bed_rect: Rect2 = bed["rect"]
	var bed_center := bed_rect.get_center()
	var head_dir := Vector2(sin(float(bed["yaw"])), cos(float(bed["yaw"])))
	var side_dir := Vector2(-head_dir.y, head_dir.x)
	var shelf_rect: Rect2 = candidate["rect"]
	var outward := side_dir * signf((shelf_rect.get_center() - bed_center).dot(side_dir))
	var obstacles: Array[Rect2] = []
	for index in range(plan.furniture.size()):
		if index == nightstand_index:
			continue
		var other: Dictionary = plan.furniture[index]
		if int(other.get("room", -1)) != room or bool(other.get("mounted", false)) or int(other.get("host", -1)) >= 0:
			continue
		if PropCatalog.blocks_floor(String(other.get("key", ""))):
			obstacles.append(Rect2(other.get("rect", Rect2())))
	if not HouseFurnishPlacement._ordinary_bedside_stance_clear(plan, room, candidate, outward, head_dir, obstacles):
		failures.append("%s generated nightstand lacks the measured clear bedside lane" % case_id)
	var clipped_outward := outward
	var wall_projection := -INF
	for corner in [floor_rect.position, Vector2(floor_rect.end.x, floor_rect.position.y), floor_rect.end, Vector2(floor_rect.position.x, floor_rect.end.y)]:
		wall_projection = maxf(wall_projection, corner.dot(clipped_outward))
	var clipped_radius := absf(clipped_outward.x) * shelf_rect.size.x * 0.5 + absf(clipped_outward.y) * shelf_rect.size.y * 0.5
	var clipped_center := shelf_rect.get_center() + clipped_outward * (wall_projection - shelf_rect.get_center().dot(clipped_outward) - clipped_radius - 0.01)
	var clipped := HouseFurnishGeometry.candidate("Nightstand_Shelf", clipped_center, float(candidate["yaw"]), 1.0, float(candidate.get("scale", 1.0)))
	if not HouseFurnishGeometry.fits(plan, room, clipped, floor_rect, [], [], []):
		failures.append("%s clipped-lane control does not have a floor-fitting nightstand body and zone" % case_id)
	elif HouseFurnishPlacement._ordinary_bedside_stance_clear(plan, room, clipped, clipped_outward, head_dir, []):
		failures.append("%s floor-fitting nightstand whose outward lane crosses the wall incorrectly passes" % case_id)
	var blocked_candidate := HouseFurnishPlacement._head_support_candidate(plan, room,
		"Nightstand_Shelf", bed_host, blocked, zones, 0.8, 0.62, true)
	if not blocked_candidate.is_empty():
		failures.append("%s blocked bedside geometry still yielded a nightstand pose" % case_id)


func _check_renderer_activity_station(plan: HousePlan, case_id: String,
		group_name: String) -> void:
	var room := -1
	var anchor_count := 0
	for index in plan.furniture.size():
		var item: Dictionary = plan.furniture[index]
		if String(item.get("activity_group", "")) == group_name:
			if room < 0:
				room = int(item.get("room", -1))
			if int(item.get("room", -1)) == room:
				anchor_count += 1
	if room < 0 or anchor_count == 0:
		failures.append("%s is missing its authored %s activity group" % [case_id, group_name])
		return
	var required_categories: Dictionary = {}
	match group_name:
		"cooking": required_categories = {"hearth": 1, "storage": 1,
			"workbench": 1, "bucket": 1, "cookware": 1}
		"sleep": required_categories = {"bed": 1, "nightstand": 1, "chest": 1, "sconce": 1}
		"witchwork": required_categories = {"hearth": 1, "workbench": 1,
			"shelf": 1, "alchemy": 2, "books": 1}
	var role_counts: Dictionary = {}
	for item in plan.furniture:
		if int(item.get("room", -1)) == room and String(item.get("activity_group", "")) == group_name:
			var category := String(item.get("cat", ""))
			role_counts[category] = int(role_counts.get(category, 0)) + 1
	for category in required_categories:
		if int(role_counts.get(category, 0)) < int(required_categories[category]):
			failures.append("%s %s is missing authored source role %s (%d/%d); rendering remains unaccepted" % [
				case_id, group_name, category, int(role_counts.get(category, 0)), int(required_categories[category])])
	var station_hosts: Array[Dictionary] = []
	for host in plan.wall_hosts:
		if int(host.get("room", -1)) == room and String(host.get("activity_group", "")) == group_name \
				and String(host.get("role", "")) == "activity_support":
			station_hosts.append(host)
	var unsatisfied := plan.was_dropped(room, "surface:%s:no_safe_station" % group_name)
	if station_hosts.size() == 1:
		six_case_positive[group_name] = int(six_case_positive.get(group_name, 0)) + 1
	elif station_hosts.is_empty() and unsatisfied:
		six_case_unsatisfied[group_name] = int(six_case_unsatisfied.get(group_name, 0)) + 1
		failures.append("%s %s is explicitly UNSAT; this renderer case is not accepted" % [case_id, group_name])
	if station_hosts.size() > 1:
		failures.append("%s %s emitted %d support hosts; expected one" % [
			case_id, group_name, station_hosts.size()])
	elif station_hosts.is_empty() and not unsatisfied:
		failures.append("%s %s has no support and no explicit no-safe-station reason" % [
			case_id, group_name])
	elif station_hosts.size() == 1:
		var host: Dictionary = station_hosts[0]
		var anchor_id := String(host.get("anchor_id", ""))
		var source_anchor: Dictionary = {}
		for item in plan.furniture:
			if String(item.get("surface_anchor_id", "")) == anchor_id:
				source_anchor = item
				break
		if source_anchor.is_empty():
			failures.append("%s %s support host has no surviving source anchor" % [case_id, group_name])
		var prep_rect := Rect2()
		if not source_anchor.is_empty():
			prep_rect = Rect2(source_anchor.get("zone", Rect2()))
			if not prep_rect.has_area():
				prep_rect = Rect2(source_anchor.get("rect", Rect2()))
		var fitting: Dictionary = {}
		for item in plan.furniture:
			if int(item.get("room", -1)) == room and String(item.get("wall_host_id", "")) == String(host.get("id", "")) \
					and String(item.get("mount_relation", "")) == "supports_activity" \
					and String(item.get("activity_anchor_id", "")) == anchor_id:
				fitting = item
				break
		if fitting.is_empty():
			failures.append("%s %s support host has no physically bound fitting" % [case_id, group_name])
		elif not prep_rect.has_area() or HousePlanFeatures._rect_distance(
				Rect2(fitting.get("rect", Rect2())), prep_rect) > 1.9:
			failures.append("%s %s support body is not within 1.9 m of its measured use/prep region" % [
				case_id, group_name])
		var light_hosts := 0
		for light_host in plan.wall_hosts:
			if int(light_host.get("room", -1)) == room and String(light_host.get("activity_group", "")) == group_name \
					and String(light_host.get("role", "")) == "lighting":
				light_hosts += 1
		var light_unsatisfied := plan.was_dropped(room, "surface:%s:no_safe_light" % group_name)
		if light_hosts > 1 or (light_hosts == 0 and not light_unsatisfied):
			failures.append("%s %s has no single task-light host or explicit no-safe-light reason" % [case_id, group_name])
	print("SURFACE_CASE case=", case_id, " activity=", group_name,
		" station=", "present" if not station_hosts.is_empty() else "UNSAT",
		" reason=", "none" if not unsatisfied else "surface:%s:no_safe_station" % group_name)


func _check_composition_idempotence(plan: HousePlan, spec: HouseSpec) -> void:
	var original_hosts: Array = plan.wall_hosts.duplicate(true)
	var original_furniture: Array = plan.furniture.duplicate(true)
	HousePlanFeatures.compose_wall_hosts(plan, spec)
	if plan.wall_hosts != original_hosts:
		failures.append("%s wall hosts changed on identical recomposition" % spec.style)
	if plan.furniture != original_furniture:
		failures.append("%s furniture, host indices, or supported books changed on identical recomposition" % spec.style)


func _mounted_fitting_is_clear(plan: HousePlan, room: int, wall: int, item: Dictionary) -> bool:
	var wall_row: Dictionary = HouseGeometry.room_walls(plan, room)[wall]
	var normal: Vector2 = wall_row["normal"]
	var horizontal := absf(normal.y) > 0.5
	var key := String(item.get("key", ""))
	var scale := float(item.get("scale", 1.0))
	var model_yaw := float(item.get("yaw", 0.0)) + PropCatalog.face_offset(key)
	var origin := PropCatalog.house_origin(item)
	var center := PropCatalog.plan_centre(key, origin, model_yaw, scale)
	var dims := PropCatalog.footprint_rotated(key, model_yaw) * scale
	var along_center := center.x if horizontal else center.y
	var along_half := dims.x * 0.5 if horizontal else dims.y * 0.5
	var body_lo := along_center - along_half
	var body_hi := along_center + along_half
	var body_depth := dims.dot(normal.abs())
	for span in HousePlanFeatures.clear_wall_spans(plan, room, wall, body_depth):
		if body_lo >= span.x - 0.01 and body_hi <= span.y + 0.01:
			return true
	return false


func _displaced_mounted_depth_control(plan: HousePlan, room: int, wall: int, item: Dictionary) -> bool:
	var wall_row: Dictionary = HouseGeometry.room_walls(plan, room)[wall]
	var axis := Vector2.RIGHT if absf(Vector2(wall_row["normal"]).y) > 0.5 else Vector2.DOWN
	var key := String(item["key"])
	var original_center := PropCatalog.plan_centre(key, PropCatalog.house_origin(item),
		float(item.get("yaw", 0.0)) + PropCatalog.face_offset(key),
		float(item.get("scale", 1.0)))
	for candidate in plan.furniture:
		if int(candidate.get("room", -1)) != room or not bool(candidate.get("mounted", false)):
			continue
		if HouseFurnishScore._back_wall_index(plan, room,
				Rect2(candidate.get("rect", Rect2())), candidate) != wall:
			continue
		var candidate_key := String(candidate.get("key", ""))
		var candidate_center := PropCatalog.plan_centre(candidate_key,
			PropCatalog.house_origin(candidate),
			float(candidate.get("yaw", 0.0)) + PropCatalog.face_offset(candidate_key),
			float(candidate.get("scale", 1.0)))
		var target_along := candidate_center.dot(axis)
		var moved := item.duplicate(true)
		var shift := target_along - original_center.dot(axis)
		moved["pos"] = Vector3(item["pos"]) + Vector3(axis.x * shift, 0.0, axis.y * shift)
		if not _mounted_fitting_is_clear(plan, room, wall, moved):
			return true
	return false


func _displaced_mounted_opening_control(plan: HousePlan, room: int, wall: int, item: Dictionary) -> bool:
	var wall_row: Dictionary = HouseGeometry.room_walls(plan, room)[wall]
	var normal: Vector2 = wall_row["normal"]
	var horizontal := absf(normal.y) > 0.5
	var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var key := String(item["key"])
	var original_origin := PropCatalog.house_origin(item)
	var original_center := PropCatalog.plan_centre(key, original_origin,
		float(item.get("yaw", 0.0)) + PropCatalog.face_offset(key),
		float(item.get("scale", 1.0)))
	var openings: Array[Dictionary] = []
	var wall_line := float(wall_row["from"].y) if horizontal else float(wall_row["from"].x)
	for index in plan.doors_of(room):
		var door: Dictionary = plan.doors[index]
		var door_normal: Vector2 = door["normal"]
		var door_across := float(door["pos"].y) if horizontal else float(door["pos"].x)
		if (absf(door_normal.y) > 0.5) == horizontal and absf(door_across - wall_line) <= 0.5:
			openings.append(door)
	for index in plan.windows_of(room):
		var window: Dictionary = plan.windows[index]
		var window_normal: Vector2 = window["normal"]
		var window_across := float(window["pos"].y) if horizontal else float(window["pos"].x)
		if (absf(window_normal.y) > 0.5) == horizontal and absf(window_across - wall_line) <= 0.5:
			openings.append(window)
	for opening in openings:
		var target: Vector2 = opening["pos"]
		var target_along := target.x if horizontal else target.y
		var moved := item.duplicate(true)
		var shift := target_along - original_center.dot(axis)
		moved["pos"] = Vector3(item["pos"]) + Vector3(axis.x * shift, 0.0, axis.y * shift)
		if not _mounted_fitting_is_clear(plan, room, wall, moved):
			return true
	return false


func _check_displaced_mounted_control(plan: HousePlan, style: StringName) -> void:
	var original: Array[Dictionary] = plan.furniture.duplicate(true)
	var rejected := false
	for index in original.size():
		var item: Dictionary = original[index]
		if not bool(item.get("mounted", false)):
			continue
		var room := int(item.get("room", -1))
		if room < 0 or room >= plan.room_count():
			continue
		var wall := HouseFurnishScore._back_wall_index(plan, room,
			Rect2(item.get("rect", Rect2())), item)
		if wall < 0:
			continue
		plan.furniture.clear()
		plan.furniture.append_array(original.duplicate(true))
		for fi in range(plan.furniture.size() - 1, -1, -1):
			if fi == index or int(plan.furniture[fi].get("host", -1)) == index:
				plan.furniture.remove_at(fi)
		# Require a genuinely clear original pose, then move only its along-wall
		# coordinate into a measured opening or occupied wall interval.
		if _mounted_fitting_is_clear(plan, room, wall, item) \
				and (_displaced_mounted_opening_control(plan, room, wall, item) \
					or _displaced_mounted_depth_control(plan, room, wall, item)):
			rejected = true
			break
	plan.furniture.clear()
	plan.furniture.append_array(original)
	if not rejected:
		failures.append("%s measured fitting fixture did not reject a clear prop displaced into a wall reservation" % style)


func _check_sleep_reading_station(plan: HousePlan, style: StringName) -> void:
	for room in range(plan.room_count()):
		if plan.kind_of(room) != &"bedroom":
			continue
		var nightstand: Dictionary = {}
		var clothes_chest: Dictionary = {}
		for item_index in plan.furniture_of(room):
			var piece: Dictionary = plan.furniture[item_index]
			var key := String(piece.get("key", ""))
			if key == "Nightstand_Shelf":
				nightstand = piece
			if String(piece.get("activity_group", "")) == "sleep" \
					and String(piece.get("cat", "")) == "chest" \
					and String(piece.get("activity_host_anchor", "")) != "head_end":
				clothes_chest = piece
		if clothes_chest.is_empty():
			var storage_shortfall := plan.was_dropped(room, "activity:sleep:chest")
			if not storage_shortfall:
				failures.append("%s bedroom lacks clothes chest without honest GROUPS shortfall" % style)
			else:
				print("SURFACE_UNSAT style=", style, " room=", room, " activity:sleep:chest; no independent clothes storage")
		# Reading is bedside-first. An independent clothes chest remains a separate
		# storage role and is only the reading fallback when no nightstand exists.
		var anchor: Dictionary = nightstand if not nightstand.is_empty() else clothes_chest
		if anchor.is_empty():
			if not plan.was_dropped(room, "surface:sleep:no_safe_station"):
				failures.append("%s bedroom has no reading anchor and no recorded unavailable station" % style)
			continue
		var anchor_id := String(anchor.get("surface_anchor_id", ""))
		if anchor_id == "":
			if not plan.was_dropped(room, "surface:sleep:no_safe_station"):
				failures.append("%s sleep reading anchor has no stable activity id" % style)
			continue
		var support_host: Dictionary = {}
		for host_variant in plan.wall_hosts:
			var host: Dictionary = host_variant
			if int(host.get("room", -1)) == room \
					and String(host.get("activity_group", "")) == "sleep" \
					and String(host.get("role", "")) == "activity_support" \
					and String(host.get("anchor_id", "")) == anchor_id:
				support_host = host
				break
		if support_host.is_empty():
			if not plan.was_dropped(room, "surface:sleep:no_safe_station"):
				failures.append("%s bedside reading anchor has no mounted shelf or recorded unavailable reason" % style)
			continue
		var support_index := -1
		for item_index in plan.furniture_of(room):
			var item: Dictionary = plan.furniture[item_index]
			if String(item.get("key", "")) == "Shelf_Simple" \
					and bool(item.get("mounted", false)) \
					and String(item.get("mount_relation", "")) == "supports_activity" \
					and String(item.get("activity_anchor_id", "")) == anchor_id:
				support_index = item_index
				break
		if support_index < 0:
			failures.append("%s sleep support host has no corresponding measured Shelf_Simple" % style)
			continue
		var support: Dictionary = plan.furniture[support_index]
		if String(support.get("wall_host_id", "")) != String(support_host.get("id", "")):
			failures.append("%s Shelf_Simple is not bound to its activity-support wall host" % style)
		var book_found := false
		for piece_index in plan.furniture_of(room):
			var child: Dictionary = plan.furniture[piece_index]
			if not String(child.get("key", "")).begins_with("Book_") \
					or String(child.get("activity_anchor_id", "")) != anchor_id:
				continue
			if int(child.get("host", -1)) != support_index \
					or String(child.get("surface_parent_id", "")) != String(support.get("surface_anchor_id", "")):
				continue
			if HousePlanFeatures._is_supported_surface_child(child, support, support_index):
				book_found = true
				break
		if not book_found:
			failures.append("%s nightstand reading shelf lacks a physically hosted book" % style)


func _check_hearth_recess(plan: HousePlan, style: StringName) -> void:
	var breast: Dictionary = HouseGeometry.hearth_breast(plan)
	if breast.is_empty():
		failures.append("%s ordinary domestic fixture has no planned chimney breast to inspect" % style)
		return
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	var centre: Vector2 = breast["centre"]
	var n2: Vector2 = breast["normal"]
	var normal := Vector3(n2.x, 0.0, n2.y)
	var depth: float = float(breast["depth"])
	var opening_width: float = minf(1.15, float(breast["width"]) - 0.28)
	var opening_mid_y: float = float(breast["storey"]) * plan.spec.height + 0.80
	var face := Vector3(centre.x, opening_mid_y, centre.y) + normal * depth * 0.5
	var start := face + normal * 0.10
	var finish := face - normal * (depth + HouseGeometry.wall_thickness(plan.spec) * 0.8)
	var clear_hit: Variant = _first_mesh_hit(mesh, start, finish)
	if clear_hit == null:
		failures.append("%s hearth recess has no emitted backing wall behind its opening" % style)
	else:
		var clear_point: Vector3 = clear_hit
		if start.distance_to(clear_point) < depth * 0.35:
			failures.append("%s hearth opening is still covered at the chimney-breast face" % style)
	var closed_control := _solid_firebox_plane(face, normal, opening_width, 0.92)
	var control_hit: Variant = _first_mesh_hit(closed_control, start, finish)
	if control_hit == null:
		failures.append("%s injected solid firebox face was not detected by the mesh ray" % style)
	else:
		var control_point: Vector3 = control_hit
		if absf(start.distance_to(control_point) - 0.10) > 0.01:
			failures.append("%s injected solid firebox face was not detected at its plane" % style)
	var required_roles := ["hearth_lintel", "hearth_jamb", "hearth_mantel"]
	for role in required_roles:
		var found := false
		for row in builder.component_log:
			if String(row.get("role", "")) == role:
				found = true
		if not found:
			failures.append("%s hearth lacks emitted %s geometry" % [style, role])
	var breast_mass := AABB()
	for mass in builder.mass_log:
		if String(mass.get("name", "")) == "chimney_breast":
			breast_mass = mass["aabb"]
	if breast_mass.size.x <= 0.0 or breast_mass.size.y <= 0.0 or breast_mass.size.z <= 0.0:
		failures.append("%s hearth has no logged chimney-breast envelope" % style)
	else:
		for row in builder.component_log:
			if String(row.get("host", "")) != "hearth":
				continue
			var bounds := _component_bounds(row)
			if bounds.position.x < breast_mass.position.x - 0.01 \
					or bounds.position.y < breast_mass.position.y - 0.01 \
					or bounds.position.z < breast_mass.position.z - 0.01 \
					or bounds.end.x > breast_mass.end.x + 0.01 \
					or bounds.end.y > breast_mass.end.y + 0.01 \
					or bounds.end.z > breast_mass.end.z + 0.01:
				failures.append("%s hearth component protrudes beyond the logged breast mass: %s" % [style, row.get("role", "")])
				break
		# Check the actual emitted component transforms against the host normal.
		# The room is on +normal; the mantel must project toward it while the
		# header body recedes behind the face to leave a real firebox recess.
		var normal3 := Vector3(n2.x, 0.0, n2.y).normalized()
		var mantel_row: Dictionary = {}
		var header_row: Dictionary = {}
		for row in builder.component_log:
			if String(row.get("host", "")) != "hearth":
				continue
			if String(row.get("role", "")) == "hearth_mantel":
				mantel_row = row
			elif String(row.get("role", "")) == "hearth_breast_header":
				header_row = row
		if mantel_row.is_empty() or header_row.is_empty():
			failures.append("%s hearth lacks transformed mantel/header geometry for orientation check" % style)
		else:
			var breast_centre3 := Vector3(centre.x,
				float(breast["storey"]) * plan.spec.height, centre.y)
			var mantel_xf: Transform3D = mantel_row["xf"]
			var header_xf: Transform3D = header_row["xf"]
			var mantel_center3: Vector3 = mantel_xf.origin
			var header_center3: Vector3 = header_xf.origin
			var mantel_inward := (mantel_center3 - breast_centre3).dot(normal3)
			var header_inward := (header_center3 - breast_centre3).dot(normal3)
			if mantel_inward <= 0.0 or header_inward >= 0.0 \
					or mantel_inward <= header_inward + 0.03:
				failures.append("%s emitted mantel/header are reversed or fail to form an inward-facing recess (%.3f / %.3f)" % [style, mantel_inward, header_inward])


func _component_bounds(row: Dictionary) -> AABB:
	var xf: Transform3D = row["xf"]
	var size: Vector3 = row["size"]
	var bounds := AABB()
	var first := true
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var point: Vector3 = xf * Vector3(size.x * sx * 0.5,
					size.y * sy * 0.5, size.z * sz * 0.5)
				if first:
					bounds = AABB(point, Vector3.ZERO)
					first = false
				else:
					bounds = bounds.expand(point)
	return bounds


func _solid_firebox_plane(centre: Vector3, normal: Vector3, width: float,
		height: float) -> ArrayMesh:
	var tangent := Vector3(normal.z, 0.0, -normal.x).normalized()
	var points := PackedVector3Array([
		centre - tangent * width * 0.5 - Vector3.UP * height * 0.5,
		centre + tangent * width * 0.5 - Vector3.UP * height * 0.5,
		centre + tangent * width * 0.5 + Vector3.UP * height * 0.5,
		centre - tangent * width * 0.5 + Vector3.UP * height * 0.5])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _first_mesh_hit(mesh: ArrayMesh, start: Vector3, finish: Vector3) -> Variant:
	var closest: Vector3 = Vector3.ZERO
	var distance := INF
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
			else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count, 3):
			var a: Vector3 = vertices[indices[i] if not indices.is_empty() else i]
			var b: Vector3 = vertices[indices[i + 1] if not indices.is_empty() else i + 1]
			var c: Vector3 = vertices[indices[i + 2] if not indices.is_empty() else i + 2]
			var hit: Variant = Geometry3D.segment_intersects_triangle(start, finish, a, b, c)
			if hit != null:
				var hit_point: Vector3 = hit
				if start.distance_to(hit_point) < distance:
					closest = hit_point
					distance = start.distance_to(hit_point)
	return null if distance == INF else closest


func _check_relations(plan: HousePlan, style: StringName) -> void:
	var groups := {}
	for item in plan.furniture:
		var group_name := String(item.get("activity_group", ""))
		if not group_name.is_empty():
			groups[group_name] = true
	if groups.is_empty():
		if not plan.wall_hosts.is_empty():
			failures.append("%s emitted surface roles without activity groups" % style)
		return
	var quiet := false
	var furniture_order_before: Array[String] = []
	for item in plan.furniture:
		furniture_order_before.append("%s|%s|%d|%s" % [item.get("key", ""),
			item.get("surface_anchor_id", ""), int(item.get("host", -1)),
			str(item.get("pos", Vector3.ZERO))])
	for host in plan.wall_hosts:
		var room := int(host.get("room", -1))
		var wall := int(host.get("wall", -1))
		if room < 0 or room >= plan.room_count() \
				or wall < 0 or wall >= HouseGeometry.room_walls(plan, room).size():
			failures.append("%s host points outside actual room walls: %s" % [style, host])
			continue
		var role := String(host.get("role", ""))
		var recorded_span: Vector2 = host.get("span", Vector2.ZERO)
		var wall_row: Dictionary = HouseGeometry.room_walls(plan, room)[wall]
		var horizontal := absf(Vector2(wall_row["normal"]).y) > 0.5
		var expected_from := Vector2(recorded_span.x, Vector2(wall_row["from"]).y) if horizontal \
			else Vector2(Vector2(wall_row["from"]).x, recorded_span.x)
		var expected_to := Vector2(recorded_span.y, Vector2(wall_row["from"]).y) if horizontal \
			else Vector2(Vector2(wall_row["from"]).x, recorded_span.y)
		if Vector2(host.get("from", Vector2.ZERO)).distance_to(expected_from) > 0.005 \
				or Vector2(host.get("to", Vector2.ZERO)).distance_to(expected_to) > 0.005:
			failures.append("%s host endpoints do not lie on the declared room wall" % style)
		var in_clear_interval := false
		var linked_items: Array[Dictionary] = []
		var furniture_before_probe: Array[Dictionary] = plan.furniture.duplicate(true)
		var host_child_indices: Dictionary = {}
		for fi in range(plan.furniture.size()):
			if String(plan.furniture[fi].get("wall_host_id", "")) == String(host.get("id", "")):
				host_child_indices[fi] = true
				linked_items.append(plan.furniture[fi])
		for fi in range(plan.furniture.size()):
			if host_child_indices.has(int(plan.furniture[fi].get("host", -1))):
				host_child_indices[fi] = true
		for fi in range(plan.furniture.size() - 1, -1, -1):
			if host_child_indices.has(fi):
				plan.furniture.remove_at(fi)
		# A quiet architectural interval has beam depth. A deeper fitting only
		# occupies its own measured extent, checked independently below.
		for span in HousePlanFeatures.clear_wall_spans(plan, room, wall, HouseGeometry.BEAM_D):
			if span.x <= recorded_span.x + 0.01 and span.y >= recorded_span.y - 0.01:
				in_clear_interval = true
		for linked in linked_items:
			if not _mounted_fitting_is_clear(plan, room, wall, linked):
				failures.append("%s linked mounted fitting crosses an opening or stair reservation" % style)
		# Restore the exact furniture sequence and indices. Re-appending linked
		# mounted items would silently invalidate their parent/host references.
		plan.furniture.clear()
		plan.furniture.append_array(furniture_before_probe)
		if not in_clear_interval:
			failures.append("%s host crosses an opening or stair reservation" % style)
		if role == "quiet":
			quiet = true
			for other in plan.wall_hosts:
				if int(other.get("room", -1)) == room and int(other.get("wall", -1)) == wall \
						and String(other.get("role", "")) in ["activity_support", "lighting"]:
					var quiet_span: Vector2 = host["span"]
					var activity_span: Vector2 = other["span"]
					if minf(quiet_span.y, activity_span.y) - maxf(quiet_span.x, activity_span.x) > 0.01:
						failures.append("%s quiet span overlaps an activity wall host" % style)
		if role in ["activity_support", "lighting"]:
			var anchor_id := String(host.get("anchor_id", ""))
			var found := false
			for item in plan.furniture:
				if String(item.get("surface_anchor_id", "")) == anchor_id:
					found = true
					if String(item.get("activity_group", "")) != String(host.get("activity_group", "")):
						failures.append("%s host relation disagrees with its final activity group" % style)
			if not found:
				failures.append("%s activity host has no durable surviving anchor %s" % [style, anchor_id])
			var linked := false
			for item in plan.furniture:
				if String(item.get("wall_host_id", "")) != String(host.get("id", "")):
					continue
				linked = true
				var key := String(item.get("key", ""))
				var scale := float(item.get("scale", 1.0))
				var height_scale := PropCatalog.placement_height_scale(item)
				var semantic_yaw := float(item.get("yaw", 0.0))
				var model_yaw := semantic_yaw + PropCatalog.face_offset(key)
				var normal: Vector2 = wall_row["normal"]
				var semantic_facing := HouseFurnishScore._facing_of(semantic_yaw).normalized()
				# This is the semantic HousePlan record contract. Imported native
				# fronts are checked independently by house_surface_front_test.gd.
				if not semantic_facing.is_equal_approx(normal.normalized()):
					failures.append("%s mounted semantic yaw faces away from its activity wall" % style)
				var origin := PropCatalog.house_origin(item)
				var plan_centre := PropCatalog.plan_centre(key, origin, model_yaw, scale)
				var dims := PropCatalog.footprint_rotated(key, model_yaw) * scale
				var body_rect := Rect2(plan_centre - dims * 0.5, dims)
				var body_lo := body_rect.position.x if horizontal else body_rect.position.y
				var body_hi := body_rect.end.x if horizontal else body_rect.end.y
				if body_lo < recorded_span.x - 0.01 or body_hi > recorded_span.y + 0.01:
					failures.append("%s mounted model exceeds its host span" % style)
				var wall_line := float(wall_row["from"].y) if horizontal else float(wall_row["from"].x)
				var body_wall_edge := body_rect.position.y if horizontal and normal.y > 0.0 \
					else body_rect.end.y if horizontal else body_rect.position.x if normal.x > 0.0 \
					else body_rect.end.x
				if absf(body_wall_edge - wall_line) > 0.015:
					failures.append("%s measured model back does not meet its declared wall face" % style)
				var floor_y := float(item["storey"]) * plan.spec.height + HouseGeometry.FLOOR_T
				var ceiling_y := (float(item["storey"]) + 1.0) * plan.spec.height - HouseGeometry.FLOOR_T
				var body_bottom := origin.y + PropCatalog.floor_offset(key) * height_scale
				var body_top := body_bottom + PropCatalog.placement_height(item)
				if body_bottom < floor_y + 0.85 or body_top > ceiling_y:
					failures.append("%s mounted body violates wall clearance" % style)
			if not linked:
				failures.append("%s activity host has no mounted piece pointing back to its host ID" % style)
		if role == "timber_bay" and not plan.spec.timber_frame:
			failures.append("%s has a timber bay without timber framing enabled" % style)
	var furniture_order_after: Array[String] = []
	for item in plan.furniture:
		furniture_order_after.append("%s|%s|%d|%s" % [item.get("key", ""),
			item.get("surface_anchor_id", ""), int(item.get("host", -1)),
			str(item.get("pos", Vector3.ZERO))])
	if furniture_order_after != furniture_order_before:
		failures.append("%s host-span negative probe changed furniture order or host indices" % style)
	if not quiet:
		failures.append("%s has activity groups but no intentional quiet wall span" % style)
	for item in plan.furniture:
		if bool(item.get("mounted", false)):
			var relation := String(item.get("mount_relation", ""))
			if not relation.is_empty() and String(item.get("wall_host_id", "")).is_empty():
				failures.append("%s mounted prop relation has no stable wall host ID" % style)
	for item in plan.furniture:
		if String(item.get("surface_parent_id", "")) != "":
			var parent_index := -1
			for pi in plan.furniture.size():
				if String(plan.furniture[pi].get("surface_anchor_id", "")) == String(item["surface_parent_id"]):
					parent_index = pi
					break
			if parent_index < 0:
				failures.append("%s shelf item has no stable support parent" % style)
				continue
			if int(item.get("host", -1)) != parent_index:
				failures.append("%s shelf item host index does not point at its support" % style)
			var parent: Dictionary = plan.furniture[parent_index]
			var parent_key := String(parent["key"])
			var parent_scale := PropCatalog.placement_height_scale(parent)
			var parent_origin := PropCatalog.house_origin(parent)
			var expected_y := parent_origin.y \
				+ PropCatalog.floor_offset(parent_key) * parent_scale \
				+ PropCatalog.surface_height(parent_key) * parent_scale
			if absf(float(item["pos"].y) - expected_y) > 0.01:
				failures.append("%s shelf item is not supported at the measured shelf top" % style)
			var item_key := String(item["key"])
			var item_yaw := float(item.get("yaw", 0.0)) + PropCatalog.face_offset(item_key)
			var parent_yaw := float(parent.get("yaw", 0.0)) + PropCatalog.face_offset(parent_key)
			var item_origin := PropCatalog.house_origin(item)
			var item_centre := PropCatalog.plan_centre(item_key, item_origin, item_yaw,
				float(item.get("scale", 1.0)))
			var item_size := PropCatalog.footprint_rotated(item_key, item_yaw) \
				* float(item.get("scale", 1.0))
			var parent_origin_xz := PropCatalog.house_origin(parent)
			var parent_centre := PropCatalog.plan_centre(parent_key, parent_origin_xz,
				parent_yaw, float(parent.get("scale", 1.0)))
			var parent_size := PropCatalog.footprint_rotated(parent_key, parent_yaw) \
				* float(parent.get("scale", 1.0))
			var item_rect := Rect2(item_centre - item_size * 0.5, item_size)
			var parent_rect := Rect2(parent_centre - parent_size * 0.5, parent_size)
			if not parent_rect.grow(-0.02).encloses(item_rect):
				failures.append("%s shelf item footprint exceeds its measured support surface" % style)


func _check_structural_gate(plan: HousePlan, style: StringName) -> void:
	plan.spec.material = &"timber"
	plan.spec.timber_frame = false
	HousePlanFeatures.compose_wall_hosts(plan, plan.spec)
	var builder := HouseBuilder.new()
	builder.build(plan, false)
	var emitted := false
	for row in builder.component_log:
		if String(row.get("role", "")).begins_with("interior_frame_"):
			emitted = true
	if not plan.spec.timber_frame and emitted:
		failures.append("%s emitted interior timber despite timber_frame=false" % style)
	plan.spec.timber_frame = true
	HousePlanFeatures.compose_wall_hosts(plan, plan.spec)
	var framed := HouseBuilder.new()
	var framed_mesh: ArrayMesh = framed.build(plan, false)
	var authored_bays := plan.wall_hosts.any(func(host: Dictionary) -> bool:
		return String(host.get("role", "")) == "timber_bay")
	if plan.spec.timber_frame and plan.spec.material != &"stone" and not authored_bays:
		failures.append("%s has no furniture-clear timber bay in its eligible quiet wall spans" % style)
	var bay_host: Dictionary = {}
	var original_bays: Array[Dictionary] = []
	for host in plan.wall_hosts:
		if String(host.get("role", "")) == "timber_bay":
			original_bays.append(host.duplicate(true))
			if bay_host.is_empty():
				bay_host = host.duplicate(true)
	if not bay_host.is_empty():
		var bay_room := int(bay_host["room"])
		var bay_wall := int(bay_host["wall"])
		var bay_span: Vector2 = bay_host["span"]
		if not HousePlanFeatures._timber_bay_clear_of_furniture(plan,
				bay_room, bay_wall, bay_span):
			failures.append("%s emitted a timber bay into occupied measured floor space" % style)
		var bay_body := HousePlanFeatures._timber_bay_body_rect(plan,
			bay_room, bay_wall, bay_span)
		var obstruction_key := "Cabinet"
		var obstruction_size := PropCatalog.footprint(obstruction_key)
		var obstruction_centre := bay_body.get_center()
		plan.furniture.append({"key": obstruction_key, "room": bay_room,
			"storey": plan.storey_of_room(bay_room),
			"pos": Vector3(obstruction_centre.x, float(plan.storey_of_room(bay_room)) * plan.spec.height,
				obstruction_centre.y), "yaw": 0.0,
			"rect": Rect2(obstruction_centre - obstruction_size * 0.5, obstruction_size),
			"zone": Rect2(), "host": -1, "cat": PropCatalog.category(obstruction_key),
			"scale": 1.0, "mounted": false})
		if HousePlanFeatures._timber_bay_clear_of_furniture(plan,
				bay_room, bay_wall, bay_span):
			failures.append("%s timber bay clearance accepted an actual measured cabinet obstruction" % style)
		HousePlanFeatures.compose_wall_hosts(plan, plan.spec)
		for host in plan.wall_hosts:
			if int(host.get("room", -1)) == bay_room and int(host.get("wall", -1)) == bay_wall \
					and String(host.get("role", "")) == "timber_bay":
				failures.append("%s retained a timber bay through an obstructing cabinet" % style)
	var emitted_bays := false
	for row in framed.component_log:
		var role := String(row.get("role", ""))
		if role.begins_with("interior_frame_"):
			emitted_bays = true
			var host_id := String(row.get("host", ""))
			if host_id.is_empty() or not host_id.begins_with("interior_frame_"):
				failures.append("%s timber bay component has no named host" % style)
	if authored_bays != emitted_bays:
		failures.append("%s plan timber bays differ from emitted frame components" % style)
	var one_post_control_checked := false
	if authored_bays:
		for surface in original_bays:
			var surface_room_idx := int(surface["room"])
			var surface_wall_idx := int(surface["wall"])
			var surface_host_id := "interior_frame_%d_%d" % [surface_room_idx, surface_wall_idx]
			var counts := _timber_frame_component_counts(framed.component_log, surface_host_id)
			if not _timber_frame_has_supports(counts):
				failures.append("%s timber bay %s needs at least two emitted posts and both floor/ceiling rails" % [style, surface_host_id])
			if not one_post_control_checked and counts.x >= 2 and counts.y >= 2:
				var control_rows: Array = []
				var kept_posts := 0
				for component in framed.component_log:
					if String(component.get("host", "")) != surface_host_id:
						continue
					var component_role := String(component.get("role", ""))
					if component_role == "interior_frame_post":
						if kept_posts >= 2:
							continue
						kept_posts += 1
					control_rows.append(component.duplicate(true))
				for row_index in range(control_rows.size()):
					var control_component: Dictionary = control_rows[row_index]
					if String(control_component.get("role", "")) == "interior_frame_post":
						control_rows.remove_at(row_index)
						break
				var negative_counts := _timber_frame_component_counts(control_rows, surface_host_id)
				if negative_counts.x != 1 \
					 or negative_counts.y != counts.y \
					 or _timber_frame_has_supports(negative_counts):
					failures.append("one-post timber-bay negative did not fail the shared per-host support predicate")
				one_post_control_checked = true
		if not one_post_control_checked:
			failures.append("no authored timber bay could exercise the one-post negative control")
		_check_timber_mesh_contacts(framed_mesh, framed.component_log, plan, style)
		_check_timber_station_alignment(framed, plan, style)
	for surface in original_bays:
		var span: Vector2 = surface["span"]
		var room := int(surface["room"])
		var wall_index := int(surface["wall"])
		var expected_host := "interior_frame_%d_%d" % [room, wall_index]
		var horizontal := wall_index < 2
		var matching_components := 0
		for row in framed.component_log:
			if not String(row.get("role", "")).begins_with("interior_frame_") or String(row.get("host", "")) != expected_host:
				continue
			matching_components += 1
			var bounds := _component_bounds(row)
			var along_lo := bounds.position.x if horizontal else bounds.position.z
			var along_hi := bounds.end.x if horizontal else bounds.end.z
			if along_lo < span.x - 0.02 or along_hi > span.y + 0.02:
				failures.append("%s timber component lies outside its authored bay span: %s" % [style, row.get("role", "")])
		if matching_components == 0:
			failures.append("%s authored timber bay has no emitted components for %s" % [style, expected_host])


func _timber_frame_has_supports(counts: Vector2i) -> bool:
	return counts.x >= 2 and counts.y >= 2


func _timber_frame_component_counts(rows: Array, host_id: String) -> Vector2i:
	var counts := Vector2i.ZERO
	for component_variant in rows:
		var component: Dictionary = component_variant
		if String(component.get("host", "")) != host_id:
			continue
		var component_role := String(component.get("role", ""))
		counts.x += int(component_role == "interior_frame_post")
		counts.y += int(component_role == "interior_frame_rail")
	return counts


func _check_timber_mesh_contacts(mesh: ArrayMesh, rows: Array[Dictionary],
		plan: HousePlan, style: StringName) -> void:
	var actual_vertices := PackedVector3Array()
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			actual_vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
	for row in rows:
		if String(row.get("role", "")) != "interior_frame_post":
			continue
		var xform: Transform3D = row["xf"]
		var size: Vector3 = row["size"]
		var storey := int(row.get("storey", 0))
		var expected_floor := float(storey) * plan.spec.height + HouseGeometry.FLOOR_T
		var expected_ceiling := float(storey + 1) * plan.spec.height
		var bottom := xform.origin.y - size.y * 0.5
		var top := xform.origin.y + size.y * 0.5
		if absf(bottom - expected_floor) > 0.002 or absf(top - expected_ceiling) > 0.002:
			failures.append("%s timber post bounds miss floor or ceiling datum" % style)
		var measured_body := Rect2()
		var expected_host := "interior_frame_%d_%d" % [int(row.get("room", -1)), int(row.get("wall", -1))]
		for host in plan.wall_hosts:
			if String(host.get("role", "")) == "timber_bay" \
					and "interior_frame_%d_%d" % [int(host.get("room", -1)), int(host.get("wall", -1))] == String(row.get("host", "")):
				measured_body = HousePlanFeatures._timber_bay_body_rect(plan,
					int(host["room"]), int(host["wall"]), Vector2(host["span"]))
				break
		for x in [-size.x * 0.5, size.x * 0.5]:
			for y in [-size.y * 0.5, size.y * 0.5]:
				for z in [-size.z * 0.5, size.z * 0.5]:
					var expected_vertex := xform * Vector3(x, y, z)
					var found := false
					for vertex in actual_vertices:
						if vertex.distance_to(expected_vertex) <= 0.002:
							found = true
							break
					if not found:
						failures.append("%s timber post endpoint is absent from assembled mesh triangles" % style)
						return
					if measured_body.has_area() and not measured_body.grow(0.003).has_point(Vector2(expected_vertex.x, expected_vertex.z)):
						failures.append("%s timber post corner exceeds measured host body" % style)


func _check_timber_station_alignment(builder: HouseBuilder, plan: HousePlan,
		style: StringName) -> void:
	for surface in plan.wall_hosts:
		if String(surface.get("role", "")) != "timber_bay":
			continue
		var room := int(surface["room"])
		var wall_index := int(surface["wall"])
		var storey := int(surface["storey"])
		var wall: Dictionary = HouseGeometry.room_walls(plan, room)[wall_index]
		var normal: Vector2 = wall["normal"]
		var direction := (Vector2(surface["to"]) - Vector2(surface["from"])).normalized()
		var span: Vector2 = surface["span"]
		var bay_body := HousePlanFeatures._timber_bay_body_rect(plan, room, wall_index, span)
		var post_width := HouseGeometry.POST_W
		var inset := (span.y - span.x - (span.y - span.x - 0.08)) * 0.5
		var bay_lo := span.x + inset + post_width * 0.5
		var bay_hi := span.y - inset - post_width * 0.5
		var matched := false
		var expected_positions: Array[Vector2] = []
		for run in HouseGeometry.shell_runs(plan, storey):
			var run_normal: Vector2 = run["normal"]
			if run_normal.dot(normal) > -0.99:
				continue
			var run_from: Vector2 = run["from"]
			var run_to: Vector2 = run["to"]
			var half_wall := float(run.get("thickness", HouseGeometry.wall_thickness(plan.spec))) * 0.5
			var inner_from := run_from + normal * half_wall
			var inner_to := run_to + normal * half_wall
			var run_dir := (inner_to - inner_from).normalized()
			if absf((inner_from - Vector2(wall["from"])).cross(direction)) > 0.025 \
					or absf((inner_to - Vector2(wall["from"])).cross(direction)) > 0.025 \
					or absf(run_dir.dot(direction)) < 0.99:
				continue
			matched = true
			var run_length := inner_from.distance_to(inner_to)
			var openings := builder._openings_on(run_from, run_to, run_normal, storey)
			var stations: Array[float] = [post_width * 0.5, run_length - post_width * 0.5]
			stations.append_array(HouseBuilder._facade_studs(run_length, openings, plan.spec.stud_pitch))
			for station in stations:
				var point := inner_from + run_dir * float(station) \
					+ normal * (HouseGeometry.BEAM_D * 0.5 - 0.004)
				var along := point.dot(direction)
				if along >= bay_lo - 0.001 and along <= bay_hi + 0.001:
					expected_positions.append(point)
			break
		if not matched:
			continue
		if expected_positions.is_empty():
			failures.append("%s exterior timber host has no real corner or façade stud in its bay" % style)
		var host_id := "interior_frame_%d_%d" % [room, wall_index]
		var actual_posts := 0
		for row in builder.component_log:
			if String(row.get("host", "")) != host_id \
					or String(row.get("role", "")) != "interior_frame_post":
				continue
			actual_posts += 1
			var xf: Transform3D = row["xf"]
			var position := Vector2(xf.origin.x, xf.origin.z)
			var matches_real_station := false
			for expected in expected_positions:
				if position.distance_to(expected) <= 0.015:
					matches_real_station = true
					break
			if not matches_real_station:
				failures.append("%s exterior interior post misses every real façade corner/stud station" % style)
			var size: Vector3 = row["size"]
			for local_x in [-size.x * 0.5, size.x * 0.5]:
				for local_z in [-size.z * 0.5, size.z * 0.5]:
					var corner := xf * Vector3(local_x, 0.0, local_z)
					if not bay_body.grow(0.003).has_point(Vector2(corner.x, corner.z)):
						failures.append("%s exterior post corner exceeds measured timber host body" % style)
		if actual_posts == 0:
			failures.append("%s exterior timber host emitted no station-aligned posts" % style)


func _check_partition_timber_control() -> void:
	var spec := HouseSpec.new()
	spec.style = &"farmhouse"
	spec.width = 11.0
	spec.length = 14.0
	var plan := HouseGenerator.generate(spec, 8102, true)
	plan.spec.timber_frame = true
	plan.spec.material = &"timber"
	plan.furniture.clear()
	plan.wall_hosts.clear()
	var chosen := false
	for room in plan.room_count():
		var walls := HouseGeometry.room_walls(plan, room)
		for wi in walls.size():
			var wall: Dictionary = walls[wi]
			var normal: Vector2 = wall["normal"]
			var horizontal := absf(normal.y) > 0.5
			var coordinate := float(wall["from"].y) if horizontal else float(wall["from"].x)
			var axis_index := 1 if horizontal else 0
			if HouseGeometry.is_exterior_edge(spec, axis_index, coordinate):
				continue
			for clear_span in HousePlanFeatures.clear_wall_spans(plan, room, wi, HouseGeometry.BEAM_D):
				if clear_span.y - clear_span.x < 1.7:
					continue
				var from := Vector2(clear_span.x, wall["from"].y) if horizontal \
					else Vector2(wall["from"].x, clear_span.x)
				var to := Vector2(clear_span.y, wall["from"].y) if horizontal \
					else Vector2(wall["from"].x, clear_span.y)
				var body := HousePlanFeatures._timber_bay_body_rect(plan, room, wi, clear_span)
				if not HousePlanFeatures._timber_bay_clear_of_furniture(plan, room, wi, clear_span):
					continue
				plan.wall_hosts.append({"id": "fixture:partition_bay", "role": "timber_bay",
					"room": room, "storey": plan.storey_of_room(room), "wall": wi,
					"from": from, "to": to, "normal": normal, "span": clear_span})
				var builder := HouseBuilder.new()
				var mesh: ArrayMesh = builder.build(plan, false)
				var post_rows: Array[Dictionary] = []
				for row in builder.component_log:
					if String(row.get("host", "")) == "interior_frame_%d_%d" % [room, wi] \
							and String(row.get("role", "")) == "interior_frame_post":
						post_rows.append(row)
				if post_rows.size() < 2:
					failures.append("internal-partition timber control emitted fewer than two posts")
				_check_timber_mesh_contacts(mesh, builder.component_log, plan, &"partition")
				for row in post_rows:
					var p2 := Vector2(row["xf"].origin.x, row["xf"].origin.z)
					if not body.grow(0.003).has_point(p2):
						failures.append("internal-partition post centre escaped measured body")
				chosen = true
				break
			if chosen:
				break
		if chosen:
			break
	if not chosen:
		failures.append("no clear interior partition available for timber pitch control")


func _check_exterior_timber_control() -> void:
	var spec := HouseSpec.new()
	spec.style = &"farmhouse"
	spec.width = 11.0
	spec.length = 14.0
	spec.timber_frame = true
	spec.material = &"timber"
	var plan := HouseGenerator.generate(spec, 8102, true)
	if plan == null:
		failures.append("exterior timber control did not generate a plan")
		return
	plan.spec.timber_frame = true
	plan.spec.material = &"timber"
	plan.furniture.clear()
	plan.zones.clear()
	plan.wall_hosts.clear()
	var selected_room := -1
	var selected_wall := -1
	var selected_span := Vector2.ZERO
	var selected_from := Vector2.ZERO
	var selected_to := Vector2.ZERO
	var selected_run: Dictionary = {}
	var facade_builder := HouseBuilder.new()
	facade_builder.plan = plan
	facade_builder.spec = spec
	for room in range(plan.room_count()):
		var storey := plan.storey_of_room(room)
		var walls := HouseGeometry.room_walls(plan, room)
		for wi in walls.size():
			var wall: Dictionary = walls[wi]
			var normal: Vector2 = wall["normal"]
			var horizontal := absf(normal.y) > 0.5
			var direction := (Vector2(wall["to"]) - Vector2(wall["from"])).normalized()
			for run in HouseGeometry.shell_runs(plan, storey):
				var run_normal: Vector2 = run["normal"]
				if run_normal.dot(normal) > -0.99:
					continue
				var half_wall := float(run.get("thickness", HouseGeometry.wall_thickness(plan.spec))) * 0.5
				var inner_from: Vector2 = run["from"] + normal * half_wall
				var inner_to: Vector2 = run["to"] + normal * half_wall
				var run_dir := (inner_to - inner_from).normalized()
				if absf((inner_from - Vector2(wall["from"])).cross(direction)) > 0.025:
					continue
				if absf((inner_to - Vector2(wall["from"])).cross(direction)) > 0.025:
					continue
				if absf(run_dir.dot(direction)) < 0.99:
					continue
				var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
				var run_length := inner_from.distance_to(inner_to)
				var openings := facade_builder._openings_on(run["from"], run["to"],
					run_normal, storey)
				var stations: Array[float] = [HouseGeometry.POST_W * 0.5,
					run_length - HouseGeometry.POST_W * 0.5]
				stations.append_array(HouseBuilder._facade_studs(run_length,
					openings, spec.stud_pitch))
				for clear_span in HousePlanFeatures.clear_wall_spans(plan, room, wi, HouseGeometry.BEAM_D):
					if clear_span.y - clear_span.x < 1.5:
						continue
					var lo := clear_span.x + 0.04 + HouseGeometry.POST_W * 0.5
					var hi := clear_span.y - 0.04 - HouseGeometry.POST_W * 0.5
					var actual_station_count := 0
					for station in stations:
						var station_point := inner_from + run_dir * float(station)
						station_point += normal * (HouseGeometry.BEAM_D * 0.5 - 0.004)
						var station_along := station_point.dot(axis)
						if station_along >= lo - 0.001 and station_along <= hi + 0.001:
							actual_station_count += 1
					if actual_station_count < 2:
						continue
					selected_room = room
					selected_wall = wi
					selected_span = clear_span
					selected_from = HousePlanFeatures._wall_point(wall, clear_span.x)
					selected_to = HousePlanFeatures._wall_point(wall, clear_span.y)
					selected_run = run
					break
				if selected_room >= 0:
					break
			if selected_room >= 0:
				break
		if selected_room >= 0:
			break
	if selected_room < 0:
		failures.append("controlled timber fixture found no shell-run-aligned exterior room wall")
		return
	if not HousePlanFeatures._timber_bay_clear_of_furniture(plan,
			selected_room, selected_wall, selected_span):
		failures.append("controlled exterior timber bay overlaps measured furniture or zone")
		return
	var wall: Dictionary = HouseGeometry.room_walls(plan, selected_room)[selected_wall]
	var from := selected_from
	var to := selected_to
	plan.wall_hosts.append({"id": "fixture:exterior_timber", "role": "timber_bay",
		"room": selected_room, "storey": plan.storey_of_room(selected_room),
		"wall": selected_wall, "span": selected_span, "from": from, "to": to,
		"normal": wall["normal"], "activity_group": "", "anchor_id": ""})
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, false)
	var host_id := "interior_frame_%d_%d" % [selected_room, selected_wall]
	var post_count := 0
	for row in builder.component_log:
		if String(row.get("host", "")) == host_id:
			if String(row.get("role", "")) == "interior_frame_post":
				post_count += 1
	if post_count < 2:
		failures.append("controlled exterior timber bay emitted fewer than two true façade stations")
		return
	_check_timber_mesh_contacts(mesh, builder.component_log, plan, &"exterior_control")
	_check_timber_station_alignment(builder, plan, &"exterior_control")
	print("TIMBER_EXTERIOR_CONTROL room=", selected_room, " wall=", selected_wall,
		" run=", selected_run, " span=", selected_span, " posts=", post_count)


func _check_aperture_and_route_negatives(style: StringName) -> void:
	for blocked_by_route in [false, true]:
		var spec := HouseSpec.new()
		spec.style = style
		spec.width = 11.0
		spec.length = 14.0
		var plan := HouseGenerator.generate(spec, 7441, true)
		var anchor: Dictionary = {}
		for item in plan.furniture:
			if String(item.get("activity_group", "")) == "cooking" \
					and String(item.get("cat", "")) == "workbench":
				anchor = item
				break
		if anchor.is_empty():
			continue
		var room := int(anchor["room"])
		var wall_index := HouseFurnishScore._back_wall_index(plan, room, Rect2(anchor["rect"]), anchor)
		if wall_index < 0:
			continue
		var wall: Dictionary = HouseGeometry.room_walls(plan, room)[wall_index]
		var horizontal := absf(Vector2(wall["normal"]).y) > 0.5
		var extent := HouseFurnishScore._piece_projection(Rect2(anchor["rect"]),
			Vector2.RIGHT if horizontal else Vector2.DOWN, anchor)
		var mid := (extent.x + extent.y) * 0.5
		var point := Vector2(mid, Vector2(wall["from"]).y) if horizontal \
			else Vector2(Vector2(wall["from"]).x, mid)
		var depth := PropCatalog.size("Torch_Metal").z
		var wall_line := float(wall["from"].y) if horizontal else float(wall["from"].x)
		var aperture_band: Rect2
		var route_band := HousePlanFeatures._wall_body_band(wall,
			extent.x - 1.0, extent.y + 1.0, wall_line, depth)
		if blocked_by_route:
			plan.zones.append({"room": room, "why": "stair access route", "rect": route_band})
		else:
			var normal: Vector2 = wall["normal"]
			var door_width := maxf(2.0, extent.y - extent.x + 1.0)
			var aperture_extent := Vector2(mid - door_width * 0.5,
				mid + door_width * 0.5)
			# The aperture is at the actual wall face. A fixture on an
			# adjacent wall may occupy nearby room space without crossing it.
			aperture_band = HousePlanFeatures._wall_body_band(wall,
				aperture_extent.x, aperture_extent.y, wall_line, 0.02)
			plan.doors.append({"a": room, "b": -1, "pos": point, "normal": normal,
				"width": door_width, "exterior": true,
				"front": false, "storey": plan.storey_of_room(room)})
		var forbidden_band := route_band if blocked_by_route else aperture_band
		HousePlanFeatures.compose_wall_hosts(plan, spec)
		for item in plan.furniture:
			if not bool(item.get("surface_generated", false)):
				continue
			if Rect2(item.get("rect", Rect2())).intersects(forbidden_band):
				failures.append("%s surface fixture crossed injected %s" % [style,
					"route reservation" if blocked_by_route else "door aperture"])

func _check_door_aperture_mesh_control() -> void:
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = 11.0
	spec.length = 14.0
	var plan := HouseGenerator.generate(spec, 7441, true)
	var anchor := _cooking_workbench(plan)
	if anchor.is_empty():
		failures.append("door aperture mesh control has no generated cooking workbench")
		return
	var room := int(anchor["room"])
	var wall_index := HouseFurnishScore._back_wall_index(plan, room,
		Rect2(anchor["rect"]), anchor)
	if wall_index < 0:
		failures.append("door aperture mesh control anchor has no real back wall")
		return
	var wall: Dictionary = HouseGeometry.room_walls(plan, room)[wall_index]
	var normal: Vector2 = wall["normal"]
	var horizontal := absf(normal.y) > 0.5
	var along_axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var extent := HouseFurnishScore._piece_projection(Rect2(anchor["rect"]),
		along_axis, anchor)
	var middle := (extent.x + extent.y) * 0.5
	var door_width := maxf(2.0, extent.y - extent.x + 1.0)
	var wall_line := float(wall["from"].y) if horizontal else float(wall["from"].x)
	# Construct the aperture face independently. Its depth is only a numerical
	# contact tolerance; an adjacent-wall fixture must not be swallowed by it.
	var aperture_face: Rect2
	if horizontal:
		var face_z := wall_line if normal.y > 0.0 else wall_line - 0.02
		aperture_face = Rect2(Vector2(middle - door_width * 0.5, face_z),
			Vector2(door_width, 0.02))
	else:
		var face_x := wall_line if normal.x > 0.0 else wall_line - 0.02
		aperture_face = Rect2(Vector2(face_x, middle - door_width * 0.5),
			Vector2(0.02, door_width))
	var floor_y := float(plan.storey_of_room(room)) * spec.height + HouseGeometry.FLOOR_T
	var target_mid_y := floor_y + HouseGeometry.DOOR_H * 0.5
	var pose := HousePlanFeatures._wall_fixture_pose("Torch_Metal", wall,
		middle, target_mid_y, 1.0)
	var intruding_torch: Dictionary = {
		"key": "Torch_Metal", "room": room, "storey": plan.storey_of_room(room),
		"pos": pose["pos"], "yaw": pose["yaw"], "rect": pose["rect"],
		"zone": Rect2(), "host": -1, "cat": PropCatalog.category("Torch_Metal"),
		"mounted": true, "scale": 1.0,
	}
	var direct_bounds := _actual_imported_triangle_bounds(intruding_torch)
	if direct_bounds.size == Vector3.ZERO:
		failures.append("direct-door Torch has no imported mesh triangles")
		return
	# Center the actual imported triangle bounds inside the door's vertical
	# opening; this is a controlled obstruction, not a guessed catalogue box.
	var direct_pos: Vector3 = intruding_torch["pos"]
	direct_pos.y += target_mid_y - (direct_bounds.position.y + direct_bounds.end.y) * 0.5
	intruding_torch["pos"] = direct_pos
	direct_bounds = _actual_imported_triangle_bounds(intruding_torch)
	if not _imported_bounds_intersect_door(direct_bounds, aperture_face,
			floor_y, HouseGeometry.DOOR_H):
		failures.append("direct-wall Torch triangle bounds did not intrude into the actual aperture face")

	# Build an independent positive control on a real adjoining wall. This
	# proves the measured doorway face does not swallow an ordinary lamp on
	# the perpendicular wall; it does not depend on compositor insertion or
	# the surface_generated metadata flag.
	var adjacent_torch: Dictionary = {}
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	for candidate_index in walls.size():
		if candidate_index == wall_index:
			continue
		var candidate_wall: Dictionary = walls[candidate_index]
		var candidate_normal: Vector2 = candidate_wall.get("normal", Vector2.ZERO)
		if absf(candidate_normal.dot(normal)) > 0.5:
			continue
		var candidate_horizontal := absf(candidate_normal.y) > 0.5
		var candidate_axis := Vector2.RIGHT if candidate_horizontal else Vector2.DOWN
		var candidate_from: Vector2 = candidate_wall.get("from", Vector2.ZERO)
		var candidate_to: Vector2 = candidate_wall.get("to", Vector2.ZERO)
		var candidate_station := (candidate_from.dot(candidate_axis) + candidate_to.dot(candidate_axis)) * 0.5
		var candidate_pose := HousePlanFeatures._wall_fixture_pose("Torch_Metal",
			candidate_wall, candidate_station, target_mid_y, 1.0)
		var candidate_piece: Dictionary = {
			"key": "Torch_Metal", "room": room, "storey": plan.storey_of_room(room),
			"pos": candidate_pose["pos"], "yaw": candidate_pose["yaw"],
			"rect": candidate_pose["rect"], "zone": Rect2(), "host": -1,
			"cat": PropCatalog.category("Torch_Metal"), "mounted": true,
			"scale": 1.0, "activity_group": "independent_aperture_control",
		}
		var candidate_bounds := _actual_imported_triangle_bounds(candidate_piece)
		if candidate_bounds.size == Vector3.ZERO:
			continue
		if not _imported_bounds_intersect_door(candidate_bounds, aperture_face,
				floor_y, HouseGeometry.DOOR_H):
			adjacent_torch = candidate_piece
			break
	if adjacent_torch.is_empty():
		failures.append("independent adjoining-wall Torch could not be placed clear of measured door face")
		return
	var adjacent_bounds := _actual_imported_triangle_bounds(adjacent_torch)
	if adjacent_bounds.size == Vector3.ZERO:
		failures.append("independent adjoining-wall Torch has no imported mesh triangles")
	elif _imported_bounds_intersect_door(adjacent_bounds, aperture_face,
			floor_y, HouseGeometry.DOOR_H):
		failures.append("adjoining-wall Torch triangle bounds falsely intrude into the door aperture")


func _imported_bounds_intersect_door(bounds: AABB, aperture_face: Rect2,
		floor_y: float, door_height: float) -> bool:
	if bounds.size == Vector3.ZERO:
		return false
	var body_xz := Rect2(Vector2(bounds.position.x, bounds.position.z),
		Vector2(bounds.size.x, bounds.size.z))
	var vertical_overlap := (bounds.position.y < floor_y + door_height
			and bounds.end.y > floor_y)
	return vertical_overlap and body_xz.intersects(aperture_face)


func _actual_imported_triangle_bounds(item: Dictionary) -> AABB:
	var instance := HouseAssembler._instance(item)
	if instance == null:
		return AABB()
	var triangles := _imported_triangles(instance)
	instance.free()
	if triangles.is_empty():
		return AABB()
	var first: Vector3 = triangles[0][0]
	var bounds := AABB(first, Vector3.ZERO)
	for triangle in triangles:
		for vertex_value in triangle:
			var vertex: Vector3 = vertex_value
			bounds = bounds.expand(vertex)
	return bounds


func _imported_triangles(root: Node3D) -> Array:
	var triangles: Array = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var instance := current as MeshInstance3D
			var transform := instance.transform
			var parent := instance.get_parent()
			while parent is Node3D:
				transform = (parent as Node3D).transform * transform
				parent = parent.get_parent()
			for surface in range(instance.mesh.get_surface_count()):
				var arrays := instance.mesh.surface_get_arrays(surface)
				if arrays.size() <= Mesh.ARRAY_VERTEX:
					continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: Variant = arrays[Mesh.ARRAY_INDEX]
				var indexed: bool = indices is PackedInt32Array and not indices.is_empty()
				var count: int = indices.size() if indexed else vertices.size()
				for offset in range(0, count - 2, 3):
					var triangle: Array[Vector3] = []
					for corner in range(3):
						var vertex_index := int(indices[offset + corner]) if indexed else offset + corner
						triangle.append(transform * vertices[vertex_index])
					triangles.append(triangle)
		for child_node in current.get_children():
			pending.append(child_node)
	return triangles


func _check_family_exclusion() -> void:
	var ordinary_spec := HouseSpec.new()
	ordinary_spec.style = &"cottage"
	ordinary_spec.width = 11.0
	ordinary_spec.length = 14.0
	var family_plan := HouseGenerator.generate(ordinary_spec, 7441, true)
	family_plan.world_family = &"vastu"
	var family_builder := HouseBuilder.new()
	family_builder.build(family_plan, true)
	var retained_solid_breast := false
	for row in family_builder.component_log:
		if String(row.get("role", "")) == "chimney_breast" \
				and String(row.get("host", "")) == "hearth":
			retained_solid_breast = true
		if String(row.get("role", "")) in ["hearth_lintel", "hearth_jamb", "hearth_mantel"]:
			failures.append("world-family HouseBuilder path received ordinary fireplace components")
	if not retained_solid_breast:
		failures.append("world-family HouseBuilder path lost its legacy solid chimney breast")
	var spec := HouseSpec.new()
	var world_plan := HousePlan.new()
	world_plan.spec = spec
	world_plan.world_family = &"vastu"
	HousePlanFeatures.compose_wall_hosts(world_plan, spec)
	if not world_plan.wall_hosts.is_empty():
		failures.append("world-family path was given domestic wall composition")
	var shop := ShopSpec.new()
	var shop_plan := HousePlan.new()
	shop_plan.spec = shop
	HousePlanFeatures.compose_wall_hosts(shop_plan, shop)
	if not shop_plan.wall_hosts.is_empty():
		failures.append("shop adapter path was given ordinary domestic wall composition")
	var hotel := HotelSpec.new()
	var hotel_plan := HousePlan.new()
	hotel_plan.spec = hotel
	HousePlanFeatures.compose_wall_hosts(hotel_plan, hotel)
	if not hotel_plan.wall_hosts.is_empty():
		failures.append("hotel path was given ordinary domestic wall composition")


func _check_reused_shelf_book() -> void:
	var spec := HouseSpec.new()
	spec.style = &"cottage"
	spec.width = 11.0
	spec.length = 14.0
	var plan := HouseGenerator.generate(spec, 7441, true)
	for index in range(plan.furniture.size() - 1, -1, -1):
		if bool(plan.furniture[index].get("surface_generated", false)):
			plan.furniture.remove_at(index)
	plan.wall_hosts.clear()
	# Isolate the authored-book reuse path from old derived rows. The source
	# Nightstand_Shelf remains the actual preferred reading anchor.
	var chest: Dictionary = {}
	for item in plan.furniture:
		if (int(item.get("room", -1)) >= 0
				and String(item.get("activity_group", "")) == "sleep"
				and String(item.get("cat", "")) == "chest"
				and String(item.get("activity_host_anchor", "")) != "head_end"):
			chest = item
			break
	if chest.is_empty():
		failures.append("reused-shelf fixture has no independent sleep clothes chest")
		return
	var room := int(chest["room"])
	var chest_source := chest.duplicate(true)
	var nightstand: Dictionary = {}
	for item in plan.furniture:
		if (int(item.get("room", -1)) == room
				and String(item.get("key", "")) == "Nightstand_Shelf"
				and String(item.get("activity_group", "")) == "sleep"):
			nightstand = item
			break
	if nightstand.is_empty():
		failures.append("reused-shelf fixture has no preferred bedside reading anchor")
		return
	var anchor_id := String(nightstand.get("surface_anchor_id", ""))
	if anchor_id.is_empty():
		failures.append("reused-shelf fixture nightstand lacks its stable activity anchor id")
		return
	var nightstand_anchor := Rect2(nightstand["rect"]).get_center()
	var nightstand_use := Rect2(nightstand.get("zone", Rect2()))
	if not nightstand_use.has_area():
		nightstand_use = Rect2(nightstand["rect"])
	var support := HousePlanFeatures._append_nearby_activity_support(plan, room,
		"Shelf_Simple", "sleep", anchor_id, nightstand_anchor,
		nightstand_use, {})
	if support.is_empty():
		failures.append("reused-shelf fixture could not create an actual mounted shelf at the preferred nightstand")
		return
	var shelf_index := int(support["furniture_index"])
	var shelf: Dictionary = plan.furniture[shelf_index]
	shelf.erase("surface_generated")
	shelf["activity_group"] = "household_storage"
	var shelf_pose := Vector3(shelf["pos"])
	var shelf_yaw := float(shelf["yaw"])
	var book_key := "Book_Stack_1"
	var shelf_key := String(shelf["key"])
	var book_yaw := float(shelf["yaw"])
	var model_yaw := book_yaw + PropCatalog.face_offset(shelf_key)
	var shelf_origin := PropCatalog.house_origin(shelf)
	var centre := PropCatalog.plan_centre(shelf_key, shelf_origin, model_yaw,
		float(shelf.get("scale", 1.0)))
	var shelf_scale := PropCatalog.placement_height_scale(shelf)
	var top := shelf_origin.y + PropCatalog.floor_offset(shelf_key) * shelf_scale \
		+ PropCatalog.surface_height(shelf_key) * shelf_scale
	var book_size := PropCatalog.footprint_rotated(book_key, book_yaw)
	var book_rect := Rect2(centre - book_size * 0.5, book_size)
	if not Rect2(shelf["rect"]).grow(-0.02).encloses(book_rect):
		failures.append("reused-shelf fixture's injected book does not fit its measured shelf")
		return
	var book := {"key": book_key, "room": room,
		"storey": HousePlan.record_storey(shelf), "pos": Vector3(centre.x, top, centre.y),
		"yaw": book_yaw, "rect": book_rect, "zone": Rect2(), "host": shelf_index,
		"cat": PropCatalog.category(book_key), "mounted": false, "scale": 1.0,
		"activity_group": "authored_display", "surface_parent_id": shelf["surface_anchor_id"]}
	plan.furniture.append(book)
	var original_shelf_index := shelf_index
	var original_book_index := plan.furniture.size() - 1
	# Exercise a valid child-before-host array order. Host references are indices,
	# so the source book must be rebound to the shelf's new index after the swap.
	var saved_shelf: Dictionary = plan.furniture[original_shelf_index]
	var saved_book: Dictionary = plan.furniture[original_book_index]
	plan.furniture[original_shelf_index] = saved_book
	plan.furniture[original_book_index] = saved_shelf
	shelf_index = original_book_index
	var book_index := original_shelf_index
	book["host"] = shelf_index
	var original_book_pose: Vector3 = book["pos"]
	var original_book_yaw := float(book["yaw"])
	var original_book_group := String(book["activity_group"])
	var original_book_host := int(book["host"])
	if not HousePlanFeatures._is_supported_surface_child(book, shelf, shelf_index):
		failures.append("reordered authored book does not meet measured shelf support geometry")
		return
	plan.wall_hosts.clear()
	HousePlanFeatures.compose_wall_hosts(plan, spec)
	_check_reused_book_survives(plan, room, shelf_index, book_index,
		original_book_pose, original_book_yaw, original_book_group, original_book_host)
	HousePlanFeatures.compose_wall_hosts(plan, spec)
	_check_reused_book_survives(plan, room, shelf_index, book_index,
		original_book_pose, original_book_yaw, original_book_group, original_book_host)
	var chest_preserved := false
	for item in plan.furniture:
		if String(item.get("key", "")) != String(chest_source.get("key", "")) \
				or int(item.get("room", -1)) != room \
				or Vector3(item.get("pos", Vector3.ZERO)).distance_to(Vector3(chest_source.get("pos", Vector3.ZERO))) > 0.001:
			continue
		chest_preserved = true
		if absf(float(item.get("yaw", 0.0)) - float(chest_source.get("yaw", 0.0))) > 0.001 \
				or absf(float(item.get("scale", 1.0)) - float(chest_source.get("scale", 1.0))) > 0.001 \
				or String(item.get("activity_group", "")) != String(chest_source.get("activity_group", "")) \
				or int(item.get("host", -1)) != int(chest_source.get("host", -1)):
			failures.append("independent clothes chest source pose/group/host changed during reading-shelf binding")
		break
	if not chest_preserved:
		failures.append("independent clothes chest record disappeared during reading-shelf binding")
	for item in plan.furniture:
		if int(item.get("room", -1)) == room and String(item.get("activity_group", "")) == "sleep":
			item["activity_group"] = "household_storage"
	HousePlanFeatures.compose_wall_hosts(plan, spec)
	var unbound_book: Dictionary = plan.furniture[book_index]
	if Vector3(unbound_book["pos"]) != original_book_pose \
			or absf(float(unbound_book["yaw"]) - original_book_yaw) > 0.001 \
			or String(unbound_book.get("activity_group", "")) != original_book_group \
			or int(unbound_book.get("host", -1)) != original_book_host:
		failures.append("clearing sleep anchor changed authored book source data")
	if not String(unbound_book.get("activity_binding_group", "")).is_empty() \
			or not String(unbound_book.get("activity_anchor_id", "")).is_empty() \
			or not String(unbound_book.get("surface_parent_id", "")).is_empty():
		failures.append("recomposition retained stale derived book-to-sleep binding")
	var shelf_after: Dictionary = plan.furniture[shelf_index]
	if Vector3(shelf_after["pos"]) != shelf_pose or absf(float(shelf_after["yaw"]) - shelf_yaw) > 0.001 \
			or String(shelf_after.get("activity_group", "")) != "household_storage":
		failures.append("reused shelf pose or source activity group changed during binding")



func _check_reused_book_survives(plan: HousePlan, room: int, shelf_index: int,
		book_index: int, original_pose: Vector3, original_yaw: float,
		original_group: String, original_host: int) -> void:
	var supported_books := 0
	for item_index in plan.furniture.size():
		var item: Dictionary = plan.furniture[item_index]
		if int(item.get("room", -1)) != room or int(item.get("host", -1)) != shelf_index \
				or not String(item.get("key", "")).begins_with("Book_"):
			continue
		supported_books += 1
		if item_index != book_index or Vector3(item["pos"]) != original_pose \
				or absf(float(item["yaw"]) - original_yaw) > 0.001 \
				or String(item.get("activity_group", "")) != original_group \
				or int(item.get("host", -1)) != original_host:
			failures.append("existing shelf book was duplicated or its authored pose/group/host changed")
		if String(item.get("surface_parent_id", "")) != String(plan.furniture[shelf_index].get("surface_anchor_id", "")) \
				or String(item.get("activity_anchor_id", "")) == "" \
				or String(item.get("activity_binding_group", "")) != "sleep":
			failures.append("existing shelf book lacks its derived stable activity binding")
	if supported_books != 1:
		failures.append("recomposing a shelf with an authored book emitted a duplicate or lost the book")


func _check_missing_groups_is_safe_empty() -> void:
	var spec := HouseSpec.new()
	spec.style = &"farmhouse"
	var plan := HouseGenerator.generate(spec, 7442, true)
	for item in plan.furniture:
		item.erase("activity_group")
	HousePlanFeatures.compose_wall_hosts(plan, spec)
	if not plan.wall_hosts.is_empty():
		failures.append("missing activity-group annotations were converted into invented surface roles")


func _check_vertical_mount_collision() -> void:
	var spec := HouseSpec.new()
	spec.style = &"farmhouse"
	spec.width = 11.0
	spec.length = 14.0
	var source := HouseGenerator.generate(spec, 7441, true)
	var workbench := _cooking_workbench(source)
	if workbench.is_empty():
		failures.append("vertical-clearance fixture has no measured cooking workbench anchor")
		return
	var room := int(workbench["room"])
	var wall_index := HouseFurnishScore._back_wall_index(source, room,
		Rect2(workbench["rect"]), workbench)
	if wall_index < 0:
		failures.append("vertical-clearance fixture workbench has no real back wall")
		return
	var wall: Dictionary = HouseGeometry.room_walls(source, room)[wall_index]
	var horizontal := absf(Vector2(wall["normal"]).y) > 0.5
	var extent := HouseFurnishScore._piece_projection(Rect2(workbench["rect"]),
		Vector2.RIGHT if horizontal else Vector2.DOWN, workbench)
	var desired := (extent.x + extent.y) * 0.5
	var anchor_id := String(workbench.get("surface_anchor_id", ""))
	if anchor_id.is_empty():
		failures.append("vertical-clearance fixture workbench lacks its measured surface anchor id")
		return

	var positive := _controlled_surface_plan(spec, workbench)
	var positive_index := HousePlanFeatures._append_wall_mount(positive, room,
		wall_index, wall, extent, desired, "Shelf_Simple", HouseGeometry.SHELF_HEIGHT,
		"cooking", anchor_id, "supports_activity", "vertical_clear")
	if positive_index < 0:
		failures.append("controlled clear wall could not accept its measured cooking shelf")
		return
	var shelf: Dictionary = positive.furniture[positive_index]
	if not bool(shelf.get("mounted", false)) or String(shelf.get("key", "")) != "Shelf_Simple":
		failures.append("controlled clear-wall candidate did not create the expected mounted shelf")
		return

	var negative := _controlled_surface_plan(spec, workbench)
	var shelf_rect := Rect2(shelf.get("rect", Rect2()))
	var yaw := float(shelf.get("yaw", 0.0))
	var blocker_size := PropCatalog.footprint_rotated("Bookcase_2", yaw)
	var blocker_center := shelf_rect.get_center()
	var floor_y := HouseFurnishGeometry.storey_base(negative, room) + HouseGeometry.FLOOR_T
	var blocker_height_scale := 1.0
	var blocker_origin_y := floor_y
	var blocker_record := {"key": "Bookcase_2", "room": room,
		"storey": int(shelf.get("storey", 0)),
		"pos": Vector3(blocker_center.x, blocker_origin_y, blocker_center.y),
		"yaw": yaw, "rect": Rect2(blocker_center - blocker_size * 0.5, blocker_size),
		"zone": Rect2(), "host": -1, "cat": "bookcase", "scale": blocker_height_scale}
	var blocker_origin := PropCatalog.house_origin(blocker_record)
	var blocker_bottom := blocker_origin.y + PropCatalog.floor_offset("Bookcase_2") * blocker_height_scale
	if absf(blocker_bottom - floor_y) > 0.001:
		failures.append("negative Bookcase_2 control is not seated on the measured floor plane")
	negative.furniture.append(blocker_record)
	var negative_index := HousePlanFeatures._append_wall_mount(negative, room,
		wall_index, wall, extent, desired, "Shelf_Simple", HouseGeometry.SHELF_HEIGHT,
		"cooking", anchor_id, "supports_activity", "vertical_blocked")
	if negative_index >= 0:
		failures.append("mounted shelf overlapped a floor Bookcase_2 body at the same wall station")


func _controlled_surface_plan(spec: HouseSpec, anchor: Dictionary) -> HousePlan:
	var plan := HouseGenerator.generate(spec, 7441, true)
	plan.furniture.clear()
	plan.furniture.append(anchor.duplicate(true))
	plan.wall_hosts.clear()
	plan.doors.clear()
	plan.windows.clear()
	plan.zones.clear()
	return plan


func _cooking_workbench(plan: HousePlan) -> Dictionary:
	for item in plan.furniture:
		if String(item.get("activity_group", "")) == "cooking" \
				and String(item.get("cat", "")) == "workbench":
			return item
	return {}



func _check_existing_task_light_reuse() -> void:
	var spec := HouseSpec.new()
	spec.style = &"farmhouse"
	spec.width = 11.0
	spec.length = 14.0
	var source := HouseGenerator.generate(spec, 7441, true)
	var workbench := _cooking_workbench(source)
	if workbench.is_empty():
		failures.append("existing-light fixture has no measured cooking workbench")
		return
	var room := int(workbench["room"])
	var wall_index := HouseFurnishScore._back_wall_index(source, room,
		Rect2(workbench["rect"]), workbench)
	if wall_index < 0:
		failures.append("existing-light fixture workbench has no real back wall")
		return
	var wall: Dictionary = HouseGeometry.room_walls(source, room)[wall_index]
	var horizontal := absf(Vector2(wall["normal"]).y) > 0.5
	var extent := HouseFurnishScore._piece_projection(Rect2(workbench["rect"]),
		Vector2.RIGHT if horizontal else Vector2.DOWN, workbench)
	var light_along := (extent.x + extent.y) * 0.5 + 0.78
	var base := HouseFurnishGeometry.storey_base(source, room)
	var pose := HousePlanFeatures._wall_fixture_pose("Torch_Metal", wall,
		light_along, base + HouseGeometry.SCONCE_HEIGHT, 1.0)
	var plan := _controlled_surface_plan(spec, workbench)
	var existing_group := "legacy_ambient"
	var authored_pos: Vector3 = pose["pos"]
	var authored_yaw := float(pose["yaw"])
	var authored_scale := 1.0
	var authored_host := -1
	var authored_mounted := true
	var authored_torch: Dictionary = {
		"key": "Torch_Metal", "room": room, "storey": plan.storey_of_room(room),
		"pos": pose["pos"], "yaw": pose["yaw"], "rect": pose["rect"],
		"zone": Rect2(), "host": -1, "cat": PropCatalog.category("Torch_Metal"),
		"mounted": true, "scale": 1.0, "activity_group": existing_group,
	}
	plan.furniture.append(authored_torch)
	HousePlanFeatures.compose_wall_hosts(plan, spec)
	var torch_count := 0
	var reused := false
	var torch_index := -1
	for index in plan.furniture.size():
		var item: Dictionary = plan.furniture[index]
		if String(item.get("key", "")) != "Torch_Metal" or int(item.get("room", -1)) != room:
			continue
		torch_count += 1
		torch_index = index
		reused = String(item.get("mount_relation", "")) == "lights_activity" 			and not bool(item.get("surface_generated", false)) 			and String(item.get("activity_group", "")) == existing_group
	if torch_count != 1:
		failures.append("existing task-light fixture was duplicated (%d Torch_Metal records)" % torch_count)
	if not reused:
		failures.append("existing Torch_Metal was not bound as the task light while preserving its source activity_group")
	if torch_index >= 0:
		var torch: Dictionary = plan.furniture[torch_index]
		if not Vector3(torch["pos"]).is_equal_approx(authored_pos) \
				or absf(float(torch["yaw"]) - authored_yaw) > 0.001 \
				or absf(float(torch.get("scale", 1.0)) - authored_scale) > 0.001 \
				or int(torch.get("host", -1)) != authored_host \
				or bool(torch.get("mounted", false)) != authored_mounted:
			failures.append("reused task light pose, scale, mounting, or original host changed")
		var host_found := false
		for host_variant in plan.wall_hosts:
			var host: Dictionary = host_variant
			if String(host.get("id", "")) == String(torch.get("wall_host_id", "")) 					and String(host.get("role", "")) == "lighting" 					and String(host.get("anchor_id", "")) == String(torch.get("activity_anchor_id", "")):
				host_found = true
		if not host_found:
			failures.append("reused wall light has no matching measured lighting host")
	_check_composition_idempotence(plan, spec)
	var off_wall: Dictionary = authored_torch.duplicate(true)
	var original_pos: Vector3 = pose["pos"]
	var inward_normal: Vector2 = wall["normal"]
	off_wall.pos = original_pos + Vector3(inward_normal.x, 0.0, inward_normal.y) * 0.12
	off_wall.rect = _mounted_rect("Torch_Metal", off_wall)
	_check_task_light_rejected(spec, workbench, room, existing_group, off_wall,
		"nearby off-wall lamp")
	var reversed: Dictionary = authored_torch.duplicate(true)
	reversed.yaw = float(reversed["yaw"]) + PI
	reversed.rect = _mounted_rect("Torch_Metal", reversed)
	_check_task_light_rejected(spec, workbench, room, existing_group, reversed,
		"back-facing lamp")


func _mounted_rect(key: String, item: Dictionary) -> Rect2:
	var yaw := float(item.get("yaw", 0.0)) + PropCatalog.face_offset(key)
	var scale := float(item.get("scale", 1.0))
	var origin := PropCatalog.house_origin(item)
	var centre := PropCatalog.plan_centre(key, origin, yaw, scale)
	var size := PropCatalog.footprint_rotated(key, yaw) * scale
	return Rect2(centre - size * 0.5, size)


func _check_task_light_rejected(spec: HouseSpec, workbench: Dictionary,
		room: int, activity_group: String, torch: Dictionary, label: String) -> void:
	var plan := _controlled_surface_plan(spec, workbench)
	torch["activity_group"] = activity_group
	plan.furniture.append(torch)
	HousePlanFeatures.compose_wall_hosts(plan, spec)
	var found := false
	for item in plan.furniture:
		if String(item.get("key", "")) == "Torch_Metal" and int(item.get("room", -1)) == room \
				and String(item.get("activity_group", "")) == activity_group:
			found = true
			if String(item.get("mount_relation", "")) == "lights_activity":
				failures.append("%s was incorrectly credited as a task light" % label)
	if not found:
		failures.append("%s fixture disappeared during composition" % label)
