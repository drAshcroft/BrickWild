extends SceneTree
## Screenshots of the Studio UI itself, to prove the 3D preview panel actually
## renders -- one per kind the studio can generate. Must run WITHOUT --headless.
## Run: godot --path . --script res://tools/shoot_studio.gd

func _init() -> void:
	var scn: PackedScene = load("res://scenes/studio.tscn")
	var ui: Control = scn.instantiate()
	root.add_child(ui)
	root.size = Vector2i(1400, 900)
	# let the scene run its own _ready() before reaching into its @onready refs
	await process_frame
	var kinds: Array[String] = ["church", "castle", "house"]
	for k in range(kinds.size()):
		ui.kind_opt.select(k)
		ui._on_kind_changed()
		for i in range(30):
			await process_frame
		var img: Image = root.get_texture().get_image()
		img.save_png("res://artifacts/renders/studio_%s.png" % kinds[k])
		print("wrote studio_%s.png" % kinds[k])
	quit(0)
