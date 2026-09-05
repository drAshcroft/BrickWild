class_name VillageMeasure
extends RefCounted
## The handful of measurements every village check reads off a VillagePlan
## (VIL-006..009): where a building is, which way it looks, where its door
## is, where the common is. Kept in one place so the four checks agree on
## what "the front of a building" means -- the same reason HouseGeometry owns
## the house's numbers.


## The full architecture of building `b` in world XZ: eaves, porches, towers.
static func bounds_poly(b: Dictionary) -> PackedVector2Array:
	return Placement.world_rect(b["placement"], b["transform"], false)


## The walls' outline in world XZ.
static func footprint_poly(b: Dictionary) -> PackedVector2Array:
	return Placement.world_rect(b["placement"], b["transform"], true)


## Which way the building looks: its local -Z in world XZ.
static func front_dir(b: Dictionary) -> Vector2:
	var v: Vector3 = (b["transform"] as Transform3D).basis * Vector3(0.0, 0.0, -1.0)
	return Vector2(v.x, v.z).normalized()


## The middle of the front face of the walls -- where the door is.
static func front_mid(b: Dictionary) -> Vector2:
	var fp: Rect2 = b["placement"]["footprint"]
	var w: Vector3 = (b["transform"] as Transform3D) * Vector3(fp.position.x + fp.size.x / 2.0, 0.0, fp.position.y)
	return Vector2(w.x, w.z)


static func door(b: Dictionary) -> Vector2:
	var d: Vector3 = b["door"]
	return Vector2(d.x, d.z)


static func centre(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	if poly.is_empty():
		return c
	for p in poly:
		c += p
	return c / float(poly.size())


static func height(b: Dictionary) -> float:
	var a: AABB = b["placement"]["bounds"]
	return a.size.y


## The common's polygon, or an empty one.
static func common_poly(plan: VillagePlan) -> PackedVector2Array:
	if plan.commons.is_empty():
		return PackedVector2Array()
	return plan.commons[0]["poly"]


static func common_centre(plan: VillagePlan) -> Vector2:
	var c: PackedVector2Array = common_poly(plan)
	if c.is_empty():
		return plan.site.get_center()
	return Poly.bounding_rect(c).get_center()


## The village's gates: where roads cross the enclosure, or, for a village
## with no enclosure, where the through road meets the edge of the site.
static func gates(plan: VillagePlan) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for g in plan.gate_crossings:
		out.append(g["pos"])
	if not out.is_empty():
		return out
	for r in plan.roads_of_class(&"through"):
		var pts: PackedVector2Array = plan.roads[r]["points"]
		if pts.size() >= 2:
			out.append(pts[0])
			out.append(pts[pts.size() - 1])
	return out


## The shop business of a building, or &"" for anything that is not a shop.
static func business(b: Dictionary) -> StringName:
	var req: BuildingRequest = b["request"]
	return req.purpose if req.kind == &"shop" else &""


## Buildings whose shop business is `biz`.
static func shops_of(plan: VillagePlan, biz: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in range(plan.buildings.size()):
		if business(plan.buildings[i]) == biz:
			out.append(i)
	return out


## Least distance between two polygons; 0 when they touch or overlap.
static func poly_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	return VillageLotPlanner._poly_distance(a, b)


static func point_to_poly(p: Vector2, poly: PackedVector2Array) -> float:
	return VillageLotPlanner._point_to_poly(p, poly)


## Distance from a point to a polyline.
static func point_to_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	if pts.size() == 1:
		best = p.distance_to(pts[0])
	return best


## Is `p` on the site's boundary, within `eps`?
static func on_boundary(site: Rect2, p: Vector2, eps := 0.5) -> bool:
	return absf(p.x - site.position.x) <= eps or absf(p.x - site.end.x) <= eps \
		or absf(p.y - site.position.y) <= eps or absf(p.y - site.end.y) <= eps


## Which side of the site a boundary point is on: 0 west, 1 east, 2 south,
## 3 north, -1 none.
static func boundary_side(site: Rect2, p: Vector2, eps := 0.5) -> int:
	if absf(p.x - site.position.x) <= eps:
		return 0
	if absf(p.x - site.end.x) <= eps:
		return 1
	if absf(p.y - site.position.y) <= eps:
		return 2
	if absf(p.y - site.end.y) <= eps:
		return 3
	return -1


## Spearman's rank correlation of two equal-length lists.
static func spearman(xs: Array, ys: Array) -> float:
	var n: int = mini(xs.size(), ys.size())
	if n < 3:
		return 0.0
	var rx: Array = _ranks(xs.slice(0, n))
	var ry: Array = _ranks(ys.slice(0, n))
	var mx := 0.0
	var my := 0.0
	for i in range(n):
		mx += float(rx[i])
		my += float(ry[i])
	mx /= float(n)
	my /= float(n)
	var num := 0.0
	var dx := 0.0
	var dy := 0.0
	for i in range(n):
		var a: float = float(rx[i]) - mx
		var b: float = float(ry[i]) - my
		num += a * b
		dx += a * a
		dy += b * b
	if dx <= 0.0 or dy <= 0.0:
		return 0.0
	return num / sqrt(dx * dy)


static func _ranks(v: Array) -> Array:
	var idx: Array = []
	for i in range(v.size()):
		idx.append(i)
	idx.sort_custom(func(a, b) -> bool: return float(v[a]) < float(v[b]))
	var out: Array = []
	out.resize(v.size())
	var i := 0
	while i < idx.size():
		var j: int = i
		while j + 1 < idx.size() and is_equal_approx(float(v[idx[j + 1]]), float(v[idx[i]])):
			j += 1
		var r: float = float(i + j) / 2.0
		for k in range(i, j + 1):
			out[idx[k]] = r
		i = j + 1
	return out
