extends SceneTree
## One-off scene authoring tool (not a test).
## Regenerates the canonical QA fixture scene.
## Run: godot --headless --script res://tools/gen_scene.gd
func _init() -> void:
	var root := Control.new()
	root.name = "Root"
	var hs := HSplitContainer.new()
	hs.name = "HSplit"
	root.add_child(hs)
	var lp := PanelContainer.new()
	lp.name = "LeftPanel"
	hs.add_child(lp)
	var mg := MarginContainer.new()
	mg.name = "Margin"
	lp.add_child(mg)
	var gr := GridContainer.new()
	gr.name = "Grid"
	gr.columns = 2
	mg.add_child(gr)
	var lb := Label.new()
	lb.name = "Lbl"
	lb.text = "hi"
	gr.add_child(lb)
	var ps := PackedScene.new()
	root.owner = root
	for n in [hs, lp, mg, gr, lb]:
		n.owner = root
	ps.pack(root)
	ResourceSaver.save(ps, "res://tests/fixtures/canon.tscn")
	quit(0)
