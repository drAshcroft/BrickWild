class_name HouseMultistorySuite
extends RefCounted
## Focused vertical-house contract.  The canonical house sweep remains
## one-storey for regression coverage; this small suite exercises the costly
## stair/elevation path explicitly.

const CASES := [
	{"style": &"cottage", "trade": &"none", "w": 8.0, "l": 10.0, "h": 2.6,
		"storeys": 2, "seed": 32101},
	{"style": &"townhouse", "trade": &"innkeeper", "w": 13.0, "l": 16.0, "h": 2.9,
		"storeys": 2, "seed": 32102},
	{"style": &"longhall", "trade": &"smith", "w": 11.0, "l": 14.0, "h": 2.7,
		"storeys": 3, "seed": 32103},
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("house multistory")
	for row in CASES:
		var spec := HouseSpec.new()
		spec.style = row["style"]
		spec.trade = row["trade"]
		spec.width = row["w"]
		spec.length = row["l"]
		spec.height = row["h"]
		spec.storeys = row["storeys"]
		var plan: HousePlan = HouseGenerator.generate(spec, row["seed"])
		var builder := HouseBuilder.new()
		builder.build(plan)
		var who := "%s %d-storey seed=%d" % [String(row["style"]), row["storeys"], row["seed"]]
		res.checked += 1
		var rep: Dictionary = HouseQA.new().check(plan, builder)
		for f in rep["failures"]:
			res.fail("%s: %s" % [who, str(f)])
		for w in rep["warnings"]:
			res.warn("%s: %s" % [who, str(w)])
		_check_elevations(res, plan, who)
		_check_stairs(res, plan, who)
		_check_roof(res, builder, spec, who)
		_check_chimney(res, plan, builder, who)
		_check_upstairs_programme(res, plan, who)

		# Generation and mesh emission must remain deterministic with vertical
		# records included, not merely with the old furniture positions.
		var again_spec := HouseSpec.new()
		again_spec.style = row["style"]
		again_spec.trade = row["trade"]
		again_spec.width = row["w"]
		again_spec.length = row["l"]
		again_spec.height = row["h"]
		again_spec.storeys = row["storeys"]
		var again: HousePlan = HouseGenerator.generate(again_spec, row["seed"])
		res.checked += 1
		if not _same_plan(plan, again):
			res.fail("%s: repeated generation changed vertical plan records" % who)

	# Existing defaults are intentionally one-storey and must not acquire a
	# phantom stair or elevated furniture.
	var one := HouseSpec.new()
	one.style = &"cottage"
	one.trade = &"none"
	one.width = 5.5
	one.length = 7.0
	one.height = 2.4
	var one_plan: HousePlan = HouseGenerator.generate(one, 32104)
	res.checked += 1
	if int(one.storeys) != 1 or not one_plan.stairs.is_empty():
		res.fail("one-storey default has vertical circulation")
	for p in one_plan.furniture:
		var y: float = float(p["pos"].y)
		if HousePlan.record_storey(p) != 0 or y < -0.03 or y > one.height + 0.03:
			res.fail("one-storey furniture left its ground-floor band at Y=%.2f" % y)
	_programme_sweep(res)
	return res


## How public a room upstairs is, lowest first. The landing is circulation --
## everybody on the floor crosses it -- so it takes the room that is nobody's
## private ground; a store is not somewhere anybody sleeps, so it outranks a
## bedroom even though it is nobody's parlour either.
const UPSTAIRS_RANK := {&"parlour": 0, &"store": 1, &"bedroom": 2}


## The upper-storey programme, over the whole case.
##
## Everything a person would notice about an upstairs: the service rooms stayed
## downstairs, somebody sleeps up here, the room you step off the stair into is
## not somebody's bedroom, no upper room opens straight onto the street, the
## fire is on the ground floor and the upper windows were cut for the rooms
## that are actually up there.
static func _check_upstairs_programme(res: SuiteResult, plan: HousePlan, who: String) -> void:
	res.checked += 1
	var beds := 0
	for i in range(plan.room_count()):
		var storey: int = plan.storey_of_room(i)
		var kind: StringName = plan.kind_of(i)
		if storey == 0:
			continue
		if kind in [&"kitchen", &"hall", &"workshop"]:
			res.fail("%s: room %d is a %s on storey %d" % [who, i, String(kind), storey])
		if kind in HouseGeometry.SLEEPING:
			if storey == 1:
				beds += 1
			if plan.windows_of(i).is_empty():
				res.fail("%s: the %s in room %d on storey %d has no window"
					% [who, String(kind), i, storey])
	if beds < 1:
		res.fail("%s: storey 1 has nowhere to sleep" % who)

	# the landing is the most public room on its floor
	for storey in range(1, int(plan.spec.storeys)):
		var landing := -1
		for stair in plan.stairs:
			if int(stair.get("to_storey", -1)) == storey:
				landing = int(stair.get("b", -1))
		if landing < 0:
			res.fail("%s: storey %d has no stair landing" % [who, storey])
			continue
		var mine: int = int(UPSTAIRS_RANK.get(plan.kind_of(landing), 9))
		for i in plan.rooms_on_storey(storey):
			if int(UPSTAIRS_RANK.get(plan.kind_of(i), 9)) < mine:
				res.fail("%s: the landing (room %d, %s) is less public than room %d (%s)"
					% [who, landing, String(plan.kind_of(landing)), i, String(plan.kind_of(i))])

	# nothing upstairs opens onto the street
	for di in range(plan.doors.size()):
		var d: Dictionary = plan.doors[di]
		if not d["exterior"]:
			continue
		if plan.storey_of_room(int(d["a"])) != 0:
			res.fail("%s: exterior door %d opens out of storey %d"
				% [who, di, plan.storey_of_room(int(d["a"]))])
	var front: int = plan.entrance()
	if front >= 0:
		# the stair is not a door: it is the only thing that may join two
		# levels, and the whole point of the programme is that what is up it
		# is not another room off the entrance hall
		var hall: int = int(plan.doors[front]["a"])
		for d in plan.doors:
			var far: int = int(d["b"]) if int(d["a"]) == hall else int(d["a"])
			if int(d["a"]) != hall and int(d["b"]) != hall:
				continue
			if far >= 0 and plan.storey_of_room(far) != 0:
				res.fail("%s: room %d on storey %d shares a door with the front door's room"
					% [who, far, plan.storey_of_room(far)])

	# the fire, and everything belonging to it, is a ground-floor thing
	for f in plan.furniture:
		if String(f.get("cat", "")) == "hearth" and int(f.get("storey", 0)) != 0:
			res.fail("%s: hearth furniture on storey %d" % [who, int(f.get("storey", 0))])


## Two hundred seeds of two-storey house, every style and a spread of
## footprints: the plan check must pass all of them, and must not have to warn
## that a floor which could have had a bedroom did not get one.
##
## The planner is called directly rather than through HouseGenerator: this is a
## sweep of the LAYOUT, and furnishing two hundred houses to look at their room
## names would cost minutes for nothing. The three cases above are the ones
## that go all the way through the furnisher and the builder.
static func _programme_sweep(res: SuiteResult) -> void:
	var styles: Array = HouseSweep.styles()
	var upstairs_beds := 0
	var ground_beds := 0
	var service_up := 0
	for n in range(200):
		var spec := HouseSpec.new(41000 + n)
		spec.style = styles[n % styles.size()]
		spec.width = 9.0 + float(n % 5) * 1.5
		spec.length = 10.0 + float(n % 7) * 1.6
		spec.height = 2.6
		spec.storeys = 2
		var inner: Rect2 = HouseGeometry.interior_rect(spec)
		spec.room_count = HouseSpec.rooms_for(inner.size.x * inner.size.y)
		var programme: Array[StringName] = []
		for kind in HouseSpec.PROGRAM:
			programme.append(kind)
		spec.program = programme
		spec.back_door = n % 3 == 0
		spec.chimney = true
		var plan: HousePlan = HousePlanner.plan(spec)
		res.checked += 1
		var who := "programme sweep seed=%d %s" % [spec.seed, String(spec.style)]
		var rep: Dictionary = HousePlanCheck.new().check(plan)
		for f in rep["failures"]:
			res.fail("%s: %s" % [who, str(f)])
		for w in rep["warnings"]:
			if str(w).begins_with("upstairs_programme:"):
				res.fail("%s: %s" % [who, str(w)])
		var up := 0
		for i in plan.rooms_on_storey(1):
			if plan.kind_of(i) == &"bedroom":
				up += 1
			elif plan.kind_of(i) in [&"kitchen", &"hall", &"workshop"]:
				service_up += 1
		if up == 0:
			res.fail("%s: no bedroom on storey 1" % who)
		upstairs_beds += up
		for i in plan.rooms_on_storey(0):
			if plan.kind_of(i) == &"bedroom":
				ground_beds += 1
	if service_up != 0:
		res.fail("programme sweep: %d service rooms above the ground floor" % service_up)
	res.note("programme  200 two-storey houses, %d bedrooms upstairs, %d spare-room bedrooms down"
		% [upstairs_beds, ground_beds])


static func _check_elevations(res: SuiteResult, plan: HousePlan, who: String) -> void:
	var counts := {}
	for room in plan.rooms:
		var level := HousePlan.record_storey(room)
		counts[level] = int(counts.get(level, 0)) + 1
	for level in range(int(plan.spec.storeys)):
		if not counts.has(level):
			res.fail("%s: storey %d has no rooms" % [who, level])
	for p in plan.furniture:
		var level := HousePlan.record_storey(p)
		var expected := float(level) * plan.spec.height
		if absf(float(p["pos"].y) - expected) > plan.spec.height + 0.05:
			res.fail("%s: furniture Y %.2f is outside storey %d" % [who, p["pos"].y, level])


static func _check_stairs(res: SuiteResult, plan: HousePlan, who: String) -> void:
	var pairs := {}
	for stair in plan.stairs:
		var lo := int(stair.get("storey", 0))
		var hi := int(stair.get("to_storey", lo + 1))
		pairs[lo] = true
		if hi != lo + 1:
			res.fail("%s: stair skips from storey %d to %d" % [who, lo, hi])
	for level in range(int(plan.spec.storeys) - 1):
		if not pairs.has(level):
			res.fail("%s: no stair transition from storey %d" % [who, level])


static func _check_roof(res: SuiteResult, builder: HouseBuilder, spec: HouseSpec, who: String) -> void:
	var roofs := 0
	var top := -INF
	for m in builder.mass_log:
		if not (m["name"] as String).begins_with("roof"):
			continue
		roofs += 1
		top = maxf(top, (m["aabb"] as AABB).end.y)
	if roofs == 0:
		res.fail("%s: no logged top-storey roof" % who)
	elif top < float(spec.storeys) * spec.height - 0.15:
		res.fail("%s: roof top %.2f is below top wall band" % [who, top])


## One house, one chimney, however many floors it has: the hearth is a ground
## floor thing and the plan says so, so a three-storey house must not grow a
## stack per cloned kitchen.
static func _check_chimney(res: SuiteResult, plan: HousePlan, builder: HouseBuilder,
		who: String) -> void:
	var stacks := 0
	for m in builder.mass_log:
		if String(m["name"]) == "chimney":
			stacks += 1
	var want: int = 1 if plan.spec.chimney else 0
	if stacks != want:
		res.fail("%s: %d chimneys logged, wanted %d" % [who, stacks, want])
	if plan.hearth.is_empty():
		return
	if plan.storey_of_room(plan.hearth_room()) != 0:
		res.fail("%s: the hearth is on storey %d, not the ground floor"
			% [who, plan.storey_of_room(plan.hearth_room())])


static func _same_plan(a: HousePlan, b: HousePlan) -> bool:
	return a.rooms == b.rooms and a.doors == b.doors and a.windows == b.windows \
		and a.stairs == b.stairs and a.furniture == b.furniture \
		and a.compromises == b.compromises and a.hearth == b.hearth
