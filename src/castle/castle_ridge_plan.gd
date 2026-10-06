extends RefCounted
## Where a ridge castle's ranges stop and its towers begin.
##
## The ranges used to dive 0.6 tower-halves into every vertex tower and the
## tower was solid, so the join was hidden inside masonry. A tower with rooms
## cannot share its floor with a range that runs through it, so each range's
## rooms now end at a plane just clear of the tower and a solid cheek of
## masonry fills the rest of the old junction. Nothing visible changes: the
## same stone is there, with the tower's own rooms and the ranges' rooms
## carved out of it on either side.
##
## `layout` is pure in the spec:
##   ranges  the trimmed segments the room plans are made on (same keys as
##           CastleGeometry.ridge_ranges, `from`/`to`/`length` shortened)
##   cheeks  floor polygons of solid masonry, with the height they stand to
##   towers  one per vertex: centre, outline polygons, door direction

const MIN_ROOM_RUN := 6.0
const SEARCH_STEP := 0.5
const SEARCH_LIMIT := 40.0
const CLEARANCE := 0.5
## Share of the dark spire's height that is rooms; the needle above is stone.
const SPIRE_ROOMS := 0.72

static var _cache := {}


static func layout(spec: CastleSpec) -> Dictionary:
	var key := CastleGeometry.spec_signature(spec)
	if not _cache.has(key):
		if _cache.size() >= 4:
			_cache.clear()
		_cache[key] = _layout(spec)
	return _cache[key]


static func _layout(spec: CastleSpec) -> Dictionary:
	var ranges: Array[Dictionary] = CastleGeometry.ridge_ranges(spec)
	var centres := CastleGeometry.ridge_tower_centers(spec)
	var spire := CastleGeometry.spine(spec).size() / 2
	var towers: Array[Dictionary] = []
	for index in range(centres.size()):
		var centre: Vector3 = centres[index].pos
		var away := Vector2(centres[index].away.x, centres[index].away.z)
		# The dark fortress puts a spire, not a tower, on its middle vertex: a
		# cylinder of rooms under a stone needle. It is the castle's "keep".
		var is_spire: bool = spec.style == &"dark" and index == spire and spec.keep
		var has_tower: bool = spec.style != &"dark" or index != spire or is_spire
		var half := CastleGeometry.tower_half_at(spec, 0, index)
		var height := CastleGeometry.tower_height_at(spec, 0, index)
		var id := "tower_0_corner_%d" % index
		var bounds := CastleGeometry.tower_aabb(spec, 0, centre, index)
		var sides: int = preload("castle_mural_plan.gd").coarse_sides(
			CastleGeometry.tower_sides(spec), half - preload("castle_manor_plan.gd").TOWER_THICKNESS)
		if is_spire:
			var spire_r := CastleGeometry.dark_spire_aabb(spec).size.x * 0.5
			half = spire_r * cos(PI / 12.0)
			height = spec.height * SPIRE_ROOMS
			id = "keep"
			sides = 12
			bounds = AABB(Vector3(centre.x - spire_r, 0.0, centre.z - spire_r),
				Vector3(spire_r * 2.0, height, spire_r * 2.0))
		var radius := half / cos(PI / float(sides))
		var reach := radius if has_tower else 1.0
		var outline := PackedVector2Array()
		var start := atan2(away.y, away.x) - PI / float(sides)
		for side in range(sides):
			var angle := start + TAU * float(side) / float(sides)
			outline.append(Vector2(centre.x, centre.z) + Vector2(cos(angle), sin(angle)) * reach)
		# The doorway faces away from the castle; masonry is kept off the strip
		# outside it so the door has somewhere to open onto.
		var door_at := Vector2(centre.x, centre.z) + away * (half - 0.2)
		var apron := _rect(door_at, door_at + away * 2.2, 2.0)
		towers.append({"index": index, "id": id, "centre": centre,
			"away": away, "half": half, "sides": sides, "outer": outline, "apron": apron,
			"has_tower": has_tower, "reach": reach, "spire": is_spire, "start": start,
			"height": height, "bounds": bounds})
	var dive := CastleGeometry.tower_half(spec, 0) * CastleGeometry.RIDGE_DIVE
	# Trim each range at both vertices.
	var cuts_at: Array[float] = []
	for index in range(towers.size()):
		cuts_at.append(_cut(spec, ranges, towers, index, dive))
	var trimmed: Array[Dictionary] = []
	var cheeks: Array[Dictionary] = []
	for index in range(ranges.size()):
		var seg: Dictionary = ranges[index].duplicate()
		var dir: Vector2 = seg.dir
		var a := Vector2(towers[index].centre.x, towers[index].centre.z)
		var b := Vector2(towers[index + 1].centre.x, towers[index + 1].centre.z)
		var from_trim := a + dir * cuts_at[index]
		var to_trim := b - dir * cuts_at[index + 1]
		var length := from_trim.distance_to(to_trim)
		seg["full_from"] = seg.from
		seg["full_to"] = seg.to
		seg["from"] = from_trim
		seg["to"] = to_trim
		seg["length"] = length
		seg["usable"] = length >= MIN_ROOM_RUN
		trimmed.append(seg)
		for end in [0, 1]:
			var strip_a: Vector2 = seg.full_from if end == 0 else to_trim
			var strip_b: Vector2 = from_trim if end == 0 else seg.full_to
			var tower: Dictionary = towers[index + end]
			for side in [-1.0, 1.0]:
				var half_strip := _half_rect(strip_a, strip_b, float(seg.width), seg.normal, side)
				var holes: Array[PackedVector2Array] = []
				if tower.has_tower:
					holes.append(tower.outer)
					holes.append(tower.apron)
				for piece in _minus_holes(half_strip, holes):
					cheeks.append({"polygon": piece, "height": float(seg.height)})
	return {"ranges": trimmed, "cheeks": cheeks, "towers": towers}


## How far from vertex `index` along its ranges the rooms may begin.
static func _cut(spec: CastleSpec, ranges: Array[Dictionary], towers: Array[Dictionary],
		index: int, dive: float) -> float:
	var base: float = float(towers[index].reach) + CLEARANCE
	if index == 0 or index == towers.size() - 1:
		return base
	var into: Dictionary = ranges[index - 1]
	var out: Dictionary = ranges[index]
	var vertex := Vector2(towers[index].centre.x, towers[index].centre.z)
	var width: float = float(into.width)
	var cut := base
	while cut < base + SEARCH_LIMIT:
		var rooms_a := _rect(vertex - into.dir * cut, vertex - into.dir * (cut + 12.0), width)
		var rooms_b := _rect(vertex + out.dir * cut, vertex + out.dir * (cut + 12.0), width)
		var strip_a := _rect(vertex - into.dir * cut, vertex + into.dir * dive, width)
		var strip_b := _rect(vertex - out.dir * dive, vertex + out.dir * cut, width)
		if Poly.intersection_area(rooms_a, rooms_b) < 0.01 \
				and Poly.intersection_area(rooms_a, strip_b) < 0.01 \
				and Poly.intersection_area(rooms_b, strip_a) < 0.01:
			return cut
		cut += SEARCH_STEP
	return cut


static func _rect(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * width * 0.5
	return PackedVector2Array([a + n, b + n, b - n, a - n])


static func _half_rect(a: Vector2, b: Vector2, width: float, normal: Vector2,
		side: float) -> PackedVector2Array:
	var n := normal * width * 0.5 * side
	return PackedVector2Array([a, b, b + n, a + n])


## `rect` minus each hole, as convex polygons (slab_poly fans a convex outline).
static func _minus_holes(rect: PackedVector2Array,
		holes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var pieces: Array = [rect]
	for hole in holes:
		var next: Array = []
		for piece in pieces:
			next.append_array(Geometry2D.clip_polygons(piece, hole))
		pieces = next
	for piece in pieces:
		var poly: PackedVector2Array = piece
		if poly.size() < 3 or Poly.area(poly) < 0.05:
			continue
		# A clockwise piece would be a hole; a half-strip cannot contain one.
		if Geometry2D.is_polygon_clockwise(poly):
			continue
		for convex in Geometry2D.decompose_polygon_in_convex(poly):
			if Poly.area(convex) > 0.02:
				out.append(convex)
	return out
