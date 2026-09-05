class_name VillageAssembler
extends RefCounted
## Turns a VillagePlan into a scene: the ground, the roads and the common as
## flat colour, and every building of the plan generated through BigGlade and
## set down at the transform the lot planner gave it -- furniture and lights
## included, because `BigGlade.instantiate()` brings them.
##
## The same split as the house and temple assemblers: everything above this
## file works in metres and polygons and never loads a model.

const GROUND := Color("6f7a4a")
const ROAD := Color("8a7b62")
const VERGE := Color("7a7f52")
const COMMON := Color("5f8a3f")
const LOT := Color("6a7546")
const WATER := Color("3e6a8a")
const SURF_GROUND := 0
const SURF_ROAD := 1
const SURF_COMMON := 2
const SURF_WATER := 3


## The whole village. `cutaway` takes the roofs off the plan-based buildings.
static func build(plan: VillagePlan, cutaway := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Village"
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = ground_mesh(plan)
	for i in range(ground.mesh.get_surface_count()):
		var m := StandardMaterial3D.new()
		m.albedo_color = [GROUND, ROAD, COMMON, WATER][i]
		m.roughness = 1.0
		ground.set_surface_override_material(i, m)
	root.add_child(ground)
	var houses := Node3D.new()
	houses.name = "Buildings"
	root.add_child(houses)
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var built: GeneratedBuilding = BigGlade.generate(b["request"])
		if built == null or not built.is_ok():
			continue
		var node: Node3D = BigGlade.instantiate(built, cutaway)
		if node == null:
			continue
		node.name = "%s_%d" % [String(b["kind"]), i]
		node.transform = b["transform"]
		houses.add_child(node)
	return root


## The ground plane, the roads with their verges, the commons and the water,
## as one flat mesh whose AABB spans the site -- which is what frames the
## camera.
static func ground_mesh(plan: VillagePlan) -> ArrayMesh:
	var kit := MeshKit.new(4)
	var site: Rect2 = plan.site
	kit.box(Vector3(site.size.x, 0.2, site.size.y),
		Vector3(site.get_center().x, -0.1, site.get_center().y), SURF_GROUND)
	for lot in plan.lots:
		_flat(kit, lot["poly"], 0.005, SURF_GROUND)
	for road in plan.roads:
		var pts: PackedVector2Array = road["points"]
		var half: float = float(road["width"]) * 0.5
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var d: Vector2 = b - a
			if d.length() < 0.01:
				continue
			var mid: Vector2 = (a + b) / 2.0
			var yaw: float = atan2(-d.y, d.x)
			kit.box(Vector3(d.length() + half * 0.5, 0.04, half * 2.0),
				Vector3(mid.x, 0.02, mid.y), SURF_ROAD, yaw)
	for c in plan.commons:
		_flat(kit, c["poly"], 0.03, SURF_COMMON)
	for w in plan.water:
		_flat(kit, w["poly"], 0.01, SURF_WATER)
	return kit.commit()


## A polygon as a fan of flat triangles at height `y`, both faces.
static func _flat(kit: MeshKit, poly: PackedVector2Array, y: float, surf: int) -> void:
	if poly.size() < 3:
		return
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	var st: SurfaceTool = kit.surface(surf)
	for t in range(0, tris.size(), 3):
		var a := Vector3(poly[tris[t]].x, y, poly[tris[t]].y)
		var b := Vector3(poly[tris[t + 1]].x, y, poly[tris[t + 1]].y)
		var c := Vector3(poly[tris[t + 2]].x, y, poly[tris[t + 2]].y)
		for tri in [[a, b, c], [a, c, b]]:
			var n: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
			for v in tri:
				st.set_normal(n)
				st.set_uv(Vector2.ZERO)
				st.add_vertex(v)


## The village in words: the form, who lives there, what stands on it.
static func sheet(plan: VillagePlan) -> String:
	var spec: VillageSpec = plan.spec
	var lines: Array[String] = ["%s -- a %s %s village of %d (%d households), %s culture, wealth %.2f"
		% [spec.variant_name, String(spec.form), String(spec.purpose), spec.population,
			spec.households, String(spec.culture), spec.wealth]]
	lines.append("site %.0f x %.0f m, %d roads, %d lots, %d buildings"
		% [plan.site.size.x, plan.site.size.y, plan.roads.size(), plan.lots.size(), plan.buildings.size()])
	var kinds := {}
	for b in plan.buildings:
		var req: BuildingRequest = b["request"]
		var key: String = String(req.kind) if req.kind != &"shop" else String(req.purpose)
		if req.kind == &"house":
			key = "%s %s" % [String(req.style), String(req.purpose)]
		kinds[key] = int(kinds.get(key, 0)) + 1
	for k in kinds:
		lines.append("  %d x %s" % [int(kinds[k]), k])
	var road_check := VillageRoadCheck.new()
	road_check.check(plan)
	lines.append(road_check.ascii_map(3.0))
	return "\n".join(lines)
