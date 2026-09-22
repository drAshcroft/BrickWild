class_name RoofOpeningCheck
extends RefCounted
## Is the hole in the roof a HOLE, and does what stands in it touch the roof?
##
## A dormer can be wrong in two ways that a coverage percentage and an
## attachment probe both miss. The host slope can still run across the opening,
## so the dormer is a box with roof behind its glazing. Or the cheek that
## should close the gap between the dormer and the slope can sit off that
## slope, leaving a slot of daylight down each side.
##
## Both are questions about the emitted mesh against the roof descriptor, so
## both are answered here rather than by eye.

## How far a cheek's lower edge may sit from the host slab underside before it
## is a gap or a burial. Slabs are 0.24 m thick, so this is well inside one.
const CHEEK_TOL := 0.06
## Clear of the opening's own rim, so a sample cannot land on the cut edge.
const OPENING_INSET := 0.12


## {ok, failures: PackedStringArray, openings: int, cheeks: int}
static func check(plan: HousePlan, builder: HouseBuilder,
		mesh: ArrayMesh) -> Dictionary:
	# Array, not PackedStringArray: a Packed* array is a VALUE type, so a
	# helper that appends to one passed as a parameter appends to a COPY and
	# its findings are silently lost. Both rules below reported nothing until
	# this was an Array.
	var failures: Array[String] = []
	var layout := HouseGeometry.roof_layout(plan)
	var faces: Array[PackedVector3Array] = layout["faces"]
	var openings := HouseGeometry.roof_openings(plan)
	var cheeks := 0
	if not faces.is_empty():
		for op in openings:
			if op["kind"] != &"dormer":
				_check_authored_cut(op, faces, builder, failures)
				continue
			_check_cut(op, faces, builder, failures)
		cheeks = _check_cheeks(layout, builder, failures)
	# A dormer the builder emitted that the descriptor does not know about is
	# as wrong as one it knows about and did not emit.
	var emitted := _emitted_dormers(builder)
	var planned := 0
	for op in openings:
		if op["kind"] == &"dormer":
			planned += 1
	if emitted.size() != planned:
		failures.append("%d dormers planned, %d emitted" % [planned, emitted.size()])
	var emitted_authored := builder.roof_opening_log.size()
	var authored := 0
	for op in openings:
		if op["kind"] != &"dormer":
			authored += 1
	if emitted_authored != authored:
		failures.append("%d authored roof openings planned, %d emitted" %
			[authored, emitted_authored])
	return {"ok": failures.is_empty(), "failures": PackedStringArray(failures),
		"openings": planned + authored, "cheeks": cheeks,
		"authored": authored}


## Nothing of the HOST face may remain over the opening. Sample the opening
## polygon's interior and require every main-roof face component to have been
## cut there -- measured on the emitted polygons, not on the descriptor that
## asked for the cut.
static func _check_cut(op: Dictionary, faces: Array[PackedVector3Array],
		builder: HouseBuilder, failures: Array[String]) -> void:
	var fi := int(op["face"])
	if fi < 0 or fi >= faces.size():
		return
	var poly: PackedVector2Array = op["polygon"]
	if poly.size() < 3:
		return
	var xf: Transform3D = HouseGeometry.roof_layout(builder.plan)["transform"]
	var inv := xf.affine_inverse()
	for sample in _interior_samples(poly):
		for c in builder.components("roof_face_"):
			var local := PackedVector2Array()
			for p in (c["points"] as PackedVector3Array):
				var lp: Vector3 = inv * p
				local.append(Vector2(lp.x, lp.z))
			if Poly.contains_point(local, sample):
				failures.append("%s: host face %s still covers (%.2f, %.2f)"
					% [op["id"], c["id"], sample.x, sample.y])
				return


## Authored holes may cross the ridge and therefore do not carry one face id.
## Probe every roof face that contains each interior sample, then verify no
## emitted `roof_face_` polygon still covers that point.
static func _check_authored_cut(op: Dictionary, faces: Array[PackedVector3Array],
		builder: HouseBuilder, failures: Array[String]) -> void:
	var poly: PackedVector2Array = op["polygon"]
	if poly.size() < 3:
		return
	var xf: Transform3D = HouseGeometry.roof_layout(builder.plan)["transform"]
	var inv := xf.affine_inverse()
	for sample in _interior_samples(poly):
		var on_host := false
		for face in faces:
			if Poly.contains_point(RoofShape.footprint(face), sample, 0.001):
				on_host = true
				break
		if not on_host:
			continue
		for c in builder.components("roof_face_"):
			var local := PackedVector2Array()
			for p in (c["points"] as PackedVector3Array):
				var lp: Vector3 = inv * p
				local.append(Vector2(lp.x, lp.z))
			if Poly.contains_point(local, sample, 0.001):
				failures.append("%s: roof face still covers authored opening at (%.2f, %.2f)"
					% [op["id"], sample.x, sample.y])
				return


## A few points comfortably inside the polygon: its centroid, and the centroid
## pulled towards each vertex so a non-convex or clipped outline is still
## probed away from its rim.
static func _interior_samples(poly: PackedVector2Array) -> PackedVector2Array:
	var centre := Vector2.ZERO
	for p in poly:
		centre += p
	centre /= float(poly.size())
	var out := PackedVector2Array([centre])
	for p in poly:
		var d: Vector2 = p - centre
		var len_d: float = d.length()
		if len_d <= OPENING_INSET * 1.5:
			continue
		out.append(centre + d.normalized() * (len_d - OPENING_INSET))
	return out


## A cheek closes the side of a dormer against the slope, so it MEETS that
## slope along an edge: two of its corners sit on the host slab underside and
## the rest of it stands above. Two rules follow, and both are needed.
##
## CONTACT -- at least two corners within tolerance of the host underside. One
## corner is a point, not a join, and zero corners is a cheek floating over the
## roof or sunk through it. An earlier version of this rule skipped everything
## ABOVE the slope as "the dormer's own wall", which silently excused exactly
## the lifted-cheek defect it was written to catch.
##
## NO BURIAL -- nothing anywhere on the cheek may hang below the underside.
static func _check_cheeks(layout: Dictionary, builder: HouseBuilder,
		failures: Array[String]) -> int:
	var faces: Array[PackedVector3Array] = layout["faces"]
	var inv: Transform3D = (layout["transform"] as Transform3D).affine_inverse()
	var checked := 0
	for c in builder.components():
		if not String(c["role"]).ends_with("_cheek"):
			continue
		checked += 1
		var pts: PackedVector3Array = c["points"]
		var touching := 0
		var nearest := INF
		var buried := 0.0
		var buried_at := Vector2.ZERO
		for i in range(pts.size()):
			var corner: Vector3 = inv * pts[i]
			var under := _under(faces, corner)
			if is_finite(under):
				var off: float = absf(corner.y - under)
				nearest = minf(nearest, off)
				if off <= CHEEK_TOL:
					touching += 1
			var b: Vector3 = inv * pts[(i + 1) % pts.size()]
			for t in [0.2, 0.4, 0.6, 0.8]:
				var p: Vector3 = corner.lerp(b, t)
				var pu := _under(faces, p)
				if not is_finite(pu):
					continue
				var dip: float = pu - p.y
				if dip > buried:
					buried = dip
					buried_at = Vector2(p.x, p.z)
		if touching < 2:
			failures.append("%s: cheek meets the host slope at %d corners, nearest %.3fm"
				% [c["id"], touching, nearest if is_finite(nearest) else -1.0])
		if buried > CHEEK_TOL:
			failures.append("%s: cheek hangs %.3fm below the host slope at (%.2f, %.2f)"
				% [c["id"], buried, buried_at.x, buried_at.y])
	return checked


## Height of the host slab UNDERSIDE at a roof-local point, or NAN when the
## point is off every face. RoofShape reports the slab mid-plane.
static func _under(faces: Array[PackedVector3Array], p: Vector3) -> float:
	var host := RoofShape.height_at(faces, Vector2(p.x, p.z))
	return host - RoofShape.DEPTH * 0.5 if is_finite(host) else NAN


static func _emitted_dormers(builder: HouseBuilder) -> PackedStringArray:
	var out := PackedStringArray()
	for c in builder.component_log:
		var h: String = c["host"]
		if h.begins_with("dormer") and not out.has(h):
			out.append(h)
	return out
