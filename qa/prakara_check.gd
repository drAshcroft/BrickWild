class_name PrakaraCheck
extends RefCounted
## WLD-014 plan and emitted-geometry checks for a Dravida prakara compound.

func check(plan: HousePlan, builder: DravidaBuilder) -> Dictionary:
	var failures: Array[String] = []
	_check_identity(plan, failures)
	_check_enclosure(plan, builder, failures)
	_check_colonnade(plan, builder, failures)
	_check_gopurams(plan, builder, failures)
	_check_dominance(plan, builder, failures)
	_check_nandi(plan, builder, failures)
	_check_vimana(plan, builder, failures)
	_check_dhvaja(plan, builder, failures)
	_check_sightline(plan, builder, failures)
	return {"ok": failures.is_empty(), "failures": failures, "warnings": [],
		"stats": {"colonnade_sides": plan.world_meta.get("colonnade", []).size(),
			"gopurams": plan.world_meta.get("gates", []).size(),
			"vimana_tiers": plan.world_meta.get("vimana_tiers", []).size(),
			"period": plan.world_meta.get("period", 0)}}


func _check_identity(plan: HousePlan, failures: Array[String]) -> void:
	if plan.world_family != DravidaGenerator.FAMILY \
			or plan.world_subkind != DravidaGenerator.KIND:
		failures.append("identity: plan is not the God-King's Precinct")
	if plan.spec == null or int(plan.world_meta.get("period", -1)) != plan.spec.period:
		failures.append("identity: the period control was not retained on the plan")


func _check_enclosure(plan: HousePlan, builder: DravidaBuilder,
		failures: Array[String]) -> void:
	var enclosure: Rect2 = plan.world_meta.get("enclosure", Rect2())
	for name in ["prakara_left", "prakara_right", "prakara_front_left",
			"prakara_front_right", "prakara_rear_left", "prakara_rear_right"]:
		if builder.mass_aabb(name).size == Vector3.ZERO:
			failures.append("enclosure: emitted prakara wall %s is missing" % name)
	if enclosure.size.x < plan.spec.width * 0.8 or enclosure.size.y < plan.spec.length * 0.8:
		failures.append("enclosure: prakara does not enclose the compound")


func _check_colonnade(plan: HousePlan, builder: DravidaBuilder,
		failures: Array[String]) -> void:
	var floor_names: Array[String] = []
	var bounds: Rect2 = plan.world_meta.get("colonnade_outer", Rect2()).grow(2.0)
	var enclosure: Rect2 = plan.world_meta.get("enclosure", Rect2())
	var gallery: Rect2 = plan.world_meta.get("colonnade_outer", Rect2())
	var inner: Rect2 = plan.world_meta.get("colonnade_inner", Rect2())
	if gallery.position.x <= enclosure.position.x or gallery.position.y <= enclosure.position.y \
			or gallery.end.x >= enclosure.end.x or gallery.end.y >= enclosure.end.y \
			or inner.position.x <= gallery.position.x or inner.position.y <= gallery.position.y \
			or inner.end.x >= gallery.end.x or inner.end.y >= gallery.end.y:
		failures.append("colonnade: gallery loop is not nested inside the prakara")
	var grid := WalkGrid.new()
	grid.setup(bounds, 0.4)
	for i in range(4):
		var a := builder.mass_aabb("colonnade_floor_%d" % i)
		if a.size == Vector3.ZERO:
			failures.append("colonnade: emitted floor side %d is missing" % i)
			continue
		grid.add_floor(Rect2(Vector2(a.position.x, a.position.z), Vector2(a.size.x, a.size.z)))
		floor_names.append("colonnade_floor_%d" % i)
	var columns := 0
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		if not name.begins_with("colonnade_column_"):
			continue
		columns += 1
		var aabb: AABB = mass["aabb"]
		grid.add_obstacle(Rect2(Vector2(aabb.position.x, aabb.position.z),
			Vector2(aabb.size.x, aabb.size.z)))
	if floor_names.size() != 4 or columns < 8:
		failures.append("colonnade: four walkable gallery sides were not emitted")
		return
	grid.build(0.42)
	if grid.walkable_area() <= 12.0:
		failures.append("colonnade: floor strips leave no body-width gallery route")
		return
	var outer: Rect2 = plan.world_meta["colonnade_outer"]
	var start := Vector2(outer.end.x - 2.0, outer.get_center().y)
	if not grid.flood_from(start):
		failures.append("colonnade: no body-width route around the inner gallery")
		return
	var targets := [Vector2(inner.end.x + 2.0, inner.end.y + 2.0),
		Vector2(inner.get_center().x, outer.end.y - 2.0),
		Vector2(outer.position.x + 2.0, outer.get_center().y),
		Vector2(inner.get_center().x, outer.position.y + 2.0)]
	for i in range(targets.size()):
		if not grid.reached(Rect2(targets[i] - Vector2(0.35, 0.35), Vector2(0.7, 0.7))):
			failures.append("colonnade: route is broken before gallery quadrant %d" % i)
			break


func _check_gopurams(plan: HousePlan, builder: DravidaBuilder,
		failures: Array[String]) -> void:
	var enclosure: Rect2 = plan.world_meta["enclosure"]
	var gates: Array = plan.world_meta.get("gates", [])
	if gates.size() < 2:
		failures.append("gopuram: the axial enclosure needs front and rear gates")
		return
	for gate in gates:
		var id := String(gate.get("id", "missing"))
		var aabb := builder.mass_aabb(id + "_tower")
		var plane := float(gate["center"].z)
		if aabb.size == Vector3.ZERO or absf(aabb.get_center().x) > 0.02 \
				or aabb.position.z > plane or aabb.end.z < plane:
			failures.append("gopuram: %s is not centred on and crossing the prakara wall" % id)
		if absf(plane) < enclosure.size.y * 0.35:
			failures.append("gopuram: %s is not on the axial enclosure wall" % id)


func _check_dominance(plan: HousePlan, builder: DravidaBuilder,
		failures: Array[String]) -> void:
	var vimana_top := 0.0
	var gopuram_top := 0.0
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		var aabb: AABB = mass["aabb"]
		if name.begins_with("vimana_tier_"):
			vimana_top = maxf(vimana_top, aabb.end.y)
		elif name.begins_with("gopuram_"):
			gopuram_top = maxf(gopuram_top, aabb.end.y)
	var late := int(plan.spec.period) >= DravidaGenerator.LATE_PERIOD
	if vimana_top <= 0.0 or gopuram_top <= 0.0:
		failures.append("dominance: vimana or gopuram AABB is missing")
	elif late and gopuram_top <= vimana_top:
		failures.append("dominance: late-period gopuram is not taller than the vimana")
	elif not late and vimana_top <= gopuram_top:
		failures.append("dominance: early-period vimana is not taller than the gopuram")


func _check_nandi(plan: HousePlan, builder: DravidaBuilder,
		failures: Array[String]) -> void:
	var aabb := builder.mass_aabb("nandi")
	var head := builder.mass_aabb("nandi_head_facing_plus_axis")
	var facing: Vector3 = plan.world_meta.get("nandi_facing", Vector3.ZERO)
	var entry: Vector2 = plan.world_meta["entry"]
	var hall: Rect2 = plan.world_meta["hall"]
	if aabb.size == Vector3.ZERO or absf(aabb.get_center().x) > 0.02 \
			or aabb.position.z <= entry.y or aabb.end.z >= hall.position.y \
			or facing.distance_to(Vector3.BACK) > 0.001:
		failures.append("nandi: bull is not on the axis between gate and mandapa facing +axis")
	if head.size == Vector3.ZERO or head.get_center().z <= aabb.get_center().z:
		failures.append("nandi: emitted head does not face toward the sanctum")


func _check_vimana(plan: HousePlan, builder: DravidaBuilder,
		failures: Array[String]) -> void:
	var tiers: Array = plan.world_meta.get("vimana_tiers", [])
	if tiers.size() < 5:
		failures.append("vimana: fewer than five planned tiers")
		return
	var previous_height := INF
	var previous_width := INF
	var previous_emitted_width := INF
	var previous_top := float(plan.world_meta.get("vimana_base_y", 0.0))
	for i in range(tiers.size()):
		var row: Dictionary = tiers[i]
		var height := float(row.get("height", 0.0))
		var width := float(row.get("width", 0.0))
		var aabb := builder.mass_aabb("vimana_tier_%d" % i)
		if aabb.size == Vector3.ZERO:
			failures.append("vimana: emitted tier %d is missing" % i)
		elif height >= previous_height or width >= previous_width \
				or absf(aabb.size.y - height) > 0.02 \
				or absf(aabb.size.x - width) > 0.02 \
				or aabb.size.x >= previous_emitted_width:
			failures.append("vimana: tiers do not decrease monotonically at tier %d" % i)
		if absf(float(row.get("base_y", INF)) - previous_top) > 0.02:
			failures.append("vimana: tier %d is not stacked on the preceding tier" % i)
		previous_height = height
		previous_width = width
		previous_emitted_width = aabb.size.x
		previous_top = float(row.get("base_y", 0.0)) + height


func _check_dhvaja(plan: HousePlan, builder: DravidaBuilder,
		failures: Array[String]) -> void:
	var aabb := builder.mass_aabb("dhvaja")
	var gates: Array = plan.world_meta.get("gates", [])
	if gates.is_empty():
		failures.append("dhvaja: no inner gate defines the processional start")
		return
	var gate_center: Vector3 = gates[0]["center"]
	var gate_inner_face := gate_center.z + float(plan.world_meta["gate_depth"]) * 0.5
	var first_mandapa := float(plan.world_meta["first_mandapa_z"])
	if aabb.size == Vector3.ZERO or aabb.position.z <= gate_inner_face \
			or aabb.end.z >= first_mandapa or absf(aabb.get_center().x) > 0.02:
		failures.append("dhvaja: flagstaff is not between the inner gate and first mandapa")


func _check_sightline(plan: HousePlan, builder: DravidaBuilder,
		failures: Array[String]) -> void:
	var nandi := builder.mass_aabb("nandi")
	var head := builder.mass_aabb("nandi_head_facing_plus_axis")
	var door: Vector2 = plan.world_meta["sanctum_door"]
	if nandi.size == Vector3.ZERO or head.size == Vector3.ZERO:
		failures.append("sightline: nandi or sanctum door endpoint is missing")
		return
	var from := Vector3(head.get_center().x, head.position.y + 0.6, head.end.z + 0.2)
	var to := Vector3(door.x, 2.4, door.y - 0.1)
	var blockers: Array[AABB] = []
	for mass in builder.mass_log:
		var name := String(mass.get("name", ""))
		if name in ["nandi", "nandi_head_facing_plus_axis"]:
			continue
		blockers.append(mass["aabb"])
	if not Sightline.clear(from, to, blockers):
		failures.append("sightline: emitted masses block Nandi's view to the sanctum door")
