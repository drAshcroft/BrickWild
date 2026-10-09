extends SceneTree
## Prints the geometric rejection path for the Witch lower roof and compact threshold.
## Copy to tests/house_witch_core_roof_diag.gd before running with the pinned Godot.
const CASES := [
	[Vector2(7.0, 9.0), 1], [Vector2(7.0, 9.0), 8102], [Vector2(7.0, 9.0), 21325],
	[Vector2(8.0, 10.0), 8102], [Vector2(8.5, 10.0), 8102],
	[Vector2(9.0, 12.0), 1], [Vector2(9.0, 12.0), 8102], [Vector2(9.0, 12.0), 21325],
	[Vector2(17.0, 18.0), 1], [Vector2(17.0, 18.0), 8102], [Vector2(17.0, 18.0), 21325]
]
func _init() -> void:
	for row in CASES:
		_dump_case(row[0], int(row[1]))
	quit()
func _dump_case(size: Vector2, seed: int) -> void:
	var s := HouseSpec.new(seed)
	s.style = &"witch_hut"
	s.trade = &"none"
	s.width = size.x
	s.length = size.y
	s.height = 2.8 if size.x >= 17.0 else 2.6
	s.storeys = 1
	s.cellars = 0
	var p := HouseGenerator.generate(s, seed, false)
	if p == null:
		print(JSON.stringify({"size": size, "seed": seed, "plan": "null"}))
		return
	var inner := HouseGeometry.interior_rect(s)
	var core := HouseGeometry.witch_high_core_rect(p)
	var bay := HouseGeometry.witch_workshop_bay(p)
	var roof_layout := HouseGeometry.roof_layout(p)
	var threshold := HouseGeometry.witch_compact_service_threshold(p)
	var room_rows: Array[Dictionary] = []
	for i in range(p.room_count()):
		room_rows.append({"index": i, "kind": String(p.kind_of(i)), "rect": p.rooms[i].get("rect", Rect2()),
			"floor": HouseGeometry.room_floor_rect(p, i), "service": bool(p.rooms[i].get("witch_service_wing", false)),
			"storey": p.storey_of_room(i), "polygon": p.is_polygonal(i)})
	var candidate_rows: Array[Dictionary] = []
	var workshop_rows: Array[int] = p.rooms_of(&"workshop")
	for wi in workshop_rows:
		var r: Rect2 = p.rooms[wi]["rect"]
		var floor := HouseGeometry.room_floor_rect(p, wi)
		var edges := [
			{"side":"front", "normal":Vector2(0,-1), "lo":r.position.x, "hi":r.end.x, "on":absf(r.position.y-inner.position.y)<0.02},
			{"side":"back", "normal":Vector2(0,1), "lo":r.position.x, "hi":r.end.x, "on":absf(r.end.y-inner.end.y)<0.02},
			{"side":"left", "normal":Vector2(-1,0), "lo":r.position.y, "hi":r.end.y, "on":absf(r.position.x-inner.position.x)<0.02},
			{"side":"right", "normal":Vector2(1,0), "lo":r.position.y, "hi":r.end.y, "on":absf(r.end.x-inner.end.x)<0.02}
		]
		var top := core if core.size.x > 0.01 else HouseGeometry.storey_rect(p, 0)
		var span := minf(top.size.x, top.size.y)
		var xf := Transform3D(Basis(Vector3.UP, PI/2.0 if top.size.x>top.size.y else 0.0), Vector3(top.get_center().x,s.height,top.get_center().y))
		var ridge := HouseGeometry.witch_ridge_x(p, span+HouseGeometry.roof_span_out(s)*2.0)
		for e in edges:
			var d: Dictionary = e
			var reason := "candidate"
			if p.storey_of_room(wi) != 0: reason = "not_ground_storey"
			elif p.is_polygonal(wi): reason = "polygon_room"
			elif not HouseGeometry.room_suits(p, wi, &"workshop"): reason = "room_suits"
			elif floor.get_area()<8.0: reason = "floor_area %.3f" % floor.get_area()
			elif minf(floor.size.x,floor.size.y)<2.45: reason = "floor_side %.3f/%.3f" % [floor.size.x,floor.size.y]
			elif not bool(d.on): reason = "not_on_exterior_inner_line"
			elif float(d.hi)-float(d.lo)<3.3: reason = "edge_run %.3f" % (float(d.hi)-float(d.lo))
			else:
				var ln := xf.basis.inverse()*Vector3(d.normal.x,0,d.normal.y)
				if absf(ln.x)<0.95: reason = "not_parallel_to_ridge local_normal=%s" % str(ln)
				else:
					var shell := HouseGeometry.site_rect(s,0)
					var n: Vector2 = d.normal
					var line := shell.position.x if n.x<0 else shell.end.x if n.x>0 else shell.position.y if n.y<0 else shell.end.y
					var ow := Vector2(line,float(d.lo)) if absf(n.x)>0.5 else Vector2(float(d.lo),line)
					var fi := floor.end.x if n.x<0 else floor.position.x if n.x>0 else floor.end.y if n.y<0 else floor.position.y
					var iw := Vector2(fi,float(d.lo)) if absf(n.x)>0.5 else Vector2(float(d.lo),fi)
					var ol := xf.affine_inverse()*Vector3(ow.x,0,ow.y)
					var il := xf.affine_inverse()*Vector3(iw.x,0,iw.y)
					if (ol.x-ridge)*(il.x-ridge)<=0: reason="ridge_side_cross outer=%.3f inner=%.3f ridge=%.3f" % [ol.x,il.x,ridge]
					else: reason="PASS outer_local=%s inner_local=%s ridge=%.3f" % [str(Vector2(ol.x,ol.z)),str(Vector2(il.x,il.z)),ridge]
			candidate_rows.append({"room":wi,"side":d.side,"normal":d.normal,"rect":r,"floor":floor,"edge_on":d.on,"local_ridge":ridge,"reason":reason})
	print(JSON.stringify({"size":size,"seed":seed,"world_family":p.world_family,"domestic_layout":p.domestic_layout,
		"inner":inner,"core":core,"bay_candidate":bay,"layout_bay":roof_layout.get("witch_bay", {}),"layout_rejection":roof_layout.get("witch_bay_rejection", ""),"roof_span":roof_layout.get("span", 0.0),"roof_rise":roof_layout.get("rise", 0.0),"compact_threshold":threshold,"rooms":room_rows,"workshop_edges":candidate_rows}))

