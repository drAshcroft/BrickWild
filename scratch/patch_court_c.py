import io

p = 'src/house/house_builder.gd'
s = io.open(p, encoding='utf-8').read()

# ---- roof: a court is sky
old = '''func _build_roof() -> void:
	tag("roof")'''
new = '''## A court is SKY. The roof is the footprint MINUS the courts, and with only
## slabs and boxes to build from, the honest way to say that is to roof each
## RANGE rather than the whole box: a lean-to falling from the outer wall in
## to the courtyard eaves, which is what a range round a yard actually has
## (GEO-003).
func _build_court_roofs() -> void:
	tag("roof")
	var site: Rect2 = HouseGeometry.site_rect(spec)
	var wall_top: float = spec.height * _storeys()
	var rise: float = HouseGeometry.roof_rise(spec) * 0.7
	for ci in range(plan.courts.size()):
		var court: Rect2 = plan.courts[ci]["rect"]
		# one lean-to per side of the yard, each falling inward
		for side in [0, 1, 2, 3]:
			var band: Rect2
			match side:
				0: band = Rect2(site.position.x, site.position.y,
					site.size.x, court.position.y - site.position.y)
				1: band = Rect2(site.position.x, court.end.y,
					site.size.x, site.end.y - court.end.y)
				2: band = Rect2(site.position.x, court.position.y,
					court.position.x - site.position.x, court.size.y)
				_: band = Rect2(court.end.x, court.position.y,
					site.end.x - court.end.x, court.size.y)
			if band.size.x < 0.3 or band.size.y < 0.3:
				continue
			var horizontal: bool = side <= 1
			var span: float = band.size.y if horizontal else band.size.x
			var along: float = band.size.x if horizontal else band.size.y
			var outward := 1.0 if (side == 0 or side == 2) else -1.0
			var c: Vector2 = band.get_center()
			var yaw: float = 0.0 if horizontal else PI / 2.0
			var xf := Transform3D(Basis(Vector3.UP, yaw),
				Vector3(c.x, wall_top, c.y))
			_kit.lean_roof(span, along, 0.0, rise, outward if horizontal else -outward,
				SURF_ROOF, 0.0)
			var slab := AABB(Vector3(band.position.x, wall_top, band.position.y),
				Vector3(band.size.x, rise + 0.25, band.size.y))
			_log_mass("roof_court_%d_%d" % [ci, side], slab)
			total_height = maxf(total_height, wall_top + rise)


func _build_roof() -> void:
	if plan.has_court():
		_build_court_roofs()
		return
	tag("roof")'''
assert old in s, 'roof'
s = s.replace(old, new, 1)

# ---- floor: the court is paved ground, not a floor slab
old = '''		var shaped: int = _shaped_room(level)'''
new = '''		var holes: Array[int] = plan.courts_on(level)
		if not holes.is_empty():
			# The floor is laid round the yard, band by band, so the court is
			# left as open ground for the walk grid to rasterise.
			_emit_floor_round_courts(r, y0, t, level, holes)
			continue
		var shaped: int = _shaped_room(level)'''
assert old in s, 'floor'
s = s.replace(old, new, 1)

old = '''## The shaped room on `level`, or -1 when that storey is rectangular.'''
new = '''## The floor of a storey with a yard in it: four bands round the hole, so the
## court itself is left as ground.
func _emit_floor_round_courts(r: Rect2, y0: float, t: float, level: int,
		holes: Array[int]) -> void:
	var court: Rect2 = plan.courts[holes[0]]["rect"]
	for band in [
			Rect2(r.position.x, r.position.y, r.size.x, court.position.y - r.position.y),
			Rect2(r.position.x, court.end.y, r.size.x, r.end.y - court.end.y),
			Rect2(r.position.x, court.position.y, court.position.x - r.position.x, court.size.y),
			Rect2(court.end.x, court.position.y, r.end.x - court.end.x, court.size.y)]:
		if band.size.x < 0.05 or band.size.y < 0.05:
			continue
		box(Vector3(band.size.x, t, band.size.y),
			Vector3(band.get_center().x, y0 + t / 2.0, band.get_center().y),
			SURF_FLOOR)
	_log_mass("floor" if _levels().size() == 1 else "floor_%d" % level,
		AABB(Vector3(r.position.x, y0, r.position.y),
			Vector3(r.size.x, t, r.size.y)), y0)
	# and the yard itself, as paving a hand's breadth down
	if level == 0:
		var pav := 0.08
		box(Vector3(court.size.x, pav, court.size.y),
			Vector3(court.get_center().x, y0 - pav / 2.0, court.get_center().y),
			SURF_FLOOR)


## The shaped room on `level`, or -1 when that storey is rectangular.'''
assert old in s, 'floor helper'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('builder ok')
