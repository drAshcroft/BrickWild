class_name HousePueblo
extends RefCounted
## HS-PUEBLO: what makes the `pueblo` style row a stepped adobe house beyond its
## thick wall, its level earth roof and its parapet.
##
##   * TERRACES: every storey is SET BACK from the one below. The front of storey k
##     stands `FRONT_STEP` behind the front of storey k-1, and one side of it
##     stands `SIDE_STEP` in from that storey's side, the side alternating, so the
##     house climbs like a stair of rooms. The part of a storey's roof the next
##     storey does not cover is a TERRACE: an earth deck with a parapet round its
##     open edges. The topmost roof is a terrace too. (`tier_outer`, `terrace_walk`)
##   * LADDERS: a terrace is reached by a ladder, as it was and is at Taos and
##     Acoma, not by a stair inside: the ladder climbs the front wall of the storey
##     below, the parapet is open at its head and its rails stand above the parapet.
##     An upper room opens onto the terrace under it, through a door on that
##     terrace. (`plan_upper`, `_plan_ladder`, `_emit_ladder`)
##   * VIGAS: the ends of the roof beams stand out of every wall, a hand under the
##     roof or terrace they carry, below the parapet (a square-ended timber 0.17 m
##     across, not a round log). They are the Sahel's toron laid out again
##     (HouseSahel.stake_row) at the size of a beam.
##   * SMALL, DEEP OPENINGS: a small low door and small high windows in the 0.72 m
##     wall (the style row's `small_openings`; `DOOR_W`, `WIN_*`).
##
## Everything is read off the style row and the footprint; nothing here draws a
## random number. A pueblo whose footprint is too small to step, or that carries a
## trade or belongs to a shop or a world family, is left to the ordinary planner.

const BASE_HOUSE_SPEC := preload("house_spec.gd")
const SURF_WALL := HouseBuilder.SURF_WALL
const SURF_TRIM := HouseBuilder.SURF_TRIM
const SURF_ROOF := HouseBuilder.SURF_ROOF

## How far each storey's front is set back from the one below, and how far one side
## is drawn in (the side alternates: +x for storey 1, -x for storey 2).
const FRONT_STEP := 2.4
const SIDE_STEP := 1.3
## The smallest a storey's clear floor may be to stand as a room.
const MIN_SIDE := 2.6
const MIN_AREA := 9.0
const MAX_TIERS := 3
## The most rooms a storey above the ground is cut into, and the least a side of one may be.
const MAX_UPPER_ROOMS := 6
const MIN_ROOM_SIDE := 3.5
const MAX_BEDROOMS := 2
const AREA_PER_UPPER_ROOM := 24.0
## A terrace deck and its parapet stand this far past the wall face they sit on, so
## no deck edge lies in the plane of the wall face under it. The top roof is laid
## with the same oversail (the style row's span_out, along_out).
const OVERSAIL := 0.04
const DECK_BURY := 0.1
## Small doors and windows: a low, narrow door and a small window set high. Heads
## and sills are heights above the storey datum, as every plan opening is (the floor
## slab is HouseGeometry.FLOOR_T of it).
const DOOR_W := 0.8
const DOOR_CLEAR_H := 1.72
const WIN_W := 0.6
const WIN_H := 0.65
const WIN_SILL := 1.1
const WIN_NARROW := 0.45
## Vigas: round beam ends, a hand's breadth across, standing this far out of the
## wall face under the roof or terrace they carry.
const VIGA_W := 0.17
const VIGA_OUT := 0.55
const VIGA_SPACING := 0.95
const VIGA_START := 0.7
const VIGA_END := 0.6
const VIGA_BELOW_TOP := 0.34
## A ladder: two rails and a rung every third of a metre. It leans on the wall at
## RAIL_OFF from the face, the rails stand RISE above the parapet's top.
const LADDER_W := 0.55
const RAIL_W := 0.07
const RAIL_OFF := 0.115
const RUNG := 0.05
const RUNG_SPACING := 0.3
const LADDER_RISE := 0.85
const LADDER_MARGIN := 0.9
const LADDER_CLEAR := 0.25
const GAP_HALF := 0.45


static func applies(spec: Object) -> bool:
	return spec != null and bool(spec.get("terraced")) and int(spec.get("storeys")) >= 2


## A plain pueblo before its size is brought to a stepped house's: `clamp_size`
## asks this. Only a dwelling with no trade, outside a shop or a world family.
static func plain(spec: HouseSpec, world_family: StringName = &"") -> bool:
	return spec != null and spec.style == &"pueblo" \
		and spec.get_script() == BASE_HOUSE_SPEC and spec.trade == &"none" \
		and world_family == &"" \
		and not spec.has_method("room_program") and not spec.has_method("custom_room_rects") \
		and not spec.has_method("landmark_footprint")


## The wall of the style row, which the generator sets only after this has run.
static func wall_t() -> float:
	return float(HouseSpec.STYLES[&"pueblo"].get("wall_t", 0.72))


## Bring a request to a stepped house: at least two storeys and as many as it asked
## for, so long as the highest storey still has a room of its own (an interior
## `MIN_SIDE` across and `MIN_AREA` in area). A footprint too small to step is left
## as it was, with no terraces. Pure arithmetic: no random draw.
static func clamp_size(spec: HouseSpec, world_family: StringName = &"") -> void:
	spec.terraced = false
	if not plain(spec, world_family) or not bool(HouseSpec.STYLES[&"pueblo"].get("terraced", false)):
		return
	var tiers := fit_tiers(spec.width, spec.length)
	if tiers < 2:
		return
	spec.terraced = true
	spec.storeys = clampi(spec.storeys, 2, tiers)
	spec.cellars = 0


## How many storeys (1 to MAX_TIERS) this footprint can step through.
static func fit_tiers(width: float, length: float) -> int:
	var best := 1
	for n in range(2, MAX_TIERS + 1):
		var inner := _outer(width, length, n - 1).grow(-wall_t())
		if inner.size.x >= MIN_SIDE and inner.size.y >= MIN_SIDE and inner.size.x * inner.size.y >= MIN_AREA:
			best = n
		else:
			break
	return best


static func _outer(width: float, length: float, level: int) -> Rect2:
	var r := Rect2(Vector2(-width * 0.5, -length * 0.5), Vector2(width, length))
	for k in range(1, level + 1):
		r.position.y += FRONT_STEP
		r.size.y -= FRONT_STEP
		if k % 2 == 1:
			r.size.x -= SIDE_STEP                    # the +x side is drawn in
		else:
			r.position.x += SIDE_STEP                # the -x side is drawn in
			r.size.x -= SIDE_STEP
	return r


## The outside of storey `level`'s walls. Storey 0 is the site rectangle.
static func tier_outer(spec: HouseSpec, level: int) -> Rect2:
	return _outer(spec.width, spec.length, clampi(level, 0, MAX_TIERS))


## Reach of anything the style stands out of a wall (the exterior bound reads it).
static func reach() -> float:
	return maxf(VIGA_OUT, RAIL_OFF + RAIL_W) + OVERSAIL


## The highest point of the house: the rails of the ladder to the top roof.
static func top_height(spec: HouseSpec) -> float:
	return deck_top(spec, spec.storeys) + HouseGeometry.PARAPET_H + LADDER_RISE


## Roof oversail of the top roof: a pueblo roof is laid flush but for a hand.
static func roof_out() -> float:
	return OVERSAIL


# ------------------------------------------------------------------ terraces

## The parapet of the terrace of storey `k`, as plan rectangles on the open edges of
## the deck: the front first (the one a ladder opens), then the sides, then the back
## where the storey above leaves it open. A segment ends where the next begins, so no
## two share a face, and where one meets the wall above it, it stands a little into it.
## For the top roof (`k == storeys`) all four sides are open.
static func parapet_rects(spec: HouseSpec, k: int) -> Array[Rect2]:
	var pt := HouseGeometry.PARAPET_T
	var o := tier_outer(spec, k - 1)
	var p := o.grow(OVERSAIL)
	var out: Array[Rect2] = []
	out.append(Rect2(p.position, Vector2(p.size.x, pt)))
	if k >= spec.storeys:
		out.append(Rect2(Vector2(p.position.x, p.position.y + pt), Vector2(pt, p.size.y - pt)))
		out.append(Rect2(Vector2(p.end.x - pt, p.position.y + pt), Vector2(pt, p.size.y - pt)))
		out.append(Rect2(Vector2(p.position.x + pt, p.end.y - pt), Vector2(p.size.x - pt * 2.0, pt)))
		return out
	var q := tier_outer(spec, k)
	var left_in := q.position.x > o.position.x + 0.2
	var right_in := q.end.x < o.end.x - 0.2
	var bury := 0.05
	var y_left := p.end.y if left_in else q.position.y + bury
	var y_right := p.end.y if right_in else q.position.y + bury
	out.append(Rect2(Vector2(p.position.x, p.position.y + pt), Vector2(pt, y_left - (p.position.y + pt))))
	out.append(Rect2(Vector2(p.end.x - pt, p.position.y + pt), Vector2(pt, y_right - (p.position.y + pt))))
	if left_in:
		out.append(Rect2(Vector2(p.position.x + pt, p.end.y - pt),
			Vector2(q.position.x + bury - (p.position.x + pt), pt)))
	if right_in:
		out.append(Rect2(Vector2(q.end.x - bury, p.end.y - pt),
			Vector2((p.end.x - pt) - (q.end.x - bury), pt)))
	return out


## The floor of the terrace of storey `k`, inside its parapet, as rectangles in plan
## space (one for the roof, a front strip and a side strip for a stepped terrace).
static func terrace_walk(spec: HouseSpec, k: int) -> Array[Rect2]:
	var pt := HouseGeometry.PARAPET_T
	var p := tier_outer(spec, k - 1).grow(OVERSAIL)
	var out: Array[Rect2] = []
	if k >= spec.storeys:
		out.append(p.grow(-pt))
		return out
	var q := tier_outer(spec, k)
	out.append(Rect2(Vector2(p.position.x + pt, p.position.y + pt),
		Vector2(p.size.x - pt * 2.0, q.position.y - (p.position.y + pt))))
	if q.position.x > p.position.x + 0.2:
		out.append(Rect2(Vector2(p.position.x + pt, q.position.y),
			Vector2(q.position.x - (p.position.x + pt), p.end.y - pt - q.position.y)))
	if q.end.x < p.end.x - 0.2:
		out.append(Rect2(Vector2(q.end.x, q.position.y),
			Vector2((p.end.x - pt) - q.end.x, p.end.y - pt - q.position.y)))
	return out


## The slabs of the deck of storey `k < storeys`, laid over the roof of storey k-1
## where the storey above does not stand. They reach DECK_BURY into the walls of
## the storey above, so deck and wall are one mass and no two faces back on.
static func deck_rects(spec: HouseSpec, k: int) -> Array[Rect2]:
	var p := tier_outer(spec, k - 1).grow(OVERSAIL)
	var q := tier_outer(spec, k)
	var out: Array[Rect2] = []
	var front_depth := q.position.y + DECK_BURY - p.position.y
	out.append(Rect2(p.position, Vector2(p.size.x, front_depth)))
	var y0 := q.position.y + DECK_BURY
	if q.position.x > p.position.x + 0.2:
		out.append(Rect2(Vector2(p.position.x, y0), Vector2(q.position.x + DECK_BURY - p.position.x, p.end.y - y0)))
	if q.end.x < p.end.x - 0.2:
		out.append(Rect2(Vector2(q.end.x - DECK_BURY, y0), Vector2(p.end.x - (q.end.x - DECK_BURY), p.end.y - y0)))
	return out


## The datum height of the surface a person stands on at terrace `k`.
static func deck_top(spec: HouseSpec, k: int) -> float:
	return float(k) * spec.height + HouseGeometry.FLOOR_T


# ------------------------------------------------------------------ the plan

## The rooms of storeys 1.. of a stepped house, their doors onto the terraces, the
## ladders and the terraces themselves. Replaces the ordinary upper storeys (clones
## of the ground partition, joined by a stair), which would stand the upper storey
## on the lower one's whole footprint. A storey is one room, or up to six on a large
## footprint (`split_tier`); the room on the front wall nearest the ladder takes the
## door onto the terrace, and the others are reached through it.
static func plan_upper(p: HousePlan, spec: HouseSpec) -> void:
	p.terraces.clear()
	p.ladders.clear()
	for k in range(1, spec.storeys + 1):
		var ladder := _plan_ladder(p, spec, k)
		p.ladders.append(ladder)
		for walk in terrace_walk(spec, k):
			p.terraces.append({"storey": k, "rect": walk, "roof": k >= spec.storeys})
		if k >= spec.storeys:
			break
		var inner := HouseGeometry.interior_rect(spec, k)
		var rects := split_tier(inner)
		var mine: Array[int] = []
		for r in rects:
			p.rooms.append({"kind": &"store", "rect": r, "storey": k})
			mine.append(p.rooms.size() - 1)
		# the door onto the terrace: on the front wall, in the room that stands there
		# nearest where the ladder comes up
		var m := HouseGeometry.DOOR_CORNER_MARGIN + door_w(spec) * 0.5
		var want_x := clampf(float(ladder["x"]), inner.position.x + m, inner.end.x - m)
		var door_room := -1
		var best := INF
		for i in mine:
			var rr := Rect2(p.rooms[i]["rect"])
			if absf(rr.position.y - inner.position.y) > 0.01 or rr.size.x < m * 2.0:
				continue
			var gap := minf(absf(want_x - (rr.position.x + m)), absf(want_x - (rr.end.x - m)))
			if want_x >= rr.position.x + m and want_x <= rr.end.x - m:
				gap = 0.0
			if gap < best:
				best = gap
				door_room = i
		if door_room < 0:
			door_room = mine[0]
		var dr := Rect2(p.rooms[door_room]["rect"])
		var x := clampf(want_x, dr.position.x + m, dr.end.x - m)
		p.doors.append({"a": door_room, "b": -1, "pos": Vector2(x, inner.position.y),
			"normal": Vector2(0, -1), "width": door_w(spec), "exterior": true,
			"front": false, "storey": k, "terrace": true,
			"head": HouseGeometry.FLOOR_T + door_h(spec)})
		# the rooms behind it, on a spanning tree from the room that has the door
		var joined := {door_room: true}
		var guard := 0
		while joined.size() < mine.size() and guard < 16:
			guard += 1
			var pick: Array = []
			var pick_run := 0.0
			for i in joined:
				for j in mine:
					if joined.has(j):
						continue
					var edge: Array = HousePlanOpenings.shared_edge(p, int(i), j)
					if edge.is_empty():
						continue
					var run: float = edge[3] - edge[2]
					if run > pick_run and run >= door_w(spec) + HouseGeometry.DOOR_CORNER_MARGIN * 2.0:
						pick_run = run
						pick = [int(i), j, edge]
			if pick.is_empty():
				break
			joined[pick[1]] = true
			HousePlanOpenings.add_inner_door(p, pick[0], pick[1], pick[2])
		# what each room is: the one the terrace opens into is the public room of the
		# storey when there are others; the household sleeps on the first storey above the
		# ground, in at most two rooms, and the rest are stores
		var beds := 0
		for i in mine:
			var kind: StringName = &"store"
			if mine.size() > 1 and i == door_room:
				kind = &"parlour"
			elif k == 1 and beds < MAX_BEDROOMS:
				kind = &"bedroom"
			if not HouseGeometry.room_suits(p, i, kind):
				kind = &"store"
			if kind == &"bedroom":
				beds += 1
			p.rooms[i]["kind"] = kind
		HousePlanOpenings.place_windows(p, spec, mine)
		HousePlanOpenings.glaze_remaining(p, spec, mine)
		HousePlanner.demote_unlit(p, mine)
	HousePlanOpenings.open_up_privacy(p)
	HousePlanOpenings.demote_through_bedrooms(p)
	HousePlanRooms.refresh_domestic_metadata(p)


## One storey's clear floor as rooms: a room to every AREA_PER_UPPER_ROOM of it, at most
## six, each with every side at least MIN_ROOM_SIDE (a bed needs 3.3 m clear). Equal cuts, no
## random draw: the longer axis is cut in two or three; four or more are two columns across
## the shorter axis, the odd one out taking a whole row. Front to back, then left to right.
static func split_tier(inner: Rect2) -> Array[Rect2]:
	var n := clampi(int(inner.size.x * inner.size.y / AREA_PER_UPPER_ROOM), 1, MAX_UPPER_ROOMS)
	while n > 1:
		var cells := _cells(inner, n)
		var ok := true
		for c in cells:
			if minf(c.size.x, c.size.y) < MIN_ROOM_SIDE or maxf(c.size.x, c.size.y) > minf(c.size.x, c.size.y) * 3.2:
				ok = false
		if ok:
			return cells
		n -= 1
	return [inner]


static func _cells(inner: Rect2, n: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var along_y := inner.size.y >= inner.size.x
	var long_len := inner.size.y if along_y else inner.size.x
	var short_len := inner.size.x if along_y else inner.size.y
	var rows := n if n <= 3 else int(ceil(float(n) / 2.0))
	var cols := 1 if n <= 3 else 2
	for r in range(rows):
		var odd_one := n > 3 and n % 2 == 1 and r == rows - 1
		var count := 1 if cols == 1 or odd_one else 2
		for c in range(count):
			var l0 := long_len * float(r) / float(rows)
			var l1 := long_len * float(r + 1) / float(rows)
			var s0 := short_len * float(c) / float(count)
			var s1 := short_len * float(c + 1) / float(count)
			if along_y:
				out.append(Rect2(Vector2(inner.position.x + s0, inner.position.y + l0), Vector2(s1 - s0, l1 - l0)))
			else:
				out.append(Rect2(Vector2(inner.position.x + l0, inner.position.y + s0), Vector2(l1 - l0, s1 - s0)))
	return out


static func door_w(spec: HouseSpec) -> float:
	return DOOR_W if spec.small_openings else HouseGeometry.DOOR_W


static func door_h(spec: HouseSpec) -> float:
	return DOOR_CLEAR_H if spec.small_openings else 2.1


## Where ladder `k` goes: up the front wall of storey k-1, on the side of the wall
## away from the door that wall already has, clear of every window (a window the
## ladder would cover is taken out). Returns its plan record.
static func _plan_ladder(p: HousePlan, spec: HouseSpec, k: int) -> Dictionary:
	var tier := k - 1
	var outer := tier_outer(spec, tier)
	var inner := HouseGeometry.interior_rect(spec, tier)
	var lo := inner.position.x + LADDER_MARGIN
	var hi := inner.end.x - LADDER_MARGIN
	var wall_y := outer.position.y
	# the door this wall has (the front door for storey 0, a terrace door above) and
	# the windows
	var ref_x := inner.get_center().x
	var doors: Array = []
	var windows: Array = []
	for d in p.doors:
		if HousePlan.record_storey(d) == tier and bool(d.get("exterior", false)) \
				and Vector2(d["normal"]).y < -0.5 and absf(Vector2(d["pos"]).y - inner.position.y) < 0.02:
			doors.append([float(Vector2(d["pos"]).x), float(d["width"]) * 0.5])
			ref_x = float(Vector2(d["pos"]).x)
	for wi in range(p.windows.size()):
		var w: Dictionary = p.windows[wi]
		if HousePlan.record_storey(w) == tier and Vector2(w["normal"]).y < -0.5 \
				and absf(Vector2(w["pos"]).y - inner.position.y) < 0.02:
			windows.append([wi, float(Vector2(w["pos"]).x), float(w["width"]) * 0.5])
	var best_x := lo
	var best_score := -INF
	var best_clear := false
	var x := lo
	while x <= hi + 0.001:
		var clear_doors := true
		for d in doors:
			if absf(x - float(d[0])) - float(d[1]) - LADDER_W * 0.5 < LADDER_CLEAR:
				clear_doors = false
		var clear_all := clear_doors
		for w in windows:
			if absf(x - float(w[1])) - float(w[2]) - LADDER_W * 0.5 < LADDER_CLEAR:
				clear_all = false
		if clear_doors:
			# a ladder clear of every opening is preferred; then the one furthest
			# from the wall's door
			var score := absf(x - ref_x) + (100.0 if clear_all else 0.0)
			if score > best_score:
				best_score = score
				best_x = x
				best_clear = clear_all
		x += 0.05
	if not best_clear:
		# take out the windows the ladder would stand across, from the highest index
		# down so the indices stay true
		var gone: Array[int] = []
		for w in windows:
			if absf(best_x - float(w[1])) - float(w[2]) - LADDER_W * 0.5 < LADDER_CLEAR:
				gone.append(int(w[0]))
		gone.sort()
		gone.reverse()
		var rooms_hit: Array[int] = []
		for wi in gone:
			var room := int(p.windows[wi]["room"])
			if not rooms_hit.has(room):
				rooms_hit.append(room)
			p.windows.remove_at(wi)
		if not rooms_hit.is_empty():
			HousePlanOpenings.glaze_remaining(p, spec, rooms_hit)
	var wall_out := wall_y
	var body := Rect2(Vector2(best_x - LADDER_W * 0.5 - RAIL_W * 0.5, wall_out - RAIL_OFF - RAIL_W),
		Vector2(LADDER_W + RAIL_W, RAIL_OFF + RAIL_W))
	var walk_front := tier_outer(spec, tier).position.y - OVERSAIL + HouseGeometry.PARAPET_T
	return {"storey": tier, "to_storey": k, "x": best_x, "wall_y": wall_out,
		"normal": Vector2(0, -1), "rect": body,
		"foot": Rect2(Vector2(best_x - 0.35, wall_out - 1.0), Vector2(0.7, 0.8)),
		"top": Rect2(Vector2(best_x - 0.35, walk_front), Vector2(0.7, 0.9))}


## The room on `storey` whose door opens onto the terrace there, or -1.
static func terrace_room(plan: HousePlan, storey: int) -> int:
	for d in plan.doors:
		if bool(d.get("terrace", false)) and HousePlan.record_storey(d) == storey:
			return int(d["a"])
	return -1


# ------------------------------------------------------------------ the walk

## Floor beyond the rooms that the walk of storey `level` stands on, as rectangles:
## the terraces of that level, the doorways through the thick wall onto them, and,
## on the ground, the ground at the foot of the first ladder with the way to it from
## the front door. The nav check and the published walk sources both read this one
## list.
static func walk_floor(plan: HousePlan, level: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if plan.terraces.is_empty():
		return out
	for t in plan.terraces:
		if int(t["storey"]) == level:
			out.append(Rect2(t["rect"]))
	var thick := HouseGeometry.wall_thickness(plan.spec)
	for d in plan.doors:
		if bool(d.get("terrace", false)) and HousePlan.record_storey(d) == level:
			var pos: Vector2 = d["pos"]
			var half := float(d["width"]) * 0.5
			# from the terrace, right through the wall, into the room
			out.append(Rect2(Vector2(pos.x - half, pos.y - thick - 0.05), Vector2(half * 2.0, thick + 0.4)))
	if level == 0 and not plan.ladders.is_empty():
		var first: Dictionary = plan.ladders[0]
		var foot := Rect2(first["foot"])
		var e := plan.entrance()
		var wall_y := float(first["wall_y"])
		var x0 := foot.position.x
		var x1 := foot.end.x
		if e >= 0:
			var dpos: Vector2 = plan.doors[e]["pos"]
			var dh := float(plan.doors[e]["width"]) * 0.5
			x0 = minf(x0, dpos.x - dh - 0.3)
			x1 = maxf(x1, dpos.x + dh + 0.3)
			# the doorway through the wall, from the ground to the room
			out.append(Rect2(Vector2(dpos.x - dh, wall_y - 0.05), Vector2(dh * 2.0, thick + 0.4)))
		out.append(Rect2(Vector2(x0, wall_y - 1.0), Vector2(x1 - x0, 1.0)))
	return out


# ----------------------------------------------------------------- the mesh

static func emit(b: HouseBuilder) -> void:
	var plan: HousePlan = b.plan
	var spec: HouseSpec = plan.spec
	if spec.style == &"pueblo" and not applies(spec) and plan.world_family == &"" 			and not HouseGeometry.is_shaped(plan) and not plan.has_court() 			and not "viga" in spec.pueblo_skip:
		# a shop, a trade house or a footprint too small to step is not terraced, but
		# it is still a pueblo: the roof beams stand out of its walls, at the beam's
		# size (not the Sahel's toron). HS-PUEBLO-RESIDUE (a pueblo apothecary was
		# walked as "the same house as the Sahel")
		b.tag("viga")
		b.host("viga", 0)
		_emit_vigas(b, plan, spec)
		b.host_end()
		return
	if not applies(spec) or plan.world_family != &"" or HouseGeometry.is_shaped(plan) or plan.has_court():
		return
	if not "terrace" in spec.pueblo_skip:
		for k in range(1, spec.storeys):
			_emit_deck(b, spec, k)
	_emit_parapets(b, plan, spec, 1, spec.storeys - 1)
	if not "ladder" in spec.pueblo_skip:
		b.tag("ladder")
		b.host("ladder", 0)
		for ladder in plan.ladders:
			_emit_ladder(b, spec, ladder)
		b.host_end()
	if not "viga" in spec.pueblo_skip:
		b.tag("viga")
		b.host("viga", 0)
		_emit_vigas(b, plan, spec)
		b.host_end()


static func _box(b: HouseBuilder, role: String, rect: Rect2, y0: float, y1: float, surf: int) -> void:
	if rect.size.x < 0.01 or rect.size.y < 0.01 or y1 - y0 < 0.01:
		return
	b.component_box(role, Vector3(rect.size.x, y1 - y0, rect.size.y),
		Transform3D(Basis(), Vector3(rect.get_center().x, (y0 + y1) * 0.5, rect.get_center().y)), surf)


## The earth deck over the roof of storey k-1: one mass per slab, logged like a floor.
static func _emit_deck(b: HouseBuilder, spec: HouseSpec, k: int) -> void:
	b.tag("terrace")
	b.host("terrace", k)
	# the underside stands a hair above the floor slab of the storey over it (which
	# hangs HouseBuilder.SLAB_TUCK below its line), so where deck and floor overlap
	# the two undersides are never in one plane
	var y0 := float(k) * spec.height - 0.003
	var y1 := deck_top(spec, k)
	var i := 0
	for r in deck_rects(spec, k):
		_box(b, "terrace", r, y0, y1, SURF_ROOF)
		b._log_mass("terrace_%d_%d" % [k, i], AABB(Vector3(r.position.x, y0, r.position.y),
			Vector3(r.size.x, y1 - y0, r.size.y)), y0)
		i += 1
	b.host_end()


## The parapet of the top roof, on the roof's own edge and open at the head of the last
## ladder. The builder's ordinary parapet hook calls it (HouseBuilder._build_parapet), so a
## builder that drops the parapet drops this one.
static func emit_roof_parapet(b: HouseBuilder) -> void:
	_emit_parapets(b, b.plan, b.plan.spec, b.plan.spec.storeys, b.plan.spec.storeys)


## The parapets of the terraces `first` to `last` on their open edges, open at the head of
## the ladder that climbs to each.
static func _emit_parapets(b: HouseBuilder, plan: HousePlan, spec: HouseSpec, first: int, last: int) -> void:
	if "parapet" in spec.pueblo_skip:
		return
	b.tag("parapet")
	b.host("parapet", spec.storeys - 1)
	for k in range(first, last + 1):
		if "terrace" in spec.pueblo_skip and k < spec.storeys:
			continue
		var y0 := deck_top(spec, k)
		var gap_x := INF
		if not "ladder" in spec.pueblo_skip and not "gap" in spec.pueblo_skip:
			for ladder in plan.ladders:
				if int(ladder["to_storey"]) == k:
					gap_x = float(ladder["x"])
		var rects := parapet_rects(spec, k)
		for i in range(rects.size()):
			var r := rects[i]
			if i == 0 and gap_x != INF:
				var left := Rect2(r.position, Vector2(maxf(gap_x - GAP_HALF - r.position.x, 0.0), r.size.y))
				var rx := gap_x + GAP_HALF
				var right := Rect2(Vector2(rx, r.position.y), Vector2(maxf(r.end.x - rx, 0.0), r.size.y))
				_box(b, "parapet", left, y0, y0 + HouseGeometry.PARAPET_H + 0.01, SURF_WALL)
				_box(b, "parapet", right, y0, y0 + HouseGeometry.PARAPET_H + 0.01, SURF_WALL)
			else:
				_box(b, "parapet", r, y0, y0 + HouseGeometry.PARAPET_H + 0.01, SURF_WALL)
	b.host_end()


## A ladder: two rails from the foot to a hand over the parapet, a rung every 0.3 m.
static func _emit_ladder(b: HouseBuilder, spec: HouseSpec, ladder: Dictionary) -> void:
	var k := int(ladder["to_storey"])
	var x := float(ladder["x"])
	var wall_y := float(ladder["wall_y"])
	var foot_y := 0.0 if int(ladder["storey"]) == 0 else deck_top(spec, int(ladder["storey"]))
	var top_deck := float(k) * spec.height + HouseGeometry.FLOOR_T if k < spec.storeys \
		else float(k) * spec.height + HouseGeometry.PARAPET_BASE
	var top_y := top_deck + HouseGeometry.PARAPET_H + LADDER_RISE
	var cy := wall_y - RAIL_OFF - RAIL_W * 0.5
	var rail_h := top_y - foot_y
	for s in [-1.0, 1.0]:
		b.component_box("ladder_rail", Vector3(RAIL_W, rail_h, RAIL_W),
			Transform3D(Basis(), Vector3(x + float(s) * LADDER_W * 0.5, foot_y + rail_h * 0.5, cy)), SURF_TRIM)
	var y := foot_y + RUNG_SPACING
	while y < top_y - 0.1:
		b.component_box("ladder_rung", Vector3(LADDER_W - RAIL_W, RUNG, RUNG),
			Transform3D(Basis(), Vector3(x, y, cy)), SURF_TRIM)
		y += RUNG_SPACING


## The roof beams of every storey, on every outer wall, under the roof or deck that
## storey carries, clear of its openings and of the ladders.
static func _emit_vigas(b: HouseBuilder, plan: HousePlan, spec: HouseSpec) -> void:
	for level in range(spec.storeys):
		var y := spec.height * float(level + 1) - VIGA_BELOW_TOP
		var reach_of := func(_t: float) -> float:
			return VIGA_OUT
		for run in HouseGeometry.shell_runs(plan, level):
			var from: Vector2 = run["from"]
			var to: Vector2 = run["to"]
			var thick: float = float(run.get("thickness", HouseGeometry.wall_thickness(spec)))
			var ops: Array = b._openings_on(from, to, run["normal"], level, thick)
			# a ladder leans on the front wall of the storey it climbs from
			if StringName(run.get("side", &"")) == &"front":
				for ladder in plan.ladders:
					if int(ladder["storey"]) == level and not "ladder" in spec.pueblo_skip:
						ops.append({"t": float(ladder["x"]) - from.x, "w": LADDER_W + 0.5, "top": 99.0})
			HouseSahel.stake_row(b, "viga", run, thick, ops, y, VIGA_W, VIGA_SPACING,
				VIGA_START, VIGA_END, reach_of, [], [])
