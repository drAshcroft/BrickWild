extends SceneTree
## Screenshot of the Studio UI itself, to prove the 3D preview panel actually
## renders. Must run WITHOUT --headless.
## Run: godot --path . --script res://tools/shoot_studio.gd

func _init() -> void:
	var scn: PackedScene = load("res://scenes/studio.tscn")
	var ui: Control = scn.instantiate()
	root.add_child(ui)
	root.size = Vector2i(1400, 900)
	for i in range(30):
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png("res://artifacts/renders/studio_ui.png")
	print("wrote studio_ui.png")
	quit(0)
