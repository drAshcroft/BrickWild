extends SceneTree
## Fingerprint every vertex the castle builder emits for the canonical sweep
## (CastleSweep: every style x tier x three sizes on fixed seeds), plus the
## village's own seat requests. Two checkouts that print the same lines emit
## the same geometry -- how a "flat castles move nothing" claim is a diff
## rather than an assertion (VTER-CASTLE-SLOPE). The castle twin of
## tools/dump_house_vertices.gd.
##
##   godot --headless --path . --script res://tools/dump_castle_vertices.gd > a.txt
##   godot --headless --path . --script res://tools/dump_castle_vertices.gd -- house manor
##
## User args name the tiers to sweep (default: house manor castle fortress).

func _init() -> void:
	var tiers: Array = []
	for a in OS.get_cmdline_user_args():
		tiers.append(StringName(a))
	if tiers.is_empty():
		tiers = CastleSweep.tiers()
	for style in CastleSweep.styles():
		for tier in tiers:
			for i in range(CastleSweep.COUNT):
				var spec: CastleSpec = CastleSweep.spec_at(style, tier, i)
				_emit("%s %s %d" % [style, tier, i], spec)
	# the village's seat and hold, through the public path
	for style in [&"norman", &"french_chateau", &"edwardian", &"bavarian", &"moorish",
			&"japanese", &"crusader"]:
		for size in [Vector3(40.0, 50.0, 10.0), Vector3(12.0, 14.0, 8.0), Vector3(26.0, 32.5, 10.0)]:
			var made := BrickWild.generate(BuildingRequest.castle(4242, style, size.x, size.y, size.z))
			if made.is_ok():
				_emit("request %s %s" % [style, size], made.spec)
	quit()


func _emit(label: String, spec: CastleSpec) -> void:
	var mesh := CastleBuilder.new().build(spec)
	for si in range(mesh.get_surface_count()):
		var v: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		var acc := 0
		var sum := Vector3.ZERO
		for p in v:
			sum += p
			acc = (acc * 31 + roundi(p.x * 100000.0)) % 1000000007
			acc = (acc * 31 + roundi(p.y * 100000.0)) % 1000000007
			acc = (acc * 31 + roundi(p.z * 100000.0)) % 1000000007
		print("%s surf=%d verts=%d hash=%d sum=%.5f,%.5f,%.5f"
			% [label, si, v.size(), acc, sum.x, sum.y, sum.z])
