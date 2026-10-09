class_name RoofShape
extends RefCounted
## Convex roof faces in local X/Y/Z. Eave and ridge coordinates describe the
## slab MID-PLANE. Slabs have constant vertical depth, so both sides of every
## shared hip/ridge edge meet exactly (normal offsets would pull them apart).

const DEPTH := 0.24
const HALF_HIP := 0.62

## A cone is not a pyramid: it has no ridge to cap and no two planes meeting
## at an apex ridge, only a ring of facets running to a single point. Mud-brick
## and reed huts are roofed with it, and a square hip cannot stand in for one
## because its ridge is the very thing a cone has not got.
const CONE_SIDES := 8


static func faces(span: float, along: float, rise: float,
		kind: StringName = &"gable") -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	if minf(span, along) <= 0.0:
		return out
	# A flat roof is a real horizontal slab, not a near-zero hip. Keep this
	# branch ahead of the rise guard so its upper face exists at rise == 0.
	if kind == &"flat":
		var h := span * 0.5
		var f := along * 0.5
		out.append(PackedVector3Array([Vector3(-h, rise, -f), Vector3(h, rise, -f),
			Vector3(h, rise, f), Vector3(-h, rise, f)]))
		return out
	if rise <= 0.0:
		return out
	if kind == &"conical":
		return _cone(span, along, rise)
	var h := span * 0.5
	var f := along * 0.5
	var cut := rise if kind == &"gable" else (rise * HALF_HIP if kind == &"half_hipped" else 0.0)
	var w := h * (1.0 - cut / rise)
	var ridge := maxf(f - w, 0.0)
	# Near-square hips become a four-face pyramid, never a forced short ridge.
	for side in [-1.0, 1.0]:
		var p := PackedVector3Array([Vector3(side * h, 0, -f), Vector3(side * h, 0, f)])
		if cut > 0.0 and cut < rise:
			p.append(Vector3(side * w, cut, f))
		p.append(Vector3(0, rise, ridge if cut < rise else f))
		if ridge > 0.0001 or cut == rise:
			p.append(Vector3(0, rise, -ridge if cut < rise else -f))
		if cut > 0.0 and cut < rise:
			p.append(Vector3(side * w, cut, -f))
		out.append(p)
	if cut < rise:
		for end_v in [-1.0, 1.0]:
			out.append(PackedVector3Array([Vector3(-w, cut, end_v * f),
				Vector3(w, cut, end_v * f), Vector3(0, rise, end_v * ridge)]))
	return out


## Two roof planes meet an off-centre ridge. This is a pitched gable with
## unequal slopes, not a decorative mesh laid over a symmetric roof. The end
## profile remains one continuous ridge across the full along span.
static func asymmetric_gable(span: float, along: float, rise: float,
		ridge_x: float) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	if minf(span, along) <= 0.0 or span <= 0.1 or rise <= 0.0:
		return out
	var half := span * 0.5
	var ridge := clampf(ridge_x, -half + 0.05, half - 0.05)
	var f := along * 0.5
	out.append(PackedVector3Array([
		Vector3(-half, 0.0, -f), Vector3(-half, 0.0, f),
		Vector3(ridge, rise, f), Vector3(ridge, rise, -f)]))
	out.append(PackedVector3Array([
		Vector3(half, 0.0, -f), Vector3(half, 0.0, f),
		Vector3(ridge, rise, f), Vector3(ridge, rise, -f)]))
	return out


## An off-axis upper half-hip. The lower end gable remains below the shoulder
## line. The side slopes meet the end hip triangles on that line, then the
## ridge ends at `ridge_half`; all shared points are built from the same
## interpolation so there are no gaps or overlapping roof skins.
static func asymmetric_half_hip(span: float, along: float, rise: float,
		ridge_x: float, ridge_half: float) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	if minf(span, along) <= 0.0 or span <= 0.1 or rise <= 0.0:
		return out
	var half := span * 0.5
	var f := along * 0.5
	var ridge := clampf(ridge_x, -half + 0.05, half - 0.05)
	var rz := clampf(ridge_half, 0.0, f - 0.001)
	var cut := rise * HALF_HIP
	var shoulder_left := lerpf(-half, ridge, cut / rise)
	var shoulder_right := lerpf(half, ridge, cut / rise)
	for side in [-1.0, 1.0]:
		out.append(PackedVector3Array([
			Vector3(side * half, 0.0, -f), Vector3(side * half, 0.0, f),
			Vector3(shoulder_left if side < 0.0 else shoulder_right, cut, f),
			Vector3(ridge, rise, rz), Vector3(ridge, rise, -rz),
			Vector3(shoulder_left if side < 0.0 else shoulder_right, cut, -f)]))
	out.append(PackedVector3Array([
		Vector3(shoulder_left, cut, -f), Vector3(shoulder_right, cut, -f),
		Vector3(ridge, rise, -rz)]))
	out.append(PackedVector3Array([
		Vector3(shoulder_left, cut, f), Vector3(shoulder_right, cut, f),
		Vector3(ridge, rise, rz)]))
	return out


## A ring of facets from the plan rectangle's own perimeter up to one apex.
##
## The base samples the RECTANGLE perimeter, not a circle inscribed in it, and
## that is deliberate on two counts. A circle would leave the four corners of
## the plan uncovered, and `wall_profile` asks "how high is the roof at this
## point?" for every crossing along a wall -- a NAN where a corner should be
## puts a hole in the wall head. And a rectangular base with a kink down the
## middle of each side is what a combed reed cone over a rectangular hut
## actually looks like, because the thatcher lays it facet by facet.
static func _cone(span: float, along: float, rise: float) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	var h := span * 0.5
	var f := along * 0.5
	var ring := PackedVector3Array()
	var corners := [Vector2(h, -f), Vector2(h, f), Vector2(-h, f), Vector2(-h, -f)]
	for i in range(corners.size()):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		for k in range(CONE_SIDES / 4):
			var p := a.lerp(b, float(k) / float(CONE_SIDES / 4))
			ring.append(Vector3(p.x, 0.0, p.y))
	for i in range(ring.size()):
		out.append(PackedVector3Array([ring[i], ring[(i + 1) % ring.size()],
			Vector3(0.0, rise, 0.0)]))
	return out


## How far below the ridge a dormer's rooflet must stop, so it dies into the
## host slope instead of bursting through the ridge line.
const DORMER_RIDGE_KEEP := 0.35


## Where a dormer sits on a slope, in the roof's own frame.
##
## Everything here is one question asked five ways: at what local X does the
## host plane reach a given height. Get that wrong and the dormer floats --
## which is exactly what the hotel did, by choosing a height as a fraction of
## the rise and never asking the roof where its surface actually was.
##
## `front` is the signed local X of the dormer's front face; its sign picks
## the slope. `lift` is how far the dormer's own eave stands above the host
## surface at that face, `rooflet` how far its ridge stands above its eave.
## Returns `fits` false when the slope cannot give the dormer a usable face --
## a shallow pitch or a front set too near the ridge. Never place a dormer on
## a seat that does not fit; the caller must not fall back to a fixed height.
static func dormer_seat(half: float, rise: float, front: float, width: float,
		lift := 1.15, rooflet := 0.45) -> Dictionary:
	var seat := {"fits": false}
	if half <= 0.0 or rise <= 0.0 or absf(front) >= half:
		return seat
	var slope: float = rise / half
	var s: float = signf(front) if absf(front) > 0.0001 else 1.0
	var base: float = rise - slope * absf(front)
	var eave: float = minf(base + lift, rise - slope * DORMER_RIDGE_KEEP - rooflet)
	if eave - base < 0.65:
		return seat
	# Local X at which the host plane is exactly this high, on `front`'s side.
	var at := func(h: float) -> float: return s * (rise - h) / slope
	var rh: float = (width + 0.25) * 0.5
	seat["fits"] = true
	seat["front"] = front
	seat["width"] = width
	seat["roof_half"] = rh
	seat["base"] = base
	seat["eave"] = eave
	seat["peak"] = eave + rooflet
	# where the dormer's eave line, its ridge, and its cheek top meet the host
	seat["side_x"] = at.call(eave)
	seat["peak_x"] = at.call(eave + rooflet)
	seat["cheek_x"] = at.call(eave + rooflet * (1.0 - width * 0.5 / rh))
	return seat


static func footprint(face: PackedVector3Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in face:
		out.append(Vector2(p.x, p.z))
	return out


static func plane_height(face: PackedVector3Array, at: Vector2) -> float:
	var n := (face[1] - face[0]).cross(face[2] - face[0])
	return face[0].y - (n.x * (at.x - face[0].x) + n.z * (at.y - face[0].z)) / n.y


## No host outside a face. Do not extrapolate a hip plane to place a dormer.
static func height_at(roof: Array[PackedVector3Array], at: Vector2) -> float:
	for face in roof:
		if Poly.contains_point(footprint(face), at, 0.0001):
			return plane_height(face, at)
	return NAN


static func lift(poly: PackedVector2Array, face: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in poly:
		out.append(Vector3(p.x, plane_height(face, p), p.y))
	return out


## Profile above a wall segment, including every crossing of a hip/ridge.
static func wall_profile(roof: Array[PackedVector3Array], a: Vector2, b: Vector2) -> PackedVector3Array:
	var ts: Array[float] = [0.0, 1.0]
	var d := b - a
	for face in roof:
		var poly := footprint(face)
		for i in range(poly.size()):
			var p := poly[i]
			var e := poly[(i + 1) % poly.size()] - p
			var cross := d.cross(e)
			if absf(cross) < 0.000001:
				continue
			var t := (p - a).cross(e) / cross
			var u := (p - a).cross(d) / cross
			if t > 0.0001 and t < 0.9999 and u >= -0.0001 and u <= 1.0001:
				if not ts.any(func(v: float) -> bool: return absf(v - t) < 0.0001):
					ts.append(t)
	ts.sort()
	var out := PackedVector3Array([Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y)])
	for i in range(ts.size() - 1, -1, -1):
		var p := a.lerp(b, ts[i])
		out.append(Vector3(p.x, maxf(0.0, height_at(roof, p) - DEPTH * 0.5), p.y))
	return out


## Subtract a convex opening as convex pieces. Each successive edge peels
## off its outside half-plane; this avoids hole rings and triangle fans
## spanning across an opening. The same clipper also handles roof valleys.
static func subtract(subject: PackedVector2Array, hole: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var inside := subject
	var cut := hole.duplicate()
	if Poly.signed_area(cut) < 0.0:
		cut.reverse()
	for i in range(cut.size()):
		var a := cut[i]
		var b := cut[(i + 1) % cut.size()]
		var outside := _half_plane(inside, b, a)
		if Poly.area(outside) > 0.000001:
			out.append(outside)
		inside = _half_plane(inside, a, b)
		if inside.size() < 3:
			break
	return out


static func _half_plane(poly: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if poly.size() < 3:
		return out
	var s := poly[poly.size() - 1]
	var ds := (b - a).cross(s - a)
	for e in poly:
		var de := (b - a).cross(e - a)
		if (de >= 0.0) != (ds >= 0.0):
			out.append(s.lerp(e, ds / (ds - de)))
		if de >= 0.0:
			out.append(e)
		s = e
		ds = de
	# Strip repeated/collinear vertices before the mesh fan is emitted.
	var clean := PackedVector2Array()
	for p in out:
		if clean.is_empty() or p.distance_squared_to(clean[clean.size() - 1]) > 1e-10:
			clean.append(p)
	if clean.size() > 1 and clean[0].distance_squared_to(clean[clean.size() - 1]) < 1e-10:
		clean.resize(clean.size() - 1)
	return clean


## Clip a roof face where another roof or solid wall top covers it. Equal
## planes belong to the earlier face, avoiding doubled skins at range joins.
static func exposed(face: PackedVector3Array, covers: Array[PackedVector3Array],
		own_index: int) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [footprint(face)]
	var bounds := _plan_bounds(face)
	for ci in range(covers.size()):
		if ci == own_index:
			continue
		var cover := covers[ci]
		if not bounds.intersects(_plan_bounds(cover)):
			continue
		var poly := footprint(cover)
		var hole := PackedVector2Array()
		var start := poly[-1]
		var bias := 0.00001 if ci < own_index else -0.00001
		var ds := plane_height(cover, start) - plane_height(face, start) + bias
		for end in poly:
			var de := plane_height(cover, end) - plane_height(face, end) + bias
			if (de > 0) != (ds > 0):
				hole.append(start.lerp(end, ds / (ds - de)))
			if de > 0:
				hole.append(end)
			start = end
			ds = de
		if Poly.area(hole) < 0.000001:
			continue
		var remaining: Array[PackedVector2Array] = []
		for piece in pieces:
			remaining.append_array(subtract(piece, hole))
		pieces = remaining
		if pieces.is_empty():
			break
	return pieces


static func _plan_bounds(face: PackedVector3Array) -> Rect2:
	var rect := Rect2(Vector2(face[0].x, face[0].z), Vector2.ZERO)
	for p in face:
		rect = rect.expand(Vector2(p.x, p.z))
	return rect
