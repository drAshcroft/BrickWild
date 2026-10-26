extends SceneTree
## Parity evidence for VillageShape (qa/village_shape.gd) against the survey's
## own `measure()` (tools/settlements/survey.py measure-plan): three plans,
## each written as a SitePlan and as VillageShape's metrics.
##
##   godot --headless --path . --script res://tools/shape_parity.gd
##   python -I -X utf8 tools/settlements/survey.py measure-plan \
##       --plan artifacts/shape/<name>.plan.json [--terrain <grid>] \
##       --out artifacts/shape/<name>.py.json
##
## then compare <name>.gd.json with <name>.py.json. `artifacts/shape/cases.json`
## lists each case's plan and terrain for the comparison. Planning the hamlet
## is about a minute each time (building measurement).

const EXPORTER := preload("res://tools/export_village_plan.gd")
const HAMLET := "res://tests/fixtures/site_requests/thorn-hamlet.json"
const MANAROLA := "res://tests/fixtures/terrain/manarola.json"
const OUT := "res://artifacts/shape"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var cases: Array = []
	var raw := FileAccess.get_file_as_string(HAMLET)
	var request: Dictionary = JSON.parse_string(raw)
	cases.append(_write("thorn_flat", _hamlet(request, raw, null), request, ""))
	cases.append(_write("thorn_manarola", _hamlet(request, raw, VillageTerrain.from_file(MANAROLA)),
		request, ProjectSettings.globalize_path(MANAROLA)))
	var spec := VillageSpec.new(4040)
	spec.population = 40
	spec.culture = &"english"
	spec.purpose = &"farming"
	spec.generate(spec.seed)
	cases.append(_write("native_40", VillageLotPlanner.plan(spec), {"city_id": "native-40"}, ""))
	# not one of the three asked for: a river village on steep ground, so the
	# water, bridge and house-on-contour branches are compared too
	var wet := VillageSpec.new(4141)
	wet.population = 90
	wet.culture = &"english"
	wet.purpose = &"farming"
	wet.water = &"river"
	wet.terrain = VillageTerrain.from_file(MANAROLA)
	wet.generate(wet.seed)
	cases.append(_write("river_90_manarola", VillageLotPlanner.plan(wet), {"city_id": "river-90"},
		ProjectSettings.globalize_path(MANAROLA)))
	var f := FileAccess.open(OUT.path_join("cases.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(cases, "\t") + "\n")
	f.close()
	quit(0)


func _hamlet(request: Dictionary, raw: String, ground: VillageTerrain) -> VillagePlan:
	var notes: Array[String] = []
	var spec: VillageSpec = EXPORTER.spec_from_request(request, raw, notes)
	spec.terrain = ground
	spec.generate(spec.seed)
	return VillageLotPlanner.plan(spec)


func _write(name: String, plan: VillagePlan, request: Dictionary, terrain: String) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var metrics := VillageShape.measure(plan)
	var ms := Time.get_ticks_msec() - t0
	var plan_path := OUT.path_join(name + ".plan.json")
	var f := FileAccess.open(plan_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(EXPORTER.site_plan(plan, request), "\t", true) + "\n")
	f.close()
	var gd_path := OUT.path_join(name + ".gd.json")
	f = FileAccess.open(gd_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(metrics, "\t", true) + "\n")
	f.close()
	print("%s: %d buildings, %d roads, measured in %d ms -> %s" % [
		name, plan.buildings.size(), plan.roads.size(), ms, gd_path])
	return {"name": name, "plan": ProjectSettings.globalize_path(plan_path),
		"gd": ProjectSettings.globalize_path(gd_path), "terrain": terrain}
