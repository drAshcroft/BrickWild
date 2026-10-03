extends Control
## Walk QA: generate one BrickWild building, walk through it, pin problems.
##
##   godot --path . res://visualqa/walk/walk_qa.tscn
##   godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=house --seed=8102 --style=cottage
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
const PIN_KINDS := ["collision", "window", "door", "roof", "wall", "floor / stair", "furniture", "other"]
## A pin of this kind also ticks the matching rating box.
const PIN_FIELD := {"collision": "collisions", "window": "window problems",
	"door": "door problems", "roof": "roof problems"}
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

var _dialog: PanelContainer
var _dlg_kind: OptionButton
var _dlg_note: LineEdit
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
	_dialog.offset_bottom = 190
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
	_dlg_kind = OptionButton.new()
	for k in PIN_KINDS:
		_dlg_kind.add_item(k)
	box.add_child(_dlg_kind)
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
		if args.get("kind", "house") == String(k):
			_kind_opt.select(_kind_opt.item_count - 1)
	_fill_options()
	_select_meta(_style_opt, String(args.get("style", "")))
	_select_meta(_purpose_opt, String(args.get("purpose", "")))
	_seed_spin.value = int(args.get("seed", "1"))
	_cutaway.button_pressed = args.has("cutaway")


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


static func _select_meta(opt: OptionButton, id: String) -> void:
	for i in opt.item_count:
		if str(opt.get_item_metadata(i)) == id:
			opt.select(i)


func _request_from_ui() -> BuildingRequest:
	var req := BrickWild.default_request(_kind(), int(_seed_spin.value))
	if _style_opt.item_count > 0:
		req.style = _style_opt.get_item_metadata(_style_opt.selected)
	if _purpose_opt.item_count > 0:
		req.purpose = _purpose_opt.get_item_metadata(_purpose_opt.selected)
	return req


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
	_info.text = "%s\n%s · %s %s · seed %d" % [b.name(), req.kind, req.style, req.purpose, req.seed]
	if not b.warnings.is_empty():
		_info.text += "\n%d generator warnings" % b.warnings.size()
	_status.text = "Built in %.1f s. Click the view to walk." % ((Time.get_ticks_msec() - t0) / 1000.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_respawn()
	_busy = false
	_set_buttons(true)


func _set_buttons(on: bool) -> void:
	for b in [_build_btn, _save_next, _save_seed]:
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
	var q := PhysicsRayQueryParameters3D.create(Vector3(spot.x, top, spot.z),
		Vector3(spot.x, -50, spot.z))
	q.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(q)
	spot.y = (hit["position"] as Vector3).y + 0.05 if not hit.is_empty() else 0.0
	_player.global_position = spot
	_player.velocity = Vector3.ZERO
	_yaw = PI
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
func _step_up(motion: Vector3) -> bool:
	var xf := _player.global_transform
	if not _player.test_move(xf, motion):
		return false
	var lift := Vector3(0, STEP, 0)
	if _player.test_move(xf, lift):
		return false
	var raised := xf.translated(lift)
	if _player.test_move(raised, motion):
		return false
	var ahead := raised.translated(motion)
	var col := KinematicCollision3D.new()
	if not _player.test_move(ahead, -lift, col):
		return false
	if col.get_normal().y < cos(_player.floor_max_angle):
		return false
	_player.global_transform = ahead.translated(col.get_travel())
	_player.velocity.y = 0.0
	return true


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
	if _building == null or _busy:
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
	var pin := _pending.duplicate()
	pin["kind"] = PIN_KINDS[_dlg_kind.selected]
	pin["note"] = _dlg_note.text.strip_edges()
	_pins.append(pin)
	var n := _pins.size()
	var marker := _make_marker(n)
	marker.position = _building_root.to_global(pin["pos"])
	_pins_root.add_child(marker)
	pin["marker"] = marker
	_pin_list.add_item("%d. %s — %s" % [n, pin["kind"], pin["note"] if pin["note"] != "" else "(no note)"])
	if PIN_FIELD.has(pin["kind"]):
		(_checks[PIN_FIELD[pin["kind"]]] as CheckBox).button_pressed = true
	_status.text = "Pinned %s. %d pins on this building." % [pin["kind"], n]
	_close_dialog()


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
		_pin_list.add_item("%d. %s — %s" % [j + 1, pin["kind"], pin["note"] if pin["note"] != "" else "(no note)"])


func _clear_pins() -> void:
	for pin in _pins:
		(pin["marker"] as Node).queue_free()
	_pins.clear()
	_pin_list.clear()


# --- saving --------------------------------------------------------------

func _save(next_kind: bool) -> void:
	if _busy or _building == null:
		return
	var err := _write_review()
	if err != "":
		_status.text = "Not saved: " + err
		return
	for f in FIELDS:
		(_checks[f] as CheckBox).button_pressed = false
	_notes.text = ""
	if next_kind:
		_kind_opt.select((_kind_opt.selected + 1) % _kind_opt.item_count)
		_fill_options()
	else:
		_seed_spin.value = randi() % 100000
	var saved := _status.text
	await _generate()
	_status.text = saved + " " + _status.text


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
		_building.name(), "yes" if _cutaway.button_pressed else "no",
		"yes" if _solid_props.button_pressed else "no"])
	md.append("Request: `%s`\n\n" % JSON.stringify(req.to_dict()))
	md.append("Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=%s --seed=%d --style=%s --purpose=%s%s`\n\n" % [
		req.kind, req.seed, req.style, req.purpose, " --cutaway" if _cutaway.button_pressed else ""])
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
		md.append("%d. **%s** — %s\n" % [i + 1, pin["kind"], pin_note if pin_note != "" else "(no note)"])
		md.append("   - at %s (building-local), normal %s, hit `%s`%s\n" % [
			_v(pin["pos"]), _v(pin["normal"]), pin["part"],
			", room: " + pin["room"] if pin["room"] != "" else ""])
		if pin["plan"] != "":
			md.append("   - plan: %s\n" % pin["plan"])
		md.append("   - camera %s looking %s\n" % [_v(pin["camera"]), _v(pin["look"])])
		md.append("   - ![pin %d](walk_shots/%s)\n" % [i + 1, shot])
		rows.append({"n": i + 1, "kind": pin["kind"], "note": pin["note"],
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
		jf.store_line(JSON.stringify({"review_id": id, "time": stamp,
			"request": req.to_dict(), "name": _building.name(),
			"cutaway": _cutaway.button_pressed, "flags": flags,
			"note": _notes.text.strip_edges(), "pins": rows}))
		jf.close()
	_status.text = "Saved %d pins to %s." % [_pins.size(), _rate_file.trim_prefix("res://")]
	return ""


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
			_dlg_kind.select(PIN_KINDS.find("door"))
			_dlg_note.text = "autotest pin"
			_confirm_pin()
			print("walk_qa: save ", _write_review(), " ", _status.text)
		else:
			print("walk_qa: autopin hit nothing: ", _status.text)
	get_tree().quit()
