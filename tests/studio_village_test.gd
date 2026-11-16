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
	_check_vernacular(ui, descriptor)
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
	print("studio_village: descriptor controls, seed, water/edge roundtrip, regional controls and blueprint binding; %d failures" % failures.size())
	ui.queue_free()
	quit(0 if failures.is_empty() else 1)


## VILLAGE-VERNACULAR: the region pickers are the descriptor's, nothing is
## asked for until a region is chosen, and every combination the controls can
## make is a request the library takes and JSON keeps.
func _check_vernacular(ui, descriptor: Dictionary) -> void:
	var regions: Array = descriptor["vernacular"]["regions"]
	for opt in [ui.region_opt, ui.blend_opt, ui.roofs_opt, ui.paint_opt]:
		if opt.item_count != regions.size() + 1 or opt.get_item_metadata(0) != &"":
			failures.append("Region options drift from the descriptor")
		for i in range(regions.size()):
			if opt.get_item_metadata(i + 1) != StringName(regions[i]["id"]):
				failures.append("Region option identity drift")
	if not ui.region_opt.visible: failures.append("Region control hidden for a village")
	if ui.blend_opt.visible or ui.share_slider.visible: failures.append("Blend controls shown with no region")
	if not ui.vernacular().is_empty() or not ui._request(42).vernacular.is_empty():
		failures.append("A region was asked for before one was chosen")
	var pick := func(opt: OptionButton, id: String) -> void:
		for i in range(opt.item_count):
			if String(opt.get_item_metadata(i)) == id:
				opt.select(i)
		ui._controls_changed()
	pick.call(ui.region_opt, "cyclades")
	if ui.vernacular() != {"cyclades": 1.0}: failures.append("One region is not a plain blend: %s" % ui.vernacular())
	if not ui.blend_opt.visible or ui.share_slider.visible: failures.append("Blend picker wrong with one region")
	pick.call(ui.blend_opt, "norse")
	ui.share_slider.value = 0.3
	ui.coherence_slider.value = 0.5
	pick.call(ui.roofs_opt, "japanese")
	var v: Dictionary = ui.vernacular()
	var blend: Dictionary = v.get("blend", {})
	if not is_equal_approx(float(blend.get("cyclades", 0)), 0.7) or not is_equal_approx(float(blend.get("norse", 0)), 0.3) \
			or not is_equal_approx(float(v.get("coherence", 0)), 0.5) or v.get("groups", {}).get("roofs", {}) != {"japanese": 1.0}:
		failures.append("Blend, coherence or roofs lost: %s" % v)
	if not ui.share_slider.visible or not ui.coherence_slider.visible: failures.append("Share and coherence hidden in a blend")
	var req: BuildingRequest = ui._request(42)
	if not BuildingLibrary.validate(req).is_empty(): failures.append("Studio's blend refused: %s" % BuildingLibrary.validate(req))
	if BuildingRequest.from_json(req.to_json()).to_dict() != req.to_dict(): failures.append("Blend lost in request JSON")
	pick.call(ui.region_opt, "")
	if not ui.vernacular().is_empty() or ui.blend_opt.visible: failures.append("None did not clear the region")
	# VILLAGE-PLACE: the presets are the descriptor's; a place replaces the
	# region, brings its own wealth and upkeep to the sliders, and the sliders
	# then drive it
	var presets: Array = descriptor["vernacular"]["place"]["presets"]
	if ui.place_opt.item_count != presets.size() + 1: failures.append("Place options drift from the descriptor")
	if not ui.place_opt.visible: failures.append("Place control hidden for a village")
	for i in range(ui.place_opt.item_count):
		if String(ui.place_opt.get_item_metadata(i)) == "rotting_frontier":
			ui.place_opt.select(i)
	ui._place_picked()
	ui._controls_changed()
	var pv: Dictionary = ui.vernacular()
	if pv.get("place", {}).get("like", "") != "rotting_frontier" or float(pv["place"].get("upkeep", 1.0)) > 0.1 \
			or float(pv["place"].get("wealth", 1.0)) > 0.2:
		failures.append("A place did not bring its wealth and upkeep: %s" % pv)
	if ui.region_opt.visible or ui.blend_opt.visible: failures.append("Region pickers shown beside a place")
	ui.upkeep_slider.value = 0.9
	if not is_equal_approx(float(ui.vernacular()["place"]["upkeep"]), 0.9): failures.append("The upkeep slider does not drive a place")
	var preq: BuildingRequest = ui._request(42)
	if not BuildingLibrary.validate(preq).is_empty(): failures.append("Studio's place refused: %s" % BuildingLibrary.validate(preq))
	if BuildingRequest.from_json(preq.to_json()).to_dict() != preq.to_dict(): failures.append("Place lost in request JSON")
	ui.place_opt.select(0)
	ui._controls_changed()
	if not ui.vernacular().is_empty() or not ui.region_opt.visible: failures.append("None did not clear the place")
