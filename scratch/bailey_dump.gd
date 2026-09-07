extends SceneTree
## What the bailey layout pass puts in the yard.


func _init() -> void:
	for e in CastleSweep.each():
		if int(e["index"]) != 1 or String(e["style"]) != "edwardian":
			continue
		var spec: CastleSpec = CastleSweep.spec_at(e["style"], e["tier"], 1)
		var yard: Rect2 = CastleGeometry.bailey_rect(spec)
		print("=== %s %s  yard %s" % [String(e["style"]), String(e["tier"]), str(yard)])
		print("  axis strip %s" % str(CastleGeometry.gate_axis_strip(spec)))
		for o in CastleGeometry.bailey_obstacles(spec):
			print("  obstacle %s" % str(o))
		for b in CastleGenerator.bailey_buildings(spec):
			print("  %-14s %s yaw %.2f" % [String(b["business"]), str(b["rect"]),
				float(b["yaw"])])
		print("  well %s" % str(CastleGenerator.bailey_well(spec)))
	quit()
