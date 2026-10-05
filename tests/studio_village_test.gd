extends SceneTree
## Descriptor-driven UI contract without furnishing an entire settlement.
var failures: Array[String] = []
func _init() -> void:
	var scene: PackedScene = load("res://scenes/studio.tscn")
	var ui = scene.instantiate()
	ui.auto_generate = false
	root.add_child(ui)
	await process_frame
	var found := false
	for i in range(ui.kind_opt.item_count):
		if ui.kind_opt.get_item_metadata(i) == &"village":
			ui.kind_opt.select(i)
			found = true
	if not found: failures.append("Village missing from kind menu")
	ui._on_kind_changed()
	var descriptor := BrickWild.describe_kind(&"village")
	for pair in [[ui.style_opt, "styles"], [ui.trade_opt, "purposes"], [ui.water_opt, "waters"], [ui.edge_opt, "enclosures"]]:
		var options: OptionButton = pair[0]
		var expected: Array = descriptor[pair[1]]
		if options.item_count != expected.size(): failures.append("Option count drift: " + pair[1])
		for i in range(expected.size()):
			if options.get_item_metadata(i) != expected[i]["id"]: failures.append("Option identity drift")
	if not ui.water_opt.visible or not ui.edge_opt.visible: failures.append("Landscape controls hidden")
	if not ui.decoration_slider.visible or not ui.upkeep_slider.visible: failures.append("Appearance controls hidden")
	if ui.decoration_slider.value != 0.5 or ui.upkeep_slider.value != 1.0: failures.append("Appearance defaults drift")
	ui.decoration_slider.value = 0.9
	ui.upkeep_slider.value = 0.2
	var selected: BuildingRequest = ui._request(42)
	if selected.decoration_level != 0.9 or selected.upkeep != 0.2: failures.append("Appearance controls lost in request")
	if not ui.info_label.text.contains("Grow village"): failures.append("Slider does not defer generation")
	if ui.seed_input.text.is_empty(): failures.append("Seed input missing")
	var request := BrickWild.default_request(&"village", 42)
	request.length = 0
	request.water = &"pond"
	request.enclosure = &"hedge"
	if not BuildingLibrary.validate(request).is_empty(): failures.append("Descriptor's zero wealth refused")
	var roundtrip := BuildingRequest.from_json(request.to_json())
	if roundtrip.water != request.water or roundtrip.enclosure != request.enclosure: failures.append("Landscape request roundtrip lost inputs")
	request.enclosure = &"wall"
	if BuildingLibrary.validate(request).is_empty(): failures.append("Impossible small-village wall accepted")
	var plan := VillagePlan.new(VillageSpec.new(42))
	plan.site = Rect2(-20, -20, 40, 40)
	ui.bp_view.setup_village(plan)
	if ui.bp_view.village != plan or ui.bp_view.spec != null: failures.append("Blueprint did not retain the village plan")
	for fail in failures: print("FAIL " + fail)
	print("studio_village: descriptor controls, seed, water/edge roundtrip and blueprint binding; %d failures" % failures.size())
	ui.queue_free()
	quit(0 if failures.is_empty() else 1)
