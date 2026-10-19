extends RefCounted
## vground: every model a village sets down stands on the ground, and the open
## land between lots is dressed (walk QA, Wolfmarch Green -- english farming,
## seed 1, the village the pins were taken in).
##
## The negative controls replay the two defects the walk found, on the same
## assembled scene: the bush sat on its buried stem stub (catalogue floor in
## place of its seat) and the yard cart sat on its declared, turned box (the
## old floor of -1.404 at the yard's 0.4 scale). Then a plain lift and a plain
## sink, so the check is shown to fire both ways.

const REQUEST := '{"enclosure": "none", "height": 1.0, "kind": "village", "length": 35.0, "material": "timber", "orientation": 0.0, "period": 1200, "purpose": "farming", "schema": "brickwild.request", "schema_version": 1, "seed": "1", "storeys": 1, "style": "english", "water": "none", "width": 40.0}'
## Dungeon_Cart's floor as the catalogue measured it from its declared box,
## before SceneBounds measured turned meshes by their vertices.
const OLD_CART_FLOOR := -1.404
const Decoration := preload("res://tests/village_decoration_test.gd")


static func run() -> SuiteResult:
	var res := SuiteResult.new("vground")
	var built: GeneratedBuilding = BrickWild.generate(BuildingRequest.from_json(REQUEST))
	res.checked += 1
	if built == null or not built.is_ok() or built.village == null:
		res.fail("Wolfmarch Green did not generate")
		return res
	var plan: VillagePlan = built.village
	var scene: Node3D = VillageAssembler.build(plan)

	# --- the positive case: the pinned village stands on its ground
	var check := VillageGroundCheck.new()
	var report: Dictionary = check.check(plan, scene)
	res.checked += 1
	for f in report["failures"]:
		res.fail("Wolfmarch Green: %s" % f)
	var stats: Dictionary = report["stats"]
	print("  vground: %d props, %d plants, %d yard models; worst gap %.3f m"
		% [stats["props"], stats["plants"], stats["yard"], stats["worst"]])
	res.checked += 1
	if int(stats["plants"]) < 20 or int(stats["yard"]) < 5:
		res.fail("the check measured too little to mean anything: %s" % str(stats))

	# --- the open ground is dressed, and only at a decoration above zero
	res.checked += 1
	var open_plants := plan.plants.filter(func(t: Dictionary) -> bool:
		return t.get("zone", &"") == &"open")
	if open_plants.size() < 6:
		res.fail("open ground: only %d plants in the open land between lots" % open_plants.size())
	res.checked += 1
	var plain: VillagePlan = Decoration._redressed(plan, 0.0, plan.spec.upkeep)
	if plain.plants.any(func(t: Dictionary) -> bool: return t.get("zone", &"") == &"open"):
		res.fail("open ground: decoration 0 still dressed the open land")
	var qa: Dictionary = VillageQA.new().check(plan, {}, false)
	res.checked += 1
	for f in qa["failures"]:
		res.fail("Wolfmarch Green QA: %s" % f)

	# --- negative controls, on the same scene
	var bush := _first(scene.get_node("Plants"), plan.plants, "Wild_Bush_Common")
	res.checked += 1
	if bush == null:
		res.fail("negative control: no Wild_Bush_Common in the pinned village to replay pin 1 with")
	else:
		var keep: Vector3 = bush.position
		var t: Dictionary = plan.plants[VillageGroundCheck._index_of(bush)]
		var s: float = float(t.get("scale", 1.0))
		bush.position.y = VillageBuilder.ground_height(plan, t["pos"]) - VillageAssembler.PLANT_SINK \
			- PropCatalog.floor_offset("Wild_Bush_Common") * s
		_expect_fail(res, check, plan, scene, "floats", "pin 1 replay (bush on its stem stub)")
		bush.position = keep
	var cart := _yard_model(scene, "Dungeon_Cart")
	res.checked += 1
	if cart == null:
		res.fail("negative control: no yard cart in the pinned village to replay pin 3 with")
	else:
		var keep2: Vector3 = cart.position
		var row_scale: float = cart.scale.x
		# where the old catalogue floor put it: its stand height less the old drop
		cart.position.y = keep2.y + PropCatalog.floor_offset("Dungeon_Cart") * row_scale \
			- OLD_CART_FLOOR * row_scale
		_expect_fail(res, check, plan, scene, "floats", "pin 3 replay (cart on its turned box)")
		cart.position = keep2
	var prop: Node3D = null
	for n in scene.get_node("Props").get_children():
		prop = n as Node3D
		break
	if prop != null:
		var keep3: Vector3 = prop.position
		prop.position.y -= 0.3
		_expect_fail(res, check, plan, scene, "sunk", "a prop pushed 0.3 m into the ground")
		prop.position = keep3
	var any_plant := scene.get_node("Plants").get_child(0) as Node3D
	var keep4: Vector3 = any_plant.position
	any_plant.position.y += 0.25
	_expect_fail(res, check, plan, scene, "floats", "a plant lifted 0.25 m")
	any_plant.position = keep4
	# and the scene, restored, is clean again: the controls changed nothing
	res.checked += 1
	if not check.check(plan, scene)["ok"]:
		res.fail("negative controls did not restore the scene")
	scene.free()
	return res


static func _expect_fail(res: SuiteResult, check: VillageGroundCheck, plan: VillagePlan,
		scene: Node3D, word: String, what: String) -> void:
	res.checked += 1
	var r: Dictionary = check.check(plan, scene)
	var hit := false
	for f in r["failures"]:
		hit = hit or String(f).contains(word)
	if not hit:
		res.fail("negative control: the ground check did not catch %s" % what)


static func _first(parent: Node, rows: Array, key: String) -> Node3D:
	for n in parent.get_children():
		var i := VillageGroundCheck._index_of(n)
		if i >= 0 and i < rows.size() and String(rows[i]["key"]) == key:
			return n as Node3D
	return null


static func _yard_model(scene: Node3D, key: String) -> Node3D:
	for b in scene.get_node("Buildings").get_children():
		for row in b.get_meta(&"stands", []):
			if String(row["key"]) == key:
				var n := b.get_node_or_null("Exterior/%s" % String(row["id"]))
				if n != null:
					return n as Node3D
	return null



# ------------------------------------------------- on given ground (VTER-GROUND-MESH)

## A small village (TERRAIN_POP people, its buildings measured once) on three
## grounds: a 30 % plane, Hallstatt's real hillside above its lake (the
## ground's own water: the shore merged into the terrain, no ground over the
## lake) -- both assembled, every model judged -- and a river the spec draws
## on a 15 % plane (the ground mesh alone: its bank carved into the slope,
## its crossings on their landings). Then, on the plane, one negative control
## per rule the ground check gained.
const VT := preload("res://tests/suites/village_terrain_plan_suite.gd")


## Suite `vgroundterrain`: kept out of `vground` (and so out of
## lane:village-fast) because measuring and assembling three villages on
## ground takes minutes where the flat suite takes seconds.
static func run_terrain() -> SuiteResult:
	var res := SuiteResult.new("vgroundterrain")
	_terrain(res)
	return res

const TERRAIN_POP := 20
const TERRAIN_SEED := 4242
## [ground, form, assemble, the spec's water]
const TERRAIN_CASES := [
	["plane_30", &"street", true, &"none"],
	["real30/hallstatt", &"green", true, &"none"],
	["plane_15", &"green", false, &"river"],
]


static func _terrain_spec(form: StringName, ground: VillageTerrain, water := &"none") -> VillageSpec:
	var s := VillageSpec.new(TERRAIN_SEED)
	s.population = TERRAIN_POP
	s.water = water
	s.generate(TERRAIN_SEED)
	s.form = form
	s.terrain = ground
	return s


static func _terrain(res: SuiteResult) -> void:
	var t0 := Time.get_ticks_msec()
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(_terrain_spec(&"street", null)))
	res.note("terrain: measured %d buildings once in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for case in TERRAIN_CASES:
		var case_jobs := jobs
		if case[3] != &"none":
			# a water village's programme is its own (a mill, a ferry)
			case_jobs = VillageLotPlanner.measure_all(VillageProgrammer.programme(
				_terrain_spec(&"street", null, case[3])))
		_terrain_case(res, case_jobs, case[0], case[1], case[2], case[3])


static func _terrain_case(res: SuiteResult, jobs: Array[Dictionary], ground_name: String, form: StringName,
		assemble: bool, water: StringName) -> void:
	var label := "%s/%s%s" % [ground_name, form, "" if water == &"none" else "/" + String(water)]
	var t0 := Time.get_ticks_msec()
	var plan := VillageLotPlanner.plan_measured(_terrain_spec(form, VT.terrain(ground_name), water), jobs)
	var plan_s := (Time.get_ticks_msec() - t0) / 1000.0
	res.checked += 1
	if plan.ground == null or plan.buildings.is_empty():
		res.fail("%s: not planned on its ground" % label)
		return
	t0 = Time.get_ticks_msec()
	var builder := VillageBuilder.new()
	var mesh := builder.build(plan)
	var build_s := (Time.get_ticks_msec() - t0) / 1000.0
	# the terrace and retaining walls are what they say they are
	res.checked += 1
	var comp: Dictionary = ComponentCheck.check(builder, mesh)
	if not comp["ok"]:
		res.fail("%s: the ground's components differ from its triangles: %s" % [label, str(comp.get("failures", comp)).left(300)])
	t0 = Time.get_ticks_msec()
	var scene: Node3D = null
	if assemble:
		scene = VillageAssembler.build(plan)
	else:
		scene = Node3D.new()
		var ground := MeshInstance3D.new()
		ground.name = "Ground"
		ground.mesh = mesh
		var rows: Array = []
		for row in builder.component_log:
			rows.append({"role": String(row["role"]), "host": String(row["host"]), "id": String(row["id"])})
		ground.set_meta(&"components", rows)
		scene.add_child(ground)
	var assemble_s := (Time.get_ticks_msec() - t0) / 1000.0
	var check := VillageGroundCheck.new()
	var report: Dictionary = check.check(plan, scene)
	res.checked += 1
	for f in (report["failures"] as Array).slice(0, 12):
		res.fail("%s: %s" % [label, f])
	if (report["failures"] as Array).size() > 12:
		res.fail("%s: and %d more" % [label, (report["failures"] as Array).size() - 12])
	var st: Dictionary = report["stats"]
	var surface := VillageGroundSurface.of(plan)
	res.note("%s: plan %.1f s, ground %.1f s, scene %.1f s; %d lots, %d buildings; %d pieces, %d risers (tallest %.2f m), %d terrace + %d retaining panels; models %d props, %d plants, %d yard (worst %.3f m); pads within %.3f m; seams %d (%d stepped), open %.3f m, layers %.3f m; terraced lots %d/%d named; water %d samples, worst %.3f m"
		% [label, plan_s, build_s, assemble_s, plan.lots.size(), plan.buildings.size(),
			int(surface.stats.get("pieces", 0)), int(surface.stats.get("risers", 0)), float(surface.stats.get("riser_max", 0.0)),
			builder.components("terrace_wall").size(), builder.components("retaining_wall").size(),
			int(st["props"]), int(st["plants"]), int(st["yard"]), float(st["worst"]), float(st.get("pad_worst", 0.0)),
			int(st.get("seam_samples", 0)), int(st.get("seam_steps", 0)), float(st.get("seam_gap_worst", 0.0)),
			float(st.get("layer_worst", 0.0)), int(st.get("terrace_named", 0)), int(st.get("terraced_lots", 0)),
			int(st.get("water_samples", 0)), float(st.get("water_worst", 0.0))])
	# the check measured something: steps to close, and on the assembled
	# grounds every building and some models
	res.checked += 1
	if int(st.get("seam_steps", 0)) < 20:
		res.fail("%s: only %d stepped seams -- the ground is not on a slope" % [label, int(st.get("seam_steps", 0))])
	res.checked += 1
	if (ground_name == "real30/hallstatt" or water != &"none") and int(st.get("water_samples", 0)) < 20:
		res.fail("%s: measured only %d points in the water" % [label, int(st.get("water_samples", 0))])
	if assemble:
		res.checked += 1
		if int(st.get("buildings", 0)) < plan.buildings.size() or int(st["plants"]) < 10 or int(st["yard"]) < 5:
			res.fail("%s: the check measured too little to mean anything: %s" % [label, str(st)])
		res.checked += 1
		if int(st.get("terraced_lots", 0)) < 1:
			res.fail("%s: no lot steps across a recorded terrace wall on a steep ground" % label)
	if ground_name == "plane_30":
		_terrain_controls(res, check, plan, scene)
	scene.free()


## One negative control per rule the ground check gained on given ground.
static func _terrain_controls(res: SuiteResult, check: VillageGroundCheck, plan: VillagePlan, scene: Node3D) -> void:
	var label := "plane_30 control"
	# a yard model set down at its centre's ground on the slope, as the
	# assembler did before (VTER-HOUSE-SLOPE's note): its downhill side floats
	var probe := VillageGroundCheck.GroundProbe.of((scene.get_node("Ground") as MeshInstance3D).mesh)
	var moved := false
	for b in scene.get_node("Buildings").get_children():
		if moved:
			break
		for row in b.get_meta(&"stands", []):
			var model := b.get_node_or_null("Exterior/%s" % String(row["id"])) as Node3D
			var key := String(row["key"])
			if model == null or float(row["y"]) > VillageAssembler.YARD_ON_DECK or not PropCatalog.known(key) \
					or PropCatalog.has_tag(key, PropCatalog.WALL_MOUNTED) or bool(row.get("mounted", false)):
				continue
			var at: Vector3 = VillageGroundCheck._to_scene(b.get_node("Exterior") as Node3D, scene) * model.position
			var size: Vector3 = PropCatalog.size(key)
			var radius := 0.5 * maxf(size.x, size.z) * absf(model.scale.x)
			var centre := probe.top(Vector2(at.x, at.z))
			var lowest := probe.lowest(Vector2(at.x, at.z), radius)
			if is_nan(centre) or centre - lowest < 0.12:
				continue
			var keep := model.position
			model.position.y += centre - lowest
			_expect_fail(res, check, plan, scene, "floats", "%s: a yard model at its centre's ground on the slope" % label)
			model.position = keep
			moved = true
			break
	res.checked += 1
	if not moved:
		res.fail("%s: no yard model on enough slope to replay the floating yard" % label)
	# a building off its platform
	var house := scene.get_node("Buildings").get_child(0) as Node3D
	var keep_xf := house.transform
	house.transform.origin.y += 0.3
	_expect_fail(res, check, plan, scene, "its platform is at", "%s: a building 0.3 m off its platform" % label)
	house.transform = keep_xf
	# the risers taken out: every step is an open seam
	var ground := scene.get_node("Ground") as MeshInstance3D
	var keep_mesh := ground.mesh
	ground.mesh = _mesh_without(keep_mesh, VillageBuilder.SURF_GROUND, true, 0.0, false)
	_expect_fail(res, check, plan, scene, "are open by more than", "%s: the risers removed" % label)
	# the yards laid twice, the second 0.3 m up: two layers, and off the pad
	ground.mesh = _mesh_without(keep_mesh, VillageBuilder.SURF_YARD, false, 0.3, true)
	_expect_fail(res, check, plan, scene, "two ground layers", "%s: a second yard layer 0.3 m up" % label)
	_expect_fail(res, check, plan, scene, "leaves its pad", "%s: a second yard layer 0.3 m up (the pads)" % label)
	ground.mesh = keep_mesh
	# the terrace walls not logged
	var keep_rows: Array = ground.get_meta(&"components", [])
	ground.set_meta(&"components", [])
	_expect_fail(res, check, plan, scene, "no terrace_wall component", "%s: the terrace walls unnamed" % label)
	ground.set_meta(&"components", keep_rows)
	res.checked += 1
	if not check.check(plan, scene)["ok"]:
		res.fail("%s: the terrain controls did not restore the scene" % label)


## A copy of `mesh` with, in surface `slot`, its vertical triangles dropped
## (`drop_vertical`), or its triangles laid again `lift` metres up (`twice`).
static func _mesh_without(mesh: ArrayMesh, slot: int, drop_vertical: bool, lift: float, twice: bool) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var name := mesh.surface_get_name(s)
		if int(name.trim_prefix("material_slot:")) == slot:
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var cs: Variant = arrays[Mesh.ARRAY_COLOR]
			var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var keep := PackedInt32Array()
			for t in range(0, vs.size() - 2, 3):
				var n := (vs[t + 2] - vs[t]).cross(vs[t + 1] - vs[t])
				if drop_vertical and n.length_squared() > 1e-14 and absf(n.normalized().y) < 0.05:
					continue
				keep.append_array([t, t + 1, t + 2])
			if twice:
				var again := keep.duplicate()
				for k in again:
					keep.append(-1 - k)
			var nv := PackedVector3Array()
			var nn := PackedVector3Array()
			var nc := PackedColorArray()
			var nu := PackedVector2Array()
			for k in keep:
				var i: int = k if k >= 0 else -1 - k
				nv.append(vs[i] + (Vector3.UP * lift if k < 0 else Vector3.ZERO))
				nn.append(ns[i])
				if cs is PackedColorArray and not (cs as PackedColorArray).is_empty():
					nc.append((cs as PackedColorArray)[i])
				if uv is PackedVector2Array and not (uv as PackedVector2Array).is_empty():
					nu.append((uv as PackedVector2Array)[i])
			arrays = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = nv
			arrays[Mesh.ARRAY_NORMAL] = nn
			if not nc.is_empty():
				arrays[Mesh.ARRAY_COLOR] = nc
			if not nu.is_empty():
				arrays[Mesh.ARRAY_TEX_UV] = nu
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_name(out.get_surface_count() - 1, name)
	return out
