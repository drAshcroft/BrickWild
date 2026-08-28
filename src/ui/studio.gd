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

@onready var viewport: SubViewport = $HSplit/CenterCol/ViewportPanel/SubViewport
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


func _ready() -> void:
	for kind_key in BigGlade.kinds():
		var descriptor: Dictionary = BigGlade.describe_kind(kind_key)
		kind_opt.add_item(descriptor["label"])
		kind_opt.set_item_metadata(kind_opt.item_count - 1, kind_key)
	kind_opt.item_selected.connect(func(_i): _on_kind_changed())
	width_slider.value_changed.connect(func(_v): regenerate())
	length_slider.value_changed.connect(func(_v): regenerate())
	height_slider.value_changed.connect(func(_v): regenerate())
	storeys_slider.value_changed.connect(func(_v): regenerate())
	cutaway_button.toggled.connect(func(_v): _show(current))
	style_opt.item_selected.connect(func(_i): regenerate())
	trade_opt.item_selected.connect(func(_i): regenerate())
	variant_list.item_selected.connect(_on_variant_picked)
	_on_kind_changed()


func _kind() -> StringName:
	return kind_opt.get_item_metadata(kind_opt.selected)


func _styles() -> Dictionary:
	match _kind():
		&"castle":
			return CastleSpec.STYLES
		&"house":
			return HouseSpec.STYLES
		&"temple":
			return TempleSpec.FORMS
	return ChurchSpec.STYLES


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
	return &"none" if _kind() == &"house" else &"blood"


func _trade() -> StringName:
	return _second_key()


## Re-range the sliders and re-fill the style list for the chosen kind. The
## sliders are moved as a batch with regeneration suspended, so switching kind
## rebuilds once instead of once per slider.
func _on_kind_changed() -> void:
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
	var has_storeys: bool = cfg.has("storeys")
	storeys_label.visible = has_storeys
	storeys_slider.visible = has_storeys
	cutaway_label.visible = has_storeys
	cutaway_button.visible = has_storeys
	if has_storeys:
		var storey_cfg: Dictionary = cfg["storeys"]
		storeys_slider.min_value = storey_cfg["min"]
		storeys_slider.max_value = storey_cfg["max"]
		storeys_slider.step = storey_cfg["step"]
		storeys_slider.value = storey_cfg["value"]
	style_opt.clear()
	for style_key in _styles():
		style_opt.add_item(_styles()[style_key]["label"])
		style_opt.set_item_metadata(style_opt.item_count - 1, style_key)
	style_opt.select(0)
	# The second dropdown is what the building is FOR: a household trade for a
	# house, a cult for a temple, and nothing at all for a church or a castle.
	trade_opt.clear()
	if _kind() == &"house" or _kind() == &"temple":
		var table: Dictionary = HouseSpec.TRADES if _kind() == &"house" \
			else TempleSpec.CULTS
		for key in table:
			trade_opt.add_item(table[key]["label"])
			trade_opt.set_item_metadata(trade_opt.item_count - 1, key)
		trade_opt.select(0)
	trade_label.text = "Trade" if _kind() == &"house" else "Cult"
	trade_opt.visible = trade_opt.item_count > 0
	trade_label.visible = trade_opt.visible
	_suspend_regen = false
	regenerate()


func regenerate() -> void:
	if _suspend_regen:
		return
	specs.clear()
	meshes.clear()
	plans.clear()
	buildings.clear()
	variant_list.clear()
	var base_seed: int = randi()
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


## Generate one variant through the public API. Mesh and scene emission happen
## separately so the retained representation is available to other tools.
func _build(seed_value: int) -> GeneratedBuilding:
	var request: BuildingRequest
	if _kind() == &"temple":
		request = BuildingRequest.temple(seed_value, _get_style_key(), _second_key(),
			width_slider.value, length_slider.value, height_slider.value)
	elif _kind() == &"house":
		request = BuildingRequest.house(seed_value, _get_style_key(), _trade(),
			width_slider.value, length_slider.value, height_slider.value,
			int(storeys_slider.value))
	elif _kind() == &"castle":
		request = BuildingRequest.castle(seed_value, _get_style_key(),
			width_slider.value, length_slider.value, height_slider.value)
	else:
		request = BuildingRequest.church(seed_value, _get_style_key(),
			width_slider.value, length_slider.value, height_slider.value)
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
	_mesh_instance = BigGlade.instantiate(buildings[idx], cutaway)
	viewport.get_node("ModelRoot").add_child(_mesh_instance)
	variant_list.select(idx)
	info_label.text = _describe(s)
	_frame(mesh)
	if s is ChurchSpec:
		bp_view.setup(s)
	elif s is HouseSpec:
		bp_view.show_note(_house_sheet(plans[idx]))
	elif s is TempleSpec:
		bp_view.show_note(_temple_sheet(s))
	else:
		# The sheet is drawn from ChurchGeometry and has no castle counterpart
		# yet; say so rather than leaving the last church's plan on screen.
		bp_view.show_note("%s — %s.\nNo blueprint sheet for castles yet: the sheet is drawn from ChurchGeometry."
			% [s.variant_name, String(s.tier).capitalize()])


## The room list, in place of a blueprint sheet: which rooms the plan came out
## with, how big they are, and what is in them.
func _house_sheet(plan: HousePlan) -> String:
	var lines: Array[String] = ["%s -- %s, %d rooms on %d storey%s"
		% [plan.spec.variant_name, HouseSpec.TRADES[plan.spec.trade]["label"],
			plan.room_count(), plan.spec.storeys, "" if plan.spec.storeys == 1 else "s"]]
	for i in range(plan.room_count()):
		var f: Rect2 = HouseGeometry.room_floor_rect(plan, i)
		var items: Array[String] = []
		for fi in plan.furniture_of(i):
			items.append(String(plan.furniture[fi]["key"]).replace("_", " "))
		lines.append("L%d %-9s %.1f x %.1f m  %d doors, %d windows\n    %s"
			% [plan.storey_of_room(i) + 1, String(plan.kind_of(i)), f.size.x, f.size.y,
				plan.doors_of(i).size(), plan.windows_of(i).size(),
				", ".join(items) if not items.is_empty() else "-"])
	return "\n".join(lines)


## What the temple is and what is in it. The rite is the interesting part, so
## the sheet lists the things the checks care about.
func _temple_sheet(s: TempleSpec) -> String:
	var bits: Array[String] = ["%s of %s"
		% [TempleSpec.FORMS[s.form]["label"], TempleSpec.CULTS[s.cult]["label"]]]
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
	if s is TempleSpec:
		return "%s -- %s of %s\n%.0f x %.0f m, %.0f m to the ceiling, %.0f m to the crown of the god" % [
			s.variant_name, TempleSpec.FORMS[s.form]["label"],
			TempleSpec.CULTS[s.cult]["label"], s.width, s.length, s.height,
			TempleGeometry.total_height(s)]
	if s is HouseSpec:
		var bits: Array[String] = []
		for kind in [&"hall", &"kitchen", &"bedroom", &"workshop", &"parlour", &"store"]:
			var n: int = s_plan_rooms(kind)
			if n > 0:
				bits.append("%d %s" % [n, String(kind)] if n > 1 else String(kind))
		return "%s -- %s %s\n%.1f x %.1f m, %d storey%s at %.1f m -- %s" % [
			s.variant_name, HouseSpec.STYLES[s.style]["label"],
			HouseSpec.TRADES[s.trade]["label"], s.width, s.length, s.storeys,
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
			s.variant_name, CastleSpec.STYLES[s.style]["label"],
			String(s.tier).capitalize(), s.width, s.length, s.height,
			CastleGeometry.total_height(s), ", ".join(bits)]
	return "%s — %s\nNave %.0f×%.0f m, eaves %.0f m%s%s%s" % [
		s.variant_name, ChurchSpec.STYLES[s.style]["label"],
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
