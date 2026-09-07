import io

p = 'tests/suites/house_qa_suite.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	_row_fixture(res)
	_step_fixture(res)'''
new = '''	_row_fixture(res)
	_roof_fixture(res)
	_step_fixture(res)'''
assert old in s, 'call'
s = s.replace(old, new)

old = '''## A dais is a step, not a wall, and a drop is not a step (CAS-010).'''
new = '''## Does the roof cover the house, and does it stay over it?
##
## Two questions a picture answers and no rule did. Both were found by looking
## at a render and then measured, and both were real:
##
##   COVER   `MeshKit.hip_roof_at` cut the long slopes back to 72% of the
##           length AND the hips back to 72% of the width, so the four corners
##           were covered by neither. A farmhouse was 4.5% open to the sky.
##   EXTENT  the half-hip slab was centred ON the gable plane, so half of it --
##           1.76 m of roof -- hung in the air beyond the end wall.
##
## Cover is a vertical ray on a 15 cm grid over the footprint: is any triangle
## above it. Extent is measured only ABOVE HALF THE RISE, because the porch
## canopy is meant to project and would otherwise be mistaken for the roof
## doing it. The roof types exercised are reported, so a sweep that quietly
## stopped producing hips would show up as a missing name rather than a pass.
const ROOF_STEP := 0.15
## What a verge or an eave may overhang, with a little room for the ridge cap
## and the bargeboard sitting proud of the slab.
const ROOF_OVERHANG_MAX := 0.55

static func _roof_fixture(res: SuiteResult) -> void:
	var kinds := {}
	for style in HouseSweep.styles():
		for i in range(12):
			var spec := HouseSpec.new()
			spec.style = style
			spec.width = 6.0 + float(i % 5) * 1.6
			spec.length = 7.0 + float(i % 7) * 1.5
			spec.height = 2.5
			spec.storeys = 1 + (i % 2)
			var plan: HousePlan = HouseGenerator.generate(spec, 73000 + i)
			var mesh: ArrayMesh = HouseBuilder.new().build(plan)
			var who := "%s seed=%d %s" % [String(style), 73000 + i,
				String(spec.roof_type)]
			kinds[spec.roof_type] = int(kinds.get(spec.roof_type, 0)) + 1
			res.checked += 1
			var cover: float = _roof_cover(mesh, spec)
			if cover < 0.999:
				res.fail("roof: %s leaves %.1f%% of the house open to the sky"
					% [who, (1.0 - cover) * 100.0])
			var out: float = _roof_reach(mesh, spec)
			if out > ROOF_OVERHANG_MAX:
				res.fail("roof: %s reaches %.2fm past the wall near the ridge, where a verge is %.2fm"
					% [who, out, ROOF_OVERHANG_MAX])
	res.note("roof        %d houses, roof types %s" % [
		HouseSweep.styles().size() * 12, str(kinds)])


## What fraction of the footprint has mesh above the wall head?
static func _roof_cover(mesh: ArrayMesh, spec: HouseSpec) -> float:
	var wall_top: float = spec.height * mini(spec.storeys, 3)
	var buckets: Dictionary = {}
	for si in range(mesh.get_surface_count()):
		for t in _triangles(mesh, si):
			if maxf(t[0].y, maxf(t[1].y, t[2].y)) < wall_top + 0.05:
				continue
			var lo := Vector2i(int(floor(minf(t[0].x, minf(t[1].x, t[2].x)))),
				int(floor(minf(t[0].z, minf(t[1].z, t[2].z)))))
			var hi := Vector2i(int(floor(maxf(t[0].x, maxf(t[1].x, t[2].x)))),
				int(floor(maxf(t[0].z, maxf(t[1].z, t[2].z)))))
			for cx in range(lo.x, hi.x + 1):
				for cz in range(lo.y, hi.y + 1):
					var key := Vector2i(cx, cz)
					if not buckets.has(key):
						buckets[key] = []
					buckets[key].append(t)
	var rect: Rect2 = HouseGeometry.interior_rect(spec)
	var hit := 0
	var total := 0
	var z: float = rect.position.y + ROOF_STEP * 0.5
	while z < rect.end.y:
		var x: float = rect.position.x + ROOF_STEP * 0.5
		while x < rect.end.x:
			total += 1
			for t2 in buckets.get(Vector2i(int(floor(x)), int(floor(z))), []):
				if Geometry2D.point_is_inside_triangle(Vector2(x, z),
						Vector2(t2[0].x, t2[0].z), Vector2(t2[1].x, t2[1].z),
						Vector2(t2[2].x, t2[2].z)):
					hit += 1
					break
			x += ROOF_STEP
		z += ROOF_STEP
	return float(hit) / float(maxi(total, 1))


## How far the roof reaches past the wall, measured above half the rise so a
## porch canopy cannot be mistaken for it.
static func _roof_reach(mesh: ArrayMesh, spec: HouseSpec) -> float:
	var site: Rect2 = HouseGeometry.site_rect(spec)
	var wall_top: float = spec.height * mini(spec.storeys, 3)
	var rise: float = HouseGeometry.roof_rise(spec)
	var out := 0.0
	for p in mesh.surface_get_arrays(HouseBuilder.SURF_ROOF)[Mesh.ARRAY_VERTEX]:
		if p.y < wall_top + rise * 0.5:
			continue
		out = maxf(out, maxf(site.position.x - p.x, p.x - site.end.x))
		out = maxf(out, maxf(site.position.y - p.z, p.z - site.end.y))
	return out


static func _triangles(mesh: ArrayMesh, surface: int) -> Array:
	var arr: Array = mesh.surface_get_arrays(surface)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var raw = arr[Mesh.ARRAY_INDEX]
	var idx: PackedInt32Array = raw if raw != null else PackedInt32Array()
	var out: Array = []
	var n: int = idx.size() if not idx.is_empty() else v.size()
	for i in range(0, n, 3):
		out.append(PackedVector3Array([
			v[idx[i]] if not idx.is_empty() else v[i],
			v[idx[i + 1]] if not idx.is_empty() else v[i + 1],
			v[idx[i + 2]] if not idx.is_empty() else v[i + 2]]))
	return out


## A dais is a step, not a wall, and a drop is not a step (CAS-010).'''
assert old in s, 'fixture body'
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
