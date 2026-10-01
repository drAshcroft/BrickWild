class_name PagodaBuilder
extends MassBuilder
## Emits a HousePlan shell and measurable roof rings, axial mast and finial.

const SURF_WALL := 0
const SURF_TRIM := 1
const SURF_ROOF := 2
const SURF_FLOOR := 3


func build(plan: HousePlan) -> ArrayMesh:
	var shell := HouseBuilder.new()
	var shell_mesh := shell.build(plan, false)
	begin(4)
	append_mapped_mesh(shell, shell_mesh, [SURF_WALL, SURF_TRIM, SURF_ROOF, SURF_FLOOR],
		Transform3D.IDENTITY)
	part_log.append_array(shell.part_log)
	mass_log.append_array(shell.mass_log)
	component_log.append_array(shell.component_log)
	prop_log.append_array(shell.prop_log)
	for tier in plan.world_meta.get("eave_tiers", []):
		_emit_eave_ring(plan, tier)
	_emit_mast(plan)
	_emit_finial(plan)
	total_height = float(plan.world_meta.get("total_height", plan.spec.height * plan.spec.storeys))
	return commit()


func _emit_eave_ring(plan: HousePlan, tier: Dictionary) -> void:
	var level := int(tier.get("storey", 0))
	var outline: PackedVector2Array = plan.outline_of(level)
	var width := float(tier.get("width", 0.0))
	var floor_bounds := Poly.bounding_rect(outline)
	var outer_scale := width / maxf(floor_bounds.size.x, 0.01)
	var outer := PackedVector2Array()
	for p in outline:
		outer.append(p * outer_scale)
	var y := float(tier.get("y", 0.0))
	var height := float(tier.get("height", 0.4))
	var thickness := minf(0.68, width * 0.06)
	host("eave_tier_%d" % level, level)
	for i in range(outer.size()):
		var a := outer[i]
		var b := outer[(i + 1) % outer.size()]
		var edge := b - a
		var angle := atan2(-edge.y, edge.x)
		var centre := (a + b) * 0.5
		var size := Vector3(edge.length() + thickness, height, thickness)
		var xf := Transform3D(Basis(Vector3.UP, angle), Vector3(centre.x, y, centre.y))
		component_box("eave_tier_%d_edge" % level, size, xf, SURF_ROOF)
		_log_part("box", xf.origin, size, angle)
		_log_mass("eave_tier_%d_edge_%d" % [level, i],
			AABB(Vector3(centre.x - size.x * 0.5, y - height * 0.5,
				centre.y - size.z * 0.5), Vector3(size.x, height, size.z)),
			float(level) * plan.spec.height)
	host_end()


func _emit_mast(plan: HousePlan) -> void:
	var radius := float(plan.world_meta.get("mast_radius", 0.34))
	var height := float(plan.world_meta.get("mast_height", 0.0))
	_kit.prism(radius, height, 8, Vector3.ZERO, SURF_TRIM, PI / 8.0)
	component_note("mast", "prism", SURF_TRIM, {"center": Vector3.ZERO,
		"radius": radius, "height": height, "sides": 8,
		"aabb": AABB(Vector3(-radius, 0.0, -radius), Vector3(radius * 2.0, height, radius * 2.0))})
	_log_mass("mast", AABB(Vector3(-radius, 0.0, -radius),
		Vector3(radius * 2.0, height, radius * 2.0)))


func _emit_finial(plan: HousePlan) -> void:
	var base_y := float(plan.world_meta.get("mast_height", 0.0))
	var height := float(plan.world_meta.get("finial_height", 0.0))
	var radius := float(plan.world_meta.get("mast_radius", 0.34)) * 1.35
	var center := Vector3(0.0, base_y, 0.0)
	_kit.cone(radius, height, center, SURF_TRIM, 12)
	component_note("finial", "cone", SURF_TRIM, {"center": center,
		"radius": radius, "height": height, "segments": 12,
		"aabb": AABB(Vector3(-radius, base_y, -radius), Vector3(radius * 2.0, height, radius * 2.0))})
	_log_mass("finial", AABB(Vector3(-radius, base_y, -radius),
		Vector3(radius * 2.0, height, radius * 2.0)))
