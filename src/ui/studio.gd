extends Control
## Blueprint Studio.
## Left panel: kind (church / castle) + width / length / height sliders + style
##   dropdown.
## Center: 3D preview (SubViewport) of the selected variant, with the blueprint
##   sheet below it.
## Right: variant list.
##
## The two generators are kept behind one `_build()` switch rather than two
## parallel UIs: everything the panel does -- slider ranges, the style list, the
## info line, framing the camera -- is a function of the kind, so adding the
## castle meant describing it, not duplicating the studio.

const VARIANTS := 6
const SHEET_HEIGHT := 300.0
const HOUSE_SHEET_HEIGHT := 470.0

@onready var viewport: SubViewport = $HSplit/CenterCol/ViewportPanel/SubViewport
@onready var bp_panel: PanelContainer = $HSplit/CenterCol/BPPanel
@onready var bp_view: BlueprintView = $HSplit/CenterCol/BPPanel/BlueprintView
@onready var width_slider: HSlider = $HSplit/LeftPanel/Margin/Grid/WidthSlider
@onready var length_slider: HSlider = $HSplit/LeftPanel/Margin/Grid/LengthSlider
@onready var height_slider: HSlider = $HSplit/LeftPanel/Margin/Grid/HeightSlider
@onready var storeys_slider: HSlider = $HSplit/LeftPanel/Margin/Grid/StoreysSlider
@onready var storeys_label: Label = $HSplit/LeftPanel/Margin/Grid/StoreysLabel
@onready var cutaway_button: CheckButton = $HSplit/LeftPanel/Margin/Grid/CutawayButton
@onready var cutaway_label: Label = $HSplit/LeftPanel/Margin/Grid/CutawayLabel
@onready var width_label: Label = $HSplit/LeftPanel/Margin/Grid/WidthLabel
@onready var length_label: Label = $HSplit/LeftPanel/Margin/Grid/LengthLabel
@onready var height_label: Label = $HSplit/LeftPanel/Margin/Grid/HeightLabel
@onready var kind_opt: OptionButton = $HSplit/LeftPanel/Margin/Grid/KindOption
@onready var style_label: Label = $HSplit/LeftPanel/Margin/Grid/StyleLabel
@onready var style_opt: OptionButton = $HSplit/LeftPanel/Margin/Grid/StyleOption
@onready var trade_opt: OptionButton = $HSplit/LeftPanel/Margin/Grid/TradeOption
@onready var trade_label: Label = $HSplit/LeftPanel/Margin/Grid/TradeLabel
@onready var variant_list: ItemList = $HSplit/RightPanel/VBox/VariantList
@onready var info_label: Label = $HSplit/CenterCol/InfoLabel
@onready var cam_root: Node3D = viewport.get_node("CamRig")

var specs: Array = []
var meshes: Array[ArrayMesh] = []
var buildings: Array[GeneratedBuilding] = []
var current := 0
var _mesh_instance: Node3D
var plans: Array = []
var _yaw := 0.7
var _pitch := -0.45
var _dist := 40.0
## Distance that frames the current model; the wheel zooms either side of it.
var _fit_dist := 40.0
var _suspend_regen := false


## The village is a registered kind now (VIL-019), so it comes out of
## `BigGlade.kinds()` with the rest and is not added by hand. It keeps its own
## controls (the sliders are a population and a wealth, not metres) and its
## own preview path, which shows two villages rather than six buildings
## because planning one is a few seconds of work.
const VILLAGE := &"village"
const VILLAGE_VARIANTS := 1
var auto_generate := true
var seed_input: LineEdit
var water_opt: OptionButton
var edge_opt: OptionButton
var water_label: Label
var edge_label: Label
var generate_button: Button
var orientation_spin: SpinBox
var period_spin: SpinBox


func _ready() -> void:
	_add_landscape_controls()
	for kind_key in BigGlade.kinds():
		if kind_key == &"world" and WorldFamilies.families().is_empty():
			continue          # a registry with no families is nothing to show yet
		var descriptor: Dictionary = BigGlade.describe_kind(kind_key)
		kind_opt.add_item(descriptor["label"])
		kind_opt.set_item_metadata(kind_opt.item_count - 1, kind_key)
	kind_opt.item_selected.connect(func(_i): _on_kind_changed())
	width_slider.value_changed.connect(func(_v): _controls_changed())
	length_slider.value_changed.connect(func(_v): _controls_changed())
	height_slider.value_changed.connect(func(_v): _controls_changed())
	storeys_slider.value_changed.connect(func(_v): _controls_changed())
	cutaway_button.toggled.connect(func(_v): _show(current))
	style_opt.item_selected.connect(func(_i): _controls_changed())
	trade_opt.item_selected.connect(func(_i): _controls_changed())
	variant_list.item_selected.connect(_on_variant_picked)
	_on_kind_changed()


func _add_landscape_controls() -> void:
	var grid: GridContainer = $HSplit/LeftPanel/Margin/Grid
	water_label = Label.new()
	water_opt = OptionButton.new()
	edge_label = Label.new()
	edge_opt = OptionButton.new()
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_input = LineEdit.new()
	seed_input.text = "42"
	seed_input.custom_minimum_size.x = 130
	seed_input.tooltip_text = "Keep the seed to return to the same place."
	var shuffle := Button.new()
	shuffle.text = "New seed"
	var orientation_label := Label.new()
	orientation_label.text = "Orientation (°)"
	orientation_spin = SpinBox.new()
	orientation_spin.min_value = -360.0
	orientation_spin.max_value = 360.0
	orientation_spin.step = 1.0
	orientation_spin.value = 0.0
	orientation_spin.suffix = "°"
	orientation_spin.tooltip_text = "Yaw of local -Z relative to north. Zero faces south."
	var period_label := Label.new()
	period_label.text = "Period"
	period_spin = SpinBox.new()
	period_spin.min_value = -10000.0
	period_spin.max_value = 10000.0
	period_spin.step = 1.0
	period_spin.value = 1200.0
	generate_button = Button.new()
	generate_button.text = "Generate"
	for control in [water_label, water_opt, edge_label, edge_opt,
			orientation_label, orientation_spin, period_label, period_spin,
			seed_label, seed_input, shuffle, generate_button]:
		grid.add_child(control)
		grid.move_child(control, grid.get_node("Hint").get_index())
	water_opt.item_selected.connect(func(_i): _controls_changed())
	edge_opt.item_selected.connect(func(_i): _controls_changed())
	orientation_spin.value_changed.connect(func(_v): _controls_changed())
	period_spin.value_changed.connect(func(_v): _controls_changed())
	seed_input.text_submitted.connect(func(_text): regenerate())
	generate_button.pressed.connect(regenerate)
	shuffle.pressed.connect(func():
		seed_input.text = str(randi())
		regenerate())


func _controls_changed() -> void:
	if _suspend_regen:
		return
	if _kind() == VILLAGE:
		var descriptor: Dictionary = BigGlade.describe_kind(VILLAGE)
		width_label.text = "%s: %d" % [descriptor["width_label"], int(width_slider.value)]
		length_label.text = "%s: %d" % [descriptor["length_label"], int(length_slider.value)]
		info_label.text = "Choose Grow village to apply these settings."
	else:
		regenerate()


func _kind() -> StringName:
	return kind_opt.get_item_metadata(kind_opt.selected)


## The style dropdown's options, as the option-discovery contract returns
## them: [{"id", "label"}]. Studio does not know what a house style or a
## temple form IS -- it asks the public descriptor, so a style added to a
## family appears here without this file changing. The village uses
## the same public discovery path as every building family.
func _options(field: StringName) -> Array[Dictionary]:
	var key: String = {&"style": "styles", &"purpose": "purposes", &"water": "waters", &"enclosure": "enclosures"}.get(field, "")
	var listed: Array = BigGlade.describe_kind(_kind()).get(key, [])
	var typed: Array[Dictionary] = []
	for row in listed:
		typed.append(row)
	return typed


## Refill a dropdown from a list of {"id", "label"}, carrying the id as the
## item's metadata so nothing has to map a display string back to a key.
static func _fill(opt: OptionButton, rows: Array[Dictionary]) -> void:
	opt.clear()
	for row in rows:
		opt.add_item(String(row["label"]))
		opt.set_item_metadata(opt.item_count - 1, row["id"])
	if opt.item_count > 0:
		opt.select(0)


func _get_style_key() -> StringName:
	return style_opt.get_item_metadata(style_opt.selected)


## The second dropdown: a trade for a house, a cult for a temple.
##
## Falls back to the first entry of whichever table the current kind uses. The
## dropdown is rebuilt every time the kind changes, and for one frame in the
## middle of that it holds nothing -- which is enough to hand a house a trade
## that does not exist.
func _second_key() -> StringName:
	if trade_opt.item_count > 0 and trade_opt.selected >= 0:
		var meta = trade_opt.get_item_metadata(trade_opt.selected)
		if meta != null:
			return meta
	if _kind() == &"house":
		return &"none"
	if _kind() == &"shop":
		return &"general_store"
	return &"blood"


func _trade() -> StringName:
	return _second_key()


## Re-range the sliders and re-fill the style list for the chosen kind. The
## sliders are moved as a batch with regeneration suspended, so switching kind
## rebuilds once instead of once per slider.
func _on_kind_changed() -> void:
	var village: bool = _kind() == VILLAGE
	var cfg: Dictionary = BigGlade.describe_kind(_kind())
	_suspend_regen = true
	for pair in [[width_slider, "width"], [length_slider, "length"],
			[height_slider, "height"]]:
		var slider: HSlider = pair[0]
		var row: Dictionary = cfg[pair[1]]
		slider.min_value = row["min"]
		slider.max_value = row["max"]
		slider.step = row["step"]
		slider.value = row["value"]
	width_label.text = "%s width (m)" % cfg["size_label"]
	length_label.text = "%s length (m)" % cfg["size_label"]
	height_label.text = cfg["height_label"]
	if village:
		width_label.text = cfg["width_label"]
		length_label.text = cfg["length_label"]
	height_label.visible = not village
	height_slider.visible = not village
	var has_storeys: bool = cfg.has("storeys")
	storeys_label.visible = has_storeys
	storeys_slider.visible = has_storeys
	cutaway_label.visible = has_storeys or village
	cutaway_button.visible = has_storeys or village
	cutaway_label.text = "Village view" if village else "House view"
	if has_storeys:
		var storey_cfg: Dictionary = cfg["storeys"]
		storeys_slider.min_value = storey_cfg["min"]
		storeys_slider.max_value = storey_cfg["max"]
		storeys_slider.step = storey_cfg["step"]
		storeys_slider.value = storey_cfg["value"]
	# Both dropdowns are filled from the option-discovery contract, and both
	# are LABELLED by it too: a temple's are a form and a cult, a shop's a
	# style and a business. Studio maintains no family vocabulary of its own.
	_fill(style_opt, _options(&"style"))
	_fill(trade_opt, _options(&"purpose"))
	style_label.text = String(cfg.get("style_label", "Style"))
	trade_label.text = String(cfg.get("purpose_label", ""))
	trade_opt.visible = trade_opt.item_count > 0
	trade_label.visible = trade_opt.visible
	water_label.visible = village
	water_opt.visible = village
	edge_label.visible = village
	edge_opt.visible = village
	if village:
		water_label.text = cfg["water_label"]
		edge_label.text = cfg["enclosure_label"]
		_fill(water_opt, _options(&"water"))
		_fill(edge_opt, _options(&"enclosure"))
	generate_button.text = "Grow village" if village else "Generate"
	_suspend_regen = false
	if village:
		_controls_changed()
	regenerate()


func regenerate() -> void:
	if _suspend_regen or not auto_generate:
		return
	var seed_text := seed_input.text.strip_edges()
	if not seed_text.is_valid_int() or str(int(seed_text)) != seed_text:
		info_label.text = "Enter a whole seed number between -9223372036854775808 and 9223372036854775807."
		return
	specs.clear()
	meshes.clear()
	plans.clear()
	buildings.clear()
	variant_list.clear()
	var base_seed: int = int(seed_input.text)
	if _kind() == VILLAGE:
		_regenerate_village(base_seed)
		return
	for i in range(VARIANTS):
		var made: GeneratedBuilding = _build(base_seed + i * 7919)
		if not made.is_ok():
			push_error("BigGlade generation failed: %s" % made.errors)
			continue
		var mesh: ArrayMesh = BigGlade.build_mesh(made)
		buildings.append(made)
		specs.append(made.spec)
		meshes.append(mesh)
		plans.append(made.plan)
		variant_list.add_item(made.name())
	if buildings.is_empty():
		return
	current = clampi(current, 0, VARIANTS - 1)
	_show(current)


## One inhabited village from the public request, retaining its complete plan.
## Generation is explicit because changing a slider should not repeatedly
## furnish every building while a person drags it.
func _regenerate_village(base_seed: int) -> void:
	for i in range(VILLAGE_VARIANTS):
		var made := _build(base_seed + i * 7919)
		if not made.is_ok():
			info_label.text = str(made.errors[0]["message"])
			return
		var plan: VillagePlan = made.village
		specs.append(made.spec)
		meshes.append(BigGlade.build_mesh(made))
		plans.append(plan)
		buildings.append(made)
		variant_list.add_item("%s (%s, %d buildings)" % [made.name(), String(made.spec.form), plan.buildings.size()])
	if not specs.is_empty():
		_show(0)


## Generate one variant through the public API. Mesh and scene emission happen
## separately so the retained representation is available to other tools.
func _build(seed_value: int) -> GeneratedBuilding:
	var request := BigGlade.default_request(_kind(), seed_value)
	request.style = _get_style_key()
	request.purpose = _second_key() if trade_opt.item_count > 0 else &""
	request.width = width_slider.value
	request.length = length_slider.value
	request.height = height_slider.value
	request.orientation = deg_to_rad(orientation_spin.value)
	request.period = int(period_spin.value)
	if BigGlade.describe_kind(_kind()).has("storeys"):
		request.storeys = int(storeys_slider.value)
	if _kind() == VILLAGE:
		request.water = water_opt.get_item_metadata(water_opt.selected)
		request.enclosure = edge_opt.get_item_metadata(edge_opt.selected)
	return BigGlade.generate(request)


func _show(idx: int) -> void:
	current = idx
	if not spec_valid(idx):
		return
	if _mesh_instance and is_instance_valid(_mesh_instance):
		_mesh_instance.queue_free()
	var mesh: ArrayMesh = meshes[idx]
	var s = specs[idx]
	var cutaway: bool = cutaway_button.button_pressed if s is HouseSpec else true
	if s is VillageSpec:
		_mesh_instance = VillageAssembler.build(plans[idx], cutaway_button.button_pressed)
	else:
		_mesh_instance = BigGlade.instantiate(buildings[idx], cutaway)
	viewport.get_node("ModelRoot").add_child(_mesh_instance)
	(viewport.get_node("ModelRoot") as Node3D).rotation.y = buildings[idx].request.orientation
	variant_list.select(idx)
	# A house sheet is a plan per storey, an elevation and a schedule: it gets
	# the room a drawing needs. The church sheet and the notes keep their strip.
	bp_panel.custom_minimum_size.y = HOUSE_SHEET_HEIGHT if s is HouseSpec else SHEET_HEIGHT
	info_label.text = _describe(s)
	_frame(mesh)
	if s is VillageSpec:
		bp_view.setup_village(plans[idx])
	elif s is ChurchSpec:
		bp_view.setup(s)
	elif s is HouseSpec:
		bp_view.setup_house(plans[idx])
	elif s is TempleSpec:
		bp_view.show_note(_temple_sheet(s))
	else:
		# The sheet is drawn from ChurchGeometry and has no castle counterpart
		# yet; say so rather than leaving the last church's plan on screen.
		bp_view.show_note("%s — %s.\nNo blueprint sheet for castles yet: the sheet is drawn from ChurchGeometry."
			% [s.variant_name, String(s.tier).capitalize()])


## What the temple is and what is in it. The rite is the interesting part, so
## the sheet lists the things the checks care about.
func _temple_sheet(s: TempleSpec) -> String:
	var bits: Array[String] = ["%s of %s"
		% [BigGlade.option_label(&"temple", &"style", s.form), BigGlade.option_label(&"temple", &"purpose", s.cult)]]
	bits.append("hall %.0f x %.0f x %.0f m" % [s.width, s.length, s.height])
	bits.append("the god: a %s, %.1f m to its crown"
		% [String(s.idol_kind), TempleGeometry.idol_apex(s)])
	bits.append("altar %.1f x %.1f m on a dais of %d steps"
		% [s.altar_w, s.altar_l, s.dais_steps])
	if s.pit:
		bits.append("a pit %.1f m across, bridged on the axis" % (s.pit_radius * 2.0))
	if s.cells > 0:
		bits.append("%d cells off the aisles" % s.cells)
	bits.append("%d columns" % TempleGeometry.column_positions(s).size())
	if s.terraces > 0:
		bits.append("%d terraces, twin stairs to the summit" % s.terraces)
	if s.obelisks:
		bits.append("obelisks at the gate")
	if s.spire:
		bits.append("a spire over the sanctum")
	return "\n".join(bits)


## One line describing what was actually generated.
func _describe(s) -> String:
	if s is VillageSpec:
		var plan: VillagePlan = plans[current]
		return "%s -- a %s village of %d, %s, %s\n%d households, %d buildings on a %.0f x %.0f m site" % [
			s.variant_name, String(s.form), s.population, String(s.culture),
			String(s.purpose), s.households, plan.buildings.size(), plan.site.size.x, plan.site.size.y]
	if s is TempleSpec:
		return "%s -- %s of %s\n%.0f x %.0f m, %.0f m to the ceiling, %.0f m to the crown of the god" % [
			s.variant_name, BigGlade.option_label(&"temple", &"style", s.form),
			BigGlade.option_label(&"temple", &"purpose", s.cult), s.width, s.length, s.height,
			TempleGeometry.total_height(s)]
	if s is HotelSpec:
		return "%s -- %s\n%.0f x %.0f m, %d guest floors at %.1f m -- %d facade bays, %d dormers, twin cupolas" % [
			s.variant_name, BigGlade.option_label(&"hotel", &"style", s.style), s.width,
			s.length, s.storeys, s.height, s.facade_bays, s.dormer_count]
	if s is ShopSpec:
		var rooms: Array[String] = []
		for room in (plans[current] as HousePlan).rooms:
			var label := String(room["kind"])
			if not label in rooms:
				rooms.append(label)
		return "%s -- %s %s\n%.1f x %.1f m, %d storey%s at %.1f m -- %s" % [
			s.variant_name, BigGlade.option_label(&"shop", &"style", s.style),
			BigGlade.option_label(&"shop", &"purpose", s.business), s.width, s.length, s.storeys,
			"" if s.storeys == 1 else "s", s.height, ", ".join(rooms)]
	if s is HouseSpec:
		var bits: Array[String] = []
		for kind in [&"hall", &"kitchen", &"bedroom", &"workshop", &"parlour", &"store"]:
			var n: int = s_plan_rooms(kind)
			if n > 0:
				bits.append("%d %s" % [n, String(kind)] if n > 1 else String(kind))
		return "%s -- %s %s\n%.1f x %.1f m, %d storey%s at %.1f m -- %s" % [
			s.variant_name, BigGlade.option_label(&"house", &"style", s.style),
			BigGlade.option_label(&"house", &"purpose", s.trade), s.width, s.length, s.storeys,
			"" if s.storeys == 1 else "s", s.height,
			", ".join(bits)]
	if s is CastleSpec:
		var bits: Array[String] = []
		if s.corner_towers:
			bits.append("corner towers")
		if s.side_towers > 0:
			bits.append("%d mural towers/side" % s.side_towers)
		if s.gatehouse:
			bits.append("twin-towered gate" if s.gate_towers else "gatehouse")
		if s.inner_ward:
			bits.append("concentric")
		if s.barbican:
			bits.append("barbican")
		if s.keep:
			bits.append("%s keep" % String(s.keep_shape))
		if s.wings > 0:
			bits.append("%d wing%s" % [s.wings, "s" if s.wings > 1 else ""])
		if s.courtyard:
			bits.append("courtyard")
		if s.chimneys > 0:
			bits.append("%d stacks" % s.chimneys)
		return "%s — %s %s\nSite %.0f×%.0f m, walls %.0f m, %.0f m to the top — %s" % [
			s.variant_name, BigGlade.option_label(&"castle", &"style", s.style),
			String(s.tier).capitalize(), s.width, s.length, s.height,
			CastleGeometry.total_height(s), ", ".join(bits)]
	return "%s — %s\nNave %.0f×%.0f m, eaves %.0f m%s%s%s" % [
		s.variant_name, BigGlade.option_label(&"church", &"style", s.style),
		s.width, s.length, s.height,
		", tower" if s.tower else "", ", spire" if s.spire else "",
		", apse" if s.apse else ""]


## How many rooms of a kind the current plan has, for the info line.
func s_plan_rooms(kind: StringName) -> int:
	if current < 0 or current >= plans.size() or plans[current] == null:
		return 0
	return (plans[current] as HousePlan).rooms_of(kind).size()


## Pull the camera back far enough to hold the whole model. A fixed 40 m orbit
## was fine for a nave and put the camera inside the courtyard of a fortress.
func _frame(mesh: ArrayMesh) -> void:
	var aabb: AABB = mesh.get_aabb()
	var radius: float = maxf(aabb.size.length() / 2.0, 4.0)
	_fit_dist = radius * 1.6
	_dist = _fit_dist


func spec_valid(i: int) -> bool:
	return i >= 0 and i < specs.size() and meshes[i] != null


func _on_variant_picked(idx: int) -> void:
	_show(idx)


func _process(delta: float) -> void:
	_yaw += delta * 0.08     # slow turntable
	var rig: Node3D = cam_root
	var cp := cos(_pitch)
	rig.position = Vector3(sin(_yaw) * cp, sin(-_pitch), cos(_yaw) * cp) * _dist
	rig.look_at(Vector3(0, _dist * 0.12, 0), Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw += event.relative.x * 0.005
		_pitch = clampf(_pitch + event.relative.y * 0.005, -1.35, -0.05)
	elif event is InputEventMouseButton:
		# zoom limits follow the model, so the wheel behaves the same on a
		# cottage as on Krak des Chevaliers
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, _fit_dist * 0.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, _fit_dist * 3.0)
