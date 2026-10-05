class_name HouseArchetypeSuite
extends RefCounted
## 14. The houses this generator is expected to be able to build.
##
## The church and castle generators are checked against real buildings. A
## fantasy dwelling has no Chartres to be measured against, so the equivalent
## here is a set of archetypes -- the one-room cottage, the smithy, the inn --
## each with the rooms and the fittings that make it that kind of house, at
## four sizes.
##
## An archetype declares the rooms and the DEFINING fittings it must contain --
## the anvil that makes a smithy a smithy -- not the dressing, and not where
## anything goes. That is the point: the layout is the generator's business,
## and the moment a test says where the bed is, it stops testing the generator
## and starts testing itself.

## Scale factors applied to the archetype's footprint.
const SCALES: Array[float] = [0.75, 1.0, 1.4, 1.9]

const ARCHETYPES: Array[Dictionary] = [
	{"key": "one_room_cottage", "style": &"cottage", "trade": &"none",
		"width": 5.5, "length": 7.0, "height": 2.4,
		"rooms": [], "cats": ["bed"],
		"about": "a single room with a bed in the corner and a fire"},
	{"key": "family_cottage", "style": &"cottage", "trade": &"none",
		"width": 8.0, "length": 10.5, "height": 2.6,
		"rooms": [&"hall"], "cats": ["table", "seat"],
		"about": "hall, and a bedroom once there is room for one"},
	{"key": "farmhouse", "style": &"farmhouse", "trade": &"farmer",
		"width": 10.0, "length": 13.0, "height": 2.7,
		"rooms": [&"hall"], "cats": ["barrel|crate"],
		"about": "a working farm: stores full of barrels and crates"},
	{"key": "smithy", "style": &"longhall", "trade": &"smith",
		"width": 11.0, "length": 13.0, "height": 2.8,
		"rooms": [&"hall", &"workshop"], "cats": ["anvil", "workbench"],
		"about": "a house with a forge in the back"},
	{"key": "alchemist", "style": &"witch_hut", "trade": &"alchemist",
		"width": 9.5, "length": 12.0, "height": 2.7,
		"rooms": [&"hall", &"workshop"], "cats": ["bookcase", "workbench"],
		"about": "a workroom of books, bottles and a cauldron"},
	{"key": "inn", "style": &"townhouse", "trade": &"innkeeper",
		"width": 13.0, "length": 16.0, "height": 2.9,
		"rooms": [&"hall", &"parlour", &"bedroom"], "cats": ["table", "bench|seat"],
		"about": "a common room, guest rooms and a cellar"},
	{"key": "scholar_house", "style": &"townhouse", "trade": &"scholar",
		"width": 10.0, "length": 12.0, "height": 2.8,
		"rooms": [&"hall", &"parlour"], "cats": ["bookcase"],
		"about": "a study lined with books"},
	# INT-016: a storey dug below the ground, reached down a stair from the hall
	{"key": "cellar_house", "style": &"townhouse", "trade": &"innkeeper",
		"width": 9.0, "length": 11.0, "height": 2.7, "cellars": 1,
		"rooms": [&"hall"], "cats": ["barrel|crate"],
		"about": "a house over a cellar: barrels below, a stair down from the hall"},
	# HOUSE-RICH: the same dwelling, banded. "ornament" is what makes this one
	# a rich house rather than a tall cottage, so it is declared the way the
	# rooms and the fittings are -- as the thing this archetype must contain.
	{"key": "rich_merchant", "style": &"rich", "trade": &"innkeeper",
		"width": 12.0, "length": 15.0, "height": 3.0, "storeys": 3, "ornament": true,
		"rooms": [&"hall", &"parlour"], "cats": ["table", "bench|seat"],
		"about": "a banded three-storey merchant's house: crown, belt courses, "
			+ "pediments and an obelisk on the ridge"},
	# HOUSE-CULTURE. "culture" is what makes these rows vernacular rather than
	# European with a new name, and it is declared the way "ornament" is: as
	# the thing this archetype must BE, not the piece a given seed happens to
	# roll. VernacularHouseCheck holds each rolled piece to its architecture.
	{"key": "mediterranean_house", "style": &"mediterranean", "trade": &"none",
		"width": 9.0, "length": 11.0, "height": 2.8, "culture": true,
		"rooms": [&"hall"], "cats": ["table|seat"],
		"about": "a limewashed house under a shallow tiled roof, shutters and all"},
	{"key": "asian_house", "style": &"asian", "trade": &"none",
		"width": 9.0, "length": 11.0, "height": 2.7, "culture": true,
		"rooms": [&"hall"], "cats": ["table|seat"],
		"about": "a boarded house under one very deep roof, on a veranda"},
	{"key": "african_compound", "style": &"african", "trade": &"none",
		"width": 10.0, "length": 12.0, "height": 2.8, "culture": true,
		"rooms": [&"hall"], "cats": ["table|seat"],
		"about": "a thick-walled compound house under combed thatch"},
	{"key": "thatched_cottage", "style": &"thatch_cottage", "trade": &"none",
		"width": 8.0, "length": 10.0, "height": 2.5, "culture": true,
		"rooms": [], "cats": ["bed"],
		"about": "a cob cottage under a very steep combed roof and no verge board"},
	{"key": "mud_hut", "style": &"mud_hut", "trade": &"none",
		"width": 6.5, "length": 7.5, "height": 2.4, "culture": true,
		"rooms": [], "cats": ["bed"],
		"about": "one room, half a metre of wall, and a cone over it"},
]


static func run() -> SuiteResult:
	var res := SuiteResult.new("house archetype")
	for row in ARCHETYPES:
		var key: String = row["key"]
		var defects := 0
		for scale in SCALES:
			var spec := HouseSpec.new()
			spec.style = row["style"]
			spec.trade = row["trade"]
			spec.width = float(row["width"]) * scale
			spec.length = float(row["length"]) * scale
			spec.height = float(row["height"])
			spec.cellars = int(row.get("cellars", 0))
			spec.storeys = int(row.get("storeys", 1))
			var plan: HousePlan = HouseGenerator.generate(spec, _seed_for(key, scale))
			var builder := HouseBuilder.new()
			builder.build(plan)
			res.checked += 1
			# The seed in every message: a failure you cannot rebuild from the
			# report is a failure you have to guess at.
			var who := "%s seed=%d scale=%.2f" % [key, spec.seed, scale]
			var before: int = res.failures.size()

			# the rooms this kind of house is defined by. A small one may not
			# have room for all of them; the scale-1.0 build must.
			for kind in row["rooms"]:
				if plan.has_kind(kind):
					continue
				if is_equal_approx(scale, 1.0) or scale > 1.0:
					res.fail("%s: no %s" % [who, String(kind)])

			# and the fittings that make it that kind of house. "a|b" means
			# either will do -- a farm needs somewhere to keep the harvest, and
			# whether that is a barrel or a crate is not the test's business.
			for cat in row["cats"]:
				if not _has_any_category(plan, String(cat)):
					if is_equal_approx(scale, 1.0) or scale > 1.0:
						res.fail("%s: nothing of kind '%s' anywhere in the house"
							% [who, String(cat)])

			var rep: Dictionary = HouseQA.new().check(plan, builder)
			for f in rep["failures"]:
				res.fail("%s: %s" % [who, str(f)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])
			# a rich archetype additionally owes the ornament, or it is a tall
			# cottage with a nice name
			if bool(row.get("ornament", false)):
				var rich: Dictionary = RichHouseCheck.new().check(plan, builder)
				for f2 in rich["failures"]:
					res.fail("%s: %s" % [who, str(f2)])
			# a vernacular archetype owes its vocabulary, or it is a European
			# house with a foreign name. The check runs on the plan as
			# generated: which pieces a seed carries is the dice's business, and
			# the check holds each of them to being the right piece in the right
			# place.
			if bool(row.get("culture", false)):
				var culture: Dictionary = VernacularHouseCheck.new().check(plan, builder)
				for f3 in culture["failures"]:
					res.fail("%s: %s" % [who, str(f3)])
			# a cellar is a storey: rooms on it, a pit dug for it, a stair
			# down to it, and the walk reaching it (INT-016)
			if spec.cellars > 0:
				if plan.rooms_on_storey(-1).is_empty():
					res.fail("%s: no rooms in the cellar" % who)
				if not builder.has_mass("pit_-1"):
					res.fail("%s: no pit dug for the cellar" % who)
				var down := false
				for stair in plan.stairs:
					if int(stair.get("storey", 0)) == -1:
						down = true
				if not down:
					res.fail("%s: no stair down to the cellar" % who)
				var cellar_barrels := 0
				for p in plan.furniture:
					if HousePlan.record_storey(p) == -1:
						cellar_barrels += 1
				if cellar_barrels == 0:
					res.warn("%s: the cellar is empty" % who)
			if res.failures.size() > before:
				defects += 1
		res.note("  %-17s %d scales, %d defects -- %s"
			% [key, SCALES.size(), defects, row["about"]])
	_round_tower(res)
	return res


static func _seed_for(key: String, scale: float) -> int:
	return 21000 + absi(key.hash()) % 900 + int(scale * 100.0)


static func _has_any_category(plan: HousePlan, spec: String) -> bool:
	for cat in spec.split("|"):
		for p in plan.furniture:
			if PropCatalog.category(p["key"]) == cat:
				return true
	return false

## The round tower: one octagonal room to a storey, three storeys (GEO-002).
##
## The archetypes above all come out of `HouseGenerator`, which partitions a
## rectangle -- so none of them can be this. The tower is built here instead,
## which is the honest place for it: the planner does not yet lay out shaped
## rooms, and what GEO-002 delivered is the REPRESENTATION and every rule that
## reads it. This is the demo that proves those rules hold on a plan a
## rectangle cannot describe, judged by the same HouseQA every house is.
const TOWER_SIDES := 8
const TOWER_STOREYS := 3

static func _round_tower(res: SuiteResult) -> void:
	for across in [8.0, 11.0]:
		var plan: HousePlan = _tower_plan(across, TOWER_STOREYS,
			int(4400 + across * 10.0))
		var builder := HouseBuilder.new()
		builder.build(plan)
		var who := "round_tower %.0fm" % across
		res.checked += 1

		for i in range(plan.room_count()):
			if not plan.is_polygonal(i):
				res.fail("%s: room %d lost its outline" % [who, i])
				continue
			var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, i)
			if walls.size() != TOWER_SIDES:
				res.fail("%s: room %d has %d walls, not %d"
					% [who, i, walls.size(), TOWER_SIDES])
		# nothing may stand outside the shape, which is the whole point of
		# carrying an outline rather than a box
		for f in range(plan.furniture.size()):
			var p: Dictionary = plan.furniture[f]
			if p.get("mounted", false) or int(p["host"]) >= 0:
				continue
			var poly: PackedVector2Array = plan.outline_of(int(p["room"]))
			var r: Rect2 = p["rect"]
			for c in [r.position, Vector2(r.end.x, r.position.y), r.end,
					Vector2(r.position.x, r.end.y)]:
				if not Poly.contains_point(poly, c, 0.02):
					res.fail("%s: %s stands outside the outline of room %d"
						% [who, String(p["key"]), int(p["room"])])
					break

		var rep: Dictionary = HouseQA.new().check(plan, builder)
		if not rep["ok"]:
			for m in rep["failures"]:
				res.fail("%s: %s" % [who, str(m)])
		for w in rep["warnings"]:
			res.warn("%s: %s" % [who, str(w)])


## An octagon to a storey, inscribed in the spec's own square, with a door on
## the edge nearest the front and a window every other edge.
static func _tower_plan(across: float, storeys: int, sd: int) -> HousePlan:
	var spec := HouseSpec.new(sd)
	spec.style = &"townhouse"
	spec.width = across
	spec.length = across
	spec.height = 2.8
	spec.storeys = storeys
	spec.room_count = storeys
	spec.variant_name = "Round Tower"
	spec.clutter = 0.5
	var plan := HousePlan.new()
	plan.spec = spec
	var poly: PackedVector2Array = _octagon(HouseGeometry.interior_rect(spec))
	var kinds: Array[StringName] = [&"hall", &"bedroom", &"bedroom"]
	for level in range(storeys):
		plan.rooms.append({"kind": kinds[level % kinds.size()],
			"rect": Poly.bounding_rect(poly), "outline": poly, "storey": level})

	var walls: Array[Dictionary] = HouseGeometry.polygon_walls(poly)
	var front := 0
	for k in range(walls.size()):
		if walls[k]["normal"].y > walls[front]["normal"].y:
			front = k
	var w: Dictionary = walls[front]
	plan.doors = [{"a": 0, "b": -1,
		"pos": (Vector2(w["from"]) + Vector2(w["to"])) / 2.0,
		"normal": -Vector2(w["normal"]), "width": HouseGeometry.DOOR_W,
		"exterior": true, "front": true, "storey": 0}]
	for level2 in range(storeys):
		for k2 in range(walls.size()):
			if (level2 == 0 and k2 == front) or k2 % 2 != 0:
				continue
			var wall: Dictionary = walls[k2]
			plan.windows.append({"room": level2,
				"pos": (Vector2(wall["from"]) + Vector2(wall["to"])) / 2.0,
				"normal": -Vector2(wall["normal"]),
				"width": HouseGeometry.WINDOW_W,
				"sill": HouseGeometry.WINDOW_SILL,
				"head": HouseGeometry.WINDOW_SILL + HouseGeometry.WINDOW_H,
				"storey": level2})
	for level3 in range(storeys - 1):
		HousePlanLevels.add_stair(plan, level3, level3 + 1, level3, level3 + 1)
	HouseFurnisher.furnish(plan, spec)
	return plan


static func _octagon(inner: Rect2) -> PackedVector2Array:
	var c: Vector2 = inner.get_center()
	var k: float = 1.0 / cos(PI / float(TOWER_SIDES))
	var out := PackedVector2Array()
	for i in range(TOWER_SIDES):
		var a: float = TAU * (float(i) + 0.5) / float(TOWER_SIDES)
		out.append(c + Vector2(cos(a) * inner.size.x / 2.0 * k,
			sin(a) * inner.size.y / 2.0 * k))
	return out
