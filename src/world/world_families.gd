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
	}
}


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
	if request.style != &"timber_hall" or not request.purpose in kinds_of(&"timber_hall"):
		return false
	out.spec = TimberHallGenerator.generate(request.purpose, request.seed,
		request.width, request.length, request.height)
	return true


## Build the mesh for a world building's spec, or null when there is none.
static func build_mesh(building) -> ArrayMesh:
	if building != null and building.plan != null \
			and building.plan.world_family in [&"courtyard_house", &"insula"]:
		return HouseBuilder.new().build(building.plan)
	if building == null or not (building.spec is TimberHallSpec):
		return null
	return TimberHallBuilder.new().build(building.spec as TimberHallSpec)
