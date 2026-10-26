extends SceneTree
## Fingerprint the FLAT village's mesh, so "a flat village is mesh-identical"
## is a diff rather than an assertion (VTER-GROUND-MESH).
##
## For a handful of flat villages chosen to reach every branch of
## VillageBuilder (each form, river, coast and pond water with bridges and a
## mill race, palisade, wall and hedge edges), prints one line per village:
## a hash of every surface's vertex, normal, colour and uv arrays, a hash of
## the component and mass logs, and -- for the first two, which are assembled
## -- a hash of every building transform and every prop and plant position.
##
##   godot --headless --path <tree> --script res://tools/fingerprint_village_ground.gd > out.txt
##
## Run it in a base worktree and in this one and `diff` the two files.

const CASES := [
	# [label, form, water, enclosure, population, seed, assemble, purpose]
	["street-none-none", &"street", &"none", &"none", 40, 4242, true, &"farming"],
	["green-river-palisade", &"green", &"river", &"palisade", 60, 11, true, &"farming"],
	["crossroads-stream-wall", &"crossroads", &"stream", &"wall", 80, 7, false, &"garrison"],
	["strand-coast-hedge", &"strand", &"coast", &"hedge", 50, 3, false, &"fishing"],
	["round-pond-none", &"round", &"pond", &"none", 40, 19, false, &"farming"],
	["planted-river-wall", &"planted", &"river", &"wall", 120, 5, false, &"garrison"],
	["gate-none-palisade", &"gate", &"none", &"palisade", 90, 23, false, &"market"],
]


func _initialize() -> void:
	for c in CASES:
		var spec := VillageSpec.new(int(c[5]))
		spec.population = int(c[4])
		spec.purpose = c[7]
		spec.water = c[2]
		spec.enclosure = c[3]
		spec.generate(int(c[5]))
		spec.form = c[1]
		var plan := VillageLotPlanner.plan(spec)
		var b := VillageBuilder.new()
		var mesh := b.build(plan)
		var line := "%s mesh=%s logs=%s surfaces=%d" % [c[0], _mesh_hash(mesh),
			str(hash(var_to_str(b.component_log) + var_to_str(b.mass_log))), mesh.get_surface_count()]
		if bool(c[6]):
			var scene := VillageAssembler.build(plan)
			line += " scene=%s" % _scene_hash(scene)
			scene.free()
		print(line)
	quit()


static func _mesh_hash(mesh: ArrayMesh) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		ctx.update(mesh.surface_get_name(s).to_utf8_buffer())
		for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
			if arrays[k] != null:
				ctx.update(var_to_bytes(arrays[k]))
	return ctx.finish().hex_encode().substr(0, 16)


static func _scene_hash(scene: Node3D) -> String:
	var rows := PackedStringArray()
	for group in ["Buildings", "Props", "Plants"]:
		var parent := scene.get_node_or_null(group)
		if parent == null:
			continue
		for n in parent.get_children():
			rows.append("%s/%s %s" % [group, n.name, var_to_str((n as Node3D).transform)])
			var ext := n.get_node_or_null("Exterior")
			if ext != null:
				for e in ext.get_children():
					rows.append("  %s %s" % [e.name, var_to_str((e as Node3D).transform)])
	return "%d:%s" % [rows.size(), "\n".join(rows).sha256_text().substr(0, 16)]
