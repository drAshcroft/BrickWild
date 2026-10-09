extends SceneTree
## Actual triangle contract for ordinary fireplace breasts and compatibility solids.
const ComponentCheck = preload("res://qa/component_check.gd")
const MeshKit = preload("res://core/mesh_kit.gd")
const MeshProbe = preload("res://qa/mesh_probe.gd")

class SolidCompatibilityBuilder extends HouseBuilder:
	func _is_ordinary_domestic_hearth() -> bool:
		return false

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	for fixture in [
		{"style": &"farmhouse", "seed": 7441},
		{"style": &"cottage", "seed": 7441},
		{"style": &"witch_hut", "seed": 7441},
	]:
		_check_ordinary_fixture(fixture)
	_check_solid_compatibility()
	for failure in failures:
		push_error(failure)
	print("house hearth mesh contract: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func _check_ordinary_fixture(fixture: Dictionary) -> void:
	var spec := HouseSpec.new(int(fixture["seed"]))
	spec.style = fixture["style"]
	spec.width = 11.0
	spec.length = 14.0
	var plan := HouseGenerator.generate(spec, spec.seed, true)
	var breast: Dictionary = HouseGeometry.hearth_breast(plan)
	var where := "%s seed=%d" % [String(spec.style), spec.seed]
	if breast.is_empty():
		_fail(where + ": fixture has no planned hearth breast")
		return
	var builder := HouseBuilder.new()
	builder.build(plan, true)
	var qa_errors: Array[String] = HouseQA.check_interior_details(plan, builder)
	if qa_errors.any(func(error: String): return error.contains("actual masonry missing")):
		_fail(where + ": QA still treats the intended open mouth as missing masonry")
	for role in ["hearth_breast_left", "hearth_breast_right", "hearth_breast_foot",
			"hearth_lintel", "hearth_breast_header", "hearth_jamb", "hearth_mantel"]:
		var count: int = _role_count(builder, role)
		var wanted := 2 if role == "hearth_jamb" else 1
		_expect(HouseQA._hearth_role_mesh_matches(builder, role, wanted),
			"%s: actual %s triangles absent or displaced" % [where, role])
		_expect(count == wanted, "%s: emitted %s count=%d expected=%d" % [where, role, count, wanted])
	_expect(HouseQA._hearth_opening_has_recess(plan, builder),
		where + ": open mouth does not reach the actual host-wall backing")
	_check_removed_component_control(plan, builder, where, "hearth_breast_left", 1)
	_check_removed_component_control(plan, builder, where, "hearth_lintel", 1)
	_check_removed_component_control(plan, builder, where, "hearth_breast_header", 1)
	_check_sealed_mouth_control(plan, builder, breast, where)
	_check_dimensions_and_back_gap(plan, builder, breast, where)
	_check_furniture_collision_negative(plan, builder, breast, where)

func _check_dimensions_and_back_gap(plan: HousePlan, builder: HouseBuilder,
		breast: Dictionary, where: String) -> void:
	var mass_found := false
	var expected: Rect2 = breast["rect"]
	for mass in builder.mass_log:
		if String(mass.get("name", "")) != "chimney_breast":
			continue
		var bounds: AABB = mass["aabb"]
		mass_found = absf(bounds.position.y - int(breast["storey"]) * plan.spec.height) < 0.001 \
			and absf(bounds.size.y - plan.spec.height) < 0.001 \
			and absf(bounds.position.x - expected.position.x) < 0.01 \
			and absf(bounds.position.z - expected.position.y) < 0.01 \
			and absf(bounds.size.x - expected.size.x) < 0.01 \
			and absf(bounds.size.z - expected.size.y) < 0.01
	_expect(mass_found, where + ": full-storey breast envelope dimensions drifted")
	_check_mass_dimensions_negative(plan, builder, where)
	for item in plan.furniture:
		if int(item["room"]) != int(breast["room"]) or PropCatalog.category(item["key"]) != "hearth":
			continue
		var hearth_width: float = PropCatalog.footprint(item["key"]).x * float(item.get("scale", 1.0))
		_expect(float(breast["width"]) >= hearth_width + 0.399,
			where + ": measured hearth no longer fits its breast")
		_expect(HouseFurnishArrangementCheck.back_gap(plan, item) <= 0.02,
			where + ": hearth back gap exceeds 20 mm")
		_check_back_gap_negative(plan, builder, breast, item, where)
		return
	_fail(where + ": fixture has no hearth furniture for the back-gap control")

func _check_mass_dimensions_negative(plan: HousePlan, builder: HouseBuilder,
		where: String) -> void:
	for index in range(builder.mass_log.size()):
		var mass: Dictionary = builder.mass_log[index]
		if String(mass.get("name", "")) != "chimney_breast":
			continue
		var original: AABB = mass["aabb"]
		mass["aabb"] = AABB(original.position, original.size + Vector3(0.0, 0.05, 0.0))
		builder.mass_log[index] = mass
		var errors := HouseQA.check_interior_details(plan, builder)
		var caught := errors.any(func(error: String):
			return error == "hearth_breast: structural mass dimensions or storey placement disagree with the planned breast")
		var restored_mass: Dictionary = builder.mass_log[index]
		restored_mass["aabb"] = original
		builder.mass_log[index] = restored_mass
		_expect(caught, where + ": full-storey mass dimension mutation escaped the existing QA predicate")
		return
	_fail(where + ": cannot find actual logged breast mass for dimension control")

func _check_back_gap_negative(plan: HousePlan, builder: HouseBuilder,
		breast: Dictionary, hearth: Dictionary, where: String) -> void:
	var index := plan.furniture.find(hearth)
	if index < 0:
		_fail(where + ": cannot select actual hearth record for back-gap control")
		return
	var original: Rect2 = hearth["rect"]
	var normal: Vector2 = breast["normal"]
	var foot: Vector2 = PropCatalog.footprint(String(hearth["key"])) * float(hearth.get("scale", 1.0))
	var back := Vector2(sin(float(hearth["yaw"])), cos(float(hearth["yaw"])))
	var face: Vector2 = breast["centre"] + normal * float(breast["depth"]) * 0.5
	var edge := original.get_center() + back * (foot.y * 0.5)
	var signed_gap: float = (edge - face).dot(normal)
	var direction := 1.0 if signed_gap >= 0.0 else -1.0
	hearth["rect"] = Rect2(original.position + normal * direction * 0.12, original.size)
	plan.furniture[index] = hearth
	var errors := HouseQA.check_interior_details(plan, builder)
	var caught := errors.any(func(error: String):
		return error == "hearth_breast: measured hearth does not fit or touch its surround")
	var restored_hearth: Dictionary = plan.furniture[index]
	restored_hearth["rect"] = original
	plan.furniture[index] = restored_hearth
	_expect(caught, where + ": 120 mm moved hearth escaped the existing back-gap QA predicate")

func _check_removed_component_control(plan: HousePlan, builder: HouseBuilder,
		where: String, role: String, expected_count: int) -> void:
	var row: Dictionary = {}
	for component in builder.component_log:
		if String(component.get("role", "")) == role:
			row = component
			break
	if row.is_empty():
		_fail(where + ": cannot select actual component for removal control: " + role)
		return
	var surface: int = HouseQA._logical_mesh_surface(builder.emitted_mesh,
		int(row["surface"]))
	if surface < 0:
		_fail(where + ": component logical material slot is not present: " + role)
		return
	var kit := MeshKit.new(1)
	kit.oriented_box(row["size"], row["xf"], 0)
	var want: PackedVector3Array = kit.commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var remaining: Dictionary = ComponentCheck.triangle_counts(want)
	var mutation: Dictionary = MeshProbe.remove_triangles(builder.emitted_mesh, surface,
		func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			var key := ComponentCheck.triangle_key(a, b, c)
			if int(remaining.get(key, 0)) <= 0:
				return false
			remaining[key] = int(remaining[key]) - 1
			return true)
	if int(mutation.get("removed_triangles", 0)) != 12:
		_fail(where + ": did not remove exactly 12 actual triangles for " + role)
		return
	var original_mesh: ArrayMesh = builder.emitted_mesh
	builder.emitted_mesh = mutation["mesh"]
	var removed_detected := not HouseQA._hearth_role_mesh_matches(builder, role, expected_count)
	builder.emitted_mesh = original_mesh
	_expect(removed_detected,
		where + ": same component-presence predicate accepted removed " + role)

func _check_sealed_mouth_control(plan: HousePlan, builder: HouseBuilder,
		breast: Dictionary, where: String) -> void:
	var mesh: ArrayMesh = builder.emitted_mesh
	var centre: Vector2 = breast["centre"]
	var n2: Vector2 = breast["normal"]
	var normal := Vector3(n2.x, 0.0, n2.y).normalized()
	var depth: float = float(breast["depth"])
	var aperture: Dictionary = HouseQA._hearth_mouth_metrics(builder, breast)
	if aperture.is_empty():
		_fail(where + ": cannot derive the mouth from its emitted foot, jambs, and lintel")
		return
	var opening_width: float = float(aperture["width"])
	var opening_height: float = float(aperture["height"])
	var mouth := Vector3(centre.x, float(aperture["center_y"]),
		centre.y) + normal * depth * 0.5
	var wall_surface: int = HouseQA._logical_mesh_surface(mesh, HouseBuilder.SURF_WALL)
	if wall_surface < 0:
		_fail(where + ": wall material slot is unavailable for the sealed-mouth control")
		return
	var seal_size := Vector3(0.04, opening_height, opening_width) if absf(normal.x) > 0.5 \
		else Vector3(opening_width, opening_height, 0.04)
	var sealed: Dictionary = MeshProbe.add_box(mesh, wall_surface,
		AABB(mouth - seal_size * 0.5, seal_size))
	if int(sealed.get("added_triangles", 0)) != 12:
		_fail(where + ": sealed-mouth mutation did not add 12 actual triangles")
		return
	var mutant := HouseBuilder.new()
	mutant.emitted_mesh = sealed["mesh"]
	# The predicate derives the mouth station from the actual emitted members;
	# retain those rows while changing only the assembled triangles.
	for row: Dictionary in builder.component_log:
		mutant.component_log.append(row.duplicate(true))
	_expect(not HouseQA._hearth_opening_has_recess(plan, mutant),
		where + ": same recess predicate accepted an actual sealed-mouth mesh")

func _check_furniture_collision_negative(plan: HousePlan, builder: HouseBuilder,
		breast: Dictionary, where: String) -> void:
	var original: Array[Dictionary] = plan.furniture.duplicate(true)
	plan.furniture.append({"key": "Table_Small", "room": int(breast["room"]),
		"rect": breast["rect"]})
	var errors := HouseQA.check_interior_details(plan, builder)
	var caught := errors.any(func(error: String):
		return error == "hearth_breast: furniture intersects masonry: Table_Small")
	_expect(caught, where + ": furniture collision with actual breast was waived")
	plan.furniture = original

func _role_count(builder: HouseBuilder, role: String) -> int:
	var count := 0
	for row in builder.component_log:
		if String(row.get("role", "")) == role and String(row.get("host", "")) == "hearth":
			count += 1
	return count

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _fail(message: String) -> void:
	failures.append(message)

func _check_solid_compatibility() -> void:
	var spec := HouseSpec.new(7441)
	spec.style = &"farmhouse"
	spec.width = 11.0
	spec.length = 14.0
	var plan := HouseGenerator.generate(spec, spec.seed, true)
	var builder := SolidCompatibilityBuilder.new()
	builder.build(plan, true)
	_expect(_role_count(builder, "chimney_breast") == 1,
		"solid compatibility path no longer emits its legacy component")
	_expect(_role_count(builder, "hearth_lintel") == 0,
		"solid compatibility path unexpectedly emits open-mouth members")
	var errors := HouseQA.check_interior_details(plan, builder)
	_expect(not errors.any(func(error: String): return error.begins_with("hearth_breast:")),
		"HouseQA misclassified an actual solid legacy/custom/trade/world breast")
