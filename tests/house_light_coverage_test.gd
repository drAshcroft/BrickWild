extends SceneTree
## Generated lighting regression. Checks the final furnished plan and real support.
const LONGHALL := {"style": &"longhall", "trade": &"smith", "width": 11.0,
	"length": 14.0, "height": 2.7, "storeys": 3, "seed": 32103}
const PUEBLO := {"style": &"pueblo", "trade": &"scholar", "width": 8.0,
	"length": 14.2, "height": 2.6, "storeys": 2, "seed": 60011}
const SAFE_BOTTOM := 2.1
const TOL := 0.03
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var failures: Array[String] = []
	_check_longhall(failures)
	_check_pueblo(failures)
	if failures.is_empty():
		print("PASS: generated lighting, measured support, headroom, thresholds and nav")
		quit(0)
		return
	for failure in failures: printerr(failure)
	quit(1)
func _generate(c: Dictionary) -> HousePlan:
	var spec := HouseSpec.new()
	spec.style = c.style
	spec.trade = c.trade
	spec.width = c.width
	spec.length = c.length
	spec.height = c.height
	spec.storeys = c.storeys
	return HouseGenerator.generate(spec, int(c.seed))
func _lights(plan: HousePlan, room: int) -> Array[int]:
	var out: Array[int] = []
	for i in plan.furniture_of(room):
		if PropCatalog.has_tag(String(plan.furniture[i]["key"]), PropCatalog.LIGHT): out.append(i)
	return out
func _check_longhall(failures: Array[String]) -> void:
	var plan := _generate(LONGHALL)
	var checked := 0
	for room in range(plan.room_count()):
		if not HouseGeometry.is_habitable(plan.kind_of(room)): continue
		var area := HouseGeometry.room_area(plan, room)
		if area < HouseFurnisher.REQUIRED_LIGHT_ROOM_AREA: continue
		checked += 1
		var lamps := _lights(plan, room)
		var required := int(ceil(area / HouseFurnisher.REQUIRED_LIGHT_AREA))
		if lamps.size() < required:
			failures.append("longhall32103 room%d has %d lights; needs %d" % [room, lamps.size(), required])
		_check_placements(plan, room, _lights(plan, room), failures, "longhall32103")
	if checked == 0: failures.append("longhall32103 did not exercise a qualifying room")
	_check_nav(plan, failures, "longhall32103")
func _check_pueblo(failures: Array[String]) -> void:
	var plan := _generate(PUEBLO)
	if not plan.rooms_of(&"hall").has(1):
		failures.append("Pueblo seed 60011 does not generate hall 1")
		return
	var room := 1
	var area := HouseGeometry.room_area(plan, room)
	if area >= HouseFurnisher.REQUIRED_LIGHT_ROOM_AREA:
		failures.append("Pueblo seed 60011 hall 1 is not the small-room control (%.1fm2)" % area)
	var sconces: Array[int] = []
	for index in plan.furniture_of(room):
		if PropCatalog.category(String(plan.furniture[index]["key"])) == "sconce": sconces.append(index)
	if sconces.size() != 1:
		failures.append("Pueblo seed 60011 scholar hall 1 has %d sconces; expected one" % sconces.size())
	var lamps := _lights(plan, room)
	if lamps.is_empty():
		failures.append("Pueblo seed 60011 hall 1 has no light source")
	_check_placements(plan, room, lamps, failures, "Pueblo60011")
	_check_nav(plan, failures, "Pueblo60011")
	# A small hall already has useful lighting. Reapplying the fallback must
	# preserve every existing light placement and must not add another source.
	var before: Array[Dictionary] = []
	for index in lamps: before.append(plan.furniture[index].duplicate(true))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(PUEBLO.seed)
	HouseFurnisher._ensure_light(plan, room, rng)
	var after_indices := _lights(plan, room)
	var after: Array[Dictionary] = []
	for index in after_indices: after.append(plan.furniture[index].duplicate(true))
	if after.size() != before.size() or after != before:
		failures.append("Pueblo seed 60011 small-room fallback changed existing light placements")
	if HouseFurnisher.REQUIRED_LIGHT_ROOM_AREA != HouseFurnishWalkCheck.LAMP_ROOM \
			or HouseFurnisher.REQUIRED_LIGHT_AREA != HouseFurnishWalkCheck.LAMP_AREA:
		failures.append("furnisher and walk-check lighting thresholds drifted")

func _check_placements(plan: HousePlan, room: int, lamps: Array[int],
		failures: Array[String], who: String) -> void:
	var base := HouseFurnishGeometry.storey_base(plan, room)
	for i in lamps:
		var p: Dictionary = plan.furniture[i]
		var key := String(p["key"])
		var scale := PropCatalog.placement_height_scale(p)
		var local_y := float(p["pos"].y) - base
		var origin := PropCatalog.house_origin(p)
		var measured_top := origin.y + (PropCatalog.floor_offset(key) + PropCatalog.height(key)) * scale
		var top_limit := _ceiling_y(plan, room)
		if measured_top > top_limit + TOL:
			failures.append("%s %s exceeds measured ceiling headroom" % [who, key])
		if HouseFurnishSurface._blocks_domestic_threshold(plan, room, key,
				Vector2(p["pos"].x, p["pos"].z), float(p["yaw"]), local_y, scale):
			failures.append("%s %s overlaps door/stair threshold clearance" % [who, key])
		if PropCatalog.category(key) == "chandelier":
			var bottom := origin.y + PropCatalog.floor_offset(key) * scale
			var top := origin.y + (PropCatalog.floor_offset(key) + PropCatalog.height(key)) * scale
			if bottom - base + TOL < HouseGeometry.FLOOR_T + SAFE_BOTTOM:
				failures.append("%s chandelier bottom %.2fm is below room-relative standing clearance" % [who, bottom - base])
			if absf(top - _ceiling_y(plan, room)) > TOL:
				failures.append("%s chandelier measured top misses underside of slab" % who)
			var model_yaw := float(p["yaw"]) + PropCatalog.face_offset(key)
			var centre := PropCatalog.plan_centre(key, origin, model_yaw, scale)
			var footprint := PropCatalog.footprint_rotated(key, model_yaw) * scale
			var body := Rect2(centre - footprint * 0.5, footprint)
			if not HouseGeometry.room_floor_rect(plan, room).encloses(body):
				failures.append("%s chandelier's measured body extends beyond its room" % who)
		elif int(p.get("host", -1)) >= 0:
			var host := int(p["host"])
			if host >= plan.furniture.size():
				failures.append("%s %s points to missing host" % [who, key])
				continue
			var support: Dictionary = plan.furniture[host]
			if not PropCatalog.has_tag(String(support["key"]), PropCatalog.SURFACE):
				failures.append("%s %s host has no measured surface" % [who, key])
				continue
			var support_y := float(support["pos"].y) + PropCatalog.surface_height(String(support["key"])) * PropCatalog.placement_height_scale(support)
			if absf(float(p["pos"].y) - support_y) > TOL:
				failures.append("%s %s does not rest on host's measured top" % [who, key])
			if not Rect2(support["rect"]).encloses(Rect2(p["rect"])):
				failures.append("%s %s footprint exceeds its supporting surface" % [who, key])
		elif bool(p.get("mounted", false)):
			var model_yaw := float(p["yaw"]) + PropCatalog.face_offset(key)
			var centre := PropCatalog.plan_centre(key, origin, model_yaw, scale)
			var footprint := PropCatalog.footprint_rotated(key, model_yaw) * scale
			var body := Rect2(centre - footprint * 0.5, footprint)
			if not HouseGeometry.room_floor_rect(plan, room).encloses(body):
				failures.append("%s %s measured body extends outside its room" % [who, key])
			var supported_by_wall := false
			for wall in HouseGeometry.room_walls(plan, room):
				var a: Vector2 = wall["from"]
				var segment: Vector2 = wall["to"] - a
				var t := clampf((Vector2(p["pos"].x, p["pos"].z) - a).dot(segment) / maxf(segment.length_squared(), 0.0001), 0.0, 1.0)
				if Vector2(p["pos"].x, p["pos"].z).distance_to(a + segment * t) <= 0.08:
					supported_by_wall = true
					break
			if not supported_by_wall:
				failures.append("%s %s is not mounted to a measured room wall" % [who, key])
		else:
			failures.append("%s %s has no measured support" % [who, key])
func _ceiling_y(plan: HousePlan, room: int) -> float:
	var highest_storey := 0
	for candidate_room in range(plan.room_count()):
		highest_storey = maxi(highest_storey, plan.storey_of_room(candidate_room))
	var y := HouseFurnishGeometry.storey_base(plan, room) + plan.spec.height
	if plan.storey_of_room(room) < highest_storey: y -= HouseBuilder.SLAB_TUCK
	return y
func _check_nav(plan: HousePlan, failures: Array[String], who: String) -> void:
	var report: Dictionary = HouseNavCheck.new().check(plan)
	if not report.get("unreached_rooms", []).is_empty():
		failures.append("%s final nav check has unreached rooms %s" % [who, str(report["unreached_rooms"])])
