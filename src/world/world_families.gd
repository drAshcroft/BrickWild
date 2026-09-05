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

const FAMILIES := {}


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
static func generate(_request: BuildingRequest, _out: GeneratedBuilding) -> bool:
	return false


## Build the mesh for a world building's spec, or null when there is none.
static func build_mesh(_building: GeneratedBuilding) -> ArrayMesh:
	return null
