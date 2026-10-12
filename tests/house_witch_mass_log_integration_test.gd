extends SceneTree
## Focused regression fixture for Witch decorative mass logging.
## Run: Godot --headless --path . --script res://tests/house_witch_mass_log_integration_test.gd

const SCALES: Array[float] = [0.75, 1.0, 1.4, 1.9]
const DECORATIVE_ROLES: Array[String] = [
	"witch_entry_knee_brace",
	"witch_service_door_hood",
	"witch_service_door_corbel",
]

var failures: Array[String] = []
var checked_cases := 0


func _init() -> void:
	for scale in SCALES:
		var spec := HouseSpec.new()
		spec.style = &"witch_hut"
		spec.trade = &"alchemist"
		spec.width = 9.5 * scale
		spec.length = 12.0 * scale
		spec.height = 2.7
		_check_case("alchemist scale=%.2f" % scale, spec,
			_seed_for("alchemist", scale), false)

	var domestic := HouseSpec.new()
	domestic.style = &"witch_hut"
	domestic.trade = &"none"
	domestic.width = 9.5
	domestic.length = 12.0
	domestic.height = 2.7
	_check_case("nontrade Witch", domestic, 74311, true)

	for failure in failures:
		printerr("FAIL ", failure)
	print("Witch mass-log integration: %d cases, %d failures" % [checked_cases, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _check_case(label: String, spec: HouseSpec, seed: int, expect_service: bool) -> void:
	var plan: HousePlan = HouseGenerator.generate(spec, seed)
	if plan == null:
		failures.append("%s seed=%d: plan did not generate" % [label, seed])
		return
	# Force the Witch entry canopy so its decorative braces are exercised for
	# every requested case, independent of the generator's porch chance.
	plan.spec.porch = true
	var service_door := false
	for door in plan.doors:
		if bool(door.get("witch_workshop_yard", false)):
			service_door = true
	var builder := HouseBuilder.new()
	var mesh: ArrayMesh = builder.build(plan, true)
	checked_cases += 1
	var who := "%s seed=%d" % [label, seed]

	var report: Dictionary = HouseQA.new().check(plan, builder)
	for failure in report["failures"]:
		if String(failure).begins_with("size_match:"):
			failures.append("%s: %s" % [who, String(failure)])

	var brace_count := _role_count(builder.component_log, "witch_entry_knee_brace")
	if brace_count != 2:
		failures.append("%s: expected two logged porch brace components; got %d" % [who, brace_count])
	if expect_service and not service_door:
		failures.append("%s: generated plan has no marked workshop-yard service door" % who)
	var hood_count := _role_count(builder.component_log, "witch_service_door_hood")
	var corbel_count := _role_count(builder.component_log, "witch_service_door_corbel")
	if service_door and hood_count != 1:
		failures.append("%s: service door has %d hood components, expected one" % [who, hood_count])
	if service_door and corbel_count != 2:
		failures.append("%s: service door has %d corbel components, expected two" % [who, corbel_count])

	for mass in builder.mass_log:
		var mass_name := String(mass.get("name", ""))
		if DECORATIVE_ROLES.has(mass_name):
			failures.append("%s: decorative component %s leaked into mass_log" % [who, mass_name])

	var parity: Dictionary = ComponentCheck.check(builder, mesh)
	for parity_failure in parity["failures"]:
		failures.append("%s: component mesh parity: %s" % [who, String(parity_failure)])
	if int(parity["checked"]) <= 0:
		failures.append("%s: component parity checked no emitted components" % who)
	print("CASE %s seed=%d service=%s braces=%d hood=%d corbels=%d size_match_failures=%d component_rows=%d parity_checked=%d" % [
		label, seed, service_door, brace_count, hood_count, corbel_count,
		_count_size_match(report["failures"]), builder.component_log.size(), int(parity["checked"])])


func _role_count(rows: Array, role: String) -> int:
	var count := 0
	for row in rows:
		if String(row.get("role", "")) == role:
			count += 1
	return count


func _count_size_match(rows: Array) -> int:
	var count := 0
	for row in rows:
		if String(row).begins_with("size_match:"):
			count += 1
	return count


func _seed_for(key: String, scale: float) -> int:
	return 21000 + absi(key.hash()) % 900 + int(scale * 100.0)
