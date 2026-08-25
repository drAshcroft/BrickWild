extends Control
## Church Blueprint Studio.
## Left panel: width / length / height sliders + style dropdown + Generate.
## Center: 3D preview (SubViewport) of the selected variant.
## Right: variant list; double info line + blueprint sheet below the 3D view.

const VARIANTS := 6

@onready var viewport: SubViewport = $HSplit/CenterCol/ViewportPanel/SubViewport
@onready var bp_view: BlueprintView = $HSplit/CenterCol/BPPanel/BlueprintView
@onready var width_slider: HSlider = $HSplit/LeftPanel/Margin/Grid/WidthSlider
@onready var length_slider: HSlider = $HSplit/LeftPanel/Margin/Grid/LengthSlider
@onready var height_slider: HSlider = $HSplit/LeftPanel/Margin/Grid/HeightSlider
@onready var style_opt: OptionButton = $HSplit/LeftPanel/Margin/Grid/StyleOption
@onready var variant_list: ItemList = $HSplit/RightPanel/VBox/VariantList
@onready var info_label: Label = $HSplit/CenterCol/InfoLabel
@onready var cam_root: Node3D = viewport.get_node("CamRig")

var specs: Array = []
var meshes: Array = []
var current := 0
var _mesh_instance: MeshInstance3D
var _yaw := 0.7
var _pitch := -0.45
var _dist := 40.0

func _ready() -> void:
	for style_key in ChurchSpec.STYLES:
		style_opt.add_item(ChurchSpec.STYLES[style_key]["label"])
		style_opt.set_item_metadata(style_opt.item_count - 1, style_key)
	width_slider.value_changed.connect(func(_v): regenerate())
	length_slider.value_changed.connect(func(_v): regenerate())
	height_slider.value_changed.connect(func(_v): regenerate())
	style_opt.item_selected.connect(func(_i): regenerate())
	variant_list.item_selected.connect(_on_variant_picked)
	regenerate()

func _get_style_key() -> StringName:
	return style_opt.get_item_metadata(style_opt.selected)

func regenerate() -> void:
	specs.clear()
	meshes.clear()
	variant_list.clear()
	var base_seed: int = randi()
	for i in range(VARIANTS):
		var spec := ChurchSpec.new()
		spec.style = _get_style_key()
		spec.width = width_slider.value
		spec.length = length_slider.value
		spec.height = height_slider.value
		ChurchGenerator.generate(spec, base_seed + i * 7919)
		specs.append(spec)
		var builder := ChurchBuilder.new()
		meshes.append(builder.build(spec))
		variant_list.add_item(spec.variant_name)
	current = mini(current, VARIANTS - 1)
	_show(current)

func _show(idx: int) -> void:
	current = idx
	if spec_valid(idx):
		if _mesh_instance and is_instance_valid(_mesh_instance):
			_mesh_instance.queue_free()
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.mesh = meshes[idx]
		# per-surface materials
		var s: ChurchSpec = specs[idx]
		var mats := [s.stone_color, s.trim_color, s.roof_color, Color("1a1c20")]
		for si in range(4):
			var m := StandardMaterial3D.new()
			m.albedo_color = mats[si]
			m.roughness = 0.9
			_mesh_instance.set_surface_override_material(si, m)
		viewport.get_node("ChurchRoot").add_child(_mesh_instance)
		variant_list.select(idx)
		info_label.text = "%s — %s\nNave %.0f×%.0f m, eaves %.0f m%s%s%s" % [
			s.variant_name, ChurchSpec.STYLES[s.style]["label"],
			s.width, s.length, s.height,
			", tower" if s.tower else "", ", spire" if s.spire else "",
			", apse" if s.apse else ""]
		bp_view.setup(s)

func spec_valid(i: int) -> bool:
	return i >= 0 and i < specs.size() and meshes[i] != null

func _on_variant_picked(idx: int) -> void:
	_show(idx)

func _process(delta: float) -> void:
	_yaw += delta * 0.08     # slow turntable
	var rig: Node3D = cam_root
	var cp := cos(_pitch)
	rig.position = Vector3(sin(_yaw) * cp, sin(-_pitch), cos(_yaw) * cp) * _dist
	rig.look_at(Vector3(0, _dist * 0.25, 0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw += event.relative.x * 0.005
		_pitch = clampf(_pitch + event.relative.y * 0.005, -1.35, -0.05)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 8.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 120.0)
