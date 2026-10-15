class_name CastleWalkSources
extends RefCounted
## Where a person can walk in a walled castle, as the outlines a navigation
## baker can union: the ward ground and each range's floors, with the doors,
## the keep's forebuilding stair and each range's own stairs as links.
##
## Nothing here reads a mesh. The ward is the ground inside the curtain; what
## stands on it is what the castle's own route check (`CastleQA.lords_walk`)
## finds there as emitted masonry -- the wall bands of an inner ring, the
## towers, the ranges, the wall stairs, the forebuilding, the yard fittings
## and the floor-blocking props -- here read from the geometry that placed
## them. A range is its own storey, joined to the ward by a link at each door,
## because a range's floor lies inside the footprint the ward walk goes round.
## Each range's floors and obstruction are `HouseWalkSources`, moved by the
## range's own transform, and its stairs are links as a house's are.
##
## Supported: a walled enceinte with a gate, a keep and no barbican, on flat
## ground. Left out, and not walked: the mural towers and gate chambers (they
## are entered from the wall walk, which has no storey yet), the wall walk
## itself, the motte, terraced and sky castles, tower houses, ridge castles and
## the unwalled manors.

const Interiors = preload("castle_interiors.gd")
const MuralPlan = preload("castle_mural_plan.gd")
const GatePlan = preload("castle_gate_plan.gd")
## A range's storeys are (index + 1) * STRIDE + level; the ward is storey 0.
const STRIDE := 100
## The gate approach starts this far outside the gate, as `lords_walk` does.
const APPROACH := 2.0
## Seconds of a keep's plan are spent on its furnishing; a spec fixes the answer.
static var _cache := {}


static func supported(spec: CastleSpec) -> bool:
	return CastleGeometry.is_enclosed(spec) and not CastleGeometry.is_motte(spec) \
		and spec.plan_kind != &"terraced" and not spec.terraced_fallback \
		and CastleGeometry.gate_width(spec, 0) > 0.0 \
		and CastleGeometry.barbican_aabb(spec).size.x <= 0.0 \
		and CastleGeometry.keep_aabb(spec).size.x > 0.0


## {storey: {"floor": [...], "obstacles": [...]}}; empty when not supported.
static func sources(spec: CastleSpec) -> Dictionary:
	return _walk(spec).get("sources", {})


## What goes with the sources; see BuildingFamilyAdapter.walk_frame.
static func frame(spec: CastleSpec) -> Dictionary:
	return _walk(spec).get("frame", {})


static func storey_of(row_index: int, level: int) -> int:
	return (row_index + 1) * STRIDE + level


## The ranges that stand in the ward, in a fixed order: the planned ones
## (keep, hall, chapel, apse) and the yard buildings.
static func rows(spec: CastleSpec) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var planned: Dictionary = Interiors.primary(spec, false)
	for id in planned:
		out.append(planned[id])
	for entry in CastleGenerator.bailey_buildings(spec):
		var row: Dictionary = Interiors.yard(spec, entry)
		if not row.has("errors") and row.has("plan"):
			out.append(row)
	return out


## Every tower's plan footprint, as the massing logs it.
static func tower_footprints(spec: CastleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for ring in CastleGeometry.rings(spec):
		var corners := CastleGeometry.vertex_tower_centers(spec, ring)
		for i in corners.size():
			out.append(_rect_of(CastleGeometry.tower_aabb(spec, ring, corners[i], i)))
		for slot in CastleGeometry.side_tower_slots(spec, ring):
			out.append(_rect_of(CastleGeometry.tower_aabb(spec, ring, slot.pos)))
		for c in CastleGeometry.gate_tower_centers(spec, ring):
			out.append(_rect_of(CastleGeometry.tower_aabb(spec, ring, c)))
	return out


## The piers that carry the gallery decks of the towers and gate chambers: they
## stand on the ward, as high as the wall walk, where the builder puts them.
static func piers(spec: CastleSpec) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var towers: Dictionary = MuralPlan.records(spec, true)
	for id in towers:
		var row: Dictionary = towers[id]
		var bounds: AABB = row.bounds
		var tower := _rect_of(bounds).grow(0.2)
		if float(row.walk_y) - 0.22 <= 0.6:
			continue
		for span in row.get("walk_gallery", []):
			var a: Vector2 = span.a
			var b: Vector2 = span.b
			var mid := (a + b) * 0.5
			if bool(span.get("guarded", false)) and (b - a).length() >= 0.03 and not tower.has_point(mid):
				out.append(Rect2(mid - Vector2.ONE * 0.325, Vector2.ONE * 0.65))
	var gates: Dictionary = GatePlan.records(spec, true)
	for id in gates:
		out.append(Rect2(Vector2(gates[id].support) - Vector2.ONE * 0.4, Vector2.ONE * 0.8))
	return out


## The footprint a floor-blocking prop stands on, or an empty rect when it
## does not block a person: the rule `CastleQA` walks its ward with.
static func prop_rect(prop: Dictionary) -> Rect2:
	var key := String(prop.key)
	if not PropCatalog.blocks_floor(key):
		return Rect2()
	var scale := float(prop.scale)
	var size := PropCatalog.size(key) * scale
	var centre := Vector3(prop.pos) + PropCatalog.centre_offset(key) * scale
	if centre.y + size.y * 0.5 <= WalkGrid.MAX_STEP or centre.y - size.y * 0.5 >= 1.8:
		return Rect2()
	var span := PropCatalog.footprint_rotated(key, float(prop.yaw)) * scale
	var plan_centre := PropCatalog.plan_centre(key, Vector3(prop.pos), float(prop.yaw), scale)
	return Rect2(plan_centre - span * 0.5, span)


static func _walk(spec: CastleSpec) -> Dictionary:
	if not supported(spec):
		return {}
	var key := CastleGeometry.spec_signature(spec)
	if not _cache.has(key):
		if _cache.size() >= 4:
			_cache.clear()
		_cache[key] = _compute(spec)
	return _cache[key]


static func _layer() -> Dictionary:
	var floor: Array[PackedVector2Array] = []
	var obstacles: Array[PackedVector2Array] = []
	return {"floor": floor, "obstacles": obstacles}


static func _rect_of(box: AABB) -> Rect2:
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)


static func _world(poly: PackedVector2Array, xf: Transform3D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in poly:
		var w: Vector3 = xf * Vector3(v.x, 0.0, v.y)
		out.append(Vector2(w.x, w.z))
	return out


static func _at(p: Vector2, xf: Transform3D) -> Vector2:
	var w: Vector3 = xf * Vector3(p.x, 0.0, p.y)
	return Vector2(w.x, w.z)


static func _compute(spec: CastleSpec) -> Dictionary:
	var ranges := rows(spec)
	var keep_at := -1
	for i in ranges.size():
		if String(ranges[i].id) == "keep":
			keep_at = i
	if keep_at < 0:
		return {}
	var ward := _layer()
	var out := {0: ward}
	var floor_y := {0: 0.0}
	var links: Array[Dictionary] = []

	# --- the ground inside the curtain, and the way in through the gate
	var rect0: Rect2 = CastleGeometry.enceinte_rect(spec, 0)
	var t0: float = CastleGeometry.wall_thickness(spec, 0)
	var gate_x: float = CastleGeometry.passage_width(CastleGeometry.gate_width(spec, 0)) * 0.5
	var front: float = CastleGeometry.gatehouse_aabb(spec, 0).position.z
	var inner_floor := CastleGeometry.inner_polygon(spec, 0)
	ward["floor"].append(inner_floor)
	# the ground outside the gate is as wide as the gate; through it, as wide
	# as the passage
	var apron := Rect2(-CastleGeometry.gate_width(spec, 0) * 0.5, front - APPROACH,
		CastleGeometry.gate_width(spec, 0), APPROACH + 0.3)
	ward["floor"].append(Poly.from_rect(apron))
	var way_in := Rect2(-gate_x, front, gate_x * 2.0, rect0.position.y + t0 + 0.5 - front)
	ward["floor"].append(Poly.from_rect(way_in))

	# --- what stands on it
	var gate_ways: Array[Rect2] = []
	for ring in CastleGeometry.rings(spec):
		var mass: AABB = CastleGeometry.gatehouse_aabb(spec, ring)
		if mass.size.x <= 0.0:
			continue
		var gx: float = CastleGeometry.passage_width(mass.size.x) * 0.5
		gate_ways.append(Rect2(-gx, mass.position.z - 1.0, gx * 2.0, mass.size.z + 2.0))
		# the masonry either side of the passage, inside the curtain's line
		for side in [-1.0, 1.0]:
			var x0: float = gx if side > 0.0 else -mass.size.x * 0.5
			ward["obstacles"].append(Poly.from_rect(Rect2(x0, mass.position.z, mass.size.x * 0.5 - gx, mass.size.z)))
	for rect in tower_footprints(spec):
		# a gate tower's bounding box laps the passage it flanks
		var pieces: Array[PackedVector2Array] = [Poly.from_rect(rect)]
		for way in gate_ways:
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				for cut in Geometry2D.clip_polygons(piece, Poly.from_rect(way)):
					if not Geometry2D.is_polygon_clockwise(cut):
						next.append(cut)
			pieces = next
		ward["obstacles"].append_array(pieces)
	for ring in CastleGeometry.rings(spec):
		if ring == 0:
			continue # the outer curtain is the edge of the floor
		var t: float = CastleGeometry.wall_thickness(spec, ring)
		var tb: float = CastleGeometry.wall_base_thickness(spec, ring)
		for seg in CastleGeometry.wall_segments(spec, ring):
			var o := Vector2((seg["outward"] as Vector3).x, (seg["outward"] as Vector3).z)
			var a: Vector2 = seg["a"]
			var b: Vector2 = seg["b"]
			ward["obstacles"].append(PackedVector2Array([a + o * (tb - t), b + o * (tb - t),
				b - o * t, a - o * t]))
	for side in [-1.0, 1.0]:
		var link := CastleGeometry.gate_link_aabb(spec, side)
		if link.size.x > 0.0:
			ward["obstacles"].append(Poly.from_rect(_rect_of(link)))
	for pier in piers(spec):
		ward["obstacles"].append(Poly.from_rect(pier))
	for stair in CastleGeometry.wall_stairs(spec):
		ward["obstacles"].append(Poly.from_rect(Rect2(stair.footprint)))
	var fore: Dictionary = CastleGeometry.forebuilding(spec)
	if not fore.is_empty():
		ward["obstacles"].append(Poly.from_rect(Rect2(fore.footprint)))
	for row in ranges:
		ward["obstacles"].append(Poly.from_rect(_rect_of(row.bounds)))

	# --- the yard fittings and the dressing the furnisher stands in the ward
	var yard_ranges: Array = CastleGenerator.bailey_buildings(spec)
	var well: Dictionary = CastleGenerator.bailey_well(spec)
	var yards: Array[Dictionary] = CastleYards.plan(spec, yard_ranges, well)
	if not well.is_empty():
		var wr: float = float(well.get("radius", 0.9))
		ward["obstacles"].append(Poly.from_rect(Rect2(Vector2(well["pos"]) - Vector2.ONE * wr,
			Vector2.ONE * wr * 2.0)))
	for yard in yards:
		for piece in yard["pieces"]:
			var r := _piece_rect(piece)
			if r.size.x > 0.0:
				ward["obstacles"].append(Poly.from_rect(r))
	var props: Array[Dictionary] = CastleFurnisher.dress(spec,
		{"ranges": yard_ranges, "well": well, "yards": yards})
	for prop in props:
		# the builder drops dressing that stands inside a range, as does this
		var inside := false
		for row in ranges:
			if (row.bounds as AABB).grow(0.2).has_point(prop["pos"]):
				inside = true
		var r := prop_rect(prop)
		if not inside and r.size.x > 0.0:
			ward["obstacles"].append(Poly.from_rect(r))

	# --- each range: its floors, its furniture, its stairs, its doors
	for i in ranges.size():
		var row: Dictionary = ranges[i]
		var plan: HousePlan = row.plan
		var xf: Transform3D = row.transform
		var layers: Dictionary = HouseWalkSources.sources(plan)
		for level in layers:
			var sid := storey_of(i, int(level))
			var layer := _layer()
			for poly in layers[level]["floor"]:
				layer["floor"].append(_world(poly, xf))
			for poly in layers[level]["obstacles"]:
				layer["obstacles"].append(_world(poly, xf))
			out[sid] = layer
			floor_y[sid] = xf.origin.y + float(level) * plan.spec.height + HouseGeometry.FLOOR_T
		for stair in plan.stairs:
			var lo := int(stair.get("storey", 0))
			var hi := int(stair.get("to_storey", lo + 1))
			if not out.has(storey_of(i, lo)) or not out.has(storey_of(i, hi)):
				continue
			links.append({"from_storey": storey_of(i, lo), "to_storey": storey_of(i, hi),
				"lower": _at(HouseWalkSources.stair_rect(stair, false).get_center(), xf),
				"upper": _at(HouseWalkSources.stair_rect(stair, true).get_center(), xf),
				"width": float(stair.get("width", 0.0))})
		var half: float = HouseGeometry.wall_thickness(plan.spec) * 0.5
		for d in plan.doors:
			if not bool(d.get("exterior", false)) or bool(d.get("secret", false)):
				continue
			var level := HousePlan.record_storey(d)
			var normal: Vector2 = d["normal"]
			var inside_local: Vector2 = Vector2(d["pos"]) - normal * (half + 0.2)
			var outside_local: Vector2 = Vector2(d["pos"]) + normal * (half + 0.6)
			var outside := _at(outside_local, xf)
			var target := 0
			if String(row.id) == "keep" and level > 0:
				if fore.is_empty():
					continue
				outside = Vector2(fore.front) + Vector2(fore.normal) * 0.8
			elif level != 0:
				continue
			else:
				# a door can open onto another range (the apse off the chapel)
				for j in ranges.size():
					if j != i and _rect_of(ranges[j].bounds).has_point(outside):
						target = storey_of(j, 0)
			if not out.has(storey_of(i, level)) or not out.has(target):
				continue
			links.append({"from_storey": target, "to_storey": storey_of(i, level),
				"lower": outside, "upper": _at(inside_local, xf), "width": float(d.get("width", 1.0))})

	# --- the way in, and what a person goes in to see
	var focus: Array[Dictionary] = []
	for i in ranges.size():
		var row: Dictionary = ranges[i]
		var plan: HousePlan = row.plan
		var wanted: Array = []
		match String(row.id):
			"keep":
				wanted = plan.rooms_of(&"lords_chamber")
			"hall", "chapel":
				var best := -1
				for r in plan.room_count():
					if HousePlan.record_storey(plan.rooms[r]) != 0:
						continue
					if best < 0 or HouseGeometry.room_floor_rect(plan, r).get_area() \
							> HouseGeometry.room_floor_rect(plan, best).get_area():
						best = r
				if best >= 0:
					wanted = [best]
		for r in wanted:
			var level := HousePlan.record_storey(plan.rooms[r])
			var focus_key := "lords_chamber" if String(row.id) == "keep" else String(row.id)
			focus.append({"key": focus_key, "storey": storey_of(i, level),
				"pos": _at(HouseGeometry.room_floor_rect(plan, r).get_center(), row.transform)})
			break
	var ids: Array = []
	for row in ranges:
		ids.append(String(row.id))
	return {"sources": out, "frame": {
		"floor_y": floor_y, "links": links, "ranges": ids,
		"doors": [{"pos": Vector2(0.0, front), "normal": Vector2(0.0, -1.0), "front": true, "storey": 0}],
		"focus": focus}}


## The plan rectangle a yard fitting takes up, or an empty one.
static func _piece_rect(piece: Dictionary) -> Rect2:
	match piece["kind"]:
		&"solid", &"woodpile":
			return Rect2(piece["rect"])
		&"stack":
			var radius := float(piece["r"])
			return Rect2(Vector2(piece["pos"]) - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		&"post":
			return Rect2(Vector2(piece["pos"]) - Vector2.ONE * 0.12, Vector2.ONE * 0.24)
		&"fence":
			var a: Vector2 = piece["a"]
			var b: Vector2 = piece["b"]
			return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs()).grow(0.18)
	return Rect2()
