class_name HouseFurnishGeometry
extends RefCounted
## Pure geometry shared by every furnishing placement strategy.

const SCALE_STEPS := [1.0, 0.88, 0.76, 0.62]
const BAR_FRACTION := 0.55

## Vertical origin of a room. Older hand-authored plans have no `storey`.
static func storey_base(plan: HousePlan, room: int) -> float:
	if room < 0 or room >= plan.rooms.size():
		return 0.0
	return float(HousePlan.record_storey(plan.rooms[room])) * plan.spec.height


# Shared candidate geometry and acceptance rules.

## A placement, before it is known whether it fits.
static func candidate(key: String, centre: Vector2, yaw: float,
		zone_side := 1.0, scale := 1.0, height_scale := -1.0) -> Dictionary:
	var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw) * scale
	var rect := Rect2(centre - foot / 2.0, foot)
	var placement := {
		"key": key, "pos": Vector3(centre.x, 0.0, centre.y), "yaw": yaw,
		"rect": rect, "zone": zone_rect(key, rect, yaw, zone_side), "host": -1,
		"cat": PropCatalog.category(key), "mounted": false, "scale": scale,
	}
	if height_scale >= 0.0:
		placement["height_scale"] = height_scale
	return placement


## The floor a person needs to USE the piece.
##
## Which side that is depends on the piece: you stand in front of a cabinet,
## you push a chair BACK from the table to sit down, and you get into a bed
## from its long side. Getting this wrong is not a cosmetic matter -- the
## navigation check requires every one of these to be reachable, so a zone on
## the wrong side of a chair reports the whole room as unusable.
static func zone_rect(key: String, rect: Rect2, yaw: float, side := 1.0) -> Rect2:
	var depth: float = PropCatalog.zone_depth(key)
	if depth <= 0.0:
		return Rect2()
	var cat: String = PropCatalog.category(key)
	var facing: Vector2 = HouseFurnishScore._facing_of(yaw)
	var dir: Vector2 = facing
	if cat == "seat" or cat == "bench":
		dir = -facing                      # pull-back space, behind the seat
	elif cat == "bed":
		dir = Vector2(facing.y, -facing.x) * side  # you get in from the side
	var c: Vector2 = rect.get_center()
	var measured := PropCatalog.footprint_rotated(key, yaw)
	var scale := rect.size.x / maxf(measured.x, 0.001)
	var raw := PropCatalog.footprint(key) * scale
	var out: float = raw.x * 0.5 if cat == "bed" else raw.y * 0.5
	var width: float = raw.y if cat == "bed" else raw.x
	var span := Vector2(dir.y, -dir.x) * width * 0.5
	# Bound all four corners of the rotated strip. Bounding just two opposite
	# corners with an absolute tangent can collapse a diagonal use zone.
	return Poly.bounding_rect(PackedVector2Array([
		c + dir * out - span, c + dir * out + span,
		c + dir * (out + depth) + span, c + dir * (out + depth) - span]))


## Does this candidate fit: inside the room, clear of everything already
## placed, and with its use zone on real floor rather than inside a wall?
static func fits(plan: HousePlan, room: int, cand: Dictionary, floor_rect: Rect2, blocked: Array[Rect2],
		zones: Array[Rect2], extra: Array[Rect2], ignore := Rect2()) -> bool:
	var rect: Rect2 = cand["rect"]
	if not floor_rect.grow(0.01).encloses(rect):
		return false
	for b in blocked:
		# a seat tucked under its own table overlaps it on purpose, so the
		# table is passed in as the one rectangle this placement may share
		if ignore.size.x > 0.0 and b.is_equal_approx(ignore):
			continue
		if b.intersects(rect):
			return false
	for z in zones:
		if z.intersects(rect):
			return false
	for e in extra:
		if e.intersects(rect):
			return false
	if not no_slivers(rect, floor_rect):
		return false
	var zone: Rect2 = cand["zone"]
	if zone.size.x > 0.0:
		# the zone may overlap another zone -- two people can share a gangway --
		# but it may not be inside a wall or under other furniture
		if not floor_rect.grow(0.02).encloses(zone):
			return false
		for b2 in blocked:
			if b2 in cand.get("zone_passages", []):
				continue
			if b2.intersects(zone):
				return false
	# Polygon corner tests are pure and substantially dearer than rectangle
	# rejection. Only candidates clear of every inexpensive obstruction need
	# the exact same outline tests; no accepted candidate or RNG draw changes.
	if not inside_outline(plan, room, rect):
		return false
	if zone.size.x > 0.0 and not inside_outline(plan, room, zone):
		return false
	return true


## Are all four corners of `rect` inside the room being furnished? True when
## the room is a plain rectangle -- the enclosing test above has said so
## already.
static func inside_outline(plan: HousePlan, room: int, rect: Rect2) -> bool:
	if not plan.is_polygonal(room):
		return true
	var outline: PackedVector2Array = plan.outline_of(room)
	for p in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		if not Poly.contains_point(outline, p, 0.01):
			return false
	return true


## Ordinary sleep beds reserve a reachable side approach while leaving their
## head-corner clear for a head-end stand. Trim only the headward end by the
## full measured stand span; keep the real access depth and footward approach.
static func ordinary_sleep_access_zone(access: Rect2, bed_rect: Rect2, yaw: float) -> Rect2:
	if not access.has_area() or not bed_rect.has_area():
		return access
	var facing := HouseFurnishScore._facing_of(yaw).normalized()
	var head_dir := -facing
	var support_footprint := PropCatalog.footprint("Nightstand_Shelf")
	var bed_side_span := absf(head_dir.x) * bed_rect.size.x + absf(head_dir.y) * bed_rect.size.y
	var minimum_approach := maxf(HouseGeometry.PATH_MIN,
		HouseGeometry.PERSON_RADIUS * 2.0 + 0.06)
	var trim := minf(maxf(support_footprint.x, support_footprint.y) + 0.06,
		maxf(0.0, bed_side_span - minimum_approach))
	var zone := access
	if absf(head_dir.x) > 0.5:
		if head_dir.x > 0.0:
			zone.size.x -= trim
		else:
			zone.position.x += trim
			zone.size.x -= trim
	else:
		if head_dir.y > 0.0:
			zone.size.y -= trim
		else:
			zone.position.y += trim
			zone.size.y -= trim
	if zone.size.x <= 0.0 or zone.size.y <= 0.0:
		return Rect2()
	return zone


## Reserve the bed's real access strip and a person-width aisle on only its chosen side.
## The lane follows the use-zone direction; it does not grow behind the bed or
## across its head and foot. Keep this shared by bed-pair preflight and room placement.
static func ordinary_bedside_aisle(access: Rect2, bed_rect: Rect2, yaw: float) -> Rect2:
	if not access.has_area() or not bed_rect.has_area():
		return access
	var facing := HouseFurnishScore._facing_of(yaw).normalized()
	var access_dir := Vector2(facing.y, -facing.x)
	var sign := 1.0 if (access.get_center() - bed_rect.get_center()).dot(access_dir) >= 0.0 else -1.0
	var outward := access_dir * sign
	var lane := access
	var minimum_width := maxf(HouseGeometry.PATH_MIN,
		HouseGeometry.PERSON_RADIUS * 2.0 + 0.06)
	if absf(outward.x) > 0.5:
		var x_deficit := maxf(0.0, minimum_width - access.size.x)
		if outward.x > 0.0:
			lane.size.x += x_deficit
		else:
			lane.position.x -= x_deficit
			lane.size.x += x_deficit
	else:
		var y_deficit := maxf(0.0, minimum_width - access.size.y)
		if outward.y > 0.0:
			lane.size.y += y_deficit
		else:
			lane.position.y -= y_deficit
			lane.size.y += y_deficit
	return lane


static func commit(plan: HousePlan, room: int, cand: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2]) -> void:
	if cand.is_empty():
		return
	cand["room"] = room
	cand["storey"] = HousePlan.record_storey(plan.rooms[room])
	var pos: Vector3 = cand["pos"]
	# Candidates are planar (Y=0) while searching. Stamp world elevation only
	# after the placement is accepted, keeping all rectangle logic 2D. A dais
	# is part of that elevation: the high table stands ON the step, and
	# everything in plan still measures as though the step were flat floor.
	pos.y += storey_base(plan, room)
	# A piece stands on the floor's TOP, not on the storey datum: the builder
	# lays each floor slab from the datum up by FLOOR_T. Standing furniture on
	# the datum sank every leg twelve centimetres into the boards, cut the
	# bottom off a crate of carrots, and put the base of an upper-storey
	# bookcase exactly on the ceiling below it, where it flickered through.
	pos.y += HouseGeometry.FLOOR_T
	if plan.on_dais(room, Vector2(pos.x, pos.z)):
		pos.y += plan.dais_rise()
	cand["pos"] = pos
	cand["must"] = false
	plan.furniture.append(cand)
	if cand.has("breast"):
		plan.hearth["breast"] = cand["breast"]
		blocked.append(cand["breast"]["rect"])
		cand.erase("breast")
	blocked.append(cand["rect"])
	var zone: Rect2 = cand["zone"]
	if zone.size.x > 0.0:
		zones.append(zone)


## The sizes this piece may be built at, largest first.
static func scales(key: String) -> Array:
	var floor_scale: float = PropCatalog.min_scale(key)
	if floor_scale >= 1.0:
		return [1.0]
	var out: Array = []
	for s in SCALE_STEPS:
		if float(s) >= floor_scale - 0.001:
			out.append(float(s))
	return out


## No dead slivers.
##
## The gap between a piece and each wall must be either nothing -- the piece is
## against that wall -- or wide enough to walk down. A table left 38 cm from the
## wall behind it is what cut one test house in half: the room stayed walkable
## on paper and a person could not get past.
static func no_slivers(rect: Rect2, floor_rect: Rect2) -> bool:
	# A gap beside a stool is a gap you step round. It only becomes a dead
	# sliver when the piece is long enough to bar the room across the other
	# axis, so that the sliver is the only way past.
	var bars_x: bool = rect.size.y > floor_rect.size.y * BAR_FRACTION
	var bars_z: bool = rect.size.x > floor_rect.size.x * BAR_FRACTION
	var gaps := []
	if bars_x:
		gaps.append(rect.position.x - floor_rect.position.x)
		gaps.append(floor_rect.end.x - rect.end.x)
	if bars_z:
		gaps.append(rect.position.y - floor_rect.position.y)
		gaps.append(floor_rect.end.y - rect.end.y)
	# And the ways round its ENDS. A table across most of the width of a room
	# is got past at its sides, not behind it, so those are the gaps that have
	# to be walkable -- a parlour with a bench drawn up to such a table is cut
	# in two by 49 cm of floor either side, and every repair pass in the world
	# will not open it again.
	if bars_z:
		gaps.append(rect.position.x - floor_rect.position.x)
		gaps.append(floor_rect.end.x - rect.end.x)
	if bars_x:
		gaps.append(rect.position.y - floor_rect.position.y)
		gaps.append(floor_rect.end.y - rect.end.y)
	for g in gaps:
		var gap: float = float(g)
		if gap > HouseGeometry.WALL_GAP + 0.06 and gap < HouseGeometry.PATH_MIN:
			return false
	return true


## Yaw that turns a prop's face (local -Z) toward `n`.
static func yaw_facing(n: Vector2) -> float:
	return atan2(-n.x, -n.y)
