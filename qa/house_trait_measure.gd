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
## HS-THATCH on `_thatch_keys`, HS-MINKA on `_minka_keys`, HS-SAHEL on `_sahel_keys`,
## HS-ROUNDHOUSE on `_round_keys`, HS-PUEBLO on `_pueblo_keys`.


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
	_minka_keys(plan, builder, out)
	_sahel_keys(plan, builder, out)
	_round_keys(plan, builder, out)
	_pueblo_keys(plan, builder, out)
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


## HS-MINKA keys (only for the `asian` style; all from the plan and the logs):
##   (1) the raised floor and the engawa
##   plinth_rise            how far the stone stylobate stands below the floor's underside (m)
##   plinth_runs            stylobate courses (one under each exterior wall)
##   plinth_closed          the stylobate's top meets the floor on every run
##   step_flights / step_riser_max / steps_reach_ground   the entry doors' stone steps
##   engawa_present / engawa_length / engawa_depth / engawa_long_side / engawa_outside
##   engawa_deck_top / floor_top   the deck's top against the floor's top (m)
##   engawa_posts / engawa_beam   the posts and the head beam carried under the eave
##   eave_over_engawa       how far the roof's eave reaches past the engawa's outer edge
##   (2) the irimoya roof
##   roof_faces / roof_hip_ends / skirt_angle / gable_angle / hafu_count / hafu_vertical /
##   hafu_on_skirt / eave_side / eave_end / eave_depth
##   (3) the sliding lattice screens
##   screen_openings / screen_panels / screen_bars / screen_lanes / screen_wall_share /
##   screen_off_wall / screen_tracks
##   (4) the main room and the garden
##   main_room_kind / main_screen_door / main_door_on_deck / main_touches_wall /
##   garden_present / garden_rocks / garden_trees / garden_stones / garden_beyond_deck /
##   garden_before_door
static func _minka_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	var spec := plan.spec
	if spec.style != &"asian":
		return
	var raise := HouseGeometry.floor_raise(spec)
	var floor_top := HouseGeometry.FLOOR_T
	var rows := {}
	for row in builder.component_log:
		var role := str(row.get("role", ""))
		if not rows.has(role):
			rows[role] = []
		(rows[role] as Array).append(row)
	# (1) plinth and steps
	var low := 0.0
	var high := -INF
	var runs := 0
	for row in rows.get("stylobate", []):
		var a := MassBuilder.component_aabb(row)
		low = minf(low, a.position.y)
		high = maxf(high, a.end.y)
		runs += 1
	out["plinth_rise"] = -low
	out["plinth_runs"] = runs
	out["plinth_closed"] = runs >= 4 and absf(high) < 0.01
	var riser_max := 0.0
	var flights := 0
	for s in plan.entry_steps:
		flights += 1
		riser_max = maxf(riser_max, (raise + floor_top) / float(maxi(int(s["count"]), 1)))
	var step_low := 0.0
	for row in rows.get("entry_step", []):
		step_low = minf(step_low, MassBuilder.component_aabb(row).position.y)
	out["step_flights"] = flights
	out["step_riser_max"] = riser_max
	out["steps_reach_ground"] = flights > 0 and absf(step_low - low) < 0.01
	# the engawa
	var long_x := spec.length >= spec.width
	out["engawa_present"] = false
	out["engawa_length"] = 0.0
	out["engawa_depth"] = 0.0
	out["engawa_long_side"] = false
	out["engawa_outside"] = false
	out["engawa_deck_top"] = -1.0
	out["floor_top"] = floor_top
	var deck_box := AABB()
	var decks: Array = rows.get("engawa_deck", [])
	if not decks.is_empty():
		deck_box = MassBuilder.component_aabb(decks[0])
		var along := maxf(deck_box.size.x, deck_box.size.z)
		var depth := minf(deck_box.size.x, deck_box.size.z)
		var deck_along_x := deck_box.size.x > deck_box.size.z
		var c := deck_box.get_center()
		out["engawa_present"] = true
		out["engawa_length"] = along
		out["engawa_depth"] = depth
		# the deck runs the way the long walls run, and is at least most of their length
		out["engawa_long_side"] = (deck_along_x != long_x) and along >= maxf(spec.width, spec.length) * 0.8
		out["engawa_outside"] = absf(c.x) > spec.width * 0.5 if long_x else absf(c.z) > spec.length * 0.5
		out["engawa_deck_top"] = deck_box.end.y
	out["engawa_posts"] = (rows.get("engawa_post", []) as Array).size()
	out["engawa_beam"] = (rows.get("engawa_beam", []) as Array).size()
	# (2) the roof, from its own faces
	var faces := 0
	var hip_ends := 0
	var skirt := INF
	var gable := 0.0
	var lowest_side := 0.0
	var lowest_end := 0.0
	var reach_engawa := 0.0
	var wall_top := spec.height * float(maxi(spec.storeys, 1))
	var n_eng := Vector2.ZERO
	if not plan.engawa.is_empty():
		n_eng = plan.engawa["normal"]
	for row in builder.component_log:
		if not str(row.get("role", "")).begins_with("roof_face_"):
			continue
		faces += 1
		var pts: Array = row["points"]
		var nrm := Vector3.ZERO
		for i in range(1, pts.size() - 1):
			nrm = (Vector3(pts[i]) - Vector3(pts[0])).cross(Vector3(pts[i + 1]) - Vector3(pts[0]))
			if nrm.length() > 0.01:
				break
		if nrm.length() > 0.01:
			nrm = nrm.normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			var ang := rad_to_deg(acos(clampf(nrm.y, 0.0, 1.0)))
			var ridge_n := absf(nrm.z) if long_x else absf(nrm.x)
			var across_n := absf(nrm.x) if long_x else absf(nrm.z)
			if ridge_n > across_n:
				hip_ends += 1
			else:
				skirt = minf(skirt, ang)
				gable = maxf(gable, ang)
		for p in pts:
			var v := Vector3(p)
			if v.y <= wall_top + 0.02:
				lowest_side = maxf(lowest_side, absf(v.x) - spec.width * 0.5)
				lowest_end = maxf(lowest_end, absf(v.z) - spec.length * 0.5)
				if n_eng != Vector2.ZERO:
					reach_engawa = maxf(reach_engawa, Vector2(v.x, v.z).dot(n_eng)
						- (spec.width if absf(n_eng.x) > 0.5 else spec.length) * 0.5)
	out["roof_faces"] = faces
	out["roof_hip_ends"] = hip_ends
	out["skirt_angle"] = skirt if skirt < INF else 0.0
	out["gable_angle"] = gable
	var hafus: Array = rows.get("irimoya_hafu", [])
	var vertical := 0
	var base_y := INF
	for row in hafus:
		var hp: Array = row["points"]
		var hn := (Vector3(hp[1]) - Vector3(hp[0])).cross(Vector3(hp[2]) - Vector3(hp[0])).normalized()
		if absf(hn.y) < 0.05:
			vertical += 1
		for p in hp:
			base_y = minf(base_y, Vector3(p).y)
	out["hafu_count"] = hafus.size()
	out["hafu_vertical"] = vertical
	out["hafu_on_skirt"] = base_y < INF and base_y > wall_top + 0.2
	out["eave_side"] = lowest_side
	out["eave_end"] = lowest_end
	out["eave_depth"] = minf(lowest_side, lowest_end)
	out["eave_over_engawa"] = reach_engawa - float(out["engawa_depth"])
	# (3) the screens: rows by host
	var hosts := {}
	var lanes := {}
	var panels := 0
	var bars := 0
	var tracks := 0
	var off_wall := 0
	var width_sum := 0.0
	var line := float(plan.engawa.get("line", 0.0)) if not plan.engawa.is_empty() else 0.0
	for row in builder.component_log:
		var role := str(row.get("role", ""))
		if not role.begins_with("screen_"):
			continue
		var host := str(row.get("host", ""))
		hosts[host] = true
		var cen := MassBuilder.component_aabb(row).get_center()
		var along_n := (cen.x * n_eng.x + cen.z * n_eng.y) if n_eng != Vector2.ZERO else 0.0
		if n_eng == Vector2.ZERO or absf(along_n - line * (n_eng.x + n_eng.y)) > 0.45:
			off_wall += 1
		if role == "screen_paper":
			panels += 1
			if not lanes.has(host):
				lanes[host] = {}
			lanes[host][snappedf(along_n, 0.02)] = true
		elif role == "screen_kumiko":
			bars += 1
		elif role == "screen_track":
			tracks += 1
	var min_lanes := 99
	for h in lanes:
		min_lanes = mini(min_lanes, (lanes[h] as Dictionary).size())
	for w in plan.windows:
		if bool(w.get("screen", false)):
			width_sum += float(w["width"])
	for d in plan.doors:
		if bool(d.get("screen", false)):
			width_sum += float(d["width"])
	var wall_len := spec.length if long_x else spec.width
	out["screen_openings"] = hosts.size()
	out["screen_panels"] = panels
	out["screen_bars"] = bars
	out["screen_tracks"] = tracks
	out["screen_lanes"] = min_lanes if min_lanes < 99 else 0
	out["screen_wall_share"] = width_sum / wall_len if hosts.size() > 0 else 0.0
	out["screen_off_wall"] = off_wall
	# (4) the main room and the garden
	var main := int(plan.engawa.get("main_room", -1)) if not plan.engawa.is_empty() else -1
	out["main_room_kind"] = String(plan.kind_of(main)) if main >= 0 else ""
	out["main_screen_door"] = false
	out["main_door_on_deck"] = false
	out["main_touches_wall"] = false
	var door_t := 0.0
	var wall_t := HouseGeometry.wall_thickness(spec)
	for d in plan.doors:
		if bool(d.get("screen", false)) and int(d["a"]) == main and bool(d.get("exterior", false)) \
				and Vector2(d["normal"]).dot(n_eng) > 0.9 and float(d["width"]) >= 1.5:
			out["main_screen_door"] = true
			var outside := Vector2(d["pos"]) + Vector2(d["normal"]) * (wall_t + 0.3)
			out["main_door_on_deck"] = deck_box.has_volume() and Rect2(
				Vector2(deck_box.position.x, deck_box.position.z),
				Vector2(deck_box.size.x, deck_box.size.z)).grow(0.05).has_point(outside)
			door_t = Vector2(d["pos"]).dot(Vector2(n_eng.y, -n_eng.x))
	if main >= 0 and main < plan.rooms.size() and n_eng != Vector2.ZERO:
		var rr: Rect2 = plan.rooms[main]["rect"]
		var edge := (rr.end.x if n_eng.x > 0.0 else rr.position.x) if absf(n_eng.x) > 0.5 \
			else (rr.end.y if n_eng.y > 0.0 else rr.position.y)
		out["main_touches_wall"] = absf(edge - line) < 0.02
	var rocks := 0
	var trees := 0
	var stones := 0
	for prop in plan.yard:
		match str(prop["role"]):
			"garden_rock":
				rocks += 1
			"garden_tree":
				trees += 1
			"garden_path":
				stones += 1
	out["garden_rocks"] = rocks
	out["garden_trees"] = trees
	out["garden_stones"] = stones
	out["garden_present"] = false
	out["garden_beyond_deck"] = false
	out["garden_before_door"] = false
	var half_across := (spec.width if absf(n_eng.x) > 0.5 else spec.length) * 0.5
	for piece in plan.yard_pieces:
		if str(piece["kind"]) != "dry_garden" or n_eng == Vector2.ZERO:
			continue
		out["garden_present"] = true
		var gr: Rect2 = piece["rect"]
		var tan := Vector2(n_eng.y, -n_eng.x)
		var near_edge := INF
		var lo := INF
		var hi := -INF
		for corner in [gr.position, Vector2(gr.end.x, gr.position.y), gr.end, Vector2(gr.position.x, gr.end.y)]:
			near_edge = minf(near_edge, Vector2(corner).dot(n_eng))
			var tt := Vector2(corner).dot(tan)
			lo = minf(lo, tt)
			hi = maxf(hi, tt)
		out["garden_beyond_deck"] = near_edge >= half_across + spec.engawa_depth - 0.01
		out["garden_before_door"] = door_t >= lo and door_t <= hi


## HS-SAHEL keys (the `african` style; every one false/zero for any other style):
##   sahel                       the style is measured at all
##   roof_flat / roof_earth      the roof faces lie level (<= 3 degrees), earth over banco
##   banco_walls                 unrendered earthen walls, not framed, >= 0.45 m thick
##   room_count                  rooms in the plan
##   sahel_court_present / sahel_court_open / sahel_court_door / sahel_court_rear_wall /
##   sahel_court_gate            the court behind the house (HouseYard `court`)
##   court_range_sides / court_range_roofs / court_range_flat / court_range_open /
##   court_sides                 the flat-roofed ranges down its sides; sides = house + ranges + wall
##   buttress_count / buttress_walls / buttress_reach (m past the wall face, smallest) /
##   buttress_height_frac (smallest, of the wall) / buttress_clear (none on an opening)
##   toron_count / toron_walls / toron_reach / toron_wood / toron_clear / toron_inside
##   glazing_count / window_count / open_windows
##   entry_pinnacles / entry_flank (one each side of the door) / entry_above_parapet /
##   entry_relief_count / entry_relief_frames_door
static func _sahel_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	var spec := plan.spec
	out["sahel"] = spec.sahel
	var rows := {}
	for row in builder.component_log:
		var role := str(row.get("role", ""))
		if not rows.has(role):
			rows[role] = []
		(rows[role] as Array).append(row)
	var wall_top := spec.height * float(maxi(spec.storeys, 1))
	out["roof_flat"] = spec.roof_type == &"flat" and float(out["roof_angle_deg"]) <= 3.0 \
		and (rows.get("roof_face_0", []) as Array).size() > 0
	out["roof_earth"] = spec.roof_material == &"earth"
	var c := spec.wall_color
	var earthen := c.h >= 0.04 and c.h <= 0.13 and c.s >= 0.25 and c.v <= 0.85
	var thick := HouseGeometry.wall_thickness(spec)
	out["banco_walls"] = earthen and not spec.timber_frame and not spec.stone_ground_floor \
		and spec.material != &"stone" and thick >= 0.45
	out["room_count"] = plan.room_count()
	out["glazing_count"] = (rows.get("opening_glazing", []) as Array).size()
	out["window_count"] = plan.windows.size()
	out["open_windows"] = plan.windows.size() > 0 and (rows.get("opening_glazing", []) as Array).is_empty()
	# openings, as intervals on their wall: [pos, normal, half width, bottom, top]
	var openings: Array = []
	for d in plan.doors:
		if bool(d.get("exterior", false)):
			openings.append([Vector2(d["pos"]), Vector2(d["normal"]), float(d["width"]) * 0.5, 0.0, HouseGeometry.DOOR_H])
	for w in plan.windows:
		openings.append([Vector2(w["pos"]), Vector2(w["normal"]), float(w["width"]) * 0.5, float(w["sill"]), float(w["head"])])
	var runs := HouseGeometry.shell_runs(plan, 0)
	# (2) buttresses
	var walls := {}
	var reach := INF
	var frac := INF
	var clear := true
	var buttress_n := (rows.get("buttress", []) as Array).size()
	for row in rows.get("buttress", []):
		var on := _on_wall(MassBuilder.component_aabb(row), runs, thick)
		if on.is_empty():
			clear = false
			continue
		walls[on["run"]] = true
		reach = minf(reach, float(on["reach"]))
		if _hits_opening(on, runs, openings, 0.0, -INF, INF):
			clear = false
	for row in rows.get("buttress_top", []):
		frac = minf(frac, MassBuilder.component_aabb(row).end.y / wall_top)
	out["buttress_count"] = buttress_n
	out["buttress_walls"] = walls.size()
	out["buttress_reach"] = reach if buttress_n > 0 else 0.0
	out["buttress_height_frac"] = frac if buttress_n > 0 else 0.0
	out["buttress_clear"] = clear and buttress_n > 0
	# (3) toron
	var t_walls := {}
	var t_reach := INF
	var t_clear := true
	var t_wood := true
	var t_inside := true
	var t_count := 0
	for row in rows.get("toron", []):
		var a := MassBuilder.component_aabb(row)
		var on := _on_wall(a, runs, thick, 0.45)
		if on.is_empty():
			continue
		t_count += 1
		t_walls[on["run"]] = int(t_walls.get(on["run"], 0)) + 1
		t_reach = minf(t_reach, float(on["reach"]))
		if int(row["surface"]) != HouseBuilder.SURF_TRIM:
			t_wood = false
		if _hits_opening(on, runs, openings, 0.0, a.position.y, a.end.y):
			t_clear = false
		# the stake begins inside the wall, as a stake that stays in the mud does
		if float(on["inner"]) > -0.1:
			t_inside = false
	var wall_count := 0
	for k in t_walls:
		if int(t_walls[k]) >= 3:
			wall_count += 1
	out["toron_count"] = t_count
	out["toron_walls"] = wall_count
	out["toron_reach"] = t_reach if t_count > 0 else 0.0
	out["toron_wood"] = t_count > 0 and t_wood
	out["toron_clear"] = t_count > 0 and t_clear
	out["toron_inside"] = t_count > 0 and t_inside
	# (4) the decorated entry
	var e := plan.entrance()
	var tips: Array = rows.get("entry_pinnacle_tip", [])
	out["entry_pinnacles"] = tips.size()
	out["entry_flank"] = false
	out["entry_above_parapet"] = false
	out["entry_relief_count"] = (rows.get("entry_relief", []) as Array).size()
	out["entry_relief_frames_door"] = false
	if e >= 0:
		var d: Dictionary = plan.doors[e]
		var n := Vector2(d["normal"]).normalized()
		var tang := Vector2(n.y, -n.x)
		var dp := Vector2(d["pos"])
		var half_door := float(d["width"]) * 0.5
		var sides := {}
		var parapet_top := wall_top + HouseGeometry.PARAPET_BASE + HouseGeometry.PARAPET_H
		var tip_top := -INF
		for row in tips:
			var a := MassBuilder.component_aabb(row)
			var ctr := Vector2(a.get_center().x, a.get_center().z)
			var lat := (ctr - dp).dot(tang)
			if absf((ctr - dp).dot(n)) < 1.2 and absf(lat) > half_door:
				sides[signf(lat)] = true
			tip_top = maxf(tip_top, a.end.y)
		out["entry_flank"] = sides.size() == 2
		out["entry_above_parapet"] = tip_top > parapet_top + 0.2
		# the frame: a raised strip beside each jamb, and a header above the door
		var jambs := {}
		var header := false
		for row in rows.get("entry_relief", []):
			var a := MassBuilder.component_aabb(row)
			var ctr := Vector2(a.get_center().x, a.get_center().z)
			var lat := (ctr - dp).dot(tang)
			if a.size.y > HouseGeometry.DOOR_H * 0.9 and absf(absf(lat) - half_door) < 0.4:
				jambs[signf(lat)] = true
			if a.position.y > HouseGeometry.DOOR_H * 0.9 and a.size.y < 0.4 and absf(lat) < half_door + 0.3:
				header = true
		out["entry_relief_frames_door"] = jambs.size() == 2 and header
	# (1) the rooms round the court
	out["court_range_roofs"] = 0
	out["court_range_sides"] = 0
	out["court_range_flat"] = false
	out["court_range_open"] = false
	out["court_range_span"] = 0.0
	out["court_sides"] = 0
	out["sahel_court_present"] = false
	out["sahel_court_door"] = false
	out["sahel_court_gate"] = 0.0
	out["sahel_court_rear_wall"] = false
	out["sahel_court_open"] = false
	if e < 0:
		return
	var n2 := Vector2(plan.doors[e]["normal"]).normalized()
	var depth_x := absf(n2.x) > absf(n2.y)
	for piece in plan.yard_pieces:
		if str(piece["kind"]) != "court":
			continue
		out["sahel_court_present"] = true
		var pr: Rect2 = piece["rect"]
		var mid := pr.get_center().y if depth_x else pr.get_center().x
		var half_w := (pr.size.y if depth_x else pr.size.x) * 0.5
		var sides := {}
		var roofs := 0
		var flat := true
		var open := true
		var run := 0.0
		var wall_len := {-1.0: 0.0, 1.0: 0.0}
		var roof_ext := {}      # side -> [near end, far end] of the range roof along the depth
		var piers := {}         # side -> depth centres of the range piers
		var rear := false
		var sky := true
		for part in piece["parts"]:
			var role := str(part["role"])
			var sz: Vector3 = part["size"]
			var ctr: Vector3 = part["centre"]
			var lat := (ctr.z if depth_x else ctr.x) - mid
			var dd := sz.x if depth_x else sz.z
			var dl := sz.z if depth_x else sz.x
			if role == "court_paving":
				run = dd
			elif role == "court_range_roof":
				roofs += 1
				sides[signf(lat)] = true
				if sz.y > 0.3 or ctr.y < 2.0:
					flat = false
				var dc := ctr.x if depth_x else ctr.z
				var ext: Array = roof_ext.get(signf(lat), [dc - dd * 0.5, dc + dd * 0.5])
				roof_ext[signf(lat)] = [minf(ext[0], dc - dd * 0.5), maxf(ext[1], dc + dd * 0.5)]
			elif role == "court_range_pier":
				var pl: Array = piers.get(signf(lat), [])
				pl.append((ctr.x if depth_x else ctr.z))
				piers[signf(lat)] = pl
			elif role == "court_range_wall":
				wall_len[signf(lat)] += dd
			elif role == "court_wall" and dl > half_w * 1.6:
				rear = true
			if role in ["court_wall", "court_range_wall"] and absf(lat) < half_w - 1.9 and dl < dd:
				open = false      # a wall standing in the open middle of the court
			if str(part["surf"]) == "roof":
				sky = false
		out["court_range_roofs"] = roofs
		out["court_range_sides"] = sides.size()
		out["court_range_flat"] = roofs >= 2 and flat
		out["court_range_open"] = open
		# the longest stretch of a range's open front the roof slab spans between
		# supports (the house wall, a pier, the pier at the far end), on the better
		# supported side: the rear door's approach keeps a between pier off the
		# range it opens beside, by the yard's own rule
		var gap := 99.0
		for side in roof_ext:
			var side_gap := 0.0
			var pts: Array = [float(roof_ext[side][0])]
			var pl2: Array = piers.get(side, [])
			pl2.sort()
			for pc in pl2:
				side_gap = maxf(side_gap, float(pc) - 0.15 - float(pts[-1]))
				pts = [float(pc) + 0.15]
			side_gap = maxf(side_gap, float(roof_ext[side][1]) - float(pts[-1]))
			gap = minf(gap, side_gap)
		out["court_range_span"] = 0.0 if roof_ext.is_empty() else gap
		out["sahel_court_rear_wall"] = rear
		out["sahel_court_open"] = sky and run > 0.0
		out["sahel_court_gate"] = maxf(run - wall_len[-1.0], run - wall_len[1.0])
		# the house is the fourth side only if a room opens onto the court
		var house_side := 0
		for i in range(plan.doors.size()):
			var dr: Dictionary = plan.doors[i]
			if i == e or not dr.get("exterior", false) or bool(dr.get("secret", false)):
				continue
			var dn := Vector2(dr["normal"]).normalized()
			if dn.dot(n2) < -0.5 and pr.grow(0.1).has_point(Vector2(dr["pos"]) + dn * 0.8):
				out["sahel_court_door"] = true
				house_side = 1
		out["court_sides"] = house_side + sides.size() + (1 if rear else 0)


## Where a box stands on the shell: {"run", "reach" (m its far face stands past
## the wall's outer face), "inner" (its near face past the outer face; negative
## is inside the wall), "t0", "t1" (along the run)}, or {} when it is on none.
## `slack` is how far inside the wall line the box's centre may be.
static func _on_wall(a: AABB, runs: Array, thick: float, slack := 0.0) -> Dictionary:
	var best := {}
	var best_gap := INF
	for ri in range(runs.size()):
		var run: Dictionary = runs[ri]
		var from: Vector2 = run["from"]
		var to: Vector2 = run["to"]
		var dir: Vector2 = (to - from).normalized()
		var nrm: Vector2 = run["normal"]
		var face := thick * 0.5
		var lo := INF
		var hi := -INF
		var t0 := INF
		var t1 := -INF
		for sx in [0.0, 1.0]:
			for sz in [0.0, 1.0]:
				var p := Vector2(a.position.x + a.size.x * sx, a.position.z + a.size.z * sz) - from
				lo = minf(lo, p.dot(nrm))
				hi = maxf(hi, p.dot(nrm))
				t0 = minf(t0, p.dot(dir))
				t1 = maxf(t1, p.dot(dir))
		var centre := (lo + hi) * 0.5
		if centre < -slack or centre > face + 1.0 or t1 < 0.0 or t0 > from.distance_to(to):
			continue
		var gap := absf(lo - face)
		if gap < best_gap:
			best_gap = gap
			best = {"run": ri, "reach": hi - face, "inner": lo - face, "t0": t0, "t1": t1}
	return best


## Does a box on a wall (from `_on_wall`) stand across an opening in that wall?
## `y0`/`y1` limit the test to the opening's height range when given.
static func _hits_opening(on: Dictionary, runs: Array, openings: Array, margin: float,
		y0: float, y1: float) -> bool:
	var run: Dictionary = runs[int(on["run"])]
	var from: Vector2 = run["from"]
	var dir: Vector2 = (Vector2(run["to"]) - from).normalized()
	for op in openings:
		if absf(Vector2(op[1]).dot(Vector2(run["normal"]))) < 0.9:
			continue
		var rel: Vector2 = Vector2(op[0]) - from
		if absf(rel.dot(Vector2(run["normal"]))) > 0.8:
			continue
		var t := rel.dot(dir)
		if float(on["t1"]) + margin < t - float(op[2]) or float(on["t0"]) - margin > t + float(op[2]):
			continue
		if y1 < INF and (y1 < float(op[3]) or y0 > float(op[4])):
			continue
		return true
	return false


## HS-ROUNDHOUSE keys (the `roundhouse` style; false/zero for any plan that is not a
## round hut):
##   round_hut                   the plan is a round hut at all (HouseRound.plan_applies)
##   round_rooms                 rooms in the plan (one)
##   round_sides / round_ratio   the room outline: vertices, and its smallest over its
##                               largest distance from the centroid (1.0 is a circle)
##   round_wall_runs / round_wall_ratio   the emitted wall masses (`wall_*`): how many, and
##                               the smallest over the largest distance of their centres
##                               from the middle (a square shell gives 4 runs and about 0.7)
##   door_reveal / door_count    wall thickness at the exterior door: the least depth of its
##                               jambs, less the 0.04 m the frame stands proud
##   cone_faces / cone_eave_ratio / cone_pitch_deg / cone_apex_off / cone_thatch
##                               the roof: facets emitted, smallest over largest eave
##                               radius, the facets' steepness, how far the highest roof
##                               point is from the middle, and the roof is thatch
##   vent_cut / vent_off / vent_area / vent_high   a hole cut in the roof (`roundhouse_vent`):
##                               its distance from the middle, its area, and at the apex
##   vent_collar / vent_collar_ring / vent_hat / vent_hat_clear   the collar round it, the
##                               collar's evenness, the hat over it, and a gap to let smoke out
##   hearth_kerb / hearth_dist / hearth_under_vent / wall_hearth / chimney_stack
##                               the fire: kerb stones, its distance from the middle of the
##                               floor, under the vent, and no fireplace in a wall or chimney
##   bed_count / bed_gap / bed_at_wall / bed_clear_of_fire    a bed, how far its head is from
##                               the nearest wall, and clear of the fire
static func _round_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	out["round_hut"] = HouseRound.plan_applies(plan)
	out["round_rooms"] = plan.room_count()
	var poly := PackedVector2Array()
	if plan.room_count() > 0 and plan.is_polygonal(0):
		poly = plan.outline_of(0)
	out["round_sides"] = poly.size()
	var centre := Vector2.ZERO
	for p in poly:
		centre += p
	centre /= maxf(float(poly.size()), 1.0)
	var rmin := INF
	var rmax := 0.0
	for p2 in poly:
		rmin = minf(rmin, p2.distance_to(centre))
		rmax = maxf(rmax, p2.distance_to(centre))
	out["round_ratio"] = rmin / rmax if poly.size() >= 3 and rmax > 0.0 else 0.0
	# the emitted wall ring
	var runs := 0
	var wmin := INF
	var wmax := 0.0
	for mass in builder.mass_log:
		if not str(mass["name"]).begins_with("wall_"):
			continue
		var box: AABB = mass["aabb"]
		var d := Vector2(box.get_center().x, box.get_center().z).distance_to(centre)
		runs += 1
		wmin = minf(wmin, d)
		wmax = maxf(wmax, d)
	out["round_wall_runs"] = runs
	out["round_wall_ratio"] = wmin / wmax if runs > 0 and wmax > 0.0 else 0.0
	# the reveal of the door: its frame's depth less the 0.04 m it stands proud
	var reveal := INF
	var doors := 0
	for row in builder.component_log:
		if str(row.get("role", "")) == "opening_jamb" and str(row.get("host", "")).begins_with("door"):
			reveal = minf(reveal, Vector3(row["size"]).z - 0.04)
	for d2 in plan.doors:
		if bool(d2.get("exterior", false)):
			doors += 1
	out["door_reveal"] = reveal if reveal < INF else 0.0
	out["door_count"] = doors
	# the cone
	var faces := {}
	var low := INF
	var high := -INF
	var apex := Vector2.ZERO
	var eave_pts: Array[Vector2] = []
	var pts: Array[Vector3] = []
	for row2 in builder.component_log:
		var role := str(row2.get("role", ""))
		if not role.begins_with("roof_face_"):
			continue
		faces[role] = true
		for p3 in PackedVector3Array(row2["points"]):
			pts.append(p3)
			low = minf(low, p3.y)
			high = maxf(high, p3.y)
	for p4 in pts:
		if p4.y >= high - 0.02:
			apex = Vector2(p4.x, p4.z)
	for p5 in pts:
		if p5.y <= low + 0.02:
			eave_pts.append(Vector2(p5.x, p5.z))
	var emin := INF
	var emax := 0.0
	for e in eave_pts:
		emin = minf(emin, e.length())
		emax = maxf(emax, e.length())
	out["cone_faces"] = faces.size()
	out["cone_eave_ratio"] = emin / emax if emax > 0.0 and eave_pts.size() >= 8 else 0.0
	out["cone_apex_off"] = apex.length() if high > -INF else INF
	out["cone_pitch_deg"] = rad_to_deg(atan2(high - low, emax)) if emax > 0.0 else 0.0
	out["cone_thatch"] = plan.spec.roof_material == &"thatch"
	# the vent, from the roof opening the builder cut
	out["vent_cut"] = false
	out["vent_off"] = INF
	out["vent_area"] = 0.0
	out["vent_high"] = false
	var vent_c := Vector2.ZERO
	for op in builder.roof_opening_log:
		if str(op["id"]) != "roundhouse_vent":
			continue
		out["vent_cut"] = true
		var oc: Vector3 = op["center"]
		vent_c = Vector2(oc.x, oc.z)
		out["vent_off"] = vent_c.length()
		out["vent_area"] = Poly.area(op["polygon"])
		out["vent_high"] = oc.y >= high - 0.6 and high > -INF
	var collar_n := 0
	var cmin := INF
	var cmax := 0.0
	var collar_top := -INF
	for row3 in builder.component_log:
		if str(row3.get("role", "")) != "vent_collar":
			continue
		collar_n += 1
		var o: Vector3 = (row3["xf"] as Transform3D).origin
		var rr := Vector2(o.x, o.z).distance_to(vent_c)
		cmin = minf(cmin, rr)
		cmax = maxf(cmax, rr)
		collar_top = maxf(collar_top, MassBuilder.component_aabb(row3).end.y)
	out["vent_collar"] = collar_n
	out["vent_collar_ring"] = cmin / cmax if collar_n >= 3 and cmax > 0.0 else 0.0
	var hat_n := 0
	var hat_low := INF
	for row4 in builder.component_log:
		if str(row4.get("role", "")).begins_with("vent_cap_"):
			hat_n += 1
			for p6 in PackedVector3Array(row4["points"]):
				hat_low = minf(hat_low, p6.y)
	out["vent_hat"] = hat_n
	out["vent_hat_clear"] = hat_n > 0 and collar_n > 0 and hat_low > collar_top + 0.15
	# the fire
	var kerb_n := 0
	var ash := Vector2(INF, INF)
	for row5 in builder.component_log:
		var r5 := str(row5.get("role", ""))
		if r5 == "hearth_kerb":
			kerb_n += 1
		elif r5 == "hearth_ash":
			var ao: Vector3 = (row5["xf"] as Transform3D).origin
			ash = Vector2(ao.x, ao.z)
	out["hearth_kerb"] = kerb_n
	out["hearth_dist"] = ash.distance_to(centre) if kerb_n > 0 and ash.x < INF else INF
	out["hearth_under_vent"] = kerb_n > 0 and bool(out["vent_cut"]) and ash.distance_to(vent_c) <= 0.3
	out["wall_hearth"] = plan.hearth_room() >= 0 or builder.has_mass("chimney_breast")
	out["chimney_stack"] = builder.has_mass("chimney")
	# the bed
	var beds := 0
	var gap := INF
	var near_fire := false
	var kerb: Rect2 = plan.open_fire().get("hearth", Rect2())
	for f in plan.furniture:
		if str(f.get("cat", "")) != "bed":
			continue
		beds += 1
		var rect := Rect2(f["rect"])
		for corner in Poly.from_rect(rect):
			for a in range(poly.size()):
				var wa: Vector2 = poly[a]
				var wb: Vector2 = poly[(a + 1) % poly.size()]
				gap = minf(gap, corner.distance_to(Geometry2D.get_closest_point_to_segment(corner, wa, wb)))
		if kerb.has_area() and rect.intersects(kerb.grow(0.2)):
			near_fire = true
	out["bed_count"] = beds
	out["bed_gap"] = gap if gap < INF else INF
	out["bed_at_wall"] = beds > 0 and gap <= 0.15
	out["bed_clear_of_fire"] = beds > 0 and not near_fire


## HS-PUEBLO keys (the `pueblo` style; every one false/zero for a house that is not a
## stepped pueblo):
##   pueblo                      the plan is a stepped pueblo at all (spec.terraced)
##   (1) stepped storeys, from the wall masses (`wall_<side>_<k>`) and the rooms
##   tier_count / tier_inside / tier_front_step (least m the front of a storey stands behind
##   the one below) / tier_side_step (least of the larger side drawn in) / tier_area_ratio
##   (largest storey area over the one below) / tier_set_back (two or more storeys, each
##   inside and smaller than the one below, its front behind the one below)
##   upper_rooms / upper_rooms_set_back   rooms above the ground, each inside the clear floor
##   of the storey below and smaller than the rooms below it
##   (2) ladders and terraces
##   terrace_levels              the storeys that have a terrace (a roof to walk on)
##   ladder_count / ladders_reach_all   a ladder per terrace whose rails run from the floor
##   it leaves to over the parapet of the terrace it reaches
##   ladder_climbable            every rung gap is 0.36 m or less, six rungs or more
##   ladder_on_wall / ladder_clear   rails lean on the wall they climb and stand across none
##   of its openings
##   ladder_head_open            the parapet is open at the head of every ladder
##   nav_ok / terraces_walkable / terrace_walk_share / upper_rooms_reached   the walk check:
##   no failure, every terrace floor walked (least share of it reached), every upper room
##   reached (by the terrace its door opens onto)
##   terrace_doors               doors of upper rooms onto a terrace
##   (3) vigas
##   viga_count / viga_tiers / viga_walls / viga_reach / viga_section / viga_wood /
##   viga_inside / viga_clear / viga_below (m under the roof surface they carry) /
##   viga_gap_min / viga_gap_max (between neighbours on a wall)
##   (4) small deep openings and flat parapeted roofs
##   door_w_max / door_h_max / win_w_max / win_h_max / win_area_max / win_sill_min /
##   opening_share / small_openings (against the thresholds on the test)
##   parapet_each_terrace (every terrace has a parapet standing on its deck, the roof
##   included); parapet_h (least height); terraces_decked (earth under every terrace
##   floor: a deck, or the roof itself under the top one)
static func _pueblo_keys(plan: HousePlan, builder: HouseBuilder, out: Dictionary) -> void:
	var spec := plan.spec
	var h := spec.height
	out["pueblo"] = spec.style == &"pueblo" and spec.terraced
	# only a pueblo is measured (the walk check below is not free)
	if spec.style != &"pueblo":
		return
	var rows := {}
	for row in builder.component_log:
		var role := str(row.get("role", ""))
		if not rows.has(role):
			rows[role] = []
		(rows[role] as Array).append(row)
	var thick := HouseGeometry.wall_thickness(spec)
	# ---- (1) the storeys, from the wall masses
	var tiers := {}
	for m in builder.mass_log:
		var nm := str(m.get("name", ""))
		if not nm.begins_with("wall_"):
			continue
		var bits := nm.split("_")
		var level := int(bits[2]) if bits.size() >= 3 else 0
		var a: AABB = m["aabb"]
		var r := Rect2(Vector2(a.position.x, a.position.z), Vector2(a.size.x, a.size.z))
		tiers[level] = r if not tiers.has(level) else (tiers[level] as Rect2).merge(r)
	var lv: Array = tiers.keys()
	lv.sort()
	var inside := true
	var front_min := INF
	var side_min := INF
	var ratio_max := 0.0
	for i in range(1, lv.size()):
		var lo: Rect2 = tiers[lv[i - 1]]
		var up: Rect2 = tiers[lv[i]]
		if not lo.grow(0.05).encloses(up):
			inside = false
		front_min = minf(front_min, up.position.y - lo.position.y)
		side_min = minf(side_min, maxf(up.position.x - lo.position.x, lo.end.x - up.end.x))
		ratio_max = maxf(ratio_max, up.get_area() / maxf(lo.get_area(), 0.001))
	out["tier_count"] = lv.size()
	out["tier_inside"] = lv.size() >= 2 and inside
	out["tier_front_step"] = front_min if lv.size() >= 2 else 0.0
	out["tier_side_step"] = side_min if lv.size() >= 2 else 0.0
	out["tier_area_ratio"] = ratio_max if lv.size() >= 2 else 1.0
	out["tier_set_back"] = lv.size() >= 2 and inside and front_min >= 1.5 and ratio_max <= 0.9
	var upper := 0
	var upper_ok := true
	for i in range(plan.room_count()):
		var st := HousePlan.record_storey(plan.rooms[i])
		if st < 1:
			continue
		upper += 1
		var below := HouseGeometry.interior_rect(spec, st - 1)
		var rr := Rect2(plan.rooms[i]["rect"])
		var below_area := 0.0
		for j in range(plan.room_count()):
			if HousePlan.record_storey(plan.rooms[j]) == st - 1:
				below_area += Rect2(plan.rooms[j]["rect"]).get_area()
		# a storey over a lower one is inside it and smaller than it
		if not below.grow(0.05).encloses(rr) or rr.get_area() >= below_area * 0.95:
			upper_ok = false
	out["upper_rooms"] = upper
	out["upper_rooms_set_back"] = upper > 0 and upper_ok
	# ---- (2) ladders, terraces and the walk
	var levels_t := {}
	for t in plan.terraces:
		levels_t[int(t["storey"])] = true
	out["terrace_levels"] = levels_t.size()
	var rails: Array = rows.get("ladder_rail", [])
	var rungs: Array = rows.get("ladder_rung", [])
	out["ladder_count"] = rails.size() / 2
	var served := 0
	var climbable := rails.size() > 0
	var on_wall := rails.size() > 0
	var clear := rails.size() > 0
	var openings: Array = []
	for d in plan.doors:
		if bool(d.get("exterior", false)):
			var dl := float(HousePlan.record_storey(d)) * h
			openings.append([Vector2(d["pos"]), Vector2(d["normal"]), float(d["width"]) * 0.5,
				dl, dl + float(d.get("head", HouseGeometry.DOOR_H))])
	for w in plan.windows:
		var wl := float(HousePlan.record_storey(w)) * h
		openings.append([Vector2(w["pos"]), Vector2(w["normal"]), float(w["width"]) * 0.5,
			wl + float(w["sill"]), wl + float(w["head"])])
	for k in levels_t:
		var walk := Rect2()
		for t in plan.terraces:
			if int(t["storey"]) == int(k):
				walk = Rect2(t["rect"])
				break
		var foot_y := 0.0 if int(k) <= 1 else float(int(k) - 1) * h + HouseGeometry.FLOOR_T
		var head_y := float(k) * h + HouseGeometry.FLOOR_T + HouseGeometry.PARAPET_H + 0.3
		for row in rails:
			var a := MassBuilder.component_aabb(row)
			var cx := a.get_center().x
			if cx < walk.position.x - 0.1 or cx > walk.end.x + 0.1 or a.position.y > foot_y + 0.1 \
					or a.end.y < head_y:
				continue
			served += 1
			# this ladder: the rungs between its rails, which stand HousePueblo.LADDER_W apart
			var ys: Array[float] = []
			for rg in rungs:
				var ra := MassBuilder.component_aabb(rg)
				if absf(ra.get_center().x - (cx + HousePueblo.LADDER_W * 0.5)) < 0.05 \
						and absf(ra.get_center().z - a.get_center().z) < 0.1 \
						and ra.get_center().y >= a.position.y and ra.get_center().y <= a.end.y:
					ys.append(ra.get_center().y)
			ys.sort()
			var gap_max := (ys[0] - a.position.y) if not ys.is_empty() else INF
			for i in range(1, ys.size()):
				gap_max = maxf(gap_max, ys[i] - ys[i - 1])
			if ys.size() < 6 or gap_max > 0.36:
				climbable = false
			var runs: Array = HouseGeometry.shell_runs(plan, int(k) - 1)
			var on := _on_wall(a, runs, thick, 0.2)
			if on.is_empty() or float(on["inner"]) > 0.3 or float(on["inner"]) < -0.01:
				on_wall = false
			elif _hits_opening(on, runs, openings, 0.0, a.position.y, a.end.y):
				clear = false
			break
	out["ladders_reach_all"] = levels_t.size() > 0 and served == levels_t.size()
	out["ladder_climbable"] = climbable
	out["ladder_on_wall"] = on_wall
	out["ladder_clear"] = clear
	# the parapet is open at the head of a ladder: no parapet part stands in the
	# line of the wall across the width of the ladder, at the height just under its top
	var head_open := rails.size() > 0
	for row in rails:
		var a := MassBuilder.component_aabb(row)
		var rail_x := a.get_center().x
		for pr in rows.get("parapet", []):
			var pa := MassBuilder.component_aabb(pr)
			if pa.position.y < a.end.y - 0.9 and pa.end.y > a.end.y - 1.4 \
					and pa.position.x < rail_x + 0.1 and pa.end.x > rail_x - 0.1 \
					and pa.position.z < a.end.z + 0.3 and pa.end.z > a.position.z:
				head_open = false
	out["ladder_head_open"] = head_open
	var nav := HouseNavCheck.new()
	var rep := nav.check(plan)
	out["nav_ok"] = bool(rep["ok"])
	var share_min := 1.0 if not plan.terraces.is_empty() else 0.0
	for t in plan.terraces:
		var grid: WalkGrid = nav._grids.get(int(t["storey"]), null)
		if grid == null:
			share_min = 0.0
			continue
		# the walk grid keeps a person a body's width from every edge
		var tr := Rect2(t["rect"]).grow(-0.4)
		var seen := 0
		var total := 0
		var px := tr.position.x
		while px <= tr.end.x + 0.001:
			var pz := tr.position.y
			while pz <= tr.end.y + 0.001:
				total += 1
				if grid.reached(Rect2(Vector2(px - 0.08, pz - 0.08), Vector2.ONE * 0.16)):
					seen += 1
				pz += 0.2
			px += 0.2
		share_min = minf(share_min, float(seen) / maxf(float(total), 1.0))
	out["terrace_walk_share"] = share_min
	out["terraces_walkable"] = not plan.terraces.is_empty() and share_min >= 0.9
	var reached_rooms := upper > 0
	for i in range(plan.room_count()):
		var st2 := HousePlan.record_storey(plan.rooms[i])
		if st2 >= 1 and not (nav._grids.has(st2) and (nav._grids[st2] as WalkGrid).reached(
				HouseGeometry.room_floor_rect(plan, i))):
			reached_rooms = false
	out["upper_rooms_reached"] = reached_rooms
	var tdoors := 0
	for d in plan.doors:
		if bool(d.get("terrace", false)):
			tdoors += 1
	out["terrace_doors"] = tdoors
	# ---- (3) vigas
	var vigas: Array = rows.get("viga", [])
	out["viga_count"] = vigas.size()
	var vwalls := {}
	var vlevels := {}
	var vreach := INF
	var vsection := 0.0
	var vwood := true
	var vinside := true
	var vclear := true
	var vbelow := INF
	var by_wall := {}
	var runs_by := {}
	for row in vigas:
		var a := MassBuilder.component_aabb(row)
		var level := clampi(int(floor(a.get_center().y / h)), 0, maxi(spec.storeys, 1) - 1)
		if not runs_by.has(level):
			runs_by[level] = HouseGeometry.shell_runs(plan, level)
		var runs: Array = runs_by[level]
		var on := _on_wall(a, runs, thick, 0.45)
		if on.is_empty():
			continue
		var key := "%d:%d" % [level, int(on["run"])]
		vwalls[key] = true
		vlevels[level] = true
		if not by_wall.has(key):
			by_wall[key] = []
		(by_wall[key] as Array).append((float(on["t0"]) + float(on["t1"])) * 0.5)
		vreach = minf(vreach, float(on["reach"]))
		var dims := [a.size.x, a.size.y, a.size.z]
		dims.sort()
		vsection = maxf(vsection, float(dims[1]))
		if int(row["surface"]) != HouseBuilder.SURF_TRIM:
			vwood = false
		if float(on["inner"]) > -0.1:
			vinside = false
		if _hits_opening(on, runs, openings, 0.0, a.position.y, a.end.y):
			vclear = false
		vbelow = minf(vbelow, float(level + 1) * h + HouseGeometry.FLOOR_T - a.end.y)
	var gap_min := INF
	var gap_max := 0.0
	for key in by_wall:
		var ts: Array = by_wall[key]
		ts.sort()
		for i in range(1, ts.size()):
			var gap := float(ts[i]) - float(ts[i - 1])
			gap_min = minf(gap_min, gap)
			gap_max = maxf(gap_max, gap)
	out["viga_tiers"] = vlevels.size()
	out["viga_walls"] = vwalls.size()
	out["viga_reach"] = vreach if not vwalls.is_empty() else 0.0
	out["viga_section"] = vsection
	out["viga_wood"] = vigas.size() > 0 and vwood
	out["viga_inside"] = vigas.size() > 0 and vinside
	out["viga_clear"] = vigas.size() > 0 and vclear
	out["viga_below"] = vbelow if not vwalls.is_empty() else 0.0
	out["viga_gap_min"] = gap_min if not by_wall.is_empty() else 0.0
	out["viga_gap_max"] = gap_max
	# ---- (4) small deep openings
	var dw := 0.0
	var dh := 0.0
	for d in plan.doors:
		dw = maxf(dw, float(d["width"]))
		dh = maxf(dh, float(d.get("head", HouseGeometry.DOOR_H)) - HouseGeometry.FLOOR_T)
	var ww := 0.0
	var wh := 0.0
	var wa := 0.0
	var sill := INF
	var aperture := 0.0
	for w in plan.windows:
		var wd := float(w["width"])
		var hh := float(w["head"]) - float(w["sill"])
		ww = maxf(ww, wd)
		wh = maxf(wh, hh)
		wa = maxf(wa, wd * hh)
		sill = minf(sill, float(w["sill"]))
		aperture += wd * hh
	for d in plan.doors:
		if bool(d.get("exterior", false)):
			aperture += float(d["width"]) * (float(d.get("head", HouseGeometry.DOOR_H)) - HouseGeometry.FLOOR_T)
	var wall_area := 0.0
	for level in range(maxi(spec.storeys, 1)):
		for run in HouseGeometry.shell_runs(plan, level):
			wall_area += Vector2(run["from"]).distance_to(Vector2(run["to"])) * h
	out["door_w_max"] = dw
	out["door_h_max"] = dh
	out["win_w_max"] = ww
	out["win_h_max"] = wh
	out["win_area_max"] = wa
	out["win_sill_min"] = sill if not plan.windows.is_empty() else 0.0
	out["opening_share"] = aperture / maxf(wall_area, 0.001)
	out["small_openings"] = not plan.windows.is_empty() and dw <= 0.85 and dh <= 1.9 \
		and wa <= 0.5 and wh <= 0.8 and sill >= 1.0
	# parapeted flat roofs: every terrace has a parapet standing on its deck
	var para: Array = rows.get("parapet", [])
	var each := not plan.terraces.is_empty()
	var ph := INF
	var ks := {}
	for t in plan.terraces:
		ks[int(t["storey"])] = true
	for k in ks:
		var deck := float(k) * h + HouseGeometry.FLOOR_T
		var n := 0
		for pr in para:
			var pa := MassBuilder.component_aabb(pr)
			if absf(pa.position.y - deck) < 0.03:
				n += 1
				ph = minf(ph, pa.size.y)
		if n < 3:
			each = false
	out["parapet_each_terrace"] = each
	out["parapet_h"] = ph if each else 0.0
	# decks: the earth under every terrace, the roof itself under the top one
	var surfaces: Array = []
	for rk in rows:
		if str(rk) == "terrace" or str(rk).begins_with("roof_face_"):
			surfaces.append_array(rows[rk])
	var decked := not plan.terraces.is_empty()
	for t in plan.terraces:
		var top_y := float(int(t["storey"])) * h + HouseGeometry.FLOOR_T
		var dr := Rect2(t["rect"]).grow(-0.1)
		var qx := dr.position.x
		while qx <= dr.end.x + 0.001:
			var qz := dr.position.y
			while qz <= dr.end.y + 0.001:
				var under := false
				for sr in surfaces:
					var sa := MassBuilder.component_aabb(sr)
					if absf(sa.end.y - top_y) < 0.03 and qx >= sa.position.x and qx <= sa.end.x \
							and qz >= sa.position.z and qz <= sa.end.z:
						under = true
						break
				if not under:
					decked = false
				qz += 0.25
			qx += 0.25
	out["terraces_decked"] = decked
