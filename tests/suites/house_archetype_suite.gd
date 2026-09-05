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
			var plan: HousePlan = HouseGenerator.generate(spec, _seed_for(key, scale))
			var builder := HouseBuilder.new()
			builder.build(plan)
			res.checked += 1
			var who := "%s scale=%.2f" % [key, scale]
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
	return res


static func _seed_for(key: String, scale: float) -> int:
	return 21000 + absi(key.hash()) % 900 + int(scale * 100.0)


static func _has_any_category(plan: HousePlan, spec: String) -> bool:
	for cat in spec.split("|"):
		for p in plan.furniture:
			if PropCatalog.category(p["key"]) == cat:
				return true
	return false
