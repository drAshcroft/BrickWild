extends RefCounted

var failures: Array[String] = []
var checks := 0

static func run() -> SuiteResult:
	var fixture = load("res://tests/suites/witchwork_cauldron_flue_suite.gd").new()
	fixture._run()
	var result := SuiteResult.new("Witchwork Cauldron flue")
	result.checked = fixture.checks
	for failure in fixture.failures:
		result.fail(failure)
	return result


func _run() -> void:
	# WITCH-SIZE: a hut is 7 x 9 m at most and has no separate Workshop bay, so
	# there is no independent Workshop Cauldron, bay aperture or flue to prove;
	# the shared Hall Cauldron is the only one. The bay/flue checks went with
	# the 9 x 12 and 17 x 18 cases they described.
	_check_size(7.0, 9.0, "small")

func _check_size(width: float, length: float, label: String) -> void:
	var spec := HouseSpec.new(1)
	spec.style = &"witch_hut"
	spec.trade = &"none"
	spec.width = width
	spec.length = length
	spec.height = 2.6
	var plan := HouseGenerator.generate(spec, 1, true)
	var workshop_station: Dictionary = {}
	var cooking_station: Dictionary = {}
	for row: Dictionary in plan.furniture:
		checks += 1
		if String(row.get("key", "")) != "Cauldron":
			continue
		checks += 1
		if String(row.get("heat_setting_id", "")) == "witchwork_cauldron":
			workshop_station = row
		checks += 1
		if int(row.get("room", -1)) == plan.hearth_room():
			cooking_station = row
	checks += 1
	if not plan.heat_settings.is_empty() or not workshop_station.is_empty():
		failures.append("small compact Witch gained an independent Workshop heat setting")
	checks += 1
	if cooking_station.is_empty():
		failures.append("small compact Witch lost its shared Hall Cauldron")
	var nav := HouseNavCheck.new().check(plan)
	checks += 1
	if not bool(nav.get("ok", false)):
		failures.append("%s heat-setting plan broke nav: %s" % [label, str(nav)])
	var builder := HouseBuilder.new()
	var shell: ArrayMesh = builder.build(plan, true)
	var audit := ComponentCheck.check(builder, shell)
	checks += 1
	if not bool(audit.get("ok", false)):
		failures.append("%s component audit failed: %s" % [label, str(audit.get("failures", []))])
	for row: Dictionary in builder.roof_opening_log:
		checks += 1
		if String(row.get("id", "")) == "witchwork_cauldron_flue":
			failures.append("small compact Witch emitted a separate bay aperture")
	for row: Dictionary in builder.component_log:
		checks += 1
		if String(row.get("host", "")) == "witchwork_cauldron_flue":
			failures.append("small compact Witch emitted a separate flue")
