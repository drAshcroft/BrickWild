extends SceneTree
## Scratch probe: what does the dressing actually come out as?
## godot --headless --path . --script res://scratch/probe_dressing.gd

func _init() -> void:
	var church := ChurchSpec.new()
	church.style = &"gothic"
	church.width = 14.0
	church.length = 34.0
	church.height = 14.0
	ChurchGenerator.generate(church, 5007)
	_report_props("church", ChurchBuilder.new())
	_count_scene("church scene", ChurchAssembler.build(church, true))

	var castle := CastleSpec.new()
	castle.style = &"norman"
	castle.width = 60.0
	castle.length = 90.0
	castle.height = 18.0
	CastleGenerator.generate(castle, 9100)
	_count_scene("castle scene", CastleAssembler.build(castle, true))

	var cb := CastleBuilder.new()
	cb.build(castle)
	_tally("castle", cb.prop_log)
	var chb := ChurchBuilder.new()
	chb.build(church)
	_tally("church", chb.prop_log)
	quit(0)


func _report_props(_label: String, _b: ChurchBuilder) -> void:
	pass


func _tally(label: String, props: Array) -> void:
	var by_kind := {}
	var by_key := {}
	for p in props:
		var k := String(p["kind"])
		by_kind[k] = int(by_kind.get(k, 0)) + 1
		by_key[String(p["key"])] = int(by_key.get(String(p["key"]), 0)) + 1
	print("%s: %d props" % [label, props.size()])
	var kinds: Array = by_kind.keys()
	kinds.sort()
	for k2 in kinds:
		print("    %-10s %d" % [k2, by_kind[k2]])
	var keys: Array = by_key.keys()
	keys.sort()
	print("    keys: " + ", ".join(keys.map(func(k3): return "%s x%d" % [k3, by_key[k3]])))


func _count_scene(label: String, root: Node3D) -> void:
	var meshes := 0
	var lights := 0
	for child in root.get_children():
		if child is OmniLight3D:
			lights += 1
		if child.name == "Dressing":
			for g in child.get_children():
				if g is Node3D:
					meshes += 1
	print("%s: %d prop nodes, %d lights" % [label, meshes, lights])
	root.free()
