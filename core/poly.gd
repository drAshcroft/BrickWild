class_name Poly
extends RefCounted
## 2D polygon helpers shared by polygon rooms (INT-014), village lots and
## roads (VIL-*), and moats. Every function is a static, pure function of its
## arguments -- there is no polygon "object" here, just PackedVector2Array in,
## PackedVector2Array or a number out, so callers can keep using whatever
## storage (room outline, lot boundary, road ribbon) they already have.
##
## Winding is not assumed on input (signed_area tells you what you were
## handed) but IS normalised internally wherever an algorithm needs a
## consistent hand (clip_convex, offset).

const ARC_STEPS := 12  ## point count for a quarter-turn of a rounded offset corner


## Unsigned area via the shoelace formula.
static func area(poly: PackedVector2Array) -> float:
	return absf(signed_area(poly))


## Shoelace formula, sign carries the winding: positive is counter-clockwise
## in the (x, y) plane used throughout this file (buildings' x/z footprint).
static func signed_area(poly: PackedVector2Array) -> float:
	var n: int = poly.size()
	if n < 3:
		return 0.0
	var s := 0.0
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


## True when `p` is inside `poly`, INCLUDING its edges -- a point sitting
## exactly on the boundary counts as inside. Callers rasterising a floor or
## testing furniture containment want that: a wall centred on the outline
## should not leave the room "outside its own room".
static func contains_point(poly: PackedVector2Array, p: Vector2, eps := 1e-6) -> bool:
	var n: int = poly.size()
	if n < 3:
		return false
	for i in range(n):
		if _on_segment(poly[i], poly[(i + 1) % n], p, eps):
			return true
	var inside := false
	var j: int = n - 1
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		if (a.y > p.y) != (b.y > p.y):
			var x_at: float = a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y)
			if p.x < x_at:
				inside = not inside
		j = i
	return inside


## Area of the intersection of two CONVEX polygons (Sutherland-Hodgman clip).
## Concave input gives the clip against the convex hull implied by the
## winding, which is wrong for a concave subject -- callers with concave
## shapes need a different algorithm, not offered here.
static func intersection_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	return area(clip_convex(a, b))


## Clip `subject` against convex `clip`, returning the (convex) overlap.
## Empty when they do not overlap.
static func clip_convex(subject: PackedVector2Array, clip: PackedVector2Array) -> PackedVector2Array:
	if subject.size() < 3 or clip.size() < 3:
		return PackedVector2Array()
	var clip_poly: PackedVector2Array = clip.duplicate()
	if signed_area(clip_poly) < 0.0:
		clip_poly.reverse()
	var output: PackedVector2Array = subject.duplicate()
	for i in range(clip_poly.size()):
		if output.is_empty():
			break
		var cp1: Vector2 = clip_poly[i]
		var cp2: Vector2 = clip_poly[(i + 1) % clip_poly.size()]
		var input_list: PackedVector2Array = output
		output = PackedVector2Array()
		var s: Vector2 = input_list[input_list.size() - 1]
		for e in input_list:
			var e_inside: bool = _left_of(cp1, cp2, e)
			var s_inside: bool = _left_of(cp1, cp2, s)
			if e_inside:
				if not s_inside:
					output.append(_line_intersect(s, e, cp1, cp2))
				output.append(e)
			elif s_inside:
				output.append(_line_intersect(s, e, cp1, cp2))
			s = e
	return output


## Grow (`d` > 0) or shrink (`d` < 0) `poly` by `d`, i.e. the boundary of the
## Minkowski sum/difference with a disc of radius |d|. Growing rounds each
## convex corner with an arc, which is what makes the area formula exact:
## new area = old area + perimeter * d + pi * d^2, for a convex `poly`.
## Shrinking just slides each edge inward along its normal -- concave results
## from a large shrink are not this function's problem, nothing here needs it
## yet.
static func offset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var n: int = poly.size()
	if n < 3 or is_equal_approx(d, 0.0):
		return poly.duplicate()
	var ccw: bool = signed_area(poly) >= 0.0
	var sign: float = 1.0 if ccw else -1.0
	var normals: Array[Vector2] = []
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var e: Vector2 = b - a
		if e.length() < 1e-9:
			normals.append(Vector2.ZERO)
		else:
			e = e.normalized()
			normals.append(Vector2(e.y, -e.x) * sign)
	var out := PackedVector2Array()
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		out.append(a + normals[i] * d)
		out.append(b + normals[i] * d)
		var ni: int = (i + 1) % n
		if d > 0.0 and normals[i].dot(normals[ni]) < 0.9999:
			var ang0: float = normals[i].angle()
			var ang1: float = normals[ni].angle()
			var delta: float = wrapf(ang1 - ang0, -PI, PI)
			var steps: int = maxi(1, int(ceil(absf(delta) / (PI * 0.5) * ARC_STEPS)))
			for s in range(1, steps):
				var t: float = float(s) / float(steps)
				var ang: float = ang0 + delta * t
				out.append(b + Vector2(cos(ang), sin(ang)) * d)
	return out


## Convex hull of a cloud of points (Andrew's monotone chain), counter-clockwise.
static func convex_hull(points: PackedVector2Array) -> PackedVector2Array:
	var pts: Array = []
	for p in points:
		pts.append(p)
	pts.sort_custom(func(a, b): return a.x < b.x if not is_equal_approx(a.x, b.x) else a.y < b.y)
	var n: int = pts.size()
	if n < 3:
		var out := PackedVector2Array()
		for p in pts:
			out.append(p)
		return out
	var lower: Array = []
	for p in pts:
		while lower.size() >= 2 and _cross(lower[lower.size() - 2], lower[lower.size() - 1], p) <= 0.0:
			lower.remove_at(lower.size() - 1)
		lower.append(p)
	var upper: Array = []
	for i in range(n - 1, -1, -1):
		var p: Vector2 = pts[i]
		while upper.size() >= 2 and _cross(upper[upper.size() - 2], upper[upper.size() - 1], p) <= 0.0:
			upper.remove_at(upper.size() - 1)
		upper.append(p)
	lower.remove_at(lower.size() - 1)
	upper.remove_at(upper.size() - 1)
	var out := PackedVector2Array()
	for p in lower:
		out.append(p)
	for p in upper:
		out.append(p)
	return out


static func bounding_rect(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var min_x: float = poly[0].x
	var max_x: float = poly[0].x
	var min_y: float = poly[0].y
	var max_y: float = poly[0].y
	for p in poly:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


## A rectangle as a four-point CCW polygon, for callers that want to compare
## the polygon path against the Rect2 path (WalkGrid rasterisation, for one).
static func from_rect(rect: Rect2) -> PackedVector2Array:
	var p := PackedVector2Array()
	p.append(rect.position)
	p.append(Vector2(rect.end.x, rect.position.y))
	p.append(rect.end)
	p.append(Vector2(rect.position.x, rect.end.y))
	return p


# ----------------------------------------------------------------- internals

static func _on_segment(a: Vector2, b: Vector2, p: Vector2, eps: float) -> bool:
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	var cross: float = ab.x * ap.y - ab.y * ap.x
	if absf(cross) > eps * maxf(ab.length(), 1.0):
		return false
	var dot: float = ap.dot(ab)
	if dot < -eps:
		return false
	if dot > ab.length_squared() + eps:
		return false
	return true


static func _left_of(a: Vector2, b: Vector2, p: Vector2) -> bool:
	return (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) >= 0.0


static func _line_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Vector2:
	var d1: Vector2 = p2 - p1
	var d2: Vector2 = p4 - p3
	var denom: float = d1.x * d2.y - d1.y * d2.x
	if absf(denom) < 1e-12:
		return p2
	var t: float = ((p3.x - p1.x) * d2.y - (p3.y - p1.y) * d2.x) / denom
	return p1 + d1 * t


static func _cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)


## ---------------------------------------------------------------- polylines

## The ribbon polygon a polyline of `points` sweeps at `half_width` -- the
## road/verge shape VIL-003 needs. Each vertex is pushed out along the
## bisector of its two segments (scaled by 1/cos(theta/2) so the ribbon keeps
## a constant WIDTH, which is what RoadCheck measures), the two sides are
## joined end to end, and the result is a closed polygon. Gentle polylines
## (bend radius >> half_width, which the road rules already require) give a
## simple polygon; a hairpin does not, and `is_simple()` is how a caller
## finds that out rather than this function guessing.
static func ribbon(points: PackedVector2Array, half_width: float) -> PackedVector2Array:
	var n: int = points.size()
	if n < 2 or half_width <= 0.0:
		return PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(n):
		var normal: Vector2 = _vertex_normal(points, i)
		left.append(points[i] + normal * half_width)
		right.append(points[i] - normal * half_width)
	var out := PackedVector2Array()
	for p in left:
		out.append(p)
	for i in range(n - 1, -1, -1):
		out.append(right[i])
	return out


## True when no two non-adjacent edges of `poly` cross -- i.e. the polygon is
## simple. Used on road ribbons, where a self-intersection means a bend
## tighter than the ribbon is wide.
static func is_simple(poly: PackedVector2Array, eps := 1e-6) -> bool:
	var n: int = poly.size()
	if n < 4:
		return n >= 3
	for i in range(n):
		var a1: Vector2 = poly[i]
		var a2: Vector2 = poly[(i + 1) % n]
		for j in range(i + 1, n):
			if j == i or (j + 1) % n == i or j == (i + 1) % n:
				continue
			var b1: Vector2 = poly[j]
			var b2: Vector2 = poly[(j + 1) % n]
			if _segments_cross(a1, a2, b1, b2, eps):
				return false
	return true


## The turn, in radians, at each interior vertex of a polyline. Index i of the
## result is the turn at `points[i + 1]`; a straight polyline is all zeros.
static func turns(points: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(1, points.size() - 1):
		var a: Vector2 = points[i] - points[i - 1]
		var b: Vector2 = points[i + 1] - points[i]
		if a.length() < 1e-9 or b.length() < 1e-9:
			out.append(0.0)
		else:
			out.append(absf(a.angle_to(b)))
	return out


## Circumradius of the three points -- the radius of the bend they describe.
## INF for three collinear points (no bend at all).
static func bend_radius(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ab: float = a.distance_to(b)
	var bc: float = b.distance_to(c)
	var ca: float = c.distance_to(a)
	var twice_area: float = absf((b - a).cross(c - a))
	if twice_area < 1e-9:
		return INF
	return ab * bc * ca / (2.0 * twice_area)


static func polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


static func _vertex_normal(points: PackedVector2Array, i: int) -> Vector2:
	var n: int = points.size()
	var prev_dir := Vector2.ZERO
	var next_dir := Vector2.ZERO
	if i > 0:
		prev_dir = (points[i] - points[i - 1]).normalized()
	if i < n - 1:
		next_dir = (points[i + 1] - points[i]).normalized()
	if prev_dir == Vector2.ZERO:
		prev_dir = next_dir
	if next_dir == Vector2.ZERO:
		next_dir = prev_dir
	var bisector: Vector2 = (prev_dir + next_dir)
	if bisector.length() < 1e-9:
		bisector = prev_dir
	bisector = bisector.normalized()
	var normal := Vector2(-bisector.y, bisector.x)
	var half_cos: float = normal.dot(Vector2(-prev_dir.y, prev_dir.x))
	if absf(half_cos) > 1e-3:
		normal /= half_cos
	return normal


static func _segments_cross(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2, eps: float) -> bool:
	var d1: Vector2 = a2 - a1
	var d2: Vector2 = b2 - b1
	var denom: float = d1.cross(d2)
	if absf(denom) < 1e-12:
		return false
	var t: float = (b1 - a1).cross(d2) / denom
	var u: float = (b1 - a1).cross(d1) / denom
	return t > eps and t < 1.0 - eps and u > eps and u < 1.0 - eps
