class_name HouseSuite
extends RefCounted
## 11. Contract: user inputs survive generation, the plan is furnished, the
##     mesh is well formed, and the same seed rebuilds the identical house --
##     furniture included, since a layout that wanders between runs cannot be
##     tested at all.

static func run() -> SuiteResult:
	var res := SuiteResult.new("house")
	for style in HouseSweep.styles():
		for trade in HouseSweep.trades():
			for i in range(HouseSweep.COUNT):
				var made: Array = HouseSweep.at(style, trade, i)
				var spec: HouseSpec = made[0]
				var plan: HousePlan = made[1]
				var row: Dictionary = HouseSweep.SIZES[i]
				var where := "style=%s trade=%s seed=%d" % [String(style),
					String(trade), spec.seed]
				res.checked += 1

				if spec.style != style or spec.trade != trade \
						or not is_equal_approx(spec.width, float(row["w"])) \
						or not is_equal_approx(spec.length, float(row["l"])) \
						or not is_equal_approx(spec.height, float(row["h"])):
					res.fail("user inputs mutated, " + where)
					continue
				if plan.room_count() < 1:
					res.fail("no rooms, " + where)
					continue
				if plan.doors.is_empty():
					res.fail("no doors at all, " + where)
				if plan.furniture.is_empty():
					res.fail("nothing was furnished, " + where)

				var builder := HouseBuilder.new()
				var before: int = plan.furniture.size()
				var mesh: ArrayMesh = builder.build(plan)
				# build() must be a pure function of its plan
				if plan.furniture.size() != before:
					res.fail("build() changed the furnishing, " + where)
				if mesh == null or mesh.get_surface_count() != 4:
					res.fail("bad mesh, " + where)
					continue
				var verts := 0
				for s in range(mesh.get_surface_count()):
					verts += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
						as PackedVector3Array).size()
				if verts < 100:
					res.fail("too few verts (%d), %s" % [verts, where])
				if builder.mass_log.is_empty():
					res.fail("no structural masses logged, " + where)

	# determinism: the same seed furnishes the same house
	res.checked += 1
	var a: Array = HouseSweep.at(&"cottage", &"smith", 2)
	var b: Array = HouseSweep.at(&"cottage", &"smith", 2)
	if not _same_furnishing(a[1], b[1]):
		res.fail("the same seed furnished two different houses")

	# and the mesh is a pure function of the plan
	res.checked += 1
	var bb := HouseBuilder.new()
	var m1: PackedVector3Array = bb.build(a[1]).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var m2: PackedVector3Array = bb.build(a[1]).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if m1 != m2:
		res.fail("rebuilding the same plan produced different geometry")

	# the room count follows the floor area, which is the whole sizing rule
	res.checked += 1
	var small: Array = HouseSweep.at(&"cottage", &"none", 0)
	var large: Array = HouseSweep.at(&"cottage", &"none", 3)
	if (small[1] as HousePlan).room_count() >= (large[1] as HousePlan).room_count():
		res.fail("a %.0f m2 house has no fewer rooms than a %.0f m2 one"
			% [(small[0] as HouseSpec).width * (small[0] as HouseSpec).length,
				(large[0] as HouseSpec).width * (large[0] as HouseSpec).length])
	return res


static func _same_furnishing(a: HousePlan, b: HousePlan) -> bool:
	if a.furniture.size() != b.furniture.size() or a.rooms.size() != b.rooms.size():
		return false
	for i in range(a.furniture.size()):
		var x: Dictionary = a.furniture[i]
		var y: Dictionary = b.furniture[i]
		if x["key"] != y["key"] or x["room"] != y["room"]:
			return false
		if (Vector3(x["pos"]) - Vector3(y["pos"])).length() > 0.001:
			return false
	return true
