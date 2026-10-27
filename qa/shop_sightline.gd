class_name ShopSightline
extends RefCounted
## What a customer standing in the street door of a shop can see of the
## furniture in the front room (LIVE-SHOPS, SHOP-<KIND>-TRAITS).
##
## The blind review judged a shop from one eye-level view along the inward door
## normal. This is that view as a rule: a piece is seen when its centre is
## inside the half field of view and no standing piece (1.5 m or taller) of the
## same room is across the line to it. tools/render_shop_trades.gd reports the
## same answer in plan_facts.json; ShopTradeSuite judges it.

const HALF_FOV := 40.0  # the review camera is 80 degrees across
const TALL := 1.5       # a piece this tall hides what is behind it


## {"from": Vector2, "dir": Vector2} -- the eye, just inside the street door,
## and the way it looks (into the front room).
static func door_pose(plan: HousePlan) -> Dictionary:
	var d := plan.entrance()
	if d < 0:
		return {}
	var pos: Vector2 = plan.doors[d]["pos"]
	var inside := -(plan.doors[d]["normal"] as Vector2)
	var rc: Vector2 = Rect2(HouseGeometry.room_floor_rect(plan, plan.entrance_room())).get_center()
	if (rc - pos).dot(inside) < 0.0:
		inside = -inside
	inside = inside.normalized()
	return {"pos": pos, "dir": inside, "from": pos + inside * 0.3}


static func sees(plan: HousePlan, pose: Dictionary, p: Dictionary) -> bool:
	var room := plan.entrance_room()
	if pose.is_empty() or int(p["room"]) != room:
		return false
	var from: Vector2 = pose["from"]
	var c: Vector2 = (p["rect"] as Rect2).get_center()
	var to := c - from
	if to.length() < 0.01:
		return true
	if rad_to_deg(absf((pose["dir"] as Vector2).angle_to(to))) > HALF_FOV:
		return false
	for q in plan.furniture:
		if q == p or int(q["room"]) != room or bool(q.get("mounted", false)):
			continue
		if PropCatalog.height(String(q["key"])) < TALL:
			continue
		if _seg_hits_rect(from, c, Rect2(q["rect"]).grow(-0.05)):
			return false
	return true


## The first floor-standing piece of this category in the front room that the
## door sees; {} if none is in view.
static func seen_of(plan: HousePlan, cat: String) -> Dictionary:
	var pose := door_pose(plan)
	for f in plan.furniture_of(plan.entrance_room()):
		var p: Dictionary = plan.furniture[f]
		if String(PropCatalog.category(String(p["key"]))) != cat or bool(p.get("mounted", false)):
			continue
		if sees(plan, pose, p):
			return p
	return {}


static func _seg_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false
