class_name WorldFamilies
extends RefCounted
## The `world` kind's registry (WLD-000; WORLD_BUILDINGS 5): the building
## families of the wider world -- courtyard houses, timber halls on their
## platforms, and the rest of WORLD_BUILDINGS -- each added here as one row
## with its own generator, check and archetype rows, so `BigGlade.generate()`
## dispatches by `request.style` (the family) and `request.purpose` (the
## sub-kind) without the facade changing for every new family.
##
## A family row: {"label": String, "kinds": [StringName], "width": {min,
## max}, "length": {...}, "height": {...}}. `generate()` below matches the
## family to its generator; a family with a row and no branch is a family
## still being built, and the facade reports it as such.

const FAMILIES := {
	&"courtyard_house": {
		"label": "Courtyard house",
		"kinds": [&"domus", &"riad", &"palazzo"],
		"width": {"min": 12.0, "max": 30.0},
		"length": {"min": 15.0, "max": 50.0},
		"height": {"min": 2.6, "max": 24.0},
	},
	&"mosque": {
		"label": "Hypostyle mosque",
		"kinds": [&"hypostyle"],
		"width": {"min": 60.0, "max": 180.0},
		"length": {"min": 40.0, "max": 130.0},
		"height": {"min": 8.0, "max": 30.0},
	},
	&"cruciform_temple": {
		"label": "Cruciform temple",
		"kinds": [&"temple_of_four_winds"],
		"width": {"min": 60.0, "max": 180.0},
		"length": {"min": 60.0, "max": 180.0},
		"height": {"min": 32.0, "max": 50.0},
	},
	&"timber_hall": {
		"label": "Timber hall",
		"kinds": [&"great_hall", &"phoenix_pavilion"],
		"width": {"min": 18.0, "max": 120.0},
		"length": {"min": 8.0, "max": 42.0},
		"height": {"min": 10.0, "max": 24.0},
	},
	&"insula": {
		"label": "Insula",
		"kinds": [&"port_tenement"],
		"width": {"min": 20.0, "max": 45.0},
		"length": {"min": 18.0, "max": 38.0},
		"height": {"min": 12.0, "max": 20.7},
	},
	&"tower_house": {
		"label": "Tower house",
		"kinds": [&"merchant_tower"],
		"width": {"min": 5.6, "max": 15.2},
		"length": {"min": 5.6, "max": 15.2},
		"height": {"min": 31.5, "max": 85.5},
	},
	&"caravanserai": {
		"label": "Caravanserai",
		"kinds": [&"sultan_han"],
		"width": {"min": 49.0, "max": 133.0},
		"length": {"min": 38.5, "max": 105.0},
		"height": {"min": 12.0, "max": 12.0},
	},
	&"hammam": {
		"label": "Hammam",
		"kinds": [&"steam_baths"],
		"width": {"min": 14.0, "max": 48.0},
		"length": {"min": 10.0, "max": 32.0},
		"height": {"min": 6.0, "max": 12.0},
	},
	&"pagoda": {
		"label": "Pagoda",
		"kinds": [&"square_pagoda", &"octagonal_pagoda", &"dodecagonal_pagoda"],
		"width": {"min": 20.0, "max": 57.0},
		"length": {"min": 20.0, "max": 57.0},
		"height": {"min": 40.0, "max": 144.0},
	},
	&"stupa": {
		"label": "Stupa",
		"kinds": [&"saints_mound"],
		"width": {"min": 32.0, "max": 48.0},
		"length": {"min": 32.0, "max": 48.0},
		"height": {"min": 14.0, "max": 20.0},
	},
	&"vihara": {
		"label": "Vihara",
		"kinds": [&"monks_cloister"],
		"width": {"min": 35.0, "max": 95.0},
		"length": {"min": 28.0, "max": 76.0},
		"height": {"min": 5.0, "max": 5.0},
	},
	&"vastu": {
		"label": "Haveli / vastu house",
		"kinds": [&"merchants_haveli"],
		"width": {"min": 12.0, "max": 36.0},
		"length": {"min": 18.0, "max": 48.0},
		"height": {"min": 7.0, "max": 16.0},
	},
	&"tulou": {
		"label": "Tulou",
		"kinds": [&"clan_ring"],
		"width": {"min": 40.0, "max": 120.0},
		"length": {"min": 40.0, "max": 120.0},
		"height": {"min": 9.0, "max": 25.0},
	},
	&"nagara": {
		"label": "Nagara temple",
		"kinds": [&"hundred_spires"],
		"width": {"min": 18.0, "max": 52.0},
		"length": {"min": 20.0, "max": 64.0},
		"height": {"min": 24.0, "max": 60.0},
	},
	&"temple_mountain": {
		"label": "Temple mountain",
		"kinds": [&"angkor_mountain"],
		"width": {"min": 120.0, "max": 380.0},
		"length": {"min": 120.0, "max": 380.0},
		"height": {"min": 30.0, "max": 90.0},
	},
	&"stepwell": {
		"label": "Stepwell",
		"kinds": [&"queens_well"],
		"width": {"min": 45.5, "max": 123.5},
		"length": {"min": 14.0, "max": 38.0},
		"height": {"min": 16.8, "max": 28.0},
	}
}

const TowerGenerator = preload("res://src/world/world_tower_house_generator.gd")
const StupaGenerator = preload("res://src/world/stupa_generator.gd")


static func families() -> Array[StringName]:
	var out: Array[StringName] = []
	for f in FAMILIES:
		out.append(f)
	return out


static func has_family(family: StringName) -> bool:
	return FAMILIES.has(family)


## The sub-kinds a family comes in.
static func kinds_of(family: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if FAMILIES.has(family):
		for k in FAMILIES[family]["kinds"]:
			out.append(k)
	return out


## The size envelope of a family, or an empty dictionary for none.
static func envelope(family: StringName) -> Dictionary:
	if not FAMILIES.has(family):
		return {}
	var row: Dictionary = FAMILIES[family]
	return {"width": row["width"].duplicate(), "length": row["length"].duplicate(),
		"height": row["height"].duplicate()}


## Generate a world building: fills `out.spec` (and `out.plan` for the
## plan-based families). Returns false when the family has no generator
## yet, which the facade reports as an error rather than a building.
static func generate(request: BuildingRequest, out: GeneratedBuilding) -> bool:
	if request.style == &"tower_house" and request.purpose in kinds_of(&"tower_house"):
		out.spec = TowerGenerator.generate(request.purpose, request.seed,
			request.width, request.length, request.height)
		return true
	if request.style == &"courtyard_house" and request.purpose in kinds_of(&"courtyard_house"):
		var made := WorldCourtyardGenerator.generate(request.purpose, request.seed,
			request.width, request.length, request.height, true)
		out.spec = made["spec"]
		out.plan = made["plan"]
		return true
	if request.style == &"insula" and request.purpose in kinds_of(&"insula"):
		var insula_made := InsulaGenerator.generate(request.seed, request.width,
			request.length, request.height)
		out.spec = insula_made["spec"]
		out.plan = insula_made["plan"]
		return true
	if request.style == &"mosque" and request.purpose in kinds_of(&"mosque"):
		var mosque_made := MosqueGenerator.generate(request.purpose, request.seed,
			request.width, request.length, request.height)
		out.spec = mosque_made["spec"]
		out.plan = mosque_made["plan"]
		return true
	if request.style == &"caravanserai" and request.purpose in kinds_of(&"caravanserai"):
		var han_made := WorldHanGenerator.generate(request.seed, request.width,
			request.length, request.height)
		out.spec = han_made["spec"]
		out.plan = han_made["plan"]
		return true
	if request.style == &"hammam" and request.purpose in kinds_of(&"hammam"):
		var hammam_made := HammamGenerator.generate(request.seed, request.width,
			request.length, request.height)
		out.spec = hammam_made["spec"]
		out.plan = hammam_made["plan"]
		return true
	if request.style == &"cruciform_temple" and request.purpose in kinds_of(&"cruciform_temple"):
		var shrine := CruciformGenerator.generate(request.purpose, request.seed,
			request.width, request.length, request.height)
		out.spec = shrine["spec"]
		out.plan = shrine["plan"]
		return true
	if request.style == &"pagoda" and request.purpose in kinds_of(&"pagoda"):
		var pagoda_made := PagodaGenerator.generate(request.purpose, request.seed,
			request.width, request.length, request.height)
		out.spec = pagoda_made["spec"]
		out.plan = pagoda_made["plan"]
		return true
	if request.style == &"stupa" and request.purpose in kinds_of(&"stupa"):
		out.spec = StupaGenerator.generate(request.purpose, request.seed,
			request.width, request.length, request.height)
		return true
	if request.style == &"vihara" and request.purpose in kinds_of(&"vihara"):
		var vihara_made := ViharaGenerator.generate(request.seed, request.width,
			request.length, request.height)
		out.spec = vihara_made["spec"]
		out.plan = vihara_made["plan"]
		return true
	if request.style == &"vastu" and request.purpose in kinds_of(&"vastu"):
		var vastu_made := VastuGenerator.generate(request.seed, request.width,
			request.length, request.height)
		out.spec = vastu_made["spec"]
		out.plan = vastu_made["plan"]
		return true
	if request.style == &"tulou" and request.purpose in kinds_of(&"tulou"):
		var tulou_made := TulouGenerator.generate(request.seed, request.width,
			request.length, request.height, request.storeys)
		out.spec = tulou_made["spec"]
		out.plan = tulou_made["plan"]
		return true
	if request.style == &"nagara" and request.purpose in kinds_of(&"nagara"):
		var nagara_made := NagaraGenerator.generate(request.purpose, request.seed,
			request.width, request.length, request.height)
		out.spec = nagara_made["spec"]
		out.plan = nagara_made["plan"]
		return true
	if request.style == &"temple_mountain" and request.purpose in kinds_of(&"temple_mountain"):
		var mountain_made := MountainGenerator.generate(request.purpose, request.seed,
			request.width, request.length, request.height)
		out.spec = mountain_made["spec"]
		out.plan = mountain_made["plan"]
		return true
	if request.style == &"stepwell" and request.purpose in kinds_of(&"stepwell"):
		var vav_made := VavGenerator.generate(request.seed, request.width,
			request.length, request.height)
		out.spec = vav_made["spec"]
		out.plan = vav_made["plan"]
		return true
	if request.style != &"timber_hall" or not request.purpose in kinds_of(&"timber_hall"):
		return false
	out.spec = TimberHallGenerator.generate(request.purpose, request.seed,
		request.width, request.length, request.height)
	return true


## Build the mesh for a world building's spec, or null when there is none.
static func build_mesh(building) -> ArrayMesh:
	if building != null and building.spec is CastleSpec \
			and CastleGeometry.is_tower_house(building.spec):
		return CastleBuilder.new().build(building.spec)
	if building != null and building.plan != null \
			and building.plan.world_family in [&"courtyard_house", &"insula", &"caravanserai", &"vastu", &"vihara"]:
		return HouseBuilder.new().build(building.plan)
	if building != null and building.plan != null \
			and building.plan.world_family == &"mosque":
		return MosqueBuilder.new().build(building.plan)
	if building != null and building.plan != null \
			and building.plan.world_family == &"hammam":
		return HammamBuilder.new().build(building.plan)
	if building != null and building.plan != null \
			and building.plan.world_family == &"cruciform_temple":
		return CruciformBuilder.new().build(building.plan)
	if building != null and building.plan != null \
			and building.plan.world_family == &"pagoda":
		return PagodaBuilder.new().build(building.plan)
	if building != null and building.spec is StupaSpec:
		return StupaBuilder.new().build(building.spec)
	if building != null and building.plan != null \
			and building.plan.world_family == &"tulou":
		return TulouBuilder.new().build(building.plan)
	if building != null and building.plan != null \
			and building.plan.world_family == &"nagara":
		return NagaraBuilder.new().build(building.plan)
	if building != null and building.plan != null \
			and building.plan.world_family == &"temple_mountain":
		return MountainBuilder.new().build(building.plan)
	if building != null and building.plan != null \
			and building.plan.world_family == &"stepwell":
		return VavBuilder.new().build(building.plan)
	if building == null or not (building.spec is TimberHallSpec):
		return null
	return TimberHallBuilder.new().build(building.spec as TimberHallSpec)
