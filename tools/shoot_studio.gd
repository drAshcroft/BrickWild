extends SceneTree
## Screenshots of the Studio UI itself, one per kind of building it can
## generate. Must run WITHOUT --headless.
## Run: godot --path . --script res://tools/shoot_studio.gd
## Only the village sheet: ... -- village
##
## The file names come from the dropdown rather than from a list kept here: the
## kinds are ordered by a dictionary in studio.gd, and a hard-coded list went
## quietly out of order the moment a fourth kind was added in the middle of it.

func _init() -> void:
	var scn: PackedScene = load("res://scenes/studio.tscn")
	var ui: Control = scn.instantiate()
	ui.auto_generate = false
	root.add_child(ui)
	# let the scene run its own _ready() before reaching into its @onready refs
	await process_frame
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = Vector2i(1600, 1000)
	await process_frame
	var selected := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://artifacts/renders")
	for k in range(ui.kind_opt.item_count):
		var kind: StringName = ui.kind_opt.get_item_metadata(k)
		if not selected.is_empty() and not String(kind) in selected:
			continue
		ui.kind_opt.select(k)
		ui._on_kind_changed()
		ui.seed_input.text = "42021"
		if kind == &"village":
			# A readable hamlet with all six controls and both landscape layers.
			ui.width_slider.value = 16
			ui.length_slider.value = 45
			ui.water_opt.select(1) # first non-none option from the descriptor
			ui.edge_opt.select(1)
		ui.auto_generate = true
		ui.regenerate()
		ui.auto_generate = false
		if ui.specs.is_empty():
			printerr("Studio generation failed for %s: %s" % [kind, ui.info_label.text])
			quit(1)
			return
		for i in range(30):
			await process_frame
		var name: String = ui.kind_opt.get_item_text(k).to_lower()
		if not name.is_valid_identifier():
			name = String(kind)         # "shop / civic building" is not a file name
		var img: Image = root.get_texture().get_image()
		img.save_png("res://artifacts/renders/studio_%s.png" % name)
		if kind == &"village":
			DirAccess.make_dir_recursive_absolute("res://docs/screenshots")
			img.save_png("res://docs/screenshots/studio_village.png")
		print("wrote studio_%s.png" % name)
		if kind == &"house":
			# the plan per storey is the point of the house sheet: a second shot
			# with two storeys shows the plans side by side and a stair
			ui.storeys_slider.value = 2
			ui.auto_generate = true
			ui.regenerate()
			ui.auto_generate = false
			for i in range(30):
				await process_frame
			root.get_texture().get_image().save_png("res://artifacts/renders/studio_house_2storey.png")
			print("wrote studio_house_2storey.png")
	quit(0)
