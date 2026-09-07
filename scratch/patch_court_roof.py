import io

p = 'src/house/house_builder.gd'
s = io.open(p, encoding='utf-8').read()

start = s.index('func _build_court_roofs() -> void:')
end = s.index('func _build_roof() -> void:')
new = '''func _build_court_roofs() -> void:
	tag("roof")
	var site: Rect2 = HouseGeometry.site_rect(spec)
	var wall_top: float = spec.height * _storeys()
	var rise: float = HouseGeometry.roof_rise(spec) * 0.7
	for ci in range(plan.courts.size()):
		var court: Rect2 = plan.courts[ci]["rect"]
		for side in range(4):
			var band: Rect2
			var outer: float
			var inner: float
			var horizontal: bool = side <= 1
			match side:
				0:
					band = Rect2(site.position.x, site.position.y,
						site.size.x, court.position.y - site.position.y)
					outer = site.position.y
					inner = court.position.y
				1:
					band = Rect2(site.position.x, court.end.y,
						site.size.x, site.end.y - court.end.y)
					outer = site.end.y
					inner = court.end.y
				2:
					band = Rect2(site.position.x, court.position.y,
						court.position.x - site.position.x, court.size.y)
					outer = site.position.x
					inner = court.position.x
				_:
					band = Rect2(court.end.x, court.position.y,
						site.end.x - court.end.x, court.size.y)
					outer = site.end.x
					inner = court.end.x
			if band.size.x < 0.3 or band.size.y < 0.3:
				continue
			# One sloping plate to a range, falling from the outer wall in to
			# the courtyard eaves -- which is what a cloister range has, and
			# the only roof shape that leaves the yard open.
			var lo: float = band.position.x if horizontal else band.position.y
			var hi: float = band.end.x if horizontal else band.end.y
			var quad := PackedVector3Array()
			if horizontal:
				quad.append(Vector3(lo, wall_top + rise, outer))
				quad.append(Vector3(hi, wall_top + rise, outer))
				quad.append(Vector3(hi, wall_top, inner))
				quad.append(Vector3(lo, wall_top, inner))
			else:
				quad.append(Vector3(outer, wall_top + rise, lo))
				quad.append(Vector3(outer, wall_top + rise, hi))
				quad.append(Vector3(inner, wall_top, hi))
				quad.append(Vector3(inner, wall_top, lo))
			_kit.slab_poly(quad, 0.24, SURF_ROOF)
			_log_mass("roof_court_%d_%d" % [ci, side],
				AABB(Vector3(band.position.x, wall_top, band.position.y),
					Vector3(band.size.x, rise + 0.25, band.size.y)))
			total_height = maxf(total_height, wall_top + rise)


'''
s = s[:start] + new + s[end:]
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('written')
