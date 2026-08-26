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

## Slider ranges and starting sizes per kind. A castle site is an order of
## magnitude bigger than a nave, and the same slider cannot serve both.
const KINDS := {
	&"church": {
		"label": "Church", "size_label": "Nave", "height_label": "Eaves height (m)",
		"width": {"min": 6.0, "max": 24.0, "step": 0.5, "value": 10.0},
		"length": {"min": 10.0, "max": 60.0, "step": 1.0, "value": 22.0},
		"height": {"min": 6.0, "max": 30.0, "step": 0.5, "value": 12.0},
	},
	&"castle": {
		"label": "Castle", "size_label": "Site", "height_label": "Wall height (m)",
		# the full ladder: a 6 x 9 m cottage up to a 320 x 400 m fortress
		"width": {"min": 6.0, "max": 320.0, "step": 1.0, "value": 55.0},
		"length": {"min": 8.0, "max": 400.0, "step": 1.0, "value": 50.0},
		"height": {"min": 3.0, "max": 40.0, "step": 0.5, "value": 18.0},
	},
	&"house": {
		"label": "House", "size_label": "House", "height_label": "Ceiling (m)",
		# from a one-room hut to a house with the full room programme
		"width": {"min": 5.0, "max": 20.0, "step": 0.5, "value": 9.0},
		"length": {"min": 6.0, "max": 26.0, "step": 0.5, "value": 12.0},
		"height": {"min": 2.2, "max": 3.6, "step": 0.1, "value": 2.6},
	},
}

@onready var viewport: SubViewport = $HSplit/CenterCol/ViewportPanel/SubViewport
@onready var bp_view: BlueprintView = $HSplit/CenterCol/BPPanel/BlueprintView
@onready var width_slider: HSlider = $HSplit/LeftPanel/Margin/Grid/WidthSlider
@onready var length_slider: HSlider = $HSplit/LeftPanel/Margin/Grid/LengthSlider
@onready var height_slider: HSlider = $HSplit/LeftPanel/Margin/Grid/HeightSlider
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
	for kind_key in KINDS:
		kind_opt.add_item(KINDS[kind_key]["label"])
		kind_opt.set_item_metadata(kind_opt.item_count - 1, kind_key)
	kind_opt.item_selected.connect(func(_i): _on_kind_changed())
	width_slider.value_changed.connect(func(_v): regenerate())
	length_slider.value_changed.connect(func(_v): regenerate())
	height_slider.value_changed.connect(func(_v): regenerate())
	style_opt.item_selected.connect(func(_i): regenerate())
	for trade_key in HouseSpec.TRADES:
		trade_opt.add_item(HouseSpec.TRADES[trade_key]["label"])
		trade_opt.set_item_metadata(trade_opt.item_count - 1, trade_key)
	trade_opt.select(0)
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
	return ChurchSpec.STYLES


func _get_style_key() -> StringName:
	return style_opt.get_item_metadata(style_opt.selected)


func _trade() -> StringName:
	return trade_opt.get_item_metadata(trade_opt.selected)


## Re-range the sliders and re-fill the style list for the chosen kind. The
## sliders are moved as a batch with regeneration suspended, so switching kind
## rebuilds once instead of once per slider.
func _on_kind_changed() -> void:
	var cfg: Dictionary = KINDS[_kind()]
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
	style_opt.clear()
	for style_key in _styles():
		style_opt.add_item(_styles()[style_key]["label"])
		style_opt.set_item_metadata(style_opt.item_count - 1, style_key)
	style_opt.select(0)
	# only a house has a trade: a cathedral does not take up blacksmithing
	trade_opt.visible = _kind() == &"house"
	trade_label.visible = trade_opt.visible
	_suspend_regen = false
	regenerate()


func regenerate() -> void:
	if _suspend_regen:
		return
	specs.clear()
	meshes.clear()
	plans.clear()
	variant_list.clear()
	var base_seed: int = randi()
	for i in range(VARIANTS):
		var made: Array = _build(base_seed + i * 7919)
		specs.append(made[0])
		meshes.append(made[1])
		plans.append(made[2] if made.size() > 2 else null)
		variant_list.add_item(made[0].variant_name)
	current = clampi(current, 0, VARIANTS - 1)
	_show(current)


## Generate and build one variant of the current kind. Returns [spec, mesh]
## for a church or castle, and [spec, mesh, plan] for a house -- a house is not
## finished until its furniture is in, and the furniture is not mesh.
func _build(seed_value: int) -> Array:
	if _kind() == &"house":
		var hspec := HouseSpec.new()
		hspec.style = _get_style_key()
		hspec.trade = _trade()
		hspec.width = width_slider.value
		hspec.length = length_slider.value
		hspec.height = height_slider.value
		var plan: HousePlan = HouseGenerator.generate(hspec, seed_value)
		return [hspec, HouseBuilder.new().build(plan), plan]
	if _kind() == &"castle":
		var cspec := CastleSpec.new()
		cspec.style = _get_style_key()
		cspec.width = width_slider.value
		cspec.length = length_slider.value
		cspec.height = height_slider.value
		CastleGenerator.generate(cspec, seed_value)
		return [cspec, CastleBuilder.new().build(cspec)]
	var spec := ChurchSpec.new()
	spec.style = _get_style_key()
	spec.width = width_slider.value
	spec.length = length_slider.value
	spec.height = height_slider.value
	ChurchGenerator.generate(spec, seed_value)
	return [spec, ChurchBuilder.new().build(spec)]


func _show(idx: int) -> void:
	current = idx
	if not spec_valid(idx):
		return
	if _mesh_instance and is_instance_valid(_mesh_instance):
		_mesh_instance.queue_free()
	var mesh: ArrayMesh = meshes[idx]
	var s = specs[idx]
	if s is HouseSpec:
		# a house is assembled rather than built: the shell plus an instance of
		# the real model for every stick of furniture in it, and the roof left
		# off so there is something to see
		_mesh_instance = HouseAssembler.build(plans[idx], true)
	else:
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		# per-surface materials: stone, trim, roof, openings
		var mats := [s.stone_color, s.trim_color, s.roof_color, Color("1a1c20")]
		for si in range(mesh.get_surface_count()):
			var m := StandardMaterial3D.new()
			m.albedo_color = mats[si]
			m.roughness = 0.9
			inst.set_surface_override_material(si, m)
		_mesh_instance = inst
	viewport.get_node("ModelRoot").add_child(_mesh_instance)
	variant_list.select(idx)
	info_label.text = _describe(s)
	_frame(mesh)
	if s is ChurchSpec:
		bp_view.setup(s)
	elif s is HouseSpec:
		bp_view.show_note(_house_sheet(plans[idx]))
	else:
		# The sheet is drawn from ChurchGeometry and has no castle counterpart
		# yet; say so rather than leaving the last church's plan on screen.
		bp_view.show_note("%s — %s.\nNo blueprint sheet for castles yet: the sheet is drawn from ChurchGeometry."
			% [s.variant_name, String(s.tier).capitalize()])


## The room list, in place of a blueprint sheet: which rooms the plan came out
## with, how big they are, and what is in them.
func _house_sheet(plan: HousePlan) -> String:
	var lines: Array[String] = ["%s -- %s, %d rooms"
		% [plan.spec.variant_name, HouseSpec.TRADES[plan.spec.trade]["label"],
			plan.room_count()]]
	for i in range(plan.room_count()):
		var f: Rect2 = HouseGeometry.room_floor_rect(plan, i)
		var items: Array[String] = []
		for fi in plan.furniture_of(i):
			items.append(String(plan.furniture[fi]["key"]).replace("_", " "))
		lines.append("%-9s %.1f x %.1f m  %d doors, %d windows\n    %s"
			% [String(plan.kind_of(i)), f.size.x, f.size.y,
				plan.doors_of(i).size(), plan.windows_of(i).size(),
				", ".join(items) if not items.is_empty() else "-"])
	return "\n".join(lines)


## One line describing what was actually generated.
func _describe(s) -> String:
	if s is HouseSpec:
		var bits: Array[String] = []
		for kind in [&"hall", &"kitchen", &"bedroom", &"workshop", &"parlour", &"store"]:
			var n: int = s_plan_rooms(kind)
			if n > 0:
				bits.append("%d %s" % [n, String(kind)] if n > 1 else String(kind))
		return "%s -- %s %s\n%.1f x %.1f m, ceiling %.1f m -- %s" % [
			s.variant_name, HouseSpec.STYLES[s.style]["label"],
			HouseSpec.TRADES[s.trade]["label"], s.width, s.length, s.height,
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
