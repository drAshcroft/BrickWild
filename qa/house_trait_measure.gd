class_name HouseTraitMeasure
extends RefCounted
## HS-* style traits, measured from the plan, mass_log and component_log (not
## from a picture). One call builds one house and returns plain numbers; each
## style's focused test states its own thresholds over them. Later HS-* tasks
## extend `measure()` with the keys they need rather than writing a second
## builder harness.
##
## Keys: storeys, eave_top (wall top above the floor, m), ridge_top (highest
## main-roof vertex), chimney_count, chimney_top, chimney_on_hearth_wall,
## chimney_clearance (m over the ridge), chimney_above_ridge, door_sheltered (a porch roof, posts and step all stand
## over the entrance door), porch_roof_count.
## HS-LONGHALL keys are listed on `_longhall_keys`, HS-MEDITERRANEAN on `_med_keys`,
## HS-THATCH on `_thatch_keys`.


static func make_spec(style: StringName, width: float, length: float, height: float,
		storeys := 1) -> HouseSpec:
	var spec := HouseSpec.new()
	spec.style = style
	spec.width = width
	spec.length = length
	spec.height = height
	spec.storeys = storeys
	return spec


## `tweak` (optional) runs on the generated plan before building: a negative
## control removes one trait there and the measure must notice.
static func measure(spec: HouseSpec, p_seed: int, tweak := Callable(),
		furnished := false) -> Dictionary:
	var plan := HouseGenerator.generate(spec, p_seed, furnished)
	if tweak.is_valid():
		tweak.call(plan)
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	var out := {"storeys": plan.spec.storeys}
	out["eave_top"] = plan.spec.height * float(maxi(plan.spec.storeys, 1))
	out["ridge_top"] = _ridge_top(mesh, plan)
	var stacks: Array = []
	for m in builder.mass_log:
		if str(m.get("name", "")) == "chimney":
			stacks.append(m["aabb"])
	out["chimney_count"] = stacks.size()
	out["chimney_top"] = -INF
	out["chimney_on_hearth_wall"] = false
	if stacks.size() > 0:
		var a: AABB = stacks[0]
		out["chimney_top"] = a.position.y + a.size.y
		out["chimney_on_hearth_wall"] = _on_hearth_wall(plan, a)
	out["chimney_clearance"] = out["chimney_top"] - out["ridge_top"]
	out["chimney_above_ridge"] = out["chimney_top"] > out["ridge_top"] + 0.05
	var roofs := 0
	for part in builder.component_log:
		if str(part.get("role", "")) == "porch_roof":
			roofs += 1
	out["porch_roof_count"] = roofs
	out["door_sheltered"] = _door_sheltered(plan, builder, roofs)
	_farm_keys(plan, builder, out)
	_town_keys(plan, out)
	_longhall_keys(plan, builder, out)
	_rich_keys(plan, builder, out)
	_med_keys(plan, builder, out)
	_thatch_keys(plan, builder, out)
	return out


## HS-TOWNHOUSE keys: `frontage` and `depth` (the entrance facade's length and
## the house's depth behind it, m), `frontage_narrower`, `room_storeys`,
## `ground_bedrooms`, `ground_work` (a work room on the ground floor: office,
## workshop or shop), `upper_bedrooms`, and the stair spine walked from the
## entrance room: `spine_storeys` (storeys reached by satisfied stairs),
## `spine_landings` (storeys whose foot or head landing is a real rectangle) and
## `spine_lit` (storeys whose landing room has a window).
static func _town_keys(plan: HousePlan, out: Dictionary) -> void:
	var r := HouseGeometry.site_rect(plan.spec)
	var e := plan.entrance()
	var along_x := true
	if e >= 0:
		along_x = absf(Vector2(plan.doors[e]["normal"]).y) > 0.5
	out["frontage"] = r.size.x if along_x else r.size.y
	out["depth"] = r.size.y if along_x else r.size.x
	out["frontage_narrower"] = out["frontage"] < out["depth"]
	var top := 0
	var ground_bed := 0
	var upper_bed := 0
	var work := false
	for i in range(plan.rooms.size()):
		var st := plan.storey_of_room(i)
		top = maxi(top, st)
		var kind := plan.kind_of(i)
		if st == 0 and kind in [&"office", &"workshop", &"shop"]:
			work = true
		if kind in [&"bedroom", &"guest_room", &"suite"]:
			if st == 0:
				ground_bed += 1
			elif st > 0:
				upper_bed += 1
	out["room_storeys"] = top + 1
	out["ground_bedrooms"] = ground_bed
	out["upper_bedrooms"] = upper_bed
	out["ground_work"] = work
	var here := plan.entrance_room()
	var reached := 1 if here >= 0 else 0
	var landings := 0
	var lit := 0
	var spent := {}
	if here >= 0 and not plan.windows_of(here).is_empty():
		lit += 1
	var guard := 0
	while here >= 0 and guard < 6:
		guard += 1
		var next := -1
		for k in range(plan.stairs.size()):
			var s: Dictionary = plan.stairs[k]
			if spent.has(k) or int(s["a"]) != here or int(s["to_storey"]) != int(s["storey"]) + 1:
				continue
			if not bool(s.get("satisfied", true)):
				continue
			spent[k] = true
			next = int(s["b"])
			if Rect2(s.get("foot_landing", Rect2())).has_area() 					and Rect2(s.get("head_landing", Rect2())).has_area():
				landings += 1
			break
		if next < 0:
			break
		reached += 1
		if not plan.windows_of(next).is_empty():
			lit += 1
		here = next
	out["spine_storeys"] = reached
	out["spine_landings"] = landings
	out["spine_lit"] = lit


## HS-RICH keys (a furnished plan is needed for the seats):
##   door_room_kind      kind of the room the front door opens into
##   hall_holds_stair    that room is a hall AND the ground-to-first stair starts in it
##                       (satisfied, foot landing and well inside the hall's floor)
##   parlour_rooms / dining_rooms   ground rooms of kind parlour / dining_room
##   parlour_seating     seat + bench pieces in the first ground parlour ; parlour_settles
##                       (Bench) and parlour_chairs (Chair_1): a group is a settle with 2 chairs
##   dining_stools       Stool pieces at the table (chairs are counted by key, not category)
##   dining_tables / dining_chairs  table and seat pieces in the first ground dining room
##   rooms_distinct      hall, parlour and dining room are three different rooms
##   dining_table_elsewhere   a table stands in the hall or parlour as well
##   trim_count          cornice_* and string_course components
##   trim_worst          the largest distance (m) from any of them to the nearest
##                       floor line or the eave (see `trim_off_level`)
##   cornice_top_gap     m between the highest cornice part's top and the eave
static func _rich_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	var door_room := plan.entrance_room()
	out["door_room_kind"] = plan.kind_of(door_room) if door_room >= 0 else &""
	var holds := false
	if door_room >= 0 and plan.kind_of(door_room) == &"hall":
		var hall_rect := HouseGeometry.room_floor_rect(plan, door_room)
		for s in plan.stairs:
			if int(s["a"]) != door_room or int(s["storey"]) != 0 or not bool(s.get("satisfied", true)):
				continue
			var foot := Rect2(s.get("foot_landing", Rect2()))
			if foot.has_area() and hall_rect.has_point(foot.get_center()):
				holds = true
	out["hall_holds_stair"] = holds
	var parlours: Array[int] = []
	var dinings: Array[int] = []
	for i in plan.rooms_on_storey(0):
		if plan.kind_of(i) == &"parlour":
			parlours.append(i)
		elif plan.kind_of(i) == &"dining_room":
			dinings.append(i)
	out["parlour_rooms"] = parlours.size()
	out["dining_rooms"] = dinings.size()
	out["parlour_seating"] = _count_cats(plan, parlours[0], ["seat", "bench"]) if not parlours.is_empty() else 0
	out["parlour_settles"] = _count_keys(plan, parlours[0], ["Bench"]) if not parlours.is_empty() else 0
	out["parlour_chairs"] = _count_keys(plan, parlours[0], ["Chair_1"]) if not parlours.is_empty() else 0
	out["dining_tables"] = _count_cats(plan, dinings[0], ["table"]) if not dinings.is_empty() else 0
	out["dining_chairs"] = _count_keys(plan, dinings[0], ["Chair_1"]) if not dinings.is_empty() else 0
	out["dining_stools"] = _count_keys(plan, dinings[0], ["Stool"]) if not dinings.is_empty() else 0
	out["rooms_distinct"] = door_room >= 0 and not parlours.is_empty() and not dinings.is_empty() 		and door_room != parlours[0] and door_room != dinings[0] and parlours[0] != dinings[0]
	var elsewhere := 0
	if door_room >= 0:
		elsewhere += _count_cats(plan, door_room, ["table"])
	if not parlours.is_empty():
		elsewhere += _count_cats(plan, parlours[0], ["table"])
	out["dining_table_elsewhere"] = elsewhere > 0
	out["component_log"] = builder.component_log
	out["storey_height"] = plan.spec.height
	var trim := trim_off_level(builder.component_log, plan.spec.height, plan.spec.storeys)
	out["trim_count"] = trim["count"]
	out["trim_worst"] = trim["worst"]
	out["cornice_top_gap"] = trim["cornice_top_gap"]


static func _count_keys(plan: HousePlan, room: int, keys: Array) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		if str(plan.furniture[f].get("key", "")) in keys:
			n += 1
	return n


static func _count_cats(plan: HousePlan, room: int, cats: Array) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		if str(plan.furniture[f].get("cat", "")) in cats:
			n += 1
	return n


## How far the ornament strays from the floor lines. A cornice or string-course
## part is a box; its distance to a level is zero when the level lies inside its
## height and the gap to its nearer face otherwise. The levels are the floors
## (0, h, 2h ...) and the eave (storeys * h). Returns {count, worst,
## cornice_top_gap} (the last: eave minus the highest cornice top, -INF when none).
static func trim_off_level(log: Array, height: float, storeys: int) -> Dictionary:
	var count := 0
	var worst := 0.0
	var top := -INF
	for c in log:
		var role := str(c.get("role", ""))
		if not (role.begins_with("cornice") or role == "string_course"):
			continue
		var xf: Transform3D = c["xf"]
		var size: Vector3 = c["size"]
		var lo := xf.origin.y - size.y * 0.5
		var hi := xf.origin.y + size.y * 0.5
		var nearest := INF
		for k in range(storeys + 1):
			var level := height * float(k)
			nearest = minf(nearest, 0.0 if lo <= level and level <= hi else minf(absf(lo - level), absf(hi - level)))
		worst = maxf(worst, nearest)
		count += 1
		if role.begins_with("cornice"):
			top = maxf(top, hi)
	return {"count": count, "worst": worst,
		"cornice_top_gap": height * float(storeys) - top if top > -INF else INF}


## HS-LONGHALL keys (a furnished plan is needed for the benches):
##   long_ratio          outer footprint, long side over short side
##   hall_fraction       the hall's share of the interior floor
##   hall_full_depth     the hall spans the whole interior depth ; hall_length (m)
##   main_roofs          masses named "roof" (one storey under ONE main roof: 1)
##   rooms_off_ends      rooms (not the hall) that overlap the hall's length
##   end_sides           how many of the two ends carry a private room (0..2)
##   private_kinds       kinds of the rooms at the ends
##   hearth_gap          least distance (m) from the fire's kerb to a hall wall
##   hearth_mid_offset   fire's offset from the hall's middle, share of its length
##   hearth_kerb_count   kerb stones emitted (4) ; hearth_wall_fire: a wall hearth exists
##   smoke_over_hearth   the roof opening's centre stands over the fire (<= 0.3 m)
##   smoke_hole          a roof opening called longhall_smoke_hole was cut
##   louvre_over_ridge   m the louvre's highest part stands over the ridge
##   ceiling_over_hall   a ceiling slab covers part of the hall floor
##   ceiling_over_ends   share of the end rooms' floor under a ceiling slab
##   truss_count         principal trusses (collars) in view ; rafter_count ; has_ridge_beam
##   bench_walls         how many long walls carry a bench (0..2)
##   bench_front_len / bench_back_len   metres of bench on each long wall
static func _longhall_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	var r := HouseGeometry.site_rect(plan.spec)
	out["long_ratio"] = maxf(r.size.x, r.size.y) / minf(r.size.x, r.size.y)
	var hall_rooms := plan.rooms_of(&"hall")
	var hall_rect := Rect2()
	if not hall_rooms.is_empty():
		hall_rect = HouseGeometry.room_floor_rect(plan, hall_rooms[0])
	var inner := HouseGeometry.interior_rect(plan.spec)
	out["hall_fraction"] = hall_rect.get_area() / maxf(inner.get_area(), 0.01)
	out["hall_full_depth"] = absf(hall_rect.size.y - inner.size.y) < 0.05
	out["hall_length"] = hall_rect.size.x
	var main_roofs := 0
	for m in builder.mass_log:
		if str(m.get("name", "")) == "roof":
			main_roofs += 1
	out["main_roofs"] = main_roofs
	var off := 0
	var west := false
	var east := false
	var kinds: Array = []
	for i in range(plan.rooms.size()):
		if not hall_rooms.is_empty() and i == hall_rooms[0]:
			continue
		var rr: Rect2 = plan.rooms[i]["rect"]
		if rr.end.x <= hall_rect.position.x + 0.2:
			west = true
		elif rr.position.x >= hall_rect.end.x - 0.2:
			east = true
		else:
			off += 1
		kinds.append(str(plan.kind_of(i)))
	out["rooms_off_ends"] = off
	out["end_sides"] = int(west) + int(east)
	out["private_kinds"] = kinds
	# the fire
	var kerb_rect: Rect2 = plan.longhall.get("hearth", Rect2())
	out["hearth_gap"] = -INF
	out["hearth_mid_offset"] = INF
	if kerb_rect.has_area() and hall_rect.has_area():
		out["hearth_gap"] = minf(minf(kerb_rect.position.x - hall_rect.position.x,
			hall_rect.end.x - kerb_rect.end.x), minf(kerb_rect.position.y - hall_rect.position.y,
			hall_rect.end.y - kerb_rect.end.y))
		out["hearth_mid_offset"] = absf(kerb_rect.get_center().x - hall_rect.get_center().x) 			/ hall_rect.size.x
	var kerbs := 0
	var truss := 0
	var rafters := 0
	var ridge_beam := false
	var ceilings: Array[Rect2] = []
	var louvre_top := -INF
	for part in builder.component_log:
		var role := str(part.get("role", ""))
		match role:
			"hearth_kerb": kerbs += 1
			"hall_truss_collar": truss += 1
			"hall_rafter": rafters += 1
			"hall_ridge_beam": ridge_beam = true
			"ceiling":
				var xf: Transform3D = part["xf"]
				var a := HouseYard.part_aabb({"basis": xf.basis, "centre": xf.origin, "size": part["size"]})
				ceilings.append(Rect2(a.position.x, a.position.z, a.size.x, a.size.z))
			"louvre_hood", "louvre_post", "louvre_end":
				var xf2: Transform3D = part["xf"]
				var a2 := HouseYard.part_aabb({"basis": xf2.basis, "centre": xf2.origin, "size": part["size"]})
				louvre_top = maxf(louvre_top, a2.position.y + a2.size.y)
	out["hearth_kerb_count"] = kerbs
	out["hearth_wall_fire"] = plan.hearth_room() >= 0
	out["truss_count"] = truss
	out["rafter_count"] = rafters
	out["has_ridge_beam"] = ridge_beam
	var over_hall := false
	for c in ceilings:
		over_hall = over_hall or c.grow(-0.05).intersects(hall_rect)
	out["ceiling_over_hall"] = over_hall
	var covered := 0.0
	var ends_area := 0.0
	for i in range(plan.rooms.size()):
		if not hall_rooms.is_empty() and i == hall_rooms[0]:
			continue
		var fr := HouseGeometry.room_floor_rect(plan, i)
		ends_area += fr.get_area()
		for c in ceilings:
			covered += c.intersection(fr).get_area()
	out["ceiling_over_ends"] = covered / maxf(ends_area, 0.01)
	out["smoke_hole"] = false
	out["smoke_over_hearth"] = false
	for op in builder.roof_opening_log:
		if str(op["id"]) == "longhall_smoke_hole":
			out["smoke_hole"] = true
			var ctr: Vector3 = op["center"]
			out["smoke_over_hearth"] = kerb_rect.has_area() 				and Vector2(ctr.x, ctr.z).distance_to(kerb_rect.get_center()) <= 0.3
	out["louvre_over_ridge"] = louvre_top - (plan.spec.height * float(maxi(plan.spec.storeys, 1))
		+ HouseGeometry.roof_rise(plan.spec)) if louvre_top > -INF else -INF
	# the benches
	var front_len := 0.0
	var back_len := 0.0
	for f in plan.furniture:
		if str(f.get("key", "")) != "Bench" or hall_rooms.is_empty() or int(f.get("room", -1)) != hall_rooms[0]:
			continue
		var br: Rect2 = f["rect"]
		if absf(br.position.y - hall_rect.position.y) < 0.12:
			front_len += br.size.x
		elif absf(br.end.y - hall_rect.end.y) < 0.12:
			back_len += br.size.x
	out["bench_front_len"] = front_len
	out["bench_back_len"] = back_len
	out["bench_walls"] = int(front_len > 0.0) + int(back_len > 0.0)


## HS-FARMHOUSE keys: the yard door, the byre, and the working props.
static func _farm_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	var e := plan.entrance()
	out["back_door_room"] = ""
	out["back_door_off_front"] = false
	for i in range(plan.doors.size()):
		var d: Dictionary = plan.doors[i]
		if i == e or not d.get("exterior", false) or bool(d.get("secret", false)):
			continue
		var kind := String(plan.rooms[int(d["a"])].get("kind", ""))
		if kind in ["kitchen", "store"]:
			out["back_door_room"] = kind
			var front_n := Vector2(plan.doors[e]["normal"]).normalized() if e >= 0 else Vector2.ZERO
			out["back_door_off_front"] = Vector2(d["normal"]).normalized().dot(front_n) < 0.5
			break
	var roofs := 0
	var top := -INF
	for part in builder.component_log:
		if str(part.get("role", "")) == "byre_roof":
			roofs += 1
			var xf: Transform3D = part["xf"]
			var a := HouseYard.part_aabb({"basis": xf.basis, "centre": xf.origin, "size": part["size"]})
			top = maxf(top, a.position.y + a.size.y)
	out["byre_roof_count"] = roofs
	out["byre_roof_top"] = top
	var r := HouseGeometry.site_rect(plan.spec).grow(0.3)
	var attached := false
	var kinds := {}
	for piece in plan.yard_pieces:
		match str(piece["kind"]):
			"byre":
				attached = attached or r.intersects(piece["rect"])
				for part in piece["parts"]:
					if str(part["role"]) == "hay_bale":
						kinds["hay"] = true
			"trough":
				kinds["trough"] = true
			"cart":
				kinds["cart"] = true
			"fence":
				kinds["fence"] = true
	for prop in plan.yard:
		if str(prop.get("role", "")) == "cart":
			kinds["cart"] = true
		if str(prop.get("key", "")) in ["Bag", "Sack"]:
			kinds["sacks"] = true
	for prop in plan.exterior:
		if str(prop.get("key", "")) in ["Bag", "Sack"]:
			kinds["sacks"] = true
	out["byre_attached"] = attached
	out["byre_lower_than_eave"] = roofs > 0 and top < float(out["eave_top"]) - 0.05
	var list: Array = kinds.keys()
	list.sort()
	out["yard_kinds"] = list


## HS-MEDITERRANEAN keys:
##   wall_kind          "white" | "ochre" | "other" (the lime wash, from the wall colour)
##   wall_rendered      masonry under render: no timber frame, no stone ground floor, white or ochre
##   wall_thick         the wall (m); reveal_min the shallowest jamb (window and door) cut through it
##   roof_angle_deg     steepest roof-face edge (from the roof_face_* slabs); roof_tile, roof_terracotta
##   parapet_count      parapet components on the eave; terrace_roof: nearly flat and parapeted
##   low_tile_roof      tile, terracotta, 25 degrees or less
##   loggia_posts / loggia_roofs / loggia_beams   veranda_post / veranda_roof_* / veranda_beam
##   loggia_covers_door the entrance door stands inside the veranda's footprint
##   loggia_depth       how far it reaches out of the wall (m)
##   court_present      a yard piece of kind "court"; court_expected (the footprint allows one)
##   court_inner_area   the paved ground inside the walls (m2); court_wall_parts
##   court_open         no roof, ceiling or part above COURT_WALL_H: open to the sky
##   court_gate         the widest gap in a side return (m); court_rear_wall: a rear wall exists
##   court_door         an exterior door that is not the entrance opens onto the court
##   court_min_side     the footprint threshold (HouseYard.COURT_MIN_SIDE), recorded here
static func _med_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	var spec := plan.spec
	var c := spec.wall_color
	var kind := "other"
	if c.v >= 0.85 and c.s <= 0.12:
		kind = "white"
	elif c.v >= 0.75 and c.s >= 0.12 and c.s <= 0.5 and c.h >= 0.07 and c.h <= 0.14:
		kind = "ochre"
	out["wall_kind"] = kind
	out["wall_rendered"] = not spec.timber_frame and not spec.stone_ground_floor and kind != "other"
	out["wall_thick"] = HouseGeometry.wall_thickness(spec)
	# the openings in the OUTER wall: every window, and the exterior doors (an
	# interior door is cut through a 0.2 m partition and is not a reveal)
	var reveal := INF
	for part in builder.component_log:
		if str(part.get("role", "")) != "opening_jamb":
			continue
		var host := str(part.get("host", ""))
		if host.begins_with("door_"):
			var di := int(host.substr(5))
			if di < 0 or di >= plan.doors.size() or not bool(plan.doors[di].get("exterior", false)):
				continue
		var sz: Vector3 = part["size"]
		reveal = minf(reveal, maxf(sz.x, sz.z))
	out["reveal_min"] = reveal
	# roof pitch, from the faces themselves
	var angle := 0.0
	for part in builder.component_log:
		if not str(part.get("role", "")).begins_with("roof_face_"):
			continue
		# the plane's own fall: the angle of its normal from the vertical (an
		# edge of a hip face is shallower than the face, so edges would undercount)
		var pts: Array = part["points"]
		var nrm := Vector3.ZERO
		for i in range(1, pts.size() - 1):
			nrm = (Vector3(pts[i]) - Vector3(pts[0])).cross(Vector3(pts[i + 1]) - Vector3(pts[0]))
			if nrm.length() > 0.01:
				break
		if nrm.length() > 0.01:
			angle = maxf(angle, rad_to_deg(acos(clampf(absf(nrm.normalized().y), 0.0, 1.0))))
	out["roof_angle_deg"] = angle
	out["roof_tile"] = spec.roof_material == &"tile"
	var rc := spec.roof_color
	out["roof_terracotta"] = rc.h >= 0.02 and rc.h <= 0.09 and rc.s >= 0.4 and rc.r > rc.g and rc.g > rc.b
	var parapets := 0
	var posts := 0
	var roofs := 0
	var beams := 0
	for part in builder.component_log:
		var role := str(part.get("role", ""))
		if role == "parapet":
			parapets += 1
		elif role == "veranda_post":
			posts += 1
		elif role.begins_with("veranda_roof_"):
			roofs += 1
		elif role == "veranda_beam":
			beams += 1
	out["parapet_count"] = parapets
	out["terrace_roof"] = parapets >= 4 and angle <= 8.0
	out["low_tile_roof"] = out["roof_tile"] and out["roof_terracotta"] and angle <= 25.0
	out["loggia_posts"] = posts
	out["loggia_roofs"] = roofs
	out["loggia_beams"] = beams
	var vr := HouseGeometry.veranda_rect(plan)
	var e := plan.entrance()
	out["loggia_covers_door"] = vr.has_area() and e >= 0 and vr.grow(0.02).has_point(Vector2(plan.doors[e]["pos"]) 		+ Vector2(plan.doors[e]["normal"]) * 0.3)
	out["loggia_depth"] = spec.veranda_depth if spec.veranda else 0.0
	# the court
	var site := HouseGeometry.site_rect(spec)
	out["court_min_side"] = HouseYard.COURT_MIN_SIDE
	out["court_expected"] = minf(site.size.x, site.size.y) >= HouseYard.COURT_MIN_SIDE
	out["court_present"] = false
	out["court_inner_area"] = 0.0
	out["court_wall_parts"] = 0
	out["court_open"] = false
	out["court_gate"] = 0.0
	out["court_rear_wall"] = false
	out["court_door"] = false
	if e < 0:
		return
	var n := Vector2(plan.doors[e]["normal"]).normalized()
	var depth_x := absf(n.x) > absf(n.y)
	for piece in plan.yard_pieces:
		if str(piece["kind"]) != "court":
			continue
		out["court_present"] = true
		var pave := Rect2()
		var walls := 0
		var open := true
		var returns := {-1: 0.0, 1: 0.0}
		for part in piece["parts"]:
			var sz: Vector3 = part["size"]
			var ctr: Vector3 = part["centre"]
			var dd := sz.x if depth_x else sz.z
			var dl := sz.z if depth_x else sz.x
			var lat := ctr.z if depth_x else ctr.x
			var role := str(part["role"])
			if role == "court_paving":
				pave = Rect2(Vector2(ctr.x - sz.x * 0.5, ctr.z - sz.z * 0.5), Vector2(sz.x, sz.z))
				out["court_inner_area"] = sz.x * sz.z
			elif role == "court_wall":
				walls += 1
				if ctr.y + sz.y * 0.5 > HouseYard.COURT_WALL_H + 0.01:
					open = false
				if dl > dd:
					out["court_rear_wall"] = true
				else:
					returns[1 if lat > 0.0 else -1] += dd
			else:
				open = false
			if str(part["surf"]) == "roof":
				open = false
		out["court_wall_parts"] = walls
		out["court_open"] = open and pave.has_area()
		var run: float = (pave.size.x if depth_x else pave.size.y)
		out["court_gate"] = maxf(run - returns[-1], run - returns[1])
		# a door that is not the entrance opens onto the court
		var pr: Rect2 = piece["rect"]
		for i in range(plan.doors.size()):
			var d: Dictionary = plan.doors[i]
			if i == e or not d.get("exterior", false) or bool(d.get("secret", false)):
				continue
			var dn := Vector2(d["normal"]).normalized()
			if dn.dot(n) < -0.5 and pr.grow(0.1).has_point(Vector2(d["pos"]) + dn * 0.8):
				out["court_door"] = true


## HS-THATCH keys (all from the plan and the logs):
##   wall_pale / wall_rendered   a pale wall, no timber frame, no stone ground floor
##   frame_parts                 exposed frame components: timber, gable_tie, gable_member,
##                               interior_frame_*, jetty* (a list of roles; empty is cob)
##   eave_count / eave_form      thatch_eave rows and their form ("slab" soft, "box" hard)
##   eave_points / eave_thick    profile points; the bundle's thickness (m) across the roof
##   eave_turn_max               the sharpest turn (deg) of the eave outline
##   roll_count / roll_points / roll_turn_max / roll_cover   ridge roll bundles, their
##                               profile points, sharpest exposed turn, and the share of the
##                               ridge length they span; roll_height above the ridge midplane
##   eyebrow_count / eyebrow_glazing / eyebrow_width / eyebrow_rise / eyebrow_seated /
##   eyebrow_below_ridge / eyebrow_faces_entrance / eyebrow_clear_of_chimney
##   path_pavers / path_reaches_door
##   flower_beds / flower_bed_sides / bed_flowers   front beds, the sides of the path they
##                               stand on (-1, +1), flower props standing on beds
##   front_roles                 the role of every prop and piece at the front but the
##                               path and the flower beds (empty means no work yard)
static func _thatch_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	var spec := plan.spec
	var c := spec.wall_color
	out["wall_pale"] = c.v >= 0.82 and c.s <= 0.22
	out["wall_rendered"] = out["wall_pale"] and not spec.timber_frame and not spec.stone_ground_floor
	var frame: Array[String] = []
	for part in builder.component_log:
		var role := str(part.get("role", ""))
		if role == "timber" or role == "gable_tie" or role == "gable_member" \
				or role.begins_with("interior_frame") or role.begins_with("jetty"):
			if role not in frame:
				frame.append(role)
	out["frame_parts"] = frame
	var layout := HouseGeometry.roof_layout(plan)
	var xf: Transform3D = layout["transform"]
	var inv := xf.affine_inverse()
	var faces: Array[PackedVector3Array] = layout["faces"]
	var half_span: float = float(layout["span"]) * 0.5
	# the eave bundles
	var eaves: Array = []
	for part in builder.component_log:
		if str(part.get("role", "")) == "thatch_eave":
			eaves.append(part)
	out["eave_count"] = eaves.size()
	out["eave_form"] = "none" if eaves.is_empty() else str(eaves[0]["form"])
	var epts := 0
	var thick := INF
	var eturn := 0.0
	for row in eaves:
		if str(row["form"]) != "slab":
			var sz: Vector3 = row["size"]
			thick = minf(thick, minf(sz.x, sz.y))
			eturn = maxf(eturn, 90.0)
			epts = 4
			continue
		var loc := _local_profile(row["points"], inv)
		epts = loc.size() if epts == 0 else mini(epts, loc.size())
		var side := signf(_centroid(loc).x)
		var y0 := RoofShape.height_at(faces, Vector2(side * half_span, 0.0))
		var y1 := RoofShape.height_at(faces, Vector2(side * half_span - side * 0.1, 0.0))
		var up := Vector2(-side * 0.1, y1 - y0).normalized()
		var nrm := Vector2(up.y, -up.x)
		var lo := INF
		var hi := -INF
		for p in loc:
			lo = minf(lo, Vector2(p.x, p.y).dot(nrm))
			hi = maxf(hi, Vector2(p.x, p.y).dot(nrm))
		thick = minf(thick, hi - lo)
		eturn = maxf(eturn, _max_turn(loc, faces, false))
	out["eave_points"] = epts
	out["eave_thick"] = thick if thick != INF else 0.0
	out["eave_turn_max"] = eturn
	# the ridge roll
	var rolls: Array = []
	for part in builder.component_log:
		if str(part.get("role", "")).begins_with("thatch_roll_"):
			rolls.append(part)
	out["roll_count"] = rolls.size()
	var rpts := 0
	var rturn := 0.0
	var zlo := INF
	var zhi := -INF
	var top := -INF
	for row in rolls:
		if str(row["form"]) != "slab":
			rpts = 3
			rturn = 120.0
			continue
		var loc := _local_profile(row["points"], inv)
		rpts = loc.size() if rpts == 0 else mini(rpts, loc.size())
		rturn = maxf(rturn, _max_turn(loc, faces, true))
		var zc := loc[0].z
		var hd := float(row["depth"]) * 0.5
		zlo = minf(zlo, zc - hd)
		zhi = maxf(zhi, zc + hd)
		for p in loc:
			top = maxf(top, p.y)
	out["roll_points"] = rpts
	out["roll_turn_max"] = rturn
	var ridge_len := 2.0 * float(layout["ridge_half"])
	out["roll_cover"] = (zhi - zlo) / ridge_len if ridge_len > 0.05 and zhi > zlo else 0.0
	out["roll_height"] = top - RoofShape.height_at(faces, Vector2(0.0, 0.0)) if top > -INF else 0.0
	# the eyebrow dormers
	var hosts := {}
	var glaze := 0
	var width := 0.0
	var rise := 0.0
	var seated := true
	var below := true
	var ridge_top: float = float(layout["rise"]) + RoofShape.DEPTH * 0.5
	var zs: Array[float] = []
	var sides := {}
	for part in builder.component_log:
		var role := str(part.get("role", ""))
		var host := str(part.get("host", ""))
		if not host.begins_with("eyebrow_"):
			continue
		if role == "eyebrow_glazing":
			glaze += 1
		elif role == "eyebrow_hood":
			hosts[host] = int(hosts.get(host, 0)) + 1
			var loc := _local_profile(part["points"], inv)
			var zl := INF
			var zh := -INF
			var side_e := signf(_centroid(loc).x)
			# the mouth is the face toward the eave: half the slab's length out from its plane
			var x_front: float = loc[0].x + side_e * float(part["depth"]) * 0.5
			var surf_front := RoofShape.height_at(faces, Vector2(x_front, loc[0].z)) + RoofShape.DEPTH * 0.5
			for i in range(loc.size()):
				zl = minf(zl, loc[i].z)
				zh = maxf(zh, loc[i].z)
				if i >= loc.size() - 2:
					# the two base vertices: on or under the roof surface (not floating), sunk a little
					if loc[i].y - surf_front > 0.05 or loc[i].y - surf_front < -0.5:
						seated = false
				else:
					rise = maxf(rise, loc[i].y - surf_front)
					if loc[i].y > ridge_top:
						below = false
			width = maxf(width, zh - zl)
			sides[signf(_centroid(loc).x)] = true
			zs.append((zl + zh) * 0.5)
	out["eyebrow_count"] = hosts.size()
	out["eyebrow_glazing"] = glaze
	out["eyebrow_width"] = width
	out["eyebrow_rise"] = rise
	out["eyebrow_seated"] = seated and not hosts.is_empty()
	out["eyebrow_below_ridge"] = below and not hosts.is_empty()
	var e := plan.entrance()
	var faces_door := false
	if e >= 0 and not zs.is_empty():
		# near the door and on its side of the ridge: the slope the visitor looks up at
		var dpos0 := Vector2(plan.doors[e]["pos"])
		var dl := inv * Vector3(dpos0.x, xf.origin.y, dpos0.y)
		var dn0 := Vector2(plan.doors[e]["normal"])
		var lx := Vector2(xf.basis.x.x, xf.basis.x.z)
		for i in range(zs.size()):
			var sd: float = sides.keys()[mini(i, sides.size() - 1)]
			var on_side := dn0.dot(lx) * sd > 0.3 if absf(dn0.dot(lx)) > 0.3 else dl.x * sd > 0.0
			if on_side and absf(zs[i] - dl.z) <= 3.5:
				faces_door = true
	out["eyebrow_faces_entrance"] = faces_door
	var clear := true
	if spec.chimney:
		var ch := HouseGeometry.chimney_center(plan)
		var cs := HouseGeometry.chimney_size(spec)
		var lc := inv * Vector3(ch.x, xf.origin.y, ch.y)
		for zc in zs:
			if absf(lc.z - zc) < cs * 0.5 + 0.7 and absf(lc.x) > half_span - 2.5:
				clear = false
	out["eyebrow_clear_of_chimney"] = clear
	# the front garden
	var pavers := 0
	var paver_pts: Array[Vector2] = []
	for part in builder.component_log:
		if str(part.get("role", "")) == "path_paver":
			pavers += 1
			var cc: Vector3 = Transform3D(part["xf"]).origin
			paver_pts.append(Vector2(cc.x, cc.z))
	out["path_pavers"] = pavers
	var reaches := false
	var lat_sign := {}
	var beds := 0
	var flowers := 0
	var other: Array[String] = []
	if e >= 0:
		var door: Dictionary = plan.doors[e]
		var dpos := Vector2(door["pos"])
		var dn2 := Vector2(door["normal"]).normalized()
		var tang := Vector2(dn2.y, -dn2.x)
		var nearest := INF
		for pp in paver_pts:
			nearest = minf(nearest, pp.distance_to(dpos + dn2 * 0.3))
		var porch_r := HouseGeometry.porch_rect(plan)
		if porch_r.has_area():
			nearest = INF
			for pp in paver_pts:
				var dx := maxf(maxf(porch_r.position.x - pp.x, pp.x - porch_r.end.x), 0.0)
				var dy := maxf(maxf(porch_r.position.y - pp.y, pp.y - porch_r.end.y), 0.0)
				nearest = minf(nearest, Vector2(dx, dy).length())
			reaches = nearest <= 0.8 and pavers >= 4
		else:
			reaches = nearest <= 1.4 and pavers >= 4
		for piece in plan.yard_pieces:
			var kind := str(piece["kind"])
			if kind == "path":
				continue
			if kind == "bed" and str(piece["role"]) == "flower_bed" and str(piece["host"]) == "front":
				beds += 1
				var pc := Rect2(piece["rect"]).get_center()
				lat_sign[signf((pc - dpos).dot(tang))] = true
			elif str(piece["host"]) in ["front", "porch"]:
				other.append(str(piece["role"]))
		for prop in plan.yard:
			if str(prop["host"]) not in ["front", "porch"]:
				continue
			if str(prop["role"]) == "bed_flowers":
				flowers += 1
			else:
				other.append(str(prop["role"]))
	out["path_reaches_door"] = reaches
	out["flower_beds"] = beds
	out["flower_bed_sides"] = lat_sign.size()
	out["bed_flowers"] = flowers
	out["front_roles"] = other


static func _local_profile(points: PackedVector3Array, inv: Transform3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in points:
		out.append(inv * Vector3(p))
	return out


static func _centroid(loc: Array[Vector3]) -> Vector3:
	var c := Vector3.ZERO
	for p in loc:
		c += p
	return c / float(maxi(loc.size(), 1))


## The sharpest turn (degrees) at a vertex of a profile polygon in the roof's
## (x, y) plane. `skip_buried` leaves out the vertices that lie at or under the
## roof's top surface: the thatch's own seam with the slope is not an edge.
static func _max_turn(loc: Array[Vector3], faces: Array[PackedVector3Array], skip_buried: bool) -> float:
	var n := loc.size()
	var worst := 0.0
	for i in range(n):
		var a := Vector2(loc[(i + n - 1) % n].x, loc[(i + n - 1) % n].y)
		var b := Vector2(loc[i].x, loc[i].y)
		var d := Vector2(loc[(i + 1) % n].x, loc[(i + 1) % n].y)
		if skip_buried:
			var surf := RoofShape.height_at(faces, Vector2(loc[i].x, loc[i].z)) + RoofShape.DEPTH * 0.5
			if loc[i].y <= surf + 0.02:
				continue
		var v1 := b - a
		var v2 := d - b
		if v1.length() < 0.001 or v2.length() < 0.001:
			continue
		worst = maxf(worst, rad_to_deg(absf(v1.angle_to(v2))))
	return worst


## Highest roof vertex that belongs to the main roof (the porch roof is lower
## by construction and never decides the ridge).
static func _ridge_top(mesh: ArrayMesh, plan: HousePlan) -> float:
	var top := -INF
	if mesh.get_surface_count() > HouseBuilder.SURF_ROOF:
		for v in mesh.surface_get_arrays(HouseBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]:
			top = maxf(top, v.y)
	return top


static func _on_hearth_wall(plan: HousePlan, stack: AABB) -> bool:
	var wall := plan.hearth_wall()
	if plan.hearth_room() < 0 or wall < 0:
		return false
	var r := HouseGeometry.site_rect(plan.spec)
	var c := Vector2(stack.position.x + stack.size.x / 2.0, stack.position.z + stack.size.z / 2.0)
	# The stack stands against the outside face of the hearth wall.
	match wall:
		0: return c.y < r.position.y + 0.05
		1: return c.y > r.end.y - 0.05
		2: return c.x < r.position.x + 0.05
		_: return c.x > r.end.x - 0.05


## Roof, both posts and the step exist, and the roof sits over the entrance.
static func _door_sheltered(plan: HousePlan, builder: HouseBuilder, roofs: int) -> bool:
	var d := plan.entrance()
	if d < 0 or roofs != 1:
		return false
	var names := {}
	for m in builder.mass_log:
		names[str(m.get("name", ""))] = m["aabb"]
	if not (names.has("porch_step") and names.has("porch_post_left") and names.has("porch_post_right")):
		return false
	var door: Dictionary = plan.doors[d]
	var p := Vector2(door["pos"])
	var step: AABB = names["porch_step"]
	var foot := Rect2(step.position.x, step.position.z, step.size.x, step.size.z).grow(0.05)
	return foot.has_point(p) or foot.has_point(p + Vector2(door["normal"]).normalized() * 0.6)
