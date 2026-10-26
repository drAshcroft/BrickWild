extends Control
## Walk QA: generate one BrickWild building, walk through it, pin problems.
##
##   godot --path . res://visualqa/walk/walk_qa.tscn
##   godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=house --seed=8102 --style=cottage
##   ... -- --kind=house --jank=0.6 | --fall=2 --downhill=90 | --foundation=piles --water=1.5
##   ... -- --tour=sprint_2026_10_26 [--stop=3]    (a bug walk: visualqa/tours/<name>.json)
##   ... -- --village-terrain=manarola [--seed=1]  (a village on a terrain fixture)
##
## A bug walk files every saved pin as a waterfree todo (tools/file_walk_bugs.py,
## launched in the background on Save; untick "File pins as todos" or pass
## --no-file to stop it). See visualqa/README.md "Bug walks".
##
## The sidebar carries the web page's five rating boxes and notes. Right-click
## pins a problem on the surface under the crosshair (or under the mouse when
## it is free), with a screenshot. Save appends the review to
## visualqa/HumanRate.md beside the web page's reviews, writes the pin
## screenshots to visualqa/walk_shots/, and appends the same review as one JSON
## line to visualqa/walk_pins.jsonl for an agent to read back.
##
## Collision is the architecture's own trimesh (BrickWild.instantiate with
## collision), plus every prop when "Solid furniture" is ticked, so a doorway
## you cannot fit through is a doorway the generator made too narrow.

const SIDEBAR_W := 360.0
const FIELDS := ["pretty", "collisions", "window problems", "door problems", "roof problems"]
const LABELS := ["Pretty", "Collisions", "Window problems", "Door problems", "Roof problems"]
## No default: the dialog opens on CHOOSE and will not pin until a kind is
## picked. Every pin before 26 Oct said "collision" because the list opened
## on it and nobody changed it.
const CHOOSE := "choose…"
const PIN_KINDS := ["collision", "door", "window", "stair / floor", "roof", "wall",
	"furniture / prop", "lighting", "floating / gap", "z-fight / texture",
	"missing / wrong for the style", "ground / terrain", "other"]
## A pin of this kind also ticks the matching rating box.
const PIN_FIELD := {"collision": "collisions", "window": "window problems",
	"door": "door problems", "roof": "roof problems"}
## blocker = P1, bug = P2, polish = P3 when tools/file_walk_bugs.py files it.
const SEVERITIES := ["blocker", "bug", "polish"]
## The kinds the request accepts a ground fall for (BuildingLibrary._validate_ground)
## and the kinds that may stand on piles (HousePiles.refusal).
const FALL_KINDS := [&"house", &"shop", &"church", &"castle"]
const PILE_KINDS := [&"house", &"shop"]
const TOUR_DIR := "res://visualqa/tours/"
const FILER := "res://tools/file_walk_bugs.py"
const FILER_LOG := "res://artifacts/walk_bugs/filer.log"
const DEFAULT_RATE_FILE := "res://visualqa/HumanRate.md"
const WALK_SPEED := 4.0
const RUN_SPEED := 8.0
const FLY_SPEED := 10.0
const JUMP := 4.5
const GRAVITY := 12.0
const EYE := 1.6
const STEP := 0.4
const LOOK := 0.0025
const RADIUS := 0.28
const BODY_H := 1.75

var _rate_file := DEFAULT_RATE_FILE

var _sv: SubViewport
var _svc: SubViewportContainer
var _world: Node3D
var _building_root: Node3D
var _pins_root: Node3D
var _player: CharacterBody3D
var _head: Node3D
var _cam: Camera3D
var _lantern: OmniLight3D
var _hud: Label

var _kind_opt: OptionButton
var _style_label: Label
var _style_opt: OptionButton
var _purpose_label: Label
var _purpose_opt: OptionButton
var _seed_spin: SpinBox
var _cutaway: CheckBox
var _solid_props: CheckBox
var _build_btn: Button
var _info: Label
var _checks := {}
var _notes: TextEdit
var _pin_list: ItemList
var _status: Label
var _save_next: Button
var _save_seed: Button
var _skip: Button
var _file_todos: CheckBox
var _tour_label: Label
var _jank_row: Control
var _jank: HSlider
var _jank_value: Label
var _fall_row: Control
var _fall: SpinBox
var _downhill: SpinBox
var _found_row: Control
var _foundation: OptionButton
var _pile_water: SpinBox
var _ground: StaticBody3D
var _water_plane: MeshInstance3D

## A tour: visualqa/tours/<name>.json, a list of request dicts, each with an
## optional "why". `_base` is the current stop's dict, so fields the sidebar
## does not show (width, storeys, ...) still reach the request.
var _tour_name := ""
var _tour: Array = []
var _tour_i := -1
var _base := {}
## A village planned on a terrain fixture (--village-terrain=<name>): there is
## no GeneratedBuilding, only the assembled scene.
var _terrain_name := ""
var _filer_pid := -1
var _filer_dry := false

var _dialog: PanelContainer
var _dlg_kind: OptionButton
var _dlg_note: LineEdit
var _dlg_sev: OptionButton
var _dlg_warn: Label
var _pending := {}
var _recapture := false

var _building: GeneratedBuilding
var _request: BuildingRequest
var _placement := {}
var _pins: Array[Dictionary] = []
var _yaw := 0.0
var _pitch := 0.0
var _fly := false
var _busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var args := _user_args()
	if args.has("rate-file"):
		_rate_file = String(args["rate-file"])
	_build_ui()
	_build_world()
	_fill_kinds(args)
	if args.has("no-file"):
		_file_todos.button_pressed = false
	if args.has("tour"):
		var err := _load_tour(String(args["tour"]))
		if err != "":
			_status.text = err
		else:
			# a reopen line carries --stop=i plus the flags that override it
			var at := clampi(int(args.get("stop", "1")) - 1, 0, _tour.size() - 1)
			var over := args.duplicate()
			for k in ["tour", "stop", "autoshot", "autopin", "walk", "rate-file", "no-file"]:
				over.erase(k)
			_enter_stop(at, over)
	if args.has("village-terrain"):
		_terrain_name = String(args["village-terrain"])
		await _generate_terrain_village()
	else:
		await _generate()
	if args.has("autoshot"):
		await _autotest(args)


# --- scene ---------------------------------------------------------------

func _build_ui() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)

	var view := Control.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(view)
	_svc = SubViewportContainer.new()
	_svc.stretch = true
	_svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_svc.gui_input.connect(_on_view_input)
	view.add_child(_svc)
	_sv = SubViewport.new()
	_sv.msaa_3d = Viewport.MSAA_4X
	_sv.handle_input_locally = false
	_svc.add_child(_sv)

	for s in [Vector2(2, 16), Vector2(16, 2)]:
		var bar := ColorRect.new()
		bar.color = Color(1, 1, 1, 0.85)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = 0.5
		bar.anchor_right = 0.5
		bar.anchor_top = 0.5
		bar.anchor_bottom = 0.5
		bar.offset_left = -s.x / 2.0
		bar.offset_right = s.x / 2.0
		bar.offset_top = -s.y / 2.0
		bar.offset_bottom = s.y / 2.0
		view.add_child(bar)
	_hud = Label.new()
	_hud.position = Vector2(12, 8)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_theme_color_override("font_color", Color.WHITE)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 5)
	view.add_child(_hud)
	_build_dialog(view)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = SIDEBAR_W
	row.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	var title := Label.new()
	title.text = "Walk QA"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	_tour_label = Label.new()
	_tour_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tour_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_tour_label.visible = false
	box.add_child(_tour_label)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	_kind_opt = _grid_option(grid, "Kind")
	_kind_opt.item_selected.connect(func(_i): _fill_options())
	_style_label = Label.new()
	_style_label.text = "Style"
	grid.add_child(_style_label)
	_style_opt = OptionButton.new()
	_style_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_style_opt)
	_purpose_label = Label.new()
	_purpose_label.text = "Purpose"
	grid.add_child(_purpose_label)
	_purpose_opt = OptionButton.new()
	_purpose_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_purpose_opt)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	grid.add_child(seed_label)
	var seed_row := HBoxContainer.new()
	grid.add_child(seed_row)
	_seed_spin = SpinBox.new()
	_seed_spin.max_value = 999999
	_seed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_spin)
	var dice := Button.new()
	dice.text = "Random"
	dice.pressed.connect(func(): _seed_spin.value = randi() % 100000)
	seed_row.add_child(dice)
	_cutaway = CheckBox.new()
	_cutaway.text = "Cutaway (roofs off)"
	box.add_child(_cutaway)
	_solid_props = CheckBox.new()
	_solid_props.text = "Solid furniture"
	_solid_props.button_pressed = true
	box.add_child(_solid_props)
	_build_request_extras(box)
	_build_btn = Button.new()
	_build_btn.text = "Build"
	_build_btn.pressed.connect(_on_build)
	box.add_child(_build_btn)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", Color(0.75, 0.78, 0.72))
	box.add_child(_info)

	box.add_child(HSeparator.new())
	var rate := Label.new()
	rate.text = "Rating"
	rate.add_theme_font_size_override("font_size", 18)
	box.add_child(rate)
	for i in FIELDS.size():
		var check := CheckBox.new()
		check.text = LABELS[i]
		box.add_child(check)
		_checks[FIELDS[i]] = check
	var notes_label := Label.new()
	notes_label.text = "Notes (optional)"
	box.add_child(notes_label)
	_notes = TextEdit.new()
	_notes.custom_minimum_size.y = 70
	_notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(_notes)

	box.add_child(HSeparator.new())
	var pins := Label.new()
	pins.text = "Pinned problems (right-click)"
	pins.add_theme_font_size_override("font_size", 18)
	box.add_child(pins)
	_pin_list = ItemList.new()
	_pin_list.custom_minimum_size.y = 150
	_pin_list.item_activated.connect(_go_to_pin)
	box.add_child(_pin_list)
	var pin_row := HBoxContainer.new()
	box.add_child(pin_row)
	var go := Button.new()
	go.text = "Go to"
	go.pressed.connect(_go_to_selected)
	pin_row.add_child(go)
	var del := Button.new()
	del.text = "Delete"
	del.pressed.connect(_delete_pin)
	pin_row.add_child(del)

	box.add_child(HSeparator.new())
	_save_next = Button.new()
	_save_next.text = "Save & next kind →"
	_save_next.pressed.connect(func(): _save(true))
	box.add_child(_save_next)
	_save_seed = Button.new()
	_save_seed.text = "Save & new seed"
	_save_seed.pressed.connect(func(): _save(false))
	box.add_child(_save_seed)
	_skip = Button.new()
	_skip.text = "Skip this stop (save nothing)"
	_skip.visible = false
	_skip.pressed.connect(_on_skip)
	box.add_child(_skip)
	_file_todos = CheckBox.new()
	_file_todos.text = "File pins as todos (on Save)"
	_file_todos.button_pressed = true
	box.add_child(_file_todos)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.65, 0.68, 0.62))
	help.text = ("Click the view to walk. WASD move, mouse look, Shift run, Space jump. "
		+ "F fly (Space/C up/down, no collision). L lantern. R back to the door. "
		+ "Right-click a surface to pin a problem. Esc frees the mouse.")
	box.add_child(help)


func _on_build() -> void:
	if not _busy:
		_generate()


func _go_to_selected() -> void:
	var sel := _pin_list.get_selected_items()
	if not sel.is_empty():
		_go_to_pin(sel[0])


func _grid_option(grid: GridContainer, text: String) -> OptionButton:
	var label := Label.new()
	label.text = text
	grid.add_child(label)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(opt)
	return opt


## Jank, ground fall and foundation: each row shows only for the kinds whose
## request accepts it, so the sidebar never offers a request that is refused.
func _build_request_extras(box: VBoxContainer) -> void:
	var jank_row := HBoxContainer.new()
	_jank_row = jank_row
	box.add_child(jank_row)
	var jl := Label.new()
	jl.text = "Jank"
	jank_row.add_child(jl)
	_jank = HSlider.new()
	_jank.min_value = 0.0
	_jank.max_value = 1.0
	_jank.step = 0.05
	_jank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	jank_row.add_child(_jank)
	_jank_value = Label.new()
	_jank_value.text = "0.00"
	_jank.value_changed.connect(func(v): _jank_value.text = "%.2f" % v)
	jank_row.add_child(_jank_value)

	var fall_row := HBoxContainer.new()
	_fall_row = fall_row
	box.add_child(fall_row)
	var fl := Label.new()
	fl.text = "Ground fall m"
	fall_row.add_child(fl)
	_fall = SpinBox.new()
	_fall.max_value = 12.0
	_fall.step = 0.1
	_fall.tooltip_text = "Total fall across the footprint (ground_fall_m). 0 is flat."
	_fall.value_changed.connect(func(_v): _sync_ground_ui())
	fall_row.add_child(_fall)
	var dl := Label.new()
	dl.text = "downhill°"
	fall_row.add_child(dl)
	_downhill = SpinBox.new()
	_downhill.max_value = 359
	_downhill.step = 15
	_downhill.tooltip_text = "0 = toward the front door, 90 = +X, 180 = the back."
	fall_row.add_child(_downhill)

	var found_row := HBoxContainer.new()
	_found_row = found_row
	box.add_child(found_row)
	var ol := Label.new()
	ol.text = "Foundation"
	found_row.add_child(ol)
	_foundation = OptionButton.new()
	_foundation.add_item("ground")
	_foundation.add_item("piles")
	_foundation.item_selected.connect(func(_i): _sync_ground_ui())
	found_row.add_child(_foundation)
	var wl := Label.new()
	wl.text = "water m"
	found_row.add_child(wl)
	_pile_water = SpinBox.new()
	_pile_water.max_value = HousePiles.MAX_WATER_M
	_pile_water.step = 0.1
	_pile_water.value = 1.0
	found_row.add_child(_pile_water)


## Piles exclude a fall: picking one zeroes the other.
func _sync_ground_ui() -> void:
	if _foundation.selected == 1 and _fall.value > 0.0:
		_fall.set_value_no_signal(0.0)
	_pile_water.editable = _foundation.selected == 1


func _build_dialog(view: Control) -> void:
	_dialog = PanelContainer.new()
	_dialog.visible = false
	_dialog.anchor_left = 0.5
	_dialog.anchor_right = 0.5
	_dialog.anchor_top = 0.5
	_dialog.anchor_bottom = 0.5
	_dialog.offset_left = -190
	_dialog.offset_right = 190
	_dialog.offset_top = 40
	_dialog.offset_bottom = 250
	view.add_child(_dialog)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_dialog.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var label := Label.new()
	label.text = "Problem here"
	box.add_child(label)
	var row := HBoxContainer.new()
	box.add_child(row)
	_dlg_kind = OptionButton.new()
	_dlg_kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dlg_kind.add_item(CHOOSE)
	for k in PIN_KINDS:
		_dlg_kind.add_item(k)
	_dlg_kind.item_selected.connect(func(_i): _dlg_warn.text = "")
	row.add_child(_dlg_kind)
	_dlg_sev = OptionButton.new()
	for sv in SEVERITIES:
		_dlg_sev.add_item(sv)
	_dlg_sev.tooltip_text = "blocker: cannot walk on / P1 · bug: plainly wrong / P2 · polish: looks off / P3"
	row.add_child(_dlg_sev)
	_dlg_warn = Label.new()
	_dlg_warn.add_theme_color_override("font_color", Color(1, 0.45, 0.35))
	box.add_child(_dlg_warn)
	_dlg_note = LineEdit.new()
	_dlg_note.placeholder_text = "What is wrong? (Enter saves, Esc cancels)"
	_dlg_note.text_submitted.connect(func(_t): _confirm_pin())
	box.add_child(_dlg_note)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var ok := Button.new()
	ok.text = "Pin it"
	ok.pressed.connect(_confirm_pin)
	buttons.add_child(ok)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_close_dialog)
	buttons.add_child(cancel)


func _build_world() -> void:
	_world = Node3D.new()
	_sv.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	_world.add_child(sun)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var gshape := CollisionShape3D.new()
	gshape.shape = WorldBoundaryShape3D.new()
	ground.add_child(gshape)
	var gmesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	gmesh.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.36, 0.42, 0.3)
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	ground.position.y = -0.02
	_world.add_child(ground)
	_ground = ground
	# the water under a house on piles: seen, not solid, so a step off the
	# deck falls to the bed
	_water_plane = MeshInstance3D.new()
	var wplane := PlaneMesh.new()
	wplane.size = Vector2(400, 400)
	_water_plane.mesh = wplane
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.2, 0.38, 0.5, 0.6)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_plane.material_override = wmat
	_water_plane.visible = false
	_world.add_child(_water_plane)

	_pins_root = Node3D.new()
	_pins_root.name = "Pins"
	_world.add_child(_pins_root)

	_player = CharacterBody3D.new()
	_player.floor_snap_length = STEP
	_player.floor_max_angle = deg_to_rad(50)
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = BODY_H
	body.shape = capsule
	body.position.y = BODY_H / 2.0
	_player.add_child(body)
	_head = Node3D.new()
	_head.position.y = EYE
	_player.add_child(_head)
	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.fov = 75
	_head.add_child(_cam)
	_lantern = OmniLight3D.new()
	_lantern.omni_range = 9.0
	_lantern.light_energy = 1.1
	_lantern.position = Vector3(0.2, 0.1, 0)
	_head.add_child(_lantern)
	_world.add_child(_player)


# --- building ------------------------------------------------------------

func _fill_kinds(args: Dictionary) -> void:
	for k in BrickWild.kinds():
		if k == &"world" and WorldFamilies.families().is_empty():
			continue
		var d := BrickWild.describe_kind(k)
		_kind_opt.add_item(String(d.get("label", String(k))))
		_kind_opt.set_item_metadata(_kind_opt.item_count - 1, k)
	_set_ui(args)


## Put a set of command-line style values on the sidebar: kind, style,
## purpose, seed, cutaway, jank, fall, downhill, foundation, water. Missing
## keys fall back to the defaults, so a tour stop resets what it does not say.
func _set_ui(args: Dictionary) -> void:
	var kind := String(args.get("kind", "house"))
	for i in _kind_opt.item_count:
		if String(_kind_opt.get_item_metadata(i)) == kind:
			_kind_opt.select(i)
	_fill_options()
	_select_meta(_style_opt, String(args.get("style", "")))
	_select_meta(_purpose_opt, String(args.get("purpose", "")))
	_seed_spin.value = int(args.get("seed", "1"))
	_cutaway.button_pressed = args.has("cutaway")
	_jank.value = clampf(float(args.get("jank", "0")), 0.0, 1.0)
	_fall.value = float(args.get("fall", "0"))
	_downhill.value = float(args.get("downhill", "0"))
	_foundation.select(1 if String(args.get("foundation", "")) == "piles" else 0)
	_pile_water.value = float(args.get("water", "1.0"))
	_sync_ground_ui()


func _kind() -> StringName:
	return _kind_opt.get_item_metadata(_kind_opt.selected)


func _fill_options() -> void:
	var d := BrickWild.describe_kind(_kind())
	_style_label.text = String(d.get("style_label", "Style")).capitalize()
	_purpose_label.text = String(d.get("purpose_label", "Purpose")).capitalize()
	for pair in [[_style_opt, d.get("styles", [])], [_purpose_opt, d.get("purposes", [])]]:
		var opt: OptionButton = pair[0]
		opt.clear()
		for r in pair[1]:
			opt.add_item(String(r["label"]))
			opt.set_item_metadata(opt.item_count - 1, r["id"])
	var has_purpose: bool = _purpose_opt.item_count > 0
	_purpose_opt.visible = has_purpose
	_purpose_label.visible = has_purpose
	var has_style: bool = _style_opt.item_count > 0
	_style_opt.visible = has_style
	_style_label.visible = has_style
	_jank_row.visible = d.has("jank")
	_fall_row.visible = _kind() in FALL_KINDS
	_found_row.visible = _kind() in PILE_KINDS


static func _select_meta(opt: OptionButton, id: String) -> void:
	for i in opt.item_count:
		if str(opt.get_item_metadata(i)) == id:
			opt.select(i)


func _request_from_ui() -> BuildingRequest:
	var req: BuildingRequest
	if not _base.is_empty() and String(_base.get("kind", "")) == String(_kind()):
		# a tour stop: its own width, storeys, ... with the sidebar on top
		req = BuildingRequest.from_dict(_base)
		req.seed = int(_seed_spin.value)
	else:
		req = BrickWild.default_request(_kind(), int(_seed_spin.value))
	if _style_opt.item_count > 0:
		req.style = _style_opt.get_item_metadata(_style_opt.selected)
	if _purpose_opt.item_count > 0:
		req.purpose = _purpose_opt.get_item_metadata(_purpose_opt.selected)
	req.jank = snappedf(_jank.value, 0.01) if _jank_row.visible else 0.0
	req.ground_fall_m = 0.0
	req.ground_downhill_deg = 0.0
	req.foundation = &""
	req.pile_water_m = 0.0
	req.pile_freeboard_m = 0.0
	req.pile_deck_m = 0.0
	if _fall_row.visible and _fall.value > 0.0:
		req.ground_fall_m = _fall.value
		req.ground_downhill_deg = _downhill.value
	if _found_row.visible and _foundation.selected == 1:
		req.foundation = &"piles"
		req.pile_water_m = _pile_water.value
		req.ground_fall_m = 0.0
		req.ground_downhill_deg = 0.0
		if not _base.is_empty():
			for f in ["pile_freeboard_m", "pile_deck_m"]:
				req.set(f, float(_base.get(f, 0.0)))
	return req


## The command line that reopens exactly this building, with every sidebar
## value it was built with. A tour stop reopens through the tour, so fields
## the sidebar does not carry (width, storeys) come back too.
func _reopen_command(req: BuildingRequest) -> String:
	var parts := PackedStringArray([".\\visualqa\\walk.ps1"])
	if _terrain_name != "":
		parts.append("--village-terrain=%s --seed=%d" % [_terrain_name, req.seed])
		return " ".join(parts)
	if _tour_name != "" and not _base.is_empty():
		parts.append("--tour=%s --stop=%d" % [_tour_name, _tour_i + 1])
	parts.append("--kind=%s --seed=%d" % [req.kind, req.seed])
	if String(req.style) != "":
		parts.append("--style=%s" % req.style)
	if String(req.purpose) != "":
		parts.append("--purpose=%s" % req.purpose)
	if req.jank > 0.0:
		parts.append("--jank=%s" % _num(req.jank))
	if req.ground_fall_m > 0.0:
		parts.append("--fall=%s --downhill=%s" % [_num(req.ground_fall_m), _num(req.ground_downhill_deg)])
	if req.foundation == &"piles":
		parts.append("--foundation=piles --water=%s" % _num(req.pile_water_m))
	if _cutaway.button_pressed:
		parts.append("--cutaway")
	return " ".join(parts)


static func _num(v: float) -> String:
	return String.num(snappedf(v, 0.01))


func _generate() -> void:
	_busy = true
	_set_buttons(false)
	var req := _request_from_ui()
	_status.text = "Generating %s, seed %d… (a hotel or village takes a minute)" % [req.kind, req.seed]
	await get_tree().process_frame
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	var b := BrickWild.generate(req)
	if not b.is_ok():
		_status.text = "Not generated: %s" % [b.errors]
		_busy = false
		_set_buttons(true)
		return
	if _building_root != null:
		_building_root.queue_free()
	_clear_pins()
	_building = b
	_request = req
	_building_root = BrickWild.instantiate(b, _cutaway.button_pressed, true)
	if _solid_props.button_pressed:
		_solidify(_building_root)
	_world.add_child(_building_root)
	_placement = BrickWild.placement(b)
	_place_ground(req)
	_info.text = "%s\n%s · %s %s · seed %d" % [b.name(), req.kind, req.style, req.purpose, req.seed]
	if req.jank > 0.0:
		_info.text += " · jank %.2f" % req.jank
	if req.ground_fall_m > 0.0:
		_info.text += " · fall %.1f m @ %d°" % [req.ground_fall_m, int(req.ground_downhill_deg)]
	if req.foundation == &"piles":
		_info.text += " · piles, %.1f m water" % req.pile_water_m
	if not b.warnings.is_empty():
		_info.text += "\n%d generator warnings" % b.warnings.size()
	_status.text = "Built in %.1f s. Click the view to walk." % ((Time.get_ticks_msec() - t0) / 1000.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_respawn()
	_busy = false
	_set_buttons(true)


## The rig's ground under the building: the flat plane, tilted to the
## requested fall (local y = 0 is the ground at the uphill edge), or dropped
## to the bed under a house on piles with the water drawn at its surface.
func _place_ground(req: BuildingRequest) -> void:
	_ground.visible = true
	(_ground.get_child(0) as CollisionShape3D).disabled = false
	_ground.transform = Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0))
	_water_plane.visible = false
	if req.foundation == &"piles":
		var free := req.pile_freeboard_m if req.pile_freeboard_m > 0.0 else HousePiles.FREEBOARD_DEFAULT
		_ground.position.y = -free - req.pile_water_m
		_water_plane.visible = true
		_water_plane.position = Vector3(0, -free, 0)
		return
	if req.ground_fall_m <= 0.0:
		return
	var d := GroundFall.downhill_vector(req.ground_downhill_deg)
	var lo := INF
	var hi := -INF
	for c in GroundFall.corners(Rect2(-req.width * 0.5, -req.length * 0.5, req.width, req.length)):
		lo = minf(lo, c.dot(d))
		hi = maxf(hi, c.dot(d))
	if hi - lo < 1e-6:
		return
	# y(p) = -g * (p.d - lo): zero along the uphill edge, -fall along the downhill
	var g := req.ground_fall_m / (hi - lo)
	var n := Vector3(g * d.x, 1.0, g * d.y).normalized()
	_ground.transform = Transform3D(Basis(Quaternion(Vector3.UP, n)), Vector3(0, g * lo - 0.02, 0))


## --village-terrain=<fixture>: a village planned on real ground the way the
## vgroundterrain suite plans one (VillageSpec with terrain -> lot planner ->
## VillageAssembler), every mesh made solid. The rig's flat ground is put
## away; the village's own ground is walked.
func _generate_terrain_village() -> void:
	_busy = true
	_set_buttons(false)
	var path := _terrain_name
	if not path.begins_with("res://"):
		path = "res://tests/fixtures/terrain/%s.json" % _terrain_name
		if not FileAccess.file_exists(path):
			path = "res://tests/fixtures/terrain/real30/%s.json" % _terrain_name
	var ground := VillageTerrain.from_file(path)
	if not ground.valid():
		_status.text = "No terrain %s (%s)." % [_terrain_name, path]
		_busy = false
		_set_buttons(true)
		return
	var v_seed := int(_seed_spin.value)
	_status.text = "Planning a village on %s, seed %d… (two minutes or so)" % [_terrain_name, v_seed]
	await get_tree().process_frame
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	var spec := VillageSpec.new(v_seed)
	spec.population = 40
	spec.terrain = ground
	spec.generate(v_seed)
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(VillageProgrammer.programme(spec))
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	if plan.ground == null or plan.buildings.is_empty():
		_status.text = "The village was not planned on %s." % _terrain_name
		_busy = false
		_set_buttons(true)
		return
	if _building_root != null:
		_building_root.queue_free()
	_clear_pins()
	_building = null
	_request = BuildingRequest.from_dict({"kind": "village", "seed": v_seed})
	_building_root = VillageAssembler.build(plan, _cutaway.button_pressed)
	_solidify(_building_root)
	_world.add_child(_building_root)
	_ground.visible = false
	(_ground.get_child(0) as CollisionShape3D).disabled = true
	_water_plane.visible = false
	# outside the first building's door, on its lot's front, on the village's
	# own ground (a lot is turned, so the rig's "-Z is the front" does not hold)
	var first: Dictionary = plan.buildings[0]
	var door: Vector3 = first.get("door", Vector3.ZERO)
	var xf: Transform3D = first.get("transform", Transform3D.IDENTITY)
	var front := xf.basis * Vector3(0, 0, -1)
	front = Vector3(front.x, 0, front.z).normalized()
	var spot := door + front * 3.0
	var gy := VillageBuilder.ground_height(plan, Vector2(spot.x, spot.z))
	_placement = {"door": door, "front": front, "ray_top": gy + 2.5,
		"bounds": AABB(Vector3(door.x - 20, gy - 40, door.z - 20), Vector3(40, 120, 40))}
	_info.text = "Village on %s · %s · %d buildings · seed %d" % [_terrain_name,
		spec.form, plan.buildings.size(), v_seed]
	_status.text = "Built in %.1f s. You start at the first building's door." % (
		(Time.get_ticks_msec() - t0) / 1000.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_respawn()
	_busy = false
	_set_buttons(true)


# --- tours ---------------------------------------------------------------

func _load_tour(tour: String) -> String:
	var path := TOUR_DIR + tour.trim_suffix(".json") + ".json"
	if not FileAccess.file_exists(path):
		return "No tour " + path
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		data = (data as Dictionary).get("stops", [])
	if not (data is Array) or (data as Array).is_empty():
		return "Tour %s has no stops." % path
	_tour_name = tour.trim_suffix(".json")
	_tour = data
	_save_next.text = "Save & next stop →"
	_skip.visible = true
	_tour_label.visible = true
	return ""


## Put stop i on the sidebar (it is built by the caller). `over` is any
## command-line value that overrides the stop's own.
func _enter_stop(i: int, over := {}) -> void:
	_tour_i = i
	_base = (_tour[i] as Dictionary).duplicate(true)
	# the family's own default style and purpose where the stop says none
	var r := BuildingRequest.from_dict(_base)
	var ui := {"kind": String(r.kind), "style": String(r.style),
		"purpose": String(r.purpose), "seed": str(r.seed),
		"jank": str(_base.get("jank", 0)), "fall": str(_base.get("ground_fall_m", 0)),
		"downhill": str(_base.get("ground_downhill_deg", 0)),
		"foundation": _base.get("foundation", ""), "water": str(_base.get("pile_water_m", 1.0))}
	if _base.get("cutaway", false):
		ui["cutaway"] = ""
	ui.merge(over, true)
	_set_ui(ui)
	_tour_label.text = "Stop %d / %d — %s" % [i + 1, _tour.size(),
		String(_base.get("why", "(no why)"))]


## Go to the next stop; false at the end of the tour.
func _next_stop() -> bool:
	if _tour_i + 1 >= _tour.size():
		_tour_label.text = "Tour %s finished: %d stops." % [_tour_name, _tour.size()]
		return false
	_enter_stop(_tour_i + 1)
	return true


func _on_skip() -> void:
	if _busy:
		return
	if _next_stop():
		await _generate()
	else:
		_status.text = "End of the tour."


func _set_buttons(on: bool) -> void:
	for b in [_build_btn, _save_next, _save_seed, _skip]:
		b.disabled = not on


## Every prop gets the architecture's kind of collision, so furniture that
## blocks a door or a stair is felt, not only seen.
static func _solidify(root: Node3D) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var has_body := false
		for c in mi.get_children():
			if c is StaticBody3D:
				has_body = true
		if not has_body:
			mi.create_trimesh_collision()


## Outside the front door, facing it. Every family puts its entrance on its
## local -Z front, and placement() says where the door actually is.
func _respawn() -> void:
	var bounds: AABB = _placement.get("bounds", AABB())
	var door: Vector3 = _placement.get("door", Vector3.ZERO)
	var spot := Vector3(door.x, 0, door.z - 3.5)
	if door == Vector3.ZERO:
		spot = Vector3(bounds.get_center().x, 0, bounds.position.z - 4.0)
	var top := maxf(bounds.end.y, 10.0) + 5.0
	_yaw = PI
	if _placement.has("front"):
		var front: Vector3 = _placement["front"]
		spot = Vector3(door.x, 0, door.z) + front * 3.0
		top = float(_placement["ray_top"])
		_yaw = atan2(front.x, front.z)
	var q := PhysicsRayQueryParameters3D.create(Vector3(spot.x, top, spot.z),
		Vector3(spot.x, minf(-50.0, bounds.position.y - 50.0), spot.z))
	q.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(q)
	var fallback := float(_placement.get("ray_top", 2.5)) - 2.5
	spot.y = (hit["position"] as Vector3).y + 0.05 if not hit.is_empty() else fallback
	_player.global_position = spot
	_player.velocity = Vector3.ZERO
	_pitch = -0.05
	_apply_look()


# --- walking -------------------------------------------------------------

func _apply_look() -> void:
	_player.rotation = Vector3(0, _yaw, 0)
	_head.rotation = Vector3(_pitch, 0, 0)


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit or f is SpinBox


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if _filer_pid > 0 and Engine.get_physics_frames() % 30 == 0:
		_poll_filer()
	_hud.text = "%s%s%s\n%s" % [
		"FLY  " if _fly else "",
		"lantern  " if _lantern.visible else "",
		"pins: %d" % _pins.size(),
		"click to walk · Esc frees mouse" if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
			else "right-click: pin a problem"]
	var input := Vector2.ZERO
	var up := 0.0
	var running := false
	if not _typing() and not _dialog.visible:
		if Input.is_physical_key_pressed(KEY_W): input.y -= 1
		if Input.is_physical_key_pressed(KEY_S): input.y += 1
		if Input.is_physical_key_pressed(KEY_A): input.x -= 1
		if Input.is_physical_key_pressed(KEY_D): input.x += 1
		if Input.is_physical_key_pressed(KEY_SPACE): up += 1
		if Input.is_physical_key_pressed(KEY_C): up -= 1
		running = Input.is_physical_key_pressed(KEY_SHIFT)
	var basis := _player.global_transform.basis
	if _fly:
		var look := _cam.global_transform.basis
		var dir := (look * Vector3(input.x, 0, input.y)).normalized() + Vector3.UP * up
		var speed := FLY_SPEED * (2.5 if running else 1.0)
		_player.global_position += dir * speed * delta
		_player.velocity = Vector3.ZERO
		return
	var wish := (basis * Vector3(input.x, 0, input.y))
	wish.y = 0
	wish = wish.normalized() * (RUN_SPEED if running else WALK_SPEED)
	_player.velocity.x = wish.x
	_player.velocity.z = wish.z
	if _player.is_on_floor():
		if up > 0:
			_player.velocity.y = JUMP
	else:
		_player.velocity.y -= GRAVITY * delta
	var motion := Vector3(wish.x, 0, wish.z) * delta
	if _player.is_on_floor() and motion.length() > 0.0005 and _step_up(motion):
		return
	_player.move_and_slide()


## Climb a stair tread: if the way ahead is blocked at the feet but clear one
## step higher, lift, move, and settle back onto the tread.
##
## The lowest lift that works, not always the full STEP. A 1.75 m body lifted
## 0.4 m needs 2.15 m of headroom, and a doorway is 2.02 m: every door with a
## 0.12 m floor sill was refused from outside, however wide it was (WALK-QA,
## 6 Oct, hotel pins 7 and 14 -- reproduced and cleared by
## tools/walk_doors.gd).
func _step_up(motion: Vector3) -> bool:
	var xf := _player.global_transform
	if not _player.test_move(xf, motion):
		return false
	for h in [STEP * 0.25, STEP * 0.5, STEP * 0.75, STEP]:
		var lift := Vector3(0, h, 0)
		if _player.test_move(xf, lift):
			continue
		var raised := xf.translated(lift)
		if _player.test_move(raised, motion):
			continue
		var ahead := raised.translated(motion)
		var col := KinematicCollision3D.new()
		if not _player.test_move(ahead, -lift, col):
			continue
		# One frame's motion lands the capsule on the tread's front EDGE, whose
		# contact normal sits right at the slope limit, so every stair stalled
		# from flat ground (castle walk pin 5). Judge the tread a body radius
		# ahead instead; still move only this frame's distance.
		var probe := raised.translated(motion.normalized() * maxf(motion.length(), RADIUS))
		var tread := KinematicCollision3D.new()
		if _player.test_move(raised, probe.origin - raised.origin):
			probe = ahead
		if not _player.test_move(probe, -lift, tread) \
				or tread.get_normal().y < cos(_player.floor_max_angle):
			continue
		_player.global_transform = ahead.translated(col.get_travel())
		_player.velocity.y = 0.0
		return true
	return false


func _input(event: InputEvent) -> void:
	if _dialog.visible:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			_close_dialog()
			get_viewport().set_input_as_handled()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * LOOK
		_pitch = clampf(_pitch - event.relative.y * LOOK, -1.5, 1.5)
		_apply_look()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_pin_at(_sv.size / 2.0)
		get_viewport().set_input_as_handled()


func _on_view_input(event: InputEvent) -> void:
	if _dialog.visible or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_capture()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_pin_at(event.position)
		_svc.accept_event()


func _capture() -> void:
	get_viewport().gui_release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or _typing():
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		KEY_F:
			_fly = not _fly
			_player.velocity = Vector3.ZERO
		KEY_L:
			_lantern.visible = not _lantern.visible
		KEY_R:
			_respawn()


# --- pins ----------------------------------------------------------------

func _pin_at(screen_pos: Vector2) -> void:
	if _building_root == null or _busy:
		return
	var from := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 400.0)
	q.exclude = [_player.get_rid()]
	var hit := _cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_status.text = "Nothing solid there to pin."
		return
	var img := _sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	_ring(img, screen_pos)
	var pos: Vector3 = hit["position"]
	var local := _building_root.to_local(pos)
	_pending = {
		"pos": local, "normal": hit["normal"], "part": _part_name(hit["collider"]),
		"room": _room_at(local), "plan": _plan_records_at(local),
		"camera": _cam.global_position,
		"look": -_cam.global_transform.basis.z, "image": img,
		"yaw": _yaw, "pitch": _pitch, "feet": _player.global_position,
	}
	_recapture = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_dlg_note.text = ""
	_dlg_kind.select(0)
	_dlg_warn.text = "Choose a kind (no default), then a severity."
	_dialog.visible = true
	_dlg_note.grab_focus()


func _part_name(collider: Object) -> String:
	if collider == null or not (collider is Node):
		return ""
	var node := collider as Node
	if node.name == &"Ground":
		return "ground"
	var owner_node := node.get_parent() if node is StaticBody3D else node
	if _building_root.is_ancestor_of(owner_node):
		return String(_building_root.get_path_to(owner_node))
	return String(owner_node.name)


## The house plan's room under a point, by its clear-floor rect and storey.
## Approximate: the plinth lifts the floor a little above storey * height.
func _room_at(p: Vector3) -> String:
	if _building == null:
		return ""
	var plan := _building.plan
	if plan == null:
		return ""
	var out := PackedStringArray()
	for i in plan.rooms.size():
		var r: Dictionary = plan.rooms[i]
		if not r.has("rect"):
			continue
		var rect: Rect2 = r["rect"]
		if not rect.grow(0.15).has_point(Vector2(p.x, p.z)):
			continue
		var storey := HousePlan.record_storey(r)
		var base := float(storey) * plan.spec.height
		if p.y < base - 0.2 or p.y > base + plan.spec.height + 1.0:
			continue
		out.append("%s #%d (storey %d)" % [r.get("kind", "room"), i, storey])
	return ", ".join(out)


## The plan's own records at a point, so a pin names `furniture[12]
## Chair_1` rather than a scene node Godot named `@Node3D@124` this run:
## furniture whose footprint holds the point, and the nearest window and door
## within a metre on the same storey.
func _plan_records_at(p: Vector3) -> String:
	if _building == null:
		return ""
	var plan := _building.plan
	if plan == null:
		return ""
	var storey := clampi(int(floor((p.y + 0.3) / plan.spec.height)), 0, maxi(plan.spec.storeys - 1, 0))
	var at := Vector2(p.x, p.z)
	var out := PackedStringArray()
	for i in plan.furniture.size():
		var f: Dictionary = plan.furniture[i]
		var rect: Rect2 = f.get("rect", Rect2())
		if HousePlan.record_storey(f) == storey and rect.grow(0.1).has_point(at):
			out.append("furniture[%d] %s" % [i, f.get("key", "?")])
	for pair in [["window", plan.windows], ["door", plan.doors]]:
		var best := -1
		var best_d := 1.0
		for i in (pair[1] as Array).size():
			var r: Dictionary = pair[1][i]
			var d := at.distance_to(r.get("pos", Vector2(INF, INF)))
			if HousePlan.record_storey(r) == storey and d < best_d:
				best = i
				best_d = d
		if best >= 0:
			out.append("%ss[%d] (%.2f m away)" % [pair[0], best, best_d])
	return ", ".join(out)


static func _ring(img: Image, c: Vector2) -> void:
	for a in range(0, 360, 2):
		for k in [13.0, 14.0, 15.0, 16.0]:
			var p: Vector2 = c + Vector2.from_angle(deg_to_rad(a)) * k
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				img.set_pixelv(Vector2i(p), Color(1, 0.1, 0.1))


func _confirm_pin() -> void:
	if _pending.is_empty():
		return
	if _dlg_kind.selected <= 0:
		_dlg_warn.text = "Choose what kind of problem this is first."
		_dlg_kind.grab_focus()
		return
	var pin := _pending.duplicate()
	pin["kind"] = PIN_KINDS[_dlg_kind.selected - 1]
	pin["severity"] = SEVERITIES[_dlg_sev.selected]
	pin["note"] = _dlg_note.text.strip_edges()
	_pins.append(pin)
	var n := _pins.size()
	var marker := _make_marker(n)
	marker.position = _building_root.to_global(pin["pos"])
	_pins_root.add_child(marker)
	pin["marker"] = marker
	_pin_list.add_item(_pin_line(n, pin))
	if PIN_FIELD.has(pin["kind"]):
		(_checks[PIN_FIELD[pin["kind"]]] as CheckBox).button_pressed = true
	_status.text = "Pinned %s. %d pins on this building." % [pin["kind"], n]
	_close_dialog()


static func _pin_line(n: int, pin: Dictionary) -> String:
	return "%d. [%s] %s — %s" % [n, pin.get("severity", "bug"), pin["kind"],
		pin["note"] if pin["note"] != "" else "(no note)"]


func _close_dialog() -> void:
	_pending = {}
	_dialog.visible = false
	get_viewport().gui_release_focus()
	if _recapture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


static func _make_marker(n: int) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.1, 0.1)
	mat.no_depth_test = true
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	ball.mesh = sphere
	ball.material_override = mat
	root.add_child(ball)
	var label := Label3D.new()
	label.text = str(n)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0015
	label.font_size = 28
	label.outline_size = 8
	label.position.y = 0.25
	root.add_child(label)
	return root


func _go_to_pin(i: int) -> void:
	if i < 0 or i >= _pins.size():
		return
	var pin: Dictionary = _pins[i]
	_fly = true
	_player.global_position = pin["camera"] - Vector3(0, EYE, 0)
	_yaw = pin["yaw"]
	_pitch = pin["pitch"]
	_apply_look()
	_status.text = "At pin %d (fly mode on; F to walk)." % (i + 1)


func _delete_pin() -> void:
	var sel := _pin_list.get_selected_items()
	if sel.is_empty():
		return
	var i: int = sel[0]
	(_pins[i]["marker"] as Node).queue_free()
	_pins.remove_at(i)
	_pin_list.clear()
	for j in _pins.size():
		var pin: Dictionary = _pins[j]
		(pin["marker"].get_child(1) as Label3D).text = str(j + 1)
		_pin_list.add_item(_pin_line(j + 1, pin))


func _clear_pins() -> void:
	for pin in _pins:
		(pin["marker"] as Node).queue_free()
	_pins.clear()
	_pin_list.clear()


# --- saving --------------------------------------------------------------

func _save(next_kind: bool) -> void:
	if _busy or _building_root == null:
		return
	var err := _write_review()
	if err != "":
		_status.text = "Not saved: " + err
		return
	for f in FIELDS:
		(_checks[f] as CheckBox).button_pressed = false
	_notes.text = ""
	var saved := _status.text
	if _terrain_name != "":
		_seed_spin.value = randi() % 100000
		await _generate_terrain_village()
		_status.text = saved + " " + _status.text
		return
	if _tour_name != "" and next_kind:
		if not _next_stop():
			_status.text = saved + " End of the tour."
			_save_next.disabled = true
			_skip.disabled = true
			return
	elif next_kind:
		_base = {}
		_kind_opt.select((_kind_opt.selected + 1) % _kind_opt.item_count)
		_fill_options()
	else:
		_seed_spin.value = randi() % 100000
	await _generate()
	_status.text = saved + " " + _status.text


func _building_name() -> String:
	if _building != null:
		return _building.name()
	return "Village on %s" % _terrain_name


## Append one review to the rating file, its screenshots beside it, and the
## same review as one JSON line. Returns an error message, or "".
func _write_review() -> String:
	var rate_path := ProjectSettings.globalize_path(_rate_file)
	var dir := rate_path.get_base_dir()
	var shot_dir := dir.path_join("walk_shots")
	if DirAccess.make_dir_recursive_absolute(shot_dir) != OK:
		return "cannot create " + shot_dir
	var id := "%x%x" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]
	var stamp := Time.get_datetime_string_from_system(true) + "Z"
	var req := _request
	var rows: Array = []
	var md := PackedStringArray()
	md.append("<!-- human-walk %s %s -->\n" % [id, req.kind])
	md.append("## Walk — %s: %s / %s, seed %d — %s\n\n" % [
		String(req.kind).capitalize(), req.style, req.purpose, req.seed, stamp])
	md.append("Building: %s · cutaway: %s · solid furniture: %s\n\n" % [
		_building_name(), "yes" if _cutaway.button_pressed else "no",
		"yes" if _solid_props.button_pressed else "no"])
	md.append("Request: `%s`\n\n" % JSON.stringify(req.to_dict()))
	var reopen := _reopen_command(req)
	md.append("Re-open: `%s`\n\n" % reopen)
	if _tour_name != "" and not _base.is_empty():
		md.append("Tour: %s, stop %d / %d — %s\n\n" % [_tour_name, _tour_i + 1, _tour.size(),
			String(_base.get("why", ""))])
	var flags := {}
	for f in FIELDS:
		flags[f] = (_checks[f] as CheckBox).button_pressed
		md.append("- [%s] %s\n" % ["x" if flags[f] else " ", f])
	var note := _notes.text.strip_edges().replace("<!--", "&lt;!--")
	if note != "":
		md.append("\nNotes:\n")
		for line in note.split("\n"):
			md.append("> %s\n" % line)
	md.append("\n### Pins (%d)\n\n" % _pins.size())
	if _pins.is_empty():
		md.append("None.\n")
	for i in _pins.size():
		var pin: Dictionary = _pins[i]
		var shot := "%s_%d.png" % [id, i + 1]
		var img: Image = pin["image"]
		if img.save_png(shot_dir.path_join(shot)) != OK:
			return "cannot write screenshot " + shot
		var pin_note := String(pin["note"]).replace("<!--", "&lt;!--").replace("\n", " ")
		md.append("%d. **%s** (%s) — %s\n" % [i + 1, pin["kind"], pin["severity"],
			pin_note if pin_note != "" else "(no note)"])
		md.append("   - at %s (building-local), normal %s, hit `%s`%s\n" % [
			_v(pin["pos"]), _v(pin["normal"]), pin["part"],
			", room: " + pin["room"] if pin["room"] != "" else ""])
		if pin["plan"] != "":
			md.append("   - plan: %s\n" % pin["plan"])
		md.append("   - camera %s looking %s\n" % [_v(pin["camera"]), _v(pin["look"])])
		md.append("   - ![pin %d](walk_shots/%s)\n" % [i + 1, shot])
		rows.append({"n": i + 1, "kind": pin["kind"], "severity": pin["severity"], "note": pin["note"],
			"pos": _a(pin["pos"]), "normal": _a(pin["normal"]), "part": pin["part"],
			"room": pin["room"], "plan": pin["plan"], "camera": _a(pin["camera"]), "look": _a(pin["look"]),
			"screenshot": "walk_shots/" + shot})
	md.append("\n")

	if not FileAccess.file_exists(rate_path):
		var init := FileAccess.open(rate_path, FileAccess.WRITE)
		if init == null:
			return "cannot create " + rate_path
		init.store_string("# Human visual QA\n\nSaved by the local review page and the walk rig. Pretty means approval; the other checked boxes mean a visible problem.\n\n")
		init.close()
	var file := FileAccess.open(rate_path, FileAccess.READ_WRITE)
	if file == null:
		return "cannot open " + rate_path
	file.seek_end()
	file.store_string("".join(md))
	file.close()

	var jsonl := dir.path_join("walk_pins.jsonl")
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(jsonl) else FileAccess.WRITE
	var jf := FileAccess.open(jsonl, mode)
	if jf != null:
		jf.seek_end()
		var record := {"review_id": id, "time": stamp,
			"request": req.to_dict(), "name": _building_name(),
			"cutaway": _cutaway.button_pressed, "flags": flags,
			"note": _notes.text.strip_edges(), "pins": rows, "reopen": reopen}
		if _tour_name != "" and not _base.is_empty():
			record["tour"] = _tour_name
			record["stop"] = _tour_i + 1
			record["why"] = String(_base.get("why", ""))
		if _terrain_name != "":
			record["village_terrain"] = _terrain_name
		jf.store_line(JSON.stringify(record))
		jf.close()
	_status.text = "Saved %d pins to %s." % [_pins.size(), _rate_file.trim_prefix("res://")]
	if _file_todos.button_pressed and not _pins.is_empty():
		_status.text += " " + _launch_filer(id, jsonl)
	return ""


## File this review's pins as waterfree todos in the background: the rig does
## not wait. _physics_process notices when the filer ends and shows its last
## log line. An autotest files with --dry-run.
func _launch_filer(review_id: String, jsonl: String) -> String:
	var log_path := ProjectSettings.globalize_path(FILER_LOG)
	DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())
	var args := PackedStringArray(["-I", ProjectSettings.globalize_path(FILER),
		"--pins", jsonl, "--review", review_id, "--log", log_path])
	if _filer_dry:
		args.append("--dry-run")
	var pid := OS.create_process("python", args)
	if pid <= 0:
		return "Could not start the filer (is python on PATH?)."
	_filer_pid = pid
	return "Filing %d pins as todos…" % _pins.size()


## The filer's last summary line, once its process has ended.
func _poll_filer() -> void:
	if _filer_pid <= 0 or OS.is_process_running(_filer_pid):
		return
	_filer_pid = -1
	var text := FileAccess.get_file_as_string(FILER_LOG).strip_edges()
	var last := text.get_slice("\n", text.get_slice_count("\n") - 1) if text != "" else "no log line"
	_status.text += " Filed: " + last.substr(20)


static func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


static func _a(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


# --- command line --------------------------------------------------------

static func _user_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		var eq := s.find("=")
		if eq < 0:
			out[s] = ""
		else:
			out[s.substr(0, eq)] = s.substr(eq + 1)
	return out


## Smoke run for an agent: walk forward a little, screenshot, optionally pin
## the crosshair and save to a scratch rating file, quit.
##   -- --autoshot=res://artifacts/walk_qa/shot.png [--autopin --rate-file=res://artifacts/walk_qa/rate.md]
func _autotest(args: Dictionary) -> void:
	for i in 40:
		await get_tree().physics_frame
	if args.has("walk"):
		var key := InputEventKey.new()
		key.physical_keycode = KEY_W
		key.pressed = true
		Input.parse_input_event(key)
		for i in int(args["walk"]):
			await get_tree().physics_frame
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
		for i in 10:
			await get_tree().physics_frame
	var shot := ProjectSettings.globalize_path(String(args["autoshot"]))
	DirAccess.make_dir_recursive_absolute(shot.get_base_dir())
	await RenderingServer.frame_post_draw
	_sv.get_texture().get_image().save_png(shot)
	get_viewport().get_texture().get_image().save_png(shot.get_basename() + "_window.png")
	print("walk_qa: feet ", _player.global_position, " on floor ", _player.is_on_floor(), " door ", _placement.get("door"), " bounds ", _placement.get("bounds"))
	if args.has("autopin"):
		_pin_at(_sv.size / 2.0)
		if _dialog.visible:
			_dlg_note.text = "autotest pin"
			_confirm_pin()
			print("walk_qa: unchosen kind refused: ", _pins.is_empty(), " (", _dlg_warn.text, ")")
			_dlg_kind.select(PIN_KINDS.find("door") + 1)
			_dlg_sev.select(SEVERITIES.find("polish"))
			_confirm_pin()
			_filer_dry = true
			print("walk_qa: save ", _write_review(), " ", _status.text)
			for i in 600:
				await get_tree().physics_frame
				if _filer_pid <= 0:
					break
			print("walk_qa: filer ", _status.text)
		else:
			print("walk_qa: autopin hit nothing: ", _status.text)
	get_tree().quit()
