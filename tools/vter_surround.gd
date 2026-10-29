extends RefCounted
## VTER-VISUAL-SURROUND: what a viewer draws AROUND a built village. The built
## ground stops at the site rectangle (consumers own the terrain round it, so
## the mesh is never extended). This is RENDER-STAGE ONLY: the fixture grid
## beyond the site as a desaturated, distance-faded context mesh that meets the
## built ground at the site edge, a water sheet shaped by that grid at the
## fixture's water level, and the removal of the built skirt (the vertical wall
## round the site) from the DISPLAYED model. Nothing here touches the village
## mesh that is built, measured or checked.

const EDGE_STEP := 2.5   ## = VillageGroundSurface.CELL, so the join leaves no crack
const OUT_OFFSETS: Array[float] = [2.5, 5.0, 8.0, 12.0, 18.0, 26.0, 36.0, 50.0, 70.0,
	95.0, 130.0, 180.0, 250.0, 350.0, 500.0, 750.0, 1100.0, 1600.0, 2400.0]
const BLEND_M := 40.0    ## the built edge height eases to the fixture's over this
const SHORE_BAND := 0.25 ## a vertex this near the water or lower is under it
const BED_DEPTH := 2.5
const HAZE := Color(0.64, 0.68, 0.66)


## Returns {"nodes": [context, water], "floor_y": lowest y drawn} and hides the
## skirt in `model`. Add the nodes to the stage.
static func build(plan: VillagePlan, model: Node3D) -> Dictionary:
	var out := {"nodes": [], "floor_y": 0.0}
	if plan.ground == null or plan.ground.parent == null:
		return out
	strip_skirt(model, plan.site)
	var ground := plan.ground
	var parent := ground.parent
	var rect := plan.site
	var level := ground.water_level_m
	var has_water := not is_nan(level)
	var xs := _axis(rect.position.x, rect.end.x)
	var ys := _axis(rect.position.y, rect.end.y)
	var nx := xs.size()
	var ny := ys.size()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var raw := PackedFloat32Array()
	var floor_y := INF
	for j in range(ny):
		for i in range(nx):
			var p := Vector2(xs[i], ys[j])
			var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
			var d := p.distance_to(q)
			var far_h := parent.height_at(ground.to_parent(p))
			var edge_h := VillageBuilder.ground_height(plan, q)
			var h := lerpf(edge_h, far_h, smoothstep(0.0, BLEND_M, d))
			raw.append(h)
			var wet := has_water and h <= level + SHORE_BAND and d > 0.0
			if wet:
				h = minf(h, level - BED_DEPTH)
			floor_y = minf(floor_y, h)
			verts.append(Vector3(p.x, h, p.y))
			cols.append(_tint(parent, ground.to_parent(p), d, wet))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wet_tris := 0
	for v in range(verts.size()):
		st.set_color(cols[v])
		st.add_vertex(verts[v])
	for j in range(ny - 1):
		for i in range(nx - 1):
			var c := Vector2((xs[i] + xs[i + 1]) * 0.5, (ys[j] + ys[j + 1]) * 0.5)
			if rect.has_point(c):
				continue
			var a := j * nx + i
			var b := a + 1
			var cc := a + nx
			var dd := cc + 1
			for tri in [[a, b, cc], [b, dd, cc]]:
				for k in tri:
					st.add_index(k)
				if has_water and _any_wet(raw, tri, level):
					wet_tris += 1
					for k in tri:
						wst.add_vertex(Vector3(verts[k].x, level, verts[k].z))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "SurroundGround"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	out["nodes"].append(mi)
	if wet_tris > 0:
		wst.generate_normals()
		var wi := MeshInstance3D.new()
		wi.name = "SurroundWater"
		wi.mesh = wst.commit()
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(0.20, 0.38, 0.52, 0.82)
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.roughness = 0.12
		wm.metallic_specular = 0.8
		wm.cull_mode = BaseMaterial3D.CULL_DISABLED
		wi.material_override = wm
		_match_built_water(model, wm)
		wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out["nodes"].append(wi)
	if has_water:
		# under the built water inside the site there is no ground to see through to
		var bed := MeshInstance3D.new()
		bed.name = "SurroundBed"
		var pm := PlaneMesh.new()
		pm.size = rect.size
		bed.mesh = pm
		bed.position = Vector3(rect.get_center().x, level - BED_DEPTH, rect.get_center().y)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.36, 0.38, 0.33).srgb_to_linear()
		bm.roughness = 1.0
		bed.material_override = bm
		out["nodes"].append(bed)
	out["floor_y"] = floor_y
	out["water_tris"] = wet_tris
	return out


## The built water inside the site takes the surround's water material, so the
## two sheets read as one sea and not a glossy rectangle in a duller one.
static func _match_built_water(model: Node, wm: Material) -> void:
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var am := mi.mesh as ArrayMesh
		if am == null:
			continue
		for s in range(am.get_surface_count()):
			if am.surface_get_name(s) == "material_slot:%d" % VillageBuilder.SURF_WATER:
				mi.set_surface_override_material(s, wm)


## Axis stops: the outer offsets, then the rect span every EDGE_STEP, then out.
static func _axis(lo: float, hi: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for k in range(OUT_OFFSETS.size() - 1, -1, -1):
		a.append(lo - OUT_OFFSETS[k])
	var n := maxi(1, int(ceil((hi - lo) / EDGE_STEP)))
	for k in range(n + 1):
		a.append(lerpf(lo, hi, float(k) / float(n)))
	for k in range(OUT_OFFSETS.size()):
		a.append(hi + OUT_OFFSETS[k])
	return a


static func _any_wet(raw: PackedFloat32Array, tri: Array, level: float) -> bool:
	for k in tri:
		if raw[k] <= level + SHORE_BAND:
			return true
	return false


## Desaturated ground, steeper land greyer, easing to haze with distance.
static func _tint(parent: VillageTerrain, pp: Vector2, d: float, wet: bool) -> Color:
	var slope := clampf(parent.slope_at(pp) / 0.9, 0.0, 1.0)
	var c := Color(0.50, 0.58, 0.40).lerp(Color(0.46, 0.43, 0.38), slope)
	if wet:
		c = Color(0.36, 0.38, 0.33)
	var grey := (c.r + c.g + c.b) / 3.0
	c = c.lerp(Color(grey, grey, grey), 0.45)
	return c.lerp(HAZE, smoothstep(150.0, 3000.0, d) * 0.55).srgb_to_linear()


## Drop the triangles of the built ground that stand on the site's boundary
## line (the skirt: both faces of each wall quad). Displayed model only.
static func strip_skirt(model: Node, rect: Rect2) -> int:
	var removed := 0
	var seen := {}
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var am := mi.mesh as ArrayMesh
		if am == null or seen.has(am):
			continue
		seen[am] = true
		var box := am.get_aabb()
		if box.size.x < rect.size.x * 0.5:
			continue   # a prop, not the ground
		var fresh := ArrayMesh.new()
		for s in range(am.get_surface_count()):
			var arr := am.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx := PackedInt32Array()
			if arr[Mesh.ARRAY_INDEX] != null:
				idx = arr[Mesh.ARRAY_INDEX]
			else:
				idx.resize(v.size())
				for k in range(v.size()):
					idx[k] = k
			var keep := PackedInt32Array()
			for t in range(0, idx.size() - 2, 3):
				if _on_boundary(rect, v[idx[t]], v[idx[t + 1]], v[idx[t + 2]]):
					removed += 1
				else:
					keep.append(idx[t])
					keep.append(idx[t + 1])
					keep.append(idx[t + 2])
			arr[Mesh.ARRAY_INDEX] = keep
			fresh.add_surface_from_arrays(am.surface_get_primitive_type(s), arr)
			fresh.surface_set_material(s, am.surface_get_material(s))
			fresh.surface_set_name(s, am.surface_get_name(s))
		mi.mesh = fresh
	return removed


static func _on_boundary(rect: Rect2, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var e := 0.02
	for x in [rect.position.x, rect.end.x]:
		if absf(a.x - x) < e and absf(b.x - x) < e and absf(c.x - x) < e:
			return true
	for z in [rect.position.y, rect.end.y]:
		if absf(a.z - z) < e and absf(b.z - z) < e and absf(c.z - z) < e:
			return true
	return false
