class_name HammamBuilder
extends HouseBuilder
## Flat roof, open lantern oculi, and revolved elliptical domes for WLD-005.

const ROOF_THICKNESS := 0.24
const DOME_SEGMENTS := 48
const DOME_PROFILE := [
	Vector2(1.0, 0.0), Vector2(0.96, 0.22), Vector2(0.84, 0.48),
	Vector2(0.66, 0.70), Vector2(0.43, 0.88), Vector2(0.20, 1.0),
]

var furnace_aabb := AABB()


func begin(surface_count: int) -> void:
	super.begin(surface_count)
	furnace_aabb = AABB()


## HouseBuilder.build() dispatches here before it commits the shared mesh kit.
func _build_roof() -> void:
	tag("roof")
	host("roof", 0)
	var site := HouseGeometry.site_rect(spec)
	var openings := HouseGeometry.roof_openings(plan)
	var pieces: Array[PackedVector2Array] = [Poly.from_rect(site)]
	for opening in openings:
		var hole: PackedVector2Array = opening["polygon"]
		var next: Array[PackedVector2Array] = []
		for piece in pieces:
			next.append_array(RoofShape.subtract(piece, hole))
		pieces = next
	for piece in pieces:
		var world := PackedVector3Array()
		for p in piece:
			world.append(Vector3(p.x, spec.height, p.y))
		_roof_face(Transform3D.IDENTITY, world, SURF_ROOF, "hammam_roof_panel")
	var roof_box := AABB(Vector3(site.position.x, spec.height - ROOF_THICKNESS * 0.5,
		site.position.y), Vector3(site.size.x, ROOF_THICKNESS, site.size.y))
	_log_mass("roof", roof_box, spec.height - ROOF_THICKNESS * 0.5)
	for opening in openings:
		var world_poly := PackedVector3Array()
		for p2 in opening["polygon"]:
			world_poly.append(Vector3(p2.x, spec.height, p2.y))
		var centre: Vector2 = Poly.bounding_rect(opening["polygon"]).get_center()
		_record_roof_opening(opening, world_poly, Vector3(centre.x, spec.height, centre.y))
	_emit_domes()
	total_height = maxf(total_height, spec.height + minf(spec.height * 0.30, 2.4))
	host_end()


func _emit_domes() -> void:
	tag("dome")
	var role_rooms := _station_rooms()
	for role in [&"cold", &"warm", &"hot"]:
		if not role_rooms.has(role):
			continue
		var room_index: int = role_rooms[role]
		var room: Rect2 = HouseGeometry.room_floor_rect(plan, room_index)
		# An ellipse is a revolved profile under a measured plan-space affine
		# scale. Its projected area is pi * .51^2, or 81.7% of the room. A small
		# eave overhang carries the shell to the room's surrounding wall.
		var rx := room.size.x * 0.51
		var rz := room.size.y * 0.51
		var rise := minf(spec.height * 0.30, 2.4)
		var centre := Vector3(room.get_center().x, spec.height, room.get_center().y)
		var profile := PackedVector2Array()
		for point in DOME_PROFILE:
			profile.append(Vector2(point.x * rx, point.y * rise))
		var ellipse_scale := Vector2(1.0, rz / maxf(rx, 0.01))
		_kit.revolve(profile, centre, SURF_ROOF, DOME_SEGMENTS, TAU, 0.0,
			ellipse_scale)
		var triangles := DOME_SEGMENTS * (profile.size() - 1) * 2
		var dome_box := AABB(Vector3(centre.x - rx, centre.y,
			centre.z - rz), Vector3(rx * 2.0, rise, rz * 2.0))
		var host_name := "dome_%s" % String(role)
		host(host_name, 0)
		component_note("dome_revolved", "revolved", SURF_ROOF, {
			"aabb": dome_box, "profile": profile, "segments": DOME_SEGMENTS,
			"room": room_index, "triangles": triangles,
			"ellipse_scale": ellipse_scale})
		_log_mass(host_name, dome_box, spec.height)

## The one fire room is the hot chamber's exterior far side. It touches the
## back wall's emitted envelope and has no door or walkable connection.
func _build_chimney() -> void:
	var site := HouseGeometry.site_rect(spec)
	var roles := _station_rooms()
	var hot_rect: Rect2 = plan.rooms[int(roles.get(&"hot", 3))]["rect"]
	var size := Vector3(2.0, minf(2.4, spec.height * 0.45), 1.8)
	var near_z := site.end.y
	var center := Vector3(hot_rect.get_center().x, size.y / 2.0,
		near_z + size.z / 2.0)
	furnace_aabb = AABB(center - size * 0.5, size)
	tag("furnace")
	host("furnace", 0)
	component_box("furnace_body", size,
		Transform3D(Basis.IDENTITY, center), SURF_WALL)
	_log_mass("furnace", furnace_aabb, 0.0)
	host_end()


func _station_rooms() -> Dictionary:
	var out := {}
	for i in range(plan.rooms.size()):
		var role := StringName(plan.rooms[i].get("role", &""))
		if role in HammamGenerator.STATIONS:
			out[role] = i
	return out
