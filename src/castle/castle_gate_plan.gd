extends RefCounted
## An occupied guard chamber above the motte's real gate passage. Its side
## gallery reaches the curtain coping behind, rather than through, a tower.

const THICKNESS := 0.45
const GALLERY_WIDTH := 1.5


static func records(spec: CastleSpec, geometry_only := false) -> Dictionary:
	var out := {}
	if not CastleGeometry.is_motte(spec):
		return out
	for ring in CastleGeometry.rings(spec):
		var gate := CastleGeometry.gatehouse_aabb(spec, ring)
		if gate.size.x <= 0.0:
			continue
		var walk_y := CastleGeometry.wall_height(spec, ring) + CastleGeometry.PARAPET_RISE
		var floor_base := walk_y - HouseGeometry.FLOOR_T
		var hs := KeepSpec.new(spec.seed ^ (7301 + ring))
		hs.material = &"stone"
		hs.style = &"townhouse"
		hs.width = gate.size.x
		hs.length = gate.size.z
		hs.height = gate.size.y - floor_base
		hs.storeys = 1
		hs.room_count = 1
		hs.wall_thickness_override = THICKNESS
		hs.plinth_height = 0.0
		hs.porch = false
		hs.chimney = false
		hs.exterior_props = false
		hs.wall_color = spec.stone_color
		hs.trim_color = spec.trim_color
		hs.roof_color = spec.roof_color
		hs.floor_color = spec.stone_color.darkened(0.35)
		hs.program.append(&"guardroom")
		var plan := HousePlan.new()
		plan.spec = hs
		var room := HouseGeometry.interior_rect(hs)
		plan.rooms.append({"kind": &"guardroom", "rect": room, "storey": 0})
		var door_pos := Vector2(room.end.x, room.end.y - 0.95)
		plan.doors.append({"a": 0, "b": -1, "pos": door_pos,
			"normal": Vector2.RIGHT, "width": 1.2, "exterior": true,
			"front": true, "storey": 0, "sill": HouseGeometry.FLOOR_T,
			"head": 2.35, "route": "curtain_gallery"})
		for column in 3:
			var x := lerpf(room.position.x + 0.7, room.end.x - 0.7, float(column) * 0.5)
			plan.windows.append({"room": 0, "storey": 0,
				"pos": Vector2(x, room.position.y), "normal": Vector2.UP,
				"width": 0.5, "sill": 1.05, "head": 1.85})
		if not geometry_only:
			CastleKeepPlan.furnish_minimum_programme(plan, hs)
		var bounds := AABB(Vector3(gate.position.x, floor_base, gate.position.z),
			Vector3(gate.size.x, hs.height, gate.size.z))
		var row := {"id": "gate_%d" % ring, "plan": plan, "bounds": bounds,
			"transform": Transform3D(Basis.IDENTITY, Vector3(bounds.get_center().x,
				floor_base, bounds.get_center().z))}
		var origin: Vector3 = row.transform.origin
		var outer := door_pos + Vector2(origin.x + THICKNESS + 0.2, origin.z)
		var target_x := gate.end.x + GALLERY_WIDTH
		for tower in CastleGeometry.gate_tower_centers(spec, ring):
			if tower.x > 0.0:
				target_x = maxf(target_x, CastleGeometry.tower_aabb(spec, ring, tower).end.x + GALLERY_WIDTH * 0.6)
		var wall := CastleGeometry.wall_aabb(spec, ring, &"front_right")
		var target := Vector2(target_x, wall.position.z + wall.size.z - CastleGeometry.wall_thickness(spec, ring) * 0.5)
		var elbow := Vector2(target_x, outer.y)
		var door_world := door_pos + Vector2(origin.x, origin.z)
		row["gate_chamber"] = true
		row["walk_y"] = walk_y
		row["walk_route"] = [door_world - Vector2.RIGHT * 0.35, outer, elbow, target]
		row["gallery"] = [Rect2(Vector2(gate.end.x - 0.05, outer.y - GALLERY_WIDTH * 0.5),
			Vector2(target_x - gate.end.x + GALLERY_WIDTH * 0.5 + 0.05, GALLERY_WIDTH)),
			Rect2(Vector2(target_x - GALLERY_WIDTH * 0.5, minf(target.y, outer.y) - GALLERY_WIDTH * 0.5),
				Vector2(GALLERY_WIDTH, absf(outer.y - target.y) + GALLERY_WIDTH))]
		row["support"] = elbow
		out[row.id] = row
	return out
