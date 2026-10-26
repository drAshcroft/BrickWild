extends SceneTree
## HOUSE-WALL-OVERRIDE: a wall thickness the caller sets on a HouseSpec
## survives HouseGenerator.generate, and the published footprint is measured
## against it. A spec left at the default still takes its style's `wall_t`.
## Run: godot --headless --script res://tests/house_wall_thickness_override_test.gd
##
## 62b60eb made generate() write the style's `wall_t` (or -1) unconditionally,
## which dropped a caller's override without a word: PaperFjord's thin paper
## shell (0.12 m on a stone house) became 0.6 m, and every measured footprint
## moved 0.48 m inward under an unchanged roof.

var failures: Array[String] = []


func _init() -> void:
	_check_caller_override_survives()
	_check_style_wall_t_still_applies()
	_check_default_style_has_no_override()
	for failure in failures:
		printerr("FAIL " + failure)
	print("house wall thickness override: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)


func _spec(style: StringName, material: StringName) -> HouseSpec:
	var spec := HouseSpec.new()
	spec.style = style
	spec.material = material
	spec.width = 7.0
	spec.length = 7.5
	spec.storeys = 2
	return spec


func _check_caller_override_survives() -> void:
	for style: StringName in [&"cottage", &"townhouse", &"mediterranean"]:
		var spec := _spec(style, &"stone")
		spec.wall_thickness_override = 0.12
		var plan := HouseGenerator.generate(spec, 41277, false)
		var t := HouseGeometry.wall_thickness(plan.spec)
		if not is_equal_approx(t, 0.12):
			failures.append("%s: caller's 0.12 m wall came back as %.3f m" % [style, t])
		# The adapter's footprint: the top storey's rect inside its walls.
		var footprint := HouseGeometry.storey_rect(plan, maxi(plan.spec.storeys - 1, 0)) \
				.grow(-HouseGeometry.wall_thickness(plan.spec))
		var site := HouseGeometry.storey_rect(plan, maxi(plan.spec.storeys - 1, 0))
		if not is_equal_approx(site.size.x - footprint.size.x, 0.24):
			failures.append("%s: footprint is %.3f m inside the walls' outer face, wanted 0.12" % [
				style, (site.size.x - footprint.size.x) * 0.5])


func _check_style_wall_t_still_applies() -> void:
	# Negative control for the fix: a fresh spec is untouched by it.
	var spec := _spec(&"mediterranean", &"plaster")
	var plan := HouseGenerator.generate(spec, 41277, false)
	var t := HouseGeometry.wall_thickness(plan.spec)
	if not is_equal_approx(t, 0.45):
		failures.append("mediterranean's own wall_t 0.45 came back as %.3f m" % t)


func _check_default_style_has_no_override() -> void:
	var spec := _spec(&"cottage", &"stone")
	var plan := HouseGenerator.generate(spec, 41277, false)
	if plan.spec.wall_thickness_override > 0.0:
		failures.append("cottage (no wall_t) acquired an override of %.3f" % plan.spec.wall_thickness_override)
	if not is_equal_approx(HouseGeometry.wall_thickness(plan.spec), 0.6):
		failures.append("a stone cottage's wall is %.3f m, wanted the material's 0.6" % \
				HouseGeometry.wall_thickness(plan.spec))
