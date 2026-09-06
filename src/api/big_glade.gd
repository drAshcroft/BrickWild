class_name BigGlade
extends RefCounted
## Public entry point for deterministic building generation.
##
## Generation and mesh emission are deliberately separate. This first API
## boundary keeps every existing family representation and builder intact;
## later renderers and serializers can grow behind it without changing callers.

## The public API version. BuildingLibrary owns the tables this facade
## publishes and validates against; the version is re-exported here because
## it is part of what every descriptor and placement carries.
const API_VERSION := BuildingLibrary.API_VERSION


static func kinds() -> Array[StringName]:
	return BuildingLibrary.kinds()


## Public controls and supported envelopes for one family: its label, its
## size envelope, and -- the option-discovery contract -- `styles` and
## `purposes`, each an ordered array of {"id", "label"}, plus the words this
## family calls them (`style_label`, `purpose_label`). A caller can fill a
## menu and build a valid request from this alone, without importing a single
## family header.
##
## The returned data is detached from the library's tables, so consumers
## cannot mutate global state by editing what they were handed.
static func describe_kind(kind: StringName) -> Dictionary:
	return BuildingLibrary.describe(kind)


## A valid request for a kind, filled from that kind's own default envelope.
static func default_request(kind: StringName, p_seed: int = 0) -> BuildingRequest:
	return BuildingLibrary.defaults(kind, p_seed)


## The word for one option id, for a caller that has to print it.
static func option_label(kind: StringName, field: StringName,
		id: StringName) -> String:
	return BuildingLibrary.option_label(kind, field, id)


## Generate the family-specific representation without emitting an ArrayMesh.
static func generate(request: BuildingRequest) -> GeneratedBuilding:
	var out := GeneratedBuilding.new()
	if request == null:
		_add_error(out, &"request_required", &"request", "A building request is required.")
		return out
	out.request = request.copy()
	_validate(out)
	if not out.errors.is_empty():
		return out

	var family: BuildingFamilyAdapter = BuildingFamilyAdapter.of(out.request.kind)
	if family == null or not family.generate(out.request, out):
		_add_error(out, &"family_not_built", &"kind",
			"'%s' has no generator yet." % String(out.request.kind))
	return out


## The middle stage (API-003): what the building IS, family-native and
## serialisable, with its placement already measured. `generate()` above is
## still the whole of the generation -- this wraps its result in the shape
## that crosses a boundary, and `build_mesh()` below takes either.
##
##     request --generate_document--> BuildingDocument --build_mesh--> mesh
##
## The payload inside is the family's own plan or spec, untouched, so the
## mesh built from a document is the same mesh vertex for vertex.
static func generate_document(request: BuildingRequest) -> BuildingDocument:
	var made: GeneratedBuilding = generate(request)
	var out := BuildingDocument.new()
	out.request = made.request
	out.errors = made.errors
	if not made.is_ok():
		return out
	out.spec = made.spec
	out.plan = made.plan
	out.village = made.village
	out.placement = placement(made)
	return out


## Emit a fresh mesh from a successful generated representation.
##
## Takes a `GeneratedBuilding` or a `BuildingDocument` -- the two carry the
## same three fields the dispatch reads (`spec`, `plan`, `request`), and a
## document exists precisely so a caller can hold one instead of the other.
static func build_mesh(building) -> ArrayMesh:
	if building == null or not building.is_ok():
		return null
	var family: BuildingFamilyAdapter = BuildingFamilyAdapter.for_building(building)
	return family.build_mesh(building) if family != null else null


## Placement facts shared by scene-based consumers. All families use local -Z
## as their public front: house doors, church entrances and castle gates are
## authored on that edge. `bounds` is measured from the emitted architecture
## (roof eaves, porches, chimney stacks and all) and is what fire gaps and
## canopies should clear; `footprint` is the walls' own outline -- narrower
## than `bounds` -- and is what `door` sits on the -Z edge of. Neither is
## merely copied from the requested envelope: both are read from the plan/spec
## that produced the mesh.
static func placement(building) -> Dictionary:
	var mesh: ArrayMesh = build_mesh(building)
	if mesh == null:
		return {}
	var bounds := mesh.get_aabb()
	return {
		"api_version": API_VERSION,
		"kind": building.request.kind,
		"seed": building.request.seed,
		"name": building.name(),
		"bounds": bounds,
		"footprint": _footprint(building),
		"front": Vector3(0.0, 0.0, -1.0),
		"door": _door(building),
	}


## The walls' own outline and the front door, from the family itself
## (API-004). Every family authors its entrance on its own -Z-facing front
## and knows which of its rects the door sits on; the facade asks rather than
## keeping a chain of `spec is ChurchSpec` of its own.
static func _footprint(building) -> Rect2:
	var family: BuildingFamilyAdapter = BuildingFamilyAdapter.for_building(building)
	return family.footprint(building) if family != null else Rect2()


static func _door(building) -> Vector3:
	var family: BuildingFamilyAdapter = BuildingFamilyAdapter.for_building(building)
	return family.door(building) if family != null else Vector3.ZERO


## Create a fresh scene instance. Every family includes its prop models: a
## house and a hotel their furniture, a temple its braziers and cages, a church
## its pews and candelabra, a castle its trestles, banners and courtyard.
## When `with_collision` is true, only the generated architectural shell gets
## trimesh collision; furniture and dressing remain visual details.
static func instantiate(building, cutaway := false,
		with_collision := false) -> Node3D:
	if building == null or not building.is_ok():
		return null
	var family: BuildingFamilyAdapter = BuildingFamilyAdapter.for_building(building)
	var root: Node3D = family.instantiate(building, cutaway) if family != null else null
	if root == null:
		# a family with no assembler of its own: its mesh, in its own colours
		var mesh: ArrayMesh = build_mesh(building)
		if mesh == null:
			return null
		var instance := MeshInstance3D.new()
		instance.name = building.name()
		instance.mesh = mesh
		ShellAssembler.surface_materials(instance,
			BuildingFamilyAdapter.colours(building.spec))
		root = instance
	root.set_meta(&"big_glade", true)
	root.set_meta(&"big_glade_kind", building.request.kind)
	root.set_meta(&"big_glade_seed", building.request.seed)
	root.set_meta(&"big_glade_name", building.name())
	if with_collision:
		_add_architecture_collision(root)
	return root


static func _add_architecture_collision(root: Node3D) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).create_trimesh_collision()
		return
	for child in root.get_children():
		if child is MeshInstance3D and child.name in [&"Shell", &"Stone"]:
			(child as MeshInstance3D).create_trimesh_collision()


## Every request is refused on its own terms before a family generator sees
## it, against the same rows describe_kind() publishes (API-002).
static func _validate(out: GeneratedBuilding) -> void:
	out.errors.append_array(BuildingLibrary.validate(out.request))


static func _add_error(out: GeneratedBuilding, code: StringName,
		field: StringName, message: String) -> void:
	out.errors.append({"code": code, "field": field, "message": message})
