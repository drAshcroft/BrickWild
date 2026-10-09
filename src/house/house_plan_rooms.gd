class_name HousePlanRooms
extends RefCounted
## Ground-floor subdivision and room programme.

const MIN_SPLIT := 0.36
const MAX_SPLIT := 0.64
const BASE_HOUSE_SPEC := preload("res://src/house/house_spec.gd")
const DOMESTIC_KITCHEN_MIN_SIDE := 3.0

# --------------------------------------------------------------- subdivide

## Split the interior until there are `spec.room_count` rooms or nothing can be
## split any further without making a cupboard.
static func subdivide(p: HousePlan, spec: HouseSpec) -> void:
	if spec.has_method("custom_room_rects"):
		var custom: Array[Rect2] = spec.custom_room_rects(HouseGeometry.interior_rect(spec))
		if custom.size() == maxi(spec.room_count, 1):
			for rect in custom:
				p.rooms.append({"kind": &"hall", "rect": rect, "storey": 0})
			return
	var style: Dictionary = HouseSpec.STYLES.get(spec.style, {})
	var domestic_family := not spec.has_method("room_program") \
		and not spec.has_method("custom_room_rects") \
		and not spec.has_method("landmark_footprint")
	if domestic_family and style.has("domestic_program"):
		var layout: Dictionary = _domestic_layout(p, spec)
		if bool(layout.get("ok", false)):
			p.domestic_layout = layout.get("provenance", {})
			for room in layout["rooms"]:
				p.rooms.append(room)
			return
		p.domestic_layout = {"status": &"fallback", "style": spec.style,
			"requested_rooms": maxi(spec.room_count, 1),
			"reason": String(layout.get("reason", "activity layout did not fit"))}
		if layout.has("activity_shortfalls"):
			p.domestic_layout["activity_status"] = &"unsatisfied"
			p.domestic_layout["activity_shortfalls"] = layout["activity_shortfalls"]
			p.domestic_layout["unsatisfied_activities"] = layout.get("unsatisfied_activities", [])
	# A family which owns an interior contract, and an ordinary style whose
	# footprint cannot carry its activities, retain the established partition.
	var rects: Array[Rect2] = [HouseGeometry.interior_rect(spec)]
	var r := spec.rng
	var want: int = maxi(spec.room_count, 1)
	var guard := 0
	while rects.size() < want and guard < 64:
		guard += 1
		# split the biggest room: splitting a random one leaves a great hall
		# next to a broom cupboard
		var best := -1
		var best_area := 0.0
		for i in range(rects.size()):
			var a: float = rects[i].size.x * rects[i].size.y
			if a > best_area and _can_split(rects[i]):
				best_area = a
				best = i
		if best < 0:
			break
		var pair: Array = _split(rects[best], r)
		if pair.is_empty():
			break
		rects.remove_at(best)
		rects.append(pair[0])
		rects.append(pair[1])

	# a stable order: front to back, then left to right, so room 0 is at the
	# front left whatever the seed did
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		if absf(a.position.y - b.position.y) > 0.01:
			return a.position.y < b.position.y
		return a.position.x < b.position.x)
	for rect in rects:
		var row := {"kind": &"hall", "rect": rect, "storey": 0}
		if not p.domestic_layout.is_empty():
			row["layout_fallback_reason"] = p.domestic_layout.get("reason", "")
		p.rooms.append(row)


## A house is partitioned around what its household does. The full-width
## front common room receives the door; increasingly private or service rooms
## sit in connected bays behind it. A compact house is allowed fewer rooms
## when its activities will not fit usable dimensions.
static func _domestic_layout(p: HousePlan, spec: HouseSpec) -> Dictionary:
	var requested: int = maxi(spec.room_count, 1)
	var wanted := requested
	var large_grammar := _large_domestic_grammar(spec)
	if large_grammar:
		wanted = maxi(wanted, 7)
	var kinds: Array[StringName] = _domestic_kinds(spec, wanted)
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var reason := ""
	var rejected: Array[Dictionary] = []
	var candidate := kinds.duplicate()
	var initial_candidate: Array[StringName] = candidate.duplicate()
	var kitchen_merged := _ordinary_domestic_no_trade(spec) \
		and _programme_includes_kitchen(spec) and not candidate.has(&"kitchen")
	var required: Array[StringName] = [&"hall"]
	if wanted >= 3 and kinds.has(&"kitchen"):
		required.append(&"kitchen")
	if wanted >= 2 and kinds.has(&"bedroom"):
		required.append(&"bedroom")
	var trade_room: StringName = HouseSpec.TRADES.get(spec.trade, {}).get("room", &"")
	if trade_room != &"" and wanted >= 3 and kinds.has(trade_room):
		required.append(trade_room)

	if _compact_witch_service_case(spec, wanted, kinds, inner):
		var shared_attempt := _fit_compact_witch_shared_hall_candidate(p, spec, inner)
		if not bool(shared_attempt.get("ok", false)):
			return {"ok": false, "reason": String(shared_attempt.get("reason", "compact Witch shared hall does not fit")),
				"activity_shortfalls": [&"kitchen", &"witchwork"], "unsatisfied_activities": [&"cooking", &"workshop"]}
		var shared_rooms: Array[Dictionary] = shared_attempt["rooms"]
		for room_index in range(shared_rooms.size()):
			if shared_rooms[room_index]["kind"] == &"hall":
				shared_rooms[room_index]["domestic_role"] = &"living_hall"
				shared_rooms[room_index]["domestic_functions"] = [&"entry", &"circulation", &"dining", &"common_living", &"cooking", &"witchwork"]
				shared_rooms[room_index]["meal_room"] = true
				shared_rooms[room_index]["shared_cooking"] = true
				shared_rooms[room_index]["shared_witchwork"] = true
				shared_rooms[room_index]["domestic_layout_storey"] = 0
			elif shared_rooms[room_index]["kind"] == &"bedroom":
				shared_rooms[room_index]["domestic_role"] = &"sleeping"
				shared_rooms[room_index]["domestic_functions"] = [&"sleeping"]
				shared_rooms[room_index]["domestic_layout_storey"] = 0
			else:
				shared_rooms[room_index]["domestic_role"] = &"store"
				shared_rooms[room_index]["domestic_functions"] = [&"storage", &"dry_herbs"]
				shared_rooms[room_index]["domestic_layout_storey"] = 0
		return {"ok": true, "rooms": shared_rooms, "provenance": {
			"status": &"planned", "style": spec.style, "requested_rooms": requested,
			"planned_rooms": shared_rooms.size(), "ground_activities": [&"hall", &"kitchen", &"bedroom", &"workshop", &"store"],
			"merged_activities": [&"kitchen", &"workshop"], "added_activities": [&"store"],
			"capacity_expanded": false, "omitted_rooms": maxi(requested - shared_rooms.size(), 0),
			"omitted_activities": [], "rejected_candidates": [],
			"reason": "kitchen and Witchwork are distinct activities in the shared living hall; dry storage is a separate room",
			"mirror": bool(shared_attempt["mirror"]), "hall_role": &"living_hall",
			"shared_cooking": true, "shared_witchwork": true, "merged_into": &"hall"}}

	# The default Witch uses a real side service wing inside the requested site.
	# Hall and private bedroom form the taller core; kitchen and Workshop share
	# the opposite strip under one lower roof. The compact shared-Hall fallback
	# above is untouched.
	if _witch_default_ell_case(p, spec, wanted, kinds):
		var ell_attempt := _fit_witch_default_ell_candidate(p, spec, inner)
		if bool(ell_attempt.get("ok", false)):
			var ell_rooms: Array[Dictionary] = ell_attempt["rooms"]
			for row in ell_rooms:
				var kind: StringName = row["kind"]
				if kind == &"hall":
					row["domestic_role"] = &"living_hall"
					row["domestic_functions"] = [&"entry", &"circulation", &"dining", &"common_living"]
					row["meal_room"] = true
					row["shared_cooking"] = false
				elif kind == &"bedroom":
					row["domestic_role"] = &"sleeping"
					row["domestic_functions"] = [&"sleeping"]
				else:
					row["domestic_role"] = _activity_role(kind)
					row["domestic_functions"] = [_activity_role(kind)]
				if kind in [&"kitchen", &"workshop"]:
					row["witch_service_wing"] = true
				row["domestic_layout_storey"] = 0
			return {"ok": true, "rooms": ell_rooms, "provenance": {
				"status": &"planned", "style": spec.style,
				"requested_rooms": requested, "planned_rooms": ell_rooms.size(),
				"ground_activities": [&"hall", &"kitchen", &"bedroom", &"workshop"],
				"merged_activities": [], "capacity_expanded": false,
				"omitted_rooms": maxi(requested - ell_rooms.size(), 0),
				"omitted_activities": [&"records", &"store"],
				"rejected_candidates": rejected, "reason": "Hall and sleeping room form the high core; kitchen and Workshop share the lower service wing",
				"mirror": bool(ell_attempt["mirror"]), "hall_role": &"living_hall",
				"shared_cooking": false, "witch_working_ell": true}}

	while candidate.size() >= required.size():
		var compact_shared: bool = kitchen_merged and _compact_shared_cooking_square(spec, inner, candidate)
		var attempt: Dictionary
		if compact_shared:
			attempt = _fit_compact_shared_cooking_candidate(p, spec, inner, candidate)
		else:
			attempt = _fit_large_domestic_candidate(p, spec, inner, candidate) \
				if large_grammar else _fit_domestic_candidate(p, spec, inner, candidate)
		if bool(attempt.get("ok", false)):
			var rooms: Array[Dictionary] = attempt["rooms"]
			if large_grammar and p.world_family == &"" and _ordinary_domestic_no_trade(spec) \
					and spec.get_script() == BASE_HOUSE_SPEC and spec.style == &"witch_hut" \
					and spec.roof_material == &"thatch":
				var work_rect := Rect2()
				for candidate_room in rooms:
					if candidate_room["kind"] == &"workshop":
						work_rect = candidate_room["rect"]
						break
				var inner_left := absf(work_rect.position.x - inner.position.x) < 0.02
				var inner_right := absf(work_rect.end.x - inner.end.x) < 0.02
				if inner_left or inner_right:
					for wing_room in rooms:
						var wing_rect: Rect2 = wing_room["rect"]
						if (inner_left and absf(wing_rect.position.x - inner.position.x) < 0.02) \
								or (inner_right and absf(wing_rect.end.x - inner.end.x) < 0.02):
							wing_room["witch_service_wing"] = true
			var has_kitchen := candidate.has(&"kitchen")
			var shared_cooking := kitchen_merged or not has_kitchen
			var satisfied_activities: Array[StringName] = candidate.duplicate()
			if kitchen_merged and not satisfied_activities.has(&"kitchen"):
				satisfied_activities.append(&"kitchen")
			for row in rooms:
				if row["kind"] == &"hall":
					var functions: Array[StringName] = [&"entry", &"circulation", &"dining", &"common_living"]
					if shared_cooking:
						functions.append(&"cooking")
					row["domestic_role"] = &"communal_hall" if spec.style == &"longhall" else &"living_hall"
					row["domestic_functions"] = functions
					row["meal_room"] = true
					row["shared_cooking"] = shared_cooking
					row["domestic_layout_storey"] = 0
				else:
					row["domestic_role"] = _activity_role(row["kind"])
					row["domestic_functions"] = [_activity_role(row["kind"])]
					row["domestic_layout_storey"] = 0
			return {"ok": true, "rooms": rooms, "provenance": {
				"status": &"planned", "style": spec.style,
				"requested_rooms": requested, "planned_rooms": rooms.size(),
				"ground_activities": candidate.duplicate(),
				"merged_activities": [&"kitchen"] if kitchen_merged else [],
				"capacity_expanded": large_grammar and rooms.size() > requested,
				"omitted_rooms": maxi(requested - rooms.size(), 0),
				"omitted_activities": _omitted_activities(initial_candidate, satisfied_activities),
				"rejected_candidates": rejected,
				"reason": "",
				"mirror": bool(attempt["mirror"]),
				"hall_role": &"communal_hall" if spec.style == &"longhall" else &"living_hall",
				"shared_cooking": shared_cooking,
			}}
		reason = String(attempt.get("reason", "activity dimensions did not fit"))
		rejected.append({"activities": candidate.duplicate(), "reason": reason})
		var drop := -1
		# Preserve an authored style activity before optional stores and other
		# generic rooms. If the plan still cannot carry it, the next pass may
		# honestly omit it.
		for i in range(candidate.size() - 1, -1, -1):
			var kind: StringName = candidate[i]
			var optional_copy := candidate.count(kind) > 1
			if (not required.has(kind) or optional_copy) and not _is_primary_style_activity(spec.style, kind):
				drop = i
				break
		if drop < 0:
			for i in range(candidate.size() - 1, -1, -1):
				var kind: StringName = candidate[i]
				if not required.has(kind) or candidate.count(kind) > 1:
					drop = i
					break
		if drop < 0:
			# Keep a dedicated kitchen through all optional/style-priority retries.
			# Only merge it after the remaining hall, kitchen and bedroom cannot fit.
			if _ordinary_domestic_no_trade(spec) and not kitchen_merged \
					and candidate.has(&"kitchen") and candidate.has(&"bedroom"):
				candidate.erase(&"kitchen")
				required.erase(&"kitchen")
				kitchen_merged = true
				var last_rejected: Dictionary = rejected.back()
				last_rejected["resolution"] = "merge kitchen activity into the hall; keep a separate bedroom"
				rejected[rejected.size() - 1] = last_rejected
				continue
			break
		candidate.remove_at(drop)

	return {"ok": false, "reason": reason if not reason.is_empty() \
		else "required hall, kitchen, bedroom or trade room does not fit"}


static func _omitted_activities(requested: Array[StringName], planned: Array[StringName]) -> Array[StringName]:
	var remaining: Array[StringName] = planned.duplicate()
	var omitted: Array[StringName] = []
	for kind in requested:
		var index := remaining.find(kind)
		if index >= 0:
			remaining.remove_at(index)
		else:
			omitted.append(kind)
	return omitted


## Reconcile roles after daylight demotion, upper-floor naming, and cellar
## cloning. These passes are allowed to change a room's kind; annotations are
## not allowed to keep describing its former use.
static func refresh_domestic_metadata(p: HousePlan) -> void:
	if p.domestic_layout.is_empty() or p.domestic_layout.get("status", &"") != &"planned":
		return
	var ground_kinds: Array[StringName] = []
	for i in range(p.rooms.size()):
		var room: Dictionary = p.rooms[i]
		var kind: StringName = p.kind_of(i)
		var storey: int = p.storey_of_room(i)
		var retained_shared_witchwork := bool(room.get("shared_witchwork", false))
		room["domestic_layout_storey"] = storey
		room["domestic_functions"] = []
		room["shared_cooking"] = false
		room["shared_witchwork"] = retained_shared_witchwork
		room["meal_room"] = false
		if storey == 0:
			ground_kinds.append(kind)
		if kind == &"hall" and storey == 0:
			var functions: Array[StringName] = [&"entry", &"circulation", &"dining", &"common_living"]
			var shared := bool(p.domestic_layout.get("shared_cooking", false)) \
				 or (not ground_kinds.has(&"kitchen") and not p.has_kind(&"kitchen"))
			var shared_witchwork: bool = bool(p.domestic_layout.get("shared_witchwork", false)) \
				 and p.domestic_layout.get("merged_into", &"") == &"hall"
			if shared:
				functions.append(&"cooking")
			if shared_witchwork:
				functions.append(&"witchwork")
			room["domestic_role"] = p.domestic_layout.get("hall_role", &"living_hall")
			room["domestic_functions"] = functions
			room["meal_room"] = true
			room["shared_cooking"] = shared
			room["shared_witchwork"] = shared_witchwork
		elif kind == &"kitchen" and retained_shared_witchwork:
			room["domestic_role"] = &"shared_service"
			room["domestic_functions"] = [_activity_role(kind), &"cooking", &"witchwork"]
		elif kind == &"store" and p.domestic_layout.get("added_activities", []).has(&"store"):
			room["domestic_role"] = &"store"
			room["domestic_functions"] = [&"storage", &"dry_herbs"]
		else:
			var role := _activity_role(kind)
			room["domestic_role"] = role
			room["domestic_functions"] = [role]
		# Never leave a former kitchen or dining claim on a cloned upstairs room.
		p.rooms[i] = room
	var missing: Array[StringName] = []
	var activities: Array = p.domestic_layout.get("ground_activities", [])
	var merged_activities: Array = p.domestic_layout.get("merged_activities", [])
	var checked: Array[StringName] = []
	for activity in activities:
		var kind := StringName(activity)
		if kind in [&"hall", &"store"] or checked.has(kind):
			continue
		checked.append(kind)
		if merged_activities.has(kind):
			var required_function: StringName = &""
			match kind:
				&"kitchen": required_function = &"cooking"
				&"workshop": required_function = &"witchwork"
				_: required_function = kind
			var merged_role_present := false
			for room_index in range(p.rooms.size()):
				if p.storey_of_room(room_index) != 0:
					continue
				var functions: Array = p.rooms[room_index].get("domestic_functions", [])
				if functions.has(required_function):
					merged_role_present = true
					break
			if not merged_role_present:
				missing.append(kind)
			continue
		var wanted_count := activities.count(kind)
		var actual_count := ground_kinds.count(kind)
		for _missing in range(maxi(wanted_count - actual_count, 0)):
			missing.append(kind)
	for added in p.domestic_layout.get("added_activities", []):
		var added_kind := StringName(added)
		if ground_kinds.count(added_kind) < 1:
			missing.append(added_kind)
	if not missing.is_empty():
		p.domestic_layout["status"] = &"fallback"
		p.domestic_layout["reason"] = "final room repair removed ground-floor activities: %s" % ", ".join(missing)


static func _domestic_kinds(spec: HouseSpec, wanted: int) -> Array[StringName]:
	var source: Array[StringName] = []
	var programme: Array = spec.program if not spec.program.is_empty() \
		else HouseSpec.STYLES.get(spec.style, {}).get("domestic_program", HouseSpec.PROGRAM)
	for value in programme:
		var kind := StringName(value)
		if kind == &"hall":
			continue
		if kind != &"bedroom" and source.has(kind):
			continue
		source.append(kind)
	var ordered: Array[StringName] = [&"hall"]
	var trade_room: StringName = HouseSpec.TRADES.get(spec.trade, {}).get("room", &"")
	if trade_room != &"" and source.has(trade_room):
		ordered.append(trade_room)
	for core in [&"bedroom", &"kitchen"]:
		if source.has(core):
			ordered.append(core)
	# One extra room beyond the core household and signature is a second bed
	# when the programme names one. Extra bedrooms are real capacity, not a
	# duplicate kind to be collapsed into a store.
	for kind in source:
		if _is_style_signature(spec.style, kind) and not ordered.has(kind):
			ordered.append(kind)
	if source.has(&"bedroom") and ((source.count(&"bedroom") > 1 and wanted >= 6) \
			or wanted >= 7):
		ordered.append(&"bedroom")
	for kind in source:
		if kind != &"bedroom" and not ordered.has(kind):
			ordered.append(kind)
	ordered = ordered.slice(0, mini(ordered.size(), wanted))
	# Additional capacity is planned here, before fitting, so every emitted bay
	# is represented by the programme and its omission provenance.
	while ordered.size() < wanted:
		ordered.append(&"store")
	return ordered


## Ordinary, no-trade domestic plans may merge cooking into the hall when
## there is not enough clear width for both a usable kitchen and bedroom.
## Adapter-owned programmes and explicit trades keep their established rules.
static func _ordinary_domestic_no_trade(spec: HouseSpec) -> bool:
	return spec != null and spec.get_script() == BASE_HOUSE_SPEC \
		and spec.trade == &"none" \
		and HouseSpec.STYLES.get(spec.style, {}).has("domestic_program") \
		and not spec.has_method("room_program") \
		and not spec.has_method("custom_room_rects") \
		and not spec.has_method("landmark_footprint")


static func _programme_includes_kitchen(spec: HouseSpec) -> bool:
	var programme: Array = spec.program if not spec.program.is_empty() \
		else HouseSpec.STYLES.get(spec.style, {}).get("domestic_program", [])
	return programme.has(&"kitchen")


static func _domestic_min_side(spec: HouseSpec, kind: StringName) -> float:
	if kind == &"kitchen" and _ordinary_domestic_no_trade(spec):
		return DOMESTIC_KITCHEN_MIN_SIDE
	return float(HouseGeometry.MIN_SIDE.get(kind, 1.6))


static func _domestic_room_suits(p: HousePlan, room: int, kind: StringName) -> bool:
	if not HouseGeometry.room_suits(p, room, kind):
		return false
	if kind == &"kitchen" and _ordinary_domestic_no_trade(p.spec):
		var floor: Rect2 = HouseGeometry.room_floor_rect(p, room)
		return minf(floor.size.x, floor.size.y) >= DOMESTIC_KITCHEN_MIN_SIDE
	return true


static func _compact_witch_service_case(spec: HouseSpec, wanted: int,
		kinds: Array[StringName], inner: Rect2) -> bool:
	return _ordinary_domestic_no_trade(spec) and spec.style == &"witch_hut" \
		and spec.storeys == 1 and spec.cellars == 0 and wanted == 3 \
		and kinds.has(&"hall") and kinds.has(&"kitchen") and kinds.has(&"bedroom") \
		and inner.size.x <= 7.5 and inner.size.y <= 9.0


static func _large_domestic_grammar(spec: HouseSpec) -> bool:
	return spec != null and spec.width >= 12.0 and spec.length >= 14.0


static func _witch_default_ell_case(p: HousePlan, spec: HouseSpec, wanted: int,
		kinds: Array[StringName]) -> bool:
	if p == null or spec == null or p.world_family != &"" \
			or not _ordinary_domestic_no_trade(spec):
		return false
	if spec.get_script() != BASE_HOUSE_SPEC or spec.style != &"witch_hut" \
			or spec.has_method("room_program") or spec.has_method("custom_room_rects") \
			or spec.has_method("landmark_footprint") or spec.storeys != 1 or spec.cellars != 0 \
			or spec.roof_material != &"thatch" \
			or minf(spec.width, spec.length) < HouseGeometry.WITCH_WORKSHOP_MIN_SITE_SPAN \
			or _large_domestic_grammar(spec) \
			or wanted < 4 or kinds.size() < 4:
		return false
	var inner := HouseGeometry.interior_rect(spec)
	if _compact_witch_service_case(spec, wanted, kinds, inner) \
			or inner.size.y <= inner.size.x:
		return false # the lower service run must stay parallel to the established main ridge
	# The compact shared-Hall branch is handled first. This branch only applies
	# while the domestic grammar still names the four core Witch rooms. A generic
	# layout that can place more than those four has enough capacity to keep its
	# established side-room programme and does not need the service ell.
	for core in [&"hall", &"bedroom", &"kitchen", &"workshop"]:
		if kinds.find(core) < 0 or kinds.find(core) >= 4:
			return false
	var generic_capacity := 0
	for count in range(mini(wanted, kinds.size()), 3, -1):
		var attempt := _fit_domestic_candidate(p, spec, inner, kinds.slice(0, count))
		if bool(attempt.get("ok", false)):
			generic_capacity = count
			break
	return generic_capacity <= 4


static func _fit_witch_default_ell_candidate(p: HousePlan, spec: HouseSpec,
		inner: Rect2) -> Dictionary:
	var wall_half: float = HouseGeometry.INNER_WALL_T * 0.5
	var core_width_min := maxf(_domestic_min_side(spec, &"hall"),
		_domestic_min_side(spec, &"bedroom")) + wall_half
	var wing_width_min := maxf(_domestic_min_side(spec, &"kitchen"),
		_domestic_min_side(spec, &"workshop")) + wall_half
	if inner.size.x < core_width_min + wing_width_min:
		return {"ok": false, "reason": "Witch service ell cannot fit the minimum clear widths for the core and working rooms"}
	# Allocate the side-to-side span in proportion to the actual room minima.
	# The 9 x 12 request lands near its previous 52/48 division, while nearby
	# supported widths scale with the room programme instead of a fixed size.
	var core_width := inner.size.x * core_width_min / (core_width_min + wing_width_min)
	var wing_width := inner.size.x - core_width
	var core_clear_width := core_width - wall_half
	var wing_clear_width := wing_width - wall_half
	var front_clear_depth := maxf(_room_required_depth(spec, &"hall", core_clear_width),
		_room_required_depth(spec, &"kitchen", wing_clear_width))
	var rear_clear_depth := maxf(_room_required_depth(spec, &"bedroom", core_clear_width),
		_room_required_depth(spec, &"workshop", wing_clear_width))
	var front_depth_min := front_clear_depth + wall_half
	var rear_depth_min := rear_clear_depth + wall_half
	if inner.size.y < front_depth_min + rear_depth_min:
		return {"ok": false, "reason": "Witch service ell cannot fit the minimum clear depths for the front and rear rooms"}
	# Keep the established deeper private rear row when the site permits it;
	# increase the entry row only when measured room minima require it.
	var row_depth := maxf(inner.size.y * 0.40, front_depth_min)
	if inner.size.y - row_depth < rear_depth_min:
		row_depth = inner.size.y - rear_depth_min
	if row_depth < front_depth_min or inner.size.y - row_depth < rear_depth_min:
		return {"ok": false, "reason": "Witch service ell depth split violates a room's measured usable minimum"}
	var mirror: bool = posmod(spec.seed, 2) == 1
	var wing_x := inner.position.x if mirror else inner.end.x - wing_width
	var core_x := wing_x + wing_width if mirror else inner.position.x
	var hall := {"kind": &"hall", "rect": Rect2(Vector2(core_x, inner.position.y),
		Vector2(core_width, row_depth)), "storey": 0}
	var kitchen := {"kind": &"kitchen", "rect": Rect2(Vector2(wing_x, inner.position.y),
		Vector2(wing_width, row_depth)), "storey": 0, "witch_service_wing": true}
	var bedroom := {"kind": &"bedroom", "rect": Rect2(Vector2(core_x, inner.position.y + row_depth),
		Vector2(core_width, inner.size.y - row_depth)), "storey": 0}
	var workshop := {"kind": &"workshop", "rect": Rect2(Vector2(wing_x, inner.position.y + row_depth),
		Vector2(wing_width, inner.size.y - row_depth)), "storey": 0, "witch_service_wing": true}
	return _validate_domestic_rooms(p, inner, [hall, kitchen, bedroom, workshop], mirror)


static func _room_required_depth(spec: HouseSpec, kind: StringName,
		clear_width: float) -> float:
	if clear_width <= 0.0:
		return INF
	var min_side := _domestic_min_side(spec, kind)
	var min_area := float(HouseGeometry.MIN_AREA.get(kind, 4.0))
	var max_aspect := HouseGeometry.aspect_max(kind)
	return maxf(min_side, maxf(clear_width / max_aspect, min_area / clear_width))


## Compact Witch plans merge the kitchen and workshop room programmes into
## one full-width lived hall. Both activities remain explicit and are furnished
## as separate work zones; a private bedroom and dry store share the rear row.
static func _fit_compact_witch_shared_hall_candidate(p: HousePlan, spec: HouseSpec,
		inner: Rect2) -> Dictionary:
	var wall_half: float = HouseGeometry.INNER_WALL_T * 0.5
	# These clear dimensions reserve the complete measured meal and two work groups.
	if inner.size.x < 6.29:
		return {"ok": false, "reason": "compact Witch shared hall needs 6.29 m measured service frontage; only %.2f m is available" % inner.size.x}
	var hall_min: float = maxf(_domestic_min_side(spec, &"hall"),
		inner.size.x / HouseGeometry.aspect_max(&"hall"))
	var bedroom_depth: float = maxf(_domestic_min_side(spec, &"bedroom"), 3.6)
	var hall_depth: float = inner.size.y - bedroom_depth
	var clear_hall_depth: float = hall_depth - wall_half
	var clear_bedroom_depth: float = bedroom_depth - wall_half
	if hall_depth < hall_min + wall_half:
		return {"ok": false, "reason": "compact Witch shared hall needs %.2f m of clear front depth; only %.2f m remains" % [hall_min, clear_hall_depth]}
	if clear_bedroom_depth < _domestic_min_side(spec, &"bedroom"):
		return {"ok": false, "reason": "compact Witch shared hall leaves only %.2f m clear for the private bedroom" % clear_bedroom_depth}
	var rear_depth := bedroom_depth
	var bedroom_clear_width := _domestic_min_side(spec, &"bedroom") + 0.02
	var bedroom_width := bedroom_clear_width + wall_half
	var store_width := inner.size.x - bedroom_width
	var store_clear_width := store_width - wall_half
	if store_clear_width < _domestic_min_side(spec, &"store"):
		return {"ok": false, "reason": "compact Witch rear row cannot fit both a private bedroom and dry store"}
	var mirror: bool = posmod(spec.seed, 2) == 1
	var bed_x := inner.position.x if not mirror else inner.end.x - bedroom_width
	var store_x := inner.position.x + bedroom_width if not mirror else inner.position.x
	var hall := {"kind": &"hall", "rect": Rect2(inner.position,
		Vector2(inner.size.x, hall_depth)), "storey": 0}
	var bedroom := {"kind": &"bedroom", "rect": Rect2(
		Vector2(bed_x, inner.position.y + hall_depth),
		Vector2(bedroom_width, rear_depth)), "storey": 0}
	var store := {"kind": &"store", "rect": Rect2(
		Vector2(store_x, inner.position.y + hall_depth),
		Vector2(store_width, rear_depth)), "storey": 0}
	var rooms: Array[Dictionary] = [hall, bedroom, store]
	return _validate_domestic_rooms(p, inner, rooms, mirror)


static func _compact_shared_cooking_square(spec: HouseSpec, inner: Rect2,
		kinds: Array[StringName]) -> bool:
	return _ordinary_domestic_no_trade(spec) and spec.storeys == 1 and spec.cellars == 0 \
		and kinds.size() == 2 and kinds.has(&"hall") and kinds.has(&"bedroom") \
		and inner.size.x <= 7.5 and inner.size.y <= 7.5 \
		and absf(inner.size.x - inner.size.y) <= 0.75


## The front-to-back split cannot leave 3.3 m for the bedroom and a useful
## shared cooking/dining hall inside a compact square. Put the rooms side by
## side instead: the hall receives the front door on its own short wall, while
## its long clear run separates meal and cooking work zones.
static func _fit_compact_shared_cooking_candidate(p: HousePlan, spec: HouseSpec,
		inner: Rect2, kinds: Array[StringName]) -> Dictionary:
	var wall_half: float = HouseGeometry.INNER_WALL_T * 0.5
	var hall_min: float = float(HouseGeometry.MIN_SIDE.get(&"hall", 2.6)) + wall_half
	var bedroom_min: float = _domestic_min_side(spec, &"bedroom")
	var hall_width: float = minf(3.1 + wall_half,
		inner.size.x - bedroom_min - wall_half)
	if hall_width < hall_min:
		return {"ok": false, "reason": "compact shared hall cannot retain its minimum width beside the bedroom"}
	var mirror: bool = posmod(spec.seed, 2) == 1
	var hall_x: float = inner.end.x - hall_width if mirror else inner.position.x
	var bedroom_x: float = inner.position.x if mirror else inner.position.x + hall_width
	var bedroom_width: float = inner.size.x - hall_width
	var hall := {"kind": &"hall", "rect": Rect2(Vector2(hall_x, inner.position.y),
		Vector2(hall_width, inner.size.y)), "storey": 0}
	var bedroom := {"kind": &"bedroom", "rect": Rect2(Vector2(bedroom_x, inner.position.y),
		Vector2(bedroom_width, inner.size.y)), "storey": 0}
	var rooms: Array[Dictionary] = [hall, bedroom]
	return _validate_domestic_rooms(p, inner, rooms, mirror)


## Large houses use a hall that is a room and a circulation spine at once.
## Side bays open directly to it; the sleeping rooms therefore remain private
## leaf rooms rather than routes to the kitchen.
static func _fit_large_domestic_candidate(p: HousePlan, spec: HouseSpec, inner: Rect2,
		kinds: Array[StringName]) -> Dictionary:
	var mirror: bool = posmod(spec.seed, 2) == 1
	var activities: Array[StringName] = kinds.slice(1)
	activities.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ra := _large_backness(a, spec.style)
		var rb := _large_backness(b, spec.style)
		if ra != rb:
			return ra < rb
		return kinds.find(a) < kinds.find(b))
	if activities.size() < 2:
		return {"ok": false, "reason": "large hall spine needs at least two side activities"}
	if activities.size() % 2 != 0:
		return {"ok": false, "reason": "large side-bay programme needs an even number of activities"}
	var row_count := int(ceil(float(activities.size()) / 2.0))
	var required_spine_width := inner.size.y / HouseGeometry.ROOM_ASPECT_MAX \
		+ HouseGeometry.INNER_WALL_T * 2.0
	var spine_width := maxf(3.6, required_spine_width)
	var wing_width := (inner.size.x - spine_width) * 0.5
	if wing_width <= 0.0:
		return {"ok": false, "reason": "central hall spine leaves no side bays"}
	var clear_bay_width := wing_width - HouseGeometry.INNER_WALL_T * 0.5
	var row_min_depths: Array[float] = []
	var min_depth_sum := 0.0
	for row_index in range(row_count):
		var row_min := 1.6
		for side in range(2):
			var activity_index := row_index * 2 + side
			if activity_index >= activities.size():
				continue
			var kind: StringName = activities[activity_index]
			var aspect_depth := clear_bay_width / HouseGeometry.aspect_max(kind)
			var area_depth := float(HouseGeometry.MIN_AREA.get(kind, 4.0)) / maxf(clear_bay_width, 0.1)
			var raw_min := maxf(_domestic_min_side(spec, kind),
				maxf(aspect_depth, area_depth))
			var depth_allowance: float = HouseGeometry.INNER_WALL_T \
				if row_index < row_count - 1 else HouseGeometry.INNER_WALL_T * 0.5
			row_min = maxf(row_min, raw_min + depth_allowance)
		row_min_depths.append(row_min)
		min_depth_sum += row_min
	if min_depth_sum > inner.size.y:
		return {"ok": false, "reason": "large side bays need %.1f m of hall length; only %.1f m is available" % [min_depth_sum, inner.size.y]}
	var extra_depth := inner.size.y - min_depth_sum
	var weights: Array[float] = []
	var total_weight := 0.0
	for row_index in range(row_count):
		var weight := 0.0
		for side in range(2):
			var activity_index := row_index * 2 + side
			if activity_index < activities.size():
				weight += _depth_weight(activities[activity_index], spec.style)
		weights.append(weight)
		total_weight += weight
	var hall_width := spine_width
	var hall_x := inner.position.x + (inner.size.x - hall_width) * 0.5
	var rooms: Array[Dictionary] = [{"kind": &"hall", "rect": Rect2(
		Vector2(hall_x, inner.position.y), Vector2(hall_width, inner.size.y)), "storey": 0}]
	var row_y := inner.position.y
	for row_index in range(row_count):
		var depth := row_min_depths[row_index] + extra_depth * weights[row_index] / maxf(total_weight, 0.001)
		for side in range(2):
			var activity_index := row_index * 2 + side
			var kind: StringName = activities[activity_index]
			var physical_side: int = 1 - side if mirror else side
			var x := inner.position.x if physical_side == 0 else hall_x + hall_width
			var rect := Rect2(Vector2(x, row_y), Vector2(wing_width, depth))
			rooms.append({"kind": kind, "rect": rect, "storey": 0})
		row_y += depth
	return _validate_domestic_rooms(p, inner, rooms, mirror)


static func _validate_domestic_rooms(p: HousePlan, inner: Rect2,
		rooms: Array[Dictionary], mirror: bool) -> Dictionary:
	var tiled_area := 0.0
	for row in rooms:
		var rect: Rect2 = row["rect"]
		if not inner.grow(0.01).encloses(rect):
			return {"ok": false, "reason": "activity bays leave the interior footprint"}
		tiled_area += rect.get_area()
	if absf(tiled_area - inner.get_area()) > 0.05:
		return {"ok": false, "reason": "activity bays do not tile the interior footprint"}
	for row in rooms:
		p.rooms.append(row)
	var valid := true
	var why := ""
	for i in range(rooms.size()):
		var room_index := p.rooms.size() - rooms.size() + i
		var kind: StringName = p.kind_of(room_index)
		if not _domestic_room_suits(p, room_index, kind):
			valid = false
			why = "%s room does not fit its minimum floor" % String(kind)
			break
		if HouseGeometry.room_aspect(p, room_index) > HouseGeometry.aspect_max(kind):
			valid = false
			why = "%s room aspect exceeds its limit" % String(kind)
			break
	for _row in rooms:
		p.rooms.pop_back()
	if not valid:
		return {"ok": false, "reason": why}
	return {"ok": true, "rooms": rooms, "mirror": mirror}


static func _fit_domestic_candidate(p: HousePlan, spec: HouseSpec, inner: Rect2,
		kinds: Array[StringName]) -> Dictionary:
	var wall_half := HouseGeometry.INNER_WALL_T * 0.5
	var mirror: bool = posmod(spec.seed, 2) == 1
	var hall_min_depth := maxf(float(HouseGeometry.MIN_SIDE.get(&"hall", 2.6)) + wall_half,
		inner.size.x / HouseGeometry.ROOM_ASPECT_MAX + wall_half)
	# The common room must hold a useful household table group outside the
	# entrance approach, rather than meeting the hall minimum by area alone.
	if inner.size.y >= 8.0:
		hall_min_depth = maxf(hall_min_depth, 3.6)
	if kinds.size() > 1 and not kinds.has(&"kitchen"):
		# A shared cooking and eating room needs depth for both work access
		# and occupied seats. Preserve the bedroom fit check below.
		var bedroom_depth := float(HouseGeometry.MIN_SIDE.get(&"bedroom", 3.3))
		var shared_depth := minf(3.1 + wall_half, inner.size.y - bedroom_depth - wall_half)
		hall_min_depth = maxf(hall_min_depth, shared_depth)
	if spec.storeys >= 3 and HousePlanLevels._is_plain_house_spec(spec):
		# The middle hall carries two flights, their protected well edge, a
		# continuous body-width transfer path, and the rear doorway apron. Keep
		# enough clear depth for that real arrangement before dividing the home
		# into rooms; the ordinary activity-fit check below still governs what
		# can remain behind this hall.
		var stair_hall_depth := HouseGeometry.STAIR_WIDTH_TARGET * 2.0 \
			+ HouseGeometry.STAIR_WIDTH_CLEAR_MIN \
			+ HousePlanLevels.WELL_CLEAR * 2.0 \
			+ HouseGeometry.DOOR_CLEAR + wall_half
		hall_min_depth = maxf(hall_min_depth, stair_hall_depth)
	var hall_ratio: float = _hall_ratio(spec.style, inner) + float(posmod(spec.seed, 3)) * 0.01
	var hall_depth := maxf(hall_min_depth, inner.size.y * hall_ratio)
	if kinds.size() == 2 and kinds.has(&"bedroom") and not kinds.has(&"kitchen") \
			and _ordinary_domestic_no_trade(spec) and spec.storeys == 1 and spec.cellars == 0:
		# This room carries entry, meals, cooking and common life. A single bed
		# must not receive the larger half while all four activities are squeezed
		# into a shallow front strip. Keep a usable sleeping bay, then assign the
		# remaining depth to the shared room; validation still checks both rooms.
		var sleep_depth := maxf(_domestic_min_side(spec, &"bedroom"), 3.6) + wall_half
		hall_depth = maxf(hall_depth, inner.size.y - sleep_depth)
	if kinds.has(&"kitchen") and kinds.size() > 2 \
			and inner.size.x >= 8.0 and inner.size.y >= 10.0:
		return _fit_service_wing_candidate(p, spec, inner, kinds, hall_depth)
	var rooms: Array[Dictionary] = []
	if kinds.size() == 1:
		var only := {"kind": &"hall", "rect": inner, "storey": 0}
		p.rooms.append(only)
		var fits := HouseGeometry.room_suits(p, p.rooms.size() - 1, &"hall") \
			and HouseGeometry.room_aspect(p, p.rooms.size() - 1) <= HouseGeometry.aspect_max(&"hall")
		p.rooms.pop_back()
		if not fits:
			return {"ok": false, "reason": "one-room common hall misses its minimum shape"}
		rooms.append(only)
		return {"ok": true, "rooms": rooms, "mirror": mirror}
	if hall_depth >= inner.size.y:
		return {"ok": false, "reason": "front hall leaves no depth for another activity"}

	var hall_rect := Rect2(inner.position, Vector2(inner.size.x, hall_depth))
	rooms.append({"kind": &"hall", "rect": hall_rect, "storey": 0})
	var remaining: Array[StringName] = kinds.slice(1)
	remaining.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ra := _compact_backness(a, spec.style)
		var rb := _compact_backness(b, spec.style)
		if ra != rb:
			return ra < rb
		return kinds.find(a) < kinds.find(b))
	var row_groups: Array[Array] = []
	var cursor := 0
	while cursor < remaining.size():
		var take := 1
		# Two bays preserve an outside wall for every inhabited room. A third
		# column would create a windowless centre room in a three-row plan.
		for possible in range(2, mini(2, remaining.size() - cursor) + 1):
			var required_width := wall_half * float(possible - 1)
			for k in range(possible):
				required_width += _domestic_min_side(spec, remaining[cursor + k])
			if inner.size.x < required_width:
				break
			take = possible
		var group: Array[StringName] = remaining.slice(cursor, cursor + take)
		row_groups.append(group)
		cursor += take

	var row_widths: Array[Array] = []
	for group in row_groups:
		var widths: Array[float] = []
		var min_width_sum := 0.0
		var width_weight_sum := 0.0
		for cell in range(group.size()):
			var kind: StringName = group[cell]
			var edge_allowance := wall_half if group.size() > 1 else 0.0
			min_width_sum += _domestic_min_side(spec, kind) + edge_allowance
			width_weight_sum += _width_weight(kind, spec.style)
		var spare_width := maxf(inner.size.x - min_width_sum, 0.0)
		for cell in range(group.size()):
			var kind: StringName = group[cell]
			var edge_allowance := wall_half if group.size() > 1 else 0.0
			var width := _domestic_min_side(spec, kind) + edge_allowance \
				+ spare_width * _width_weight(kind, spec.style) / maxf(width_weight_sum, 0.001)
			widths.append(width)
		row_widths.append(widths)

	var row_min_depths: Array[float] = []
	var min_depth_sum := 0.0
	for row_index in range(row_groups.size()):
		var group: Array = row_groups[row_index]
		var widths: Array = row_widths[row_index]
		var row_min := 1.6
		for cell in range(group.size()):
			var kind: StringName = group[cell]
			var clear_width: float = widths[cell] - (wall_half if group.size() > 1 else 0.0)
			var aspect_depth := clear_width / HouseGeometry.aspect_max(kind)
			var area_depth := float(HouseGeometry.MIN_AREA.get(kind, 4.0)) / maxf(clear_width, 0.1)
			var depth_allowance: float = wall_half * (2.0 if row_index < row_groups.size() - 1 else 1.0)
			row_min = maxf(row_min, maxf(_domestic_min_side(spec, kind),
				maxf(aspect_depth, area_depth)) + depth_allowance)
		row_min_depths.append(row_min)
		min_depth_sum += row_min
	var rest_depth := inner.size.y - hall_depth
	if min_depth_sum > rest_depth:
		return {"ok": false, "reason": "required activities need %.1f m behind the entry hall; only %.1f m remains" % [min_depth_sum, rest_depth]}
	var extra_depth := rest_depth - min_depth_sum
	var total_weight := 0.0
	var row_weights: Array[float] = []
	for group in row_groups:
		var weight := 0.0
		for kind in group:
			weight += _depth_weight(kind, spec.style)
		row_weights.append(weight)
		total_weight += weight
	var row_y := hall_rect.end.y
	for row_index in range(row_groups.size()):
		var group: Array = row_groups[row_index]
		var depth := row_min_depths[row_index] + extra_depth * row_weights[row_index] / maxf(total_weight, 0.001)
		var widths: Array = row_widths[row_index]
		var x := inner.position.x
		for cell in range(group.size()):
			var x_cell := cell if not mirror else group.size() - 1 - cell
			var width: float = float(widths[x_cell]) if group.size() > 1 else inner.size.x
			var rect := Rect2(Vector2(x, row_y), Vector2(width, depth))
			rooms.append({"kind": group[x_cell], "rect": rect, "storey": 0})
			x += width
		row_y += depth

	# Validate geometry before accepting the plan. An area-equal result that
	# runs past the shell is not a room layout.
	var tiled_area := 0.0
	for row in rooms:
		var rect: Rect2 = row["rect"]
		if not inner.grow(0.01).encloses(rect):
			return {"ok": false, "reason": "activity bays leave the interior footprint"}
		tiled_area += rect.get_area()
	if absf(tiled_area - inner.get_area()) > 0.05:
		return {"ok": false, "reason": "activity bays do not tile the interior footprint"}

	# Room labels do not get to make an undersized bay pass.
	for row in rooms:
		p.rooms.append(row)
	var valid := true
	var why := ""
	for i in range(rooms.size()):
		var kind: StringName = p.kind_of(p.rooms.size() - rooms.size() + i)
		var room_index := p.rooms.size() - rooms.size() + i
		if not _domestic_room_suits(p, room_index, kind):
			valid = false
			why = "%s room does not fit its minimum floor" % String(kind)
			break
		if HouseGeometry.room_aspect(p, room_index) > HouseGeometry.aspect_max(kind):
			valid = false
			why = "%s room aspect exceeds its limit" % String(kind)
			break
	for _row in rooms:
		p.rooms.pop_back()
	if not valid:
		return {"ok": false, "reason": why}
	return {"ok": true, "rooms": rooms, "mirror": mirror}


## A back-yard kitchen belongs on the yard wall. In a compact house it runs
## beside the common rooms as a service wing, with a direct opening to the
## entry hall. This avoids making the household cross a sleeping room to reach
## the kitchen or yard.
static func _fit_service_wing_candidate(p: HousePlan, spec: HouseSpec, inner: Rect2,
		kinds: Array[StringName], hall_depth: float) -> Dictionary:
	var wall_half := HouseGeometry.INNER_WALL_T * 0.5
	var rest_depth := inner.size.y - hall_depth
	var service_width := maxf(_domestic_min_side(spec, &"kitchen") + wall_half,
		inner.size.x * 0.38)
	var wing_width := inner.size.x - service_width
	if wing_width < _domestic_min_side(spec, &"bedroom") + wall_half:
		return {"ok": false, "reason": "back-yard kitchen wing leaves no private room bay"}
	var activities: Array[StringName] = kinds.slice(1)
	activities.erase(&"kitchen")
	activities.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ra := _compact_backness(a, spec.style)
		var rb := _compact_backness(b, spec.style)
		if ra != rb:
			return ra < rb
		return kinds.find(a) < kinds.find(b))
	var row_min_depths: Array[float] = []
	var min_depth_sum := 0.0
	for kind in activities:
		var aspect_depth := wing_width / HouseGeometry.aspect_max(kind)
		var area_depth := float(HouseGeometry.MIN_AREA.get(kind, 4.0)) / maxf(wing_width, 0.1)
		var row_min := maxf(_domestic_min_side(spec, kind),
			maxf(aspect_depth, area_depth)) + wall_half
		row_min_depths.append(row_min)
		min_depth_sum += row_min
	if activities.is_empty() or min_depth_sum > rest_depth:
		return {"ok": false, "reason": "yard kitchen and private wing need %.1f m behind the hall; only %.1f m remains" % [min_depth_sum, rest_depth]}
	var extra := rest_depth - min_depth_sum
	var total_weight := 0.0
	var weights: Array[float] = []
	for kind in activities:
		var weight := _depth_weight(kind, spec.style)
		weights.append(weight)
		total_weight += weight
	var mirror: bool = posmod(spec.seed, 2) == 1
	var kitchen_x := inner.position.x + wing_width if mirror else inner.position.x
	var wing_x := inner.position.x if mirror else inner.position.x + service_width
	var rooms: Array[Dictionary] = [{"kind": &"hall",
		"rect": Rect2(inner.position, Vector2(inner.size.x, hall_depth)), "storey": 0},
		{"kind": &"kitchen", "rect": Rect2(Vector2(kitchen_x, inner.position.y + hall_depth),
			Vector2(service_width, rest_depth)), "storey": 0}]
	var y := inner.position.y + hall_depth
	for i in range(activities.size()):
		var depth := row_min_depths[i] + extra * weights[i] / maxf(total_weight, 0.001)
		rooms.append({"kind": activities[i],
			"rect": Rect2(Vector2(wing_x, y), Vector2(wing_width, depth)), "storey": 0})
		y += depth
	return _validate_domestic_rooms(p, inner, rooms, mirror)


## Small plans bring the kitchen and defining household activity directly off
## the lived common room. Stores sit behind those shared rooms; bedrooms form
## the quiet terminal row.
static func _compact_backness(kind: StringName, style: StringName) -> int:
	if _is_primary_style_activity(style, kind):
		return 0
	if _is_style_signature(style, kind):
		return 1
	if kind == &"kitchen":
		return 0
	if kind in [&"bedroom", &"guest_room", &"suite"]:
		return 3
	if kind in [&"store", &"records"]:
		return 2
	return 1


static func _is_primary_style_activity(style: StringName, kind: StringName) -> bool:
	match style:
		&"cottage": return kind == &"parlour"
		&"farmhouse": return kind == &"workshop"
		&"townhouse": return kind == &"office"
		&"witch_hut": return kind == &"workshop"
		&"longhall": return kind == &"workshop"
	return false


## The large hall is a spine. Put the service kitchen against the rear yard
## wall, with a private bedroom beside it; all rooms still open directly to
## the spine, so neither is a route through the other.
static func _large_backness(kind: StringName, style: StringName) -> int:
	if kind == &"kitchen":
		return 4
	if kind in [&"bedroom", &"guest_room", &"suite"]:
		return 3
	if kind in [&"store", &"records"] and not _is_style_signature(style, kind):
		return 2
	if _is_style_signature(style, kind):
		return 0
	return 1


static func _is_style_signature(style: StringName, kind: StringName) -> bool:
	match style:
		&"cottage": return kind == &"parlour"
		&"farmhouse": return kind == &"workshop"
		&"townhouse": return kind in [&"parlour", &"office"]
		&"witch_hut": return kind in [&"workshop", &"records"]
		&"longhall": return kind == &"workshop"
	return false


static func _width_weight(kind: StringName, style: StringName) -> float:
	if _is_style_signature(style, kind):
		return 1.15
	if kind in [&"kitchen", &"store", &"records"]:
		return 0.9
	return 1.0


static func _hall_ratio(style: StringName, inner: Rect2) -> float:
	match style:
		&"longhall": return 0.40 if inner.size.x >= 10.0 and inner.size.y >= 14.0 else 0.24
		&"cottage": return 0.22
		&"farmhouse": return 0.22
		&"townhouse": return 0.23
		&"witch_hut": return 0.24
	return 0.22


static func _depth_weight(kind: StringName, style: StringName) -> float:
	if kind == &"store":
		return 0.72 if style in [&"townhouse", &"cottage"] else 0.88
	if style == &"farmhouse" and kind in [&"kitchen", &"workshop"]:
		return 1.25
	if style == &"townhouse" and kind in [&"office", &"parlour"]:
		return 1.18
	if style == &"witch_hut" and kind in [&"workshop", &"records"]:
		return 1.22
	return 1.0


static func _activity_role(kind: StringName) -> StringName:
	return StringName("activity_%s" % String(kind))


static func _can_split(rect: Rect2) -> bool:
	var m: float = HouseGeometry.MIN_ROOM_SIDE + HouseGeometry.INNER_WALL_T
	return rect.size.x >= m * 2.0 or rect.size.y >= m * 2.0


## Cut along the longer axis, so rooms tend toward square rather than toward
## corridors. Returns [] when neither axis has room for the cut.
static func _split(rect: Rect2, r: RandomNumberGenerator) -> Array:
	var m: float = HouseGeometry.MIN_ROOM_SIDE + HouseGeometry.INNER_WALL_T
	var axes: Array[int] = []
	if rect.size.x >= rect.size.y:
		axes = [0, 1]
	else:
		axes = [1, 0]
	for axis in axes:
		var span: float = rect.size.x if axis == 0 else rect.size.y
		if span < m * 2.0:
			continue
		var lo: float = maxf(MIN_SPLIT, m / span)
		var hi: float = minf(MAX_SPLIT, 1.0 - m / span)
		if hi <= lo:
			continue
		var t: float = r.randf_range(lo, hi)
		var cut: float = span * t
		if axis == 0:
			return [
				Rect2(rect.position, Vector2(cut, rect.size.y)),
				Rect2(rect.position + Vector2(cut, 0.0),
					Vector2(rect.size.x - cut, rect.size.y)),
			]
		return [
			Rect2(rect.position, Vector2(rect.size.x, cut)),
			Rect2(rect.position + Vector2(0.0, cut),
				Vector2(rect.size.x, rect.size.y - cut)),
		]
	return []


# ------------------------------------------------------------- name rooms

## How strongly each kind is drawn to the two poles of a house (LAY-006): the
## FRONT, where the door and the street are, and the SERVICE end at the back,
## where the yard, the well and the midden are. The hall and the parlour want
## the front; the kitchen and the store want the back, so the back door lands
## on the kitchen where it belongs; a bedroom wants neither, and is pushed
## away from both. A kind not listed here sits in the middle. One pole was
## the old rule and it put the kitchen beside the front door, because it was
## second in the programme and second nearest the door was the best it could
## be given.
const KIND_POLES := {
	&"hall": {"front": 1.0, "service": 0.0},
	&"parlour": {"front": 0.8, "service": -0.2},
	&"dining_room": {"front": 0.8, "service": 0.0},
	&"sales_floor": {"front": 1.0, "service": 0.0},
	&"workshop": {"front": 0.5, "service": 0.2},
	&"kitchen": {"front": -0.2, "service": 1.0},
	&"store": {"front": -0.2, "service": 0.7},
	&"tack_room": {"front": 0.0, "service": 0.5},
	&"office": {"front": -0.2, "service": 0.3},
	&"records": {"front": -0.3, "service": 0.3},
	&"bedroom": {"front": -1.0, "service": -0.3},
	&"guest_room": {"front": -1.0, "service": -0.3},
	&"suite": {"front": -1.0, "service": -0.3},
	&"dormitory": {"front": -1.0, "service": 1.0},
	&"armoury": {"front": -0.3, "service": 0.3},
	&"mess": {"front": 0.8, "service": 0.0},
	&"reading_room": {"front": 0.9, "service": 0.0},
	&"stacks": {"front": -0.1, "service": 0.9},
	&"scriptorium": {"front": 0.1, "service": 0.5},
}


## How well room `i` answers what `kind` wants of the two poles: 1 at a pole
## it is drawn to, 0 at the far corner from it, negative where it is pushed.
static func _pole_score(p: HousePlan, spec: HouseSpec, i: int, kind: StringName) -> float:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var c: Vector2 = HouseGeometry.room_floor_rect(p, i).get_center()
	var front := Vector2(inner.get_center().x, inner.position.y)
	var back := Vector2(inner.get_center().x, inner.end.y)
	var reach: float = maxf(inner.size.length(), 0.01)
	var w: Dictionary = KIND_POLES.get(kind, {"front": 0.0, "service": 0.0})
	return float(w["front"]) * (1.0 - c.distance_to(front) / reach) \
		+ float(w["service"]) * (1.0 - c.distance_to(back) / reach)


## Assign kinds by publicness: the hall takes the front, the kitchen the back,
## bedrooms go away from both, and anything nothing wanted becomes a store.
static func name_rooms(p: HousePlan, spec: HouseSpec) -> void:
	if p.domestic_layout.get("status", &"") == &"planned":
		return
	var n: int = p.rooms.size()
	var inner: Rect2 = HouseGeometry.interior_rect(spec)

	# how far each room's centre sits from the middle of the front wall
	var order: Array[int] = []
	for i in range(n):
		order.append(i)
	var front := Vector2(0.0, inner.position.y)
	var dist := {}
	for i in range(n):
		var f: Rect2 = HouseGeometry.room_floor_rect(p, i)
		dist[i] = f.get_center().distance_to(front)
	order.sort_custom(func(a: int, b: int) -> bool: return dist[a] < dist[b])

	# the hall is the front-most room that can hold a hall; if none can, the
	# biggest room takes it, because a house must have somewhere to come in to.
	# A shop's hall becomes its public room afterwards, so it is measured
	# against what that room has to be -- a meeting hall wants a wider room
	# than a cottage hall does
	var hall_kind: StringName = &"hall"
	if spec.has_method("front_room"):
		hall_kind = spec.front_room()
	var hall := -1
	if spec.has_method("preferred_front_room_index"):
		var preferred: int = spec.preferred_front_room_index()
		if preferred >= 0 and preferred < n \
				and HouseGeometry.room_suits(p, preferred, hall_kind) \
				and HouseGeometry.room_suits(p, preferred, &"hall"):
			hall = preferred
	for i in order:
		if hall >= 0:
			break
		if HouseGeometry.room_suits(p, i, hall_kind) and HouseGeometry.room_suits(p, i, &"hall"):
			hall = i
			break
	if hall < 0:
		hall = _largest(p)
	p.rooms[hall]["kind"] = &"hall"

	# the rest of the program, most public first, over the remaining rooms
	# ordered from the door backwards
	var queue: Array[StringName] = []
	var deferred: Array[StringName] = []
	for kind in spec.program:
		if kind == &"hall":
			continue
		# A house with an upstairs sleeps upstairs. The ground floor keeps the
		# public and service programme -- hall, kitchen, parlour, workshop,
		# store -- and a bedroom only lands down here when the rooms outlast
		# the kinds that want them.
		if kind == &"bedroom" and HousePlanLevels.has_upstairs(spec) and HousePlanLevels.can_sleep_upstairs(p):
			deferred.append(kind)
		else:
			queue.append(kind)
	queue.append_array(deferred)
	var rest: Array[int] = []
	for i in order:
		if i != hall:
			rest.append(i)

	# Each kind takes the room that best answers its two poles among those
	# that can hold it; ties go to the room nearer the door, which is the old
	# one-pole order. The kinds the service pole pulls hardest -- the kitchen
	# -- choose first, or a bedroom, which merely wants to be far from the
	# front, would take the back room the kitchen needs. What nothing claimed
	# is the store.
	for i in rest:
		p.rooms[i]["kind"] = &"store"
	var ordered: Array[StringName] = []
	for kind in queue:
		if float(KIND_POLES.get(kind, {"service": 0.0})["service"]) >= 0.9:
			ordered.append(kind)
	for kind2 in queue:
		if not kind2 in ordered:
			ordered.append(kind2)
	for kind in ordered:
		var best := -1
		var best_score := -INF
		for i in rest:
			if p.kind_of(i) != &"store" or not HouseGeometry.room_suits(p, i, kind):
				continue
			var score: float = _pole_score(p, spec, i, kind)
			if score > best_score + 0.0001:
				best_score = score
				best = i
		if best >= 0:
			p.rooms[best]["kind"] = kind

	# bedrooms belong at the back: swap the front-most bedroom with the
	# back-most non-bedroom whenever that improves the arrangement
	_push_bedrooms_back(p, order)
	_demote_windowless(p, spec)


## A room with no outside wall can never have a window, so it cannot be a room
## anybody lives in. It becomes the store, and the store's kind goes to a room
## that does have a wall to the world.
static func _demote_windowless(p: HousePlan, spec: HouseSpec) -> void:
	for i in range(p.rooms.size()):
		if not HouseGeometry.is_habitable(p.kind_of(i)) or _has_outside_wall(p, spec, i):
			continue
		var swap := -1
		for j in range(p.rooms.size()):
			if p.kind_of(j) == &"store" and _has_outside_wall(p, spec, j) \
					and HouseGeometry.room_suits(p, j, p.kind_of(i)):
				swap = j
				break
		if swap >= 0:
			var mine: StringName = p.kind_of(i)
			p.rooms[i]["kind"] = &"store"
			p.rooms[swap]["kind"] = mine
		else:
			p.rooms[i]["kind"] = &"store"


static func _has_outside_wall(p: HousePlan, spec: HouseSpec, i: int) -> bool:
	var inner: Rect2 = HouseGeometry.interior_rect(spec)
	var rect: Rect2 = p.rooms[i]["rect"]
	return absf(rect.position.x - inner.position.x) < 0.01 \
		or absf(rect.end.x - inner.end.x) < 0.01 \
		or absf(rect.position.y - inner.position.y) < 0.01 \
		or absf(rect.end.y - inner.end.y) < 0.01


static func _push_bedrooms_back(p: HousePlan, order: Array[int]) -> void:
	var swapped := true
	var guard := 0
	while swapped and guard < 12:
		swapped = false
		guard += 1
		for a in range(order.size()):
			for b in range(order.size() - 1, a, -1):
				var ra: int = order[a]
				var rb: int = order[b]
				# ra is nearer the door than rb; and a service room at the
				# back is there because the back is where it belongs (LAY-006)
				if p.kind_of(ra) == &"bedroom" and p.kind_of(rb) != &"bedroom" \
						and p.kind_of(rb) != &"hall" \
						and float(KIND_POLES.get(p.kind_of(rb), {"service": 0.0})["service"]) < 0.5:
					var ka: StringName = p.kind_of(ra)
					var kb: StringName = p.kind_of(rb)
					# only swap when both rooms can hold the other's kind
					if HouseGeometry.room_suits(p, ra, kb) \
							and HouseGeometry.room_suits(p, rb, ka):
						p.rooms[ra]["kind"] = kb
						p.rooms[rb]["kind"] = ka
						swapped = true
						break
			if swapped:
				break


static func all_rooms(p: HousePlan) -> Array[int]:
	var out: Array[int] = []
	for i in range(p.rooms.size()):
		out.append(i)
	return out


static func _largest(p: HousePlan) -> int:
	var best := 0
	var area := -1.0
	for i in range(p.rooms.size()):
		var a: float = HouseGeometry.room_area(p, i)
		if a > area:
			area = a
			best = i
	return best
