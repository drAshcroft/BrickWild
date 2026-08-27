extends SceneTree
## Screenshots of the Studio UI itself, one per kind of building it can
## generate. Must run WITHOUT --headless.
## Run: godot --path . --script res://tools/shoot_studio.gd
##
## The file names come from the dropdown rather than from a list kept here: the
## kinds are ordered by a dictionary in studio.gd, and a hard-coded list went
## quietly out of order the moment a fourth kind was added in the middle of it.

func _init() -> void:
	var scn: PackedScene = load("res://scenes/studio.tscn")
	var ui: Control = scn.instantiate()
	root.add_child(ui)
	root.size = Vector2i(1400, 900)
	# let the scene run its own _ready() before reaching into its @onready refs
	await process_frame
	for k in range(ui.kind_opt.item_count):
		ui.kind_opt.select(k)
		ui._on_kind_changed()
		for i in range(30):
			await process_frame
		var name: String = ui.kind_opt.get_item_text(k).to_lower()
		var img: Image = root.get_texture().get_image()
		img.save_png("res://artifacts/renders/studio_%s.png" % name)
		print("wrote studio_%s.png" % name)
	quit(0)
