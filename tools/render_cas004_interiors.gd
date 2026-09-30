extends "res://tools/render_shots.gd"

const OUT := "cas004_acceptance"
const Interiors = preload("res://src/castle/castle_interiors.gd")

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR + "/" + OUT))
	_build_stage()
	await process_frame
	await _render_keep()
	await _render_wizard()
	quit()

func _render_keep() -> void:
	var spec := CastleSweep.spec_at(&"norman", &"fortress", 2)
	var rows := Interiors.primary(spec)
	var plan: HousePlan = rows["keep"].plan
	var room_index := 1 # The generated great hall, carrying the new table and seat.
	var cut := HousePlan.new()
	cut.spec = plan.spec
	cut.spec.storeys = 1
	cut.spec.room_count = 1
	cut.spec.program = [plan.kind_of(room_index)]
	cut.spec.entry_storey = 0
	var room: Dictionary = plan.rooms[room_index].duplicate(true)
	room["storey"] = 0
	cut.rooms = [room]
	for door_row in plan.doors:
		if HousePlan.record_storey(door_row) != room_index:
			continue
		var door: Dictionary = door_row.duplicate(true)
		door["a"] = 0
		door["storey"] = 0
		cut.doors.append(door)
	for window_row in plan.windows:
		if int(window_row["room"]) != room_index:
			continue
		var window: Dictionary = window_row.duplicate(true)
		window["room"] = 0
		window["storey"] = 0
		cut.windows.append(window)
	for furniture_row in plan.furniture:
		if int(furniture_row["room"]) != room_index:
			continue
		var furniture: Dictionary = furniture_row.duplicate(true)
		furniture["room"] = 0
		furniture["storey"] = 0
		var position: Vector3 = furniture["pos"]
		position.y = 0.0
		furniture["pos"] = position
		cut.furniture.append(furniture)
	_mesh_inst.mesh = null
	var node: Node3D = HouseAssembler.build(cut, true)
	_root3d.add_child(node)
	await process_frame
	var focus := Vector3(0.0, 1.2, 0.0)
	_cam.position = focus + Vector3(2.2, 2.6, 2.8)
	_cam.look_at(focus, Vector3.UP)
	await _capture(OUT + "/norman_fortress_keep_cutaway.jpg")
	var furniture_root: Node3D = node.get_node("Furniture")
	print("CAS004_INTERIOR_RENDER norman seed=", spec.seed,
		" room=", cut.kind_of(0), " props=", furniture_root.get_child_count(),
		" placements=", cut.furniture)
	node.queue_free()

func _render_wizard() -> void:
	var spec := CastleSpec.new()
	spec.style = &"wizard"
	spec.width = 9.0
	spec.length = 9.0
	spec.height = 42.0
	spec.tier_override = &"house"
	CastleGenerator.generate(spec, 12012)
	var plan: HousePlan = Interiors.primary(spec)["tower_house"].plan
	var node: Node3D = HouseAssembler.build(plan, true)
	_mesh_inst.mesh = null
	_root3d.add_child(node)
	await process_frame
	var door: Dictionary = plan.doors[plan.entrance()]
	var pos: Vector2 = door["pos"]
	var outward: Vector2 = door["normal"]
	var stair_rect := Rect2(plan.stairs[0]["rect"])
	var stair_centre := stair_rect.get_center()
	var target := Vector3(stair_centre.x, 1.5, stair_centre.y)
	var sightline := (pos - stair_centre).normalized()
	_cam.position = Vector3(pos.x + sightline.x * 4.0,
		float(door["sill"]) + 3.8, pos.y + sightline.y * 4.0)
	_cam.look_at(target, Vector3.UP)
	var interior_fill := OmniLight3D.new()
	interior_fill.position = target + Vector3(0.0, 3.0, 0.0)
	interior_fill.light_energy = 18.0
	interior_fill.omni_range = 25.0
	_root3d.add_child(interior_fill)
	await _capture(OUT + "/wizard_tower_raised_door_stair.jpg")
	print("CAS004_INTERIOR_RENDER wizard seed=12012 door=", door,
		" first_stair=", stair_rect, " stairs=", plan.stairs.size())
	node.queue_free()
	interior_fill.queue_free()
