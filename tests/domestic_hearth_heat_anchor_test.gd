extends SceneTree
## Structural heat reach does not require a fictitious hearth furniture row.
func _initialize() -> void:
	var spec := HouseSpec.new(7441)
	spec.style = &"farmhouse"
	spec.width = 9.0
	spec.length = 12.0
	spec.height = 2.6
	var plan: HousePlan = HouseGenerator.generate(spec, spec.seed, true)
	var breast: Dictionary = HouseGeometry.hearth_breast(plan)
	var failures: Array[String] = []
	var proxy_hearth_rows := 0
	for piece: Dictionary in plan.furniture:
		if String(piece.get("cat", "")) == "hearth":
			proxy_hearth_rows += 1
	if breast.is_empty() or proxy_hearth_rows != 0:
		failures.append("fixture requires an actual shell breast without a proxy hearth row")
	else:
		var prep := {"zone": Rect2(breast["rect"]).grow(0.6)}
		var gap := HouseFurnishPlacement._cooking_prep_heat_gap(plan,
			int(breast["room"]), prep)
		if not is_finite(gap) or gap > HouseFurnishPlacement.MAX_COOKING_HEAT_GAP:
			failures.append("native breast did not provide a finite measured cooking reach")
	var no_host := HousePlan.new()
	no_host.spec = spec
	var missing_gap := HouseFurnishPlacement._cooking_prep_heat_gap(no_host, 0,
		{"zone": Rect2(Vector2.ZERO, Vector2.ONE)})
	if is_finite(missing_gap):
		failures.append("missing structural breast must stay fail-closed")
	for failure in failures:
		push_error(failure)
	print("domestic hearth heat anchor: 2 checks, %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)
