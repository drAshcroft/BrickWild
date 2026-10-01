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
	return _generate(request, false)


## Measure actual architecture for lot planning without retaining an interior.
## Shops omit furnishing; houses replay the exact prefix that places the hearth
## and its chimney. All other families use full generation.
## The returned placement equals placement(generate(request)), including exterior
## prop bounds. Invalid requests return an empty dictionary. Use generate() when
## a document, scene or functional interior is needed.
static func measure(request: BuildingRequest) -> Dictionary:
	var building := _generate(request, true)
	return placement(building) if building.is_ok() else {}


static func _generate(request: BuildingRequest, placement_only: bool) -> GeneratedBuilding:
	var out := GeneratedBuilding.new()
	if request == null:
		_add_error(out, &"request_required", &"request", "A building request is required.")
		return out
	out.request = request.copy()
	_validate(out)
	if not out.errors.is_empty():
		return out

	var family: BuildingFamilyAdapter = BuildingFamilyAdapter.of(out.request.kind)
	var built := false
	if family != null:
		built = family.generate_for_placement(out.request, out) if placement_only \
			else family.generate(out.request, out)
	if not built:
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


## Run the existing family's geometry and functionality checks. This may be
## expensive (church/castle voxel QA); call it explicitly, never per frame.
static func check(building) -> Dictionary:
	return BuildingResult.check(building)


## Placement facts shared by scene-based consumers. All families use local -Z
## as their public front. `door` is the actual entrance and may be recessed
## within an open manor courtyard. `bounds` is measured from the emitted architecture
## (roof eaves, porches, chimney stacks and all) and is what fire gaps and
## canopies should clear; `footprint` is the walls' own outline -- narrower
## than `bounds`. Neither is
## merely copied from the requested envelope: both are read from the plan/spec
## that produced the mesh.
static func placement(building) -> Dictionary:
	# `bounds` is the ARCHITECTURE (and the facade pieces on its walls), never the
	# yard: the yard's built pieces are put aside while this mesh is measured and
	# restored after. The yard is reported beside it (`yard`, `yard_extent`,
	# `yard_blocks`), so a lot can size itself on the house as it always did and
	# still keep the ground the yard needs; the village walks round `yard_blocks`.
	var held: Array[Dictionary] = []
	if building != null and building.plan is HousePlan:
		held = building.plan.yard_pieces.duplicate()
		building.plan.yard_pieces.clear()
	var mesh: ArrayMesh = build_mesh(building)
	if building != null and building.plan is HousePlan:
		building.plan.yard_pieces.assign(held)
	if mesh == null:
		return {}
	var bounds := mesh.get_aabb()
	# Exterior props must fit in the placement envelope too. They remain
	# separate from the architectural mesh and the wall footprint.
	if building.plan != null and building.plan.spec.exterior_props:
		for p in building.plan.exterior:
			bounds = bounds.merge(HouseExterior.bounds_of(p))
	var out := {
		"api_version": API_VERSION,
		"kind": building.request.kind,
		"seed": building.request.seed,
		"name": building.name(),
		"bounds": bounds,
		"footprint": _footprint(building),
		"front": Vector3(0.0, 0.0, -1.0),
		"north": Basis(Vector3.UP, building.request.orientation).inverse() * Vector3.BACK,
		"door": _door(building),
	}
	# The yard: `bounds` above already holds what is really there (built pieces in
	# the mesh, props merged in). `yard` is the ENVELOPE the house may dress, the
	# footprint with its porch and chimney grown by the apron (2 to 3 m): the
	# permission, not an extent. A lot that keeps `yard` clear keeps every yard
	# prop and the walkway to the door; the lot owns everything beyond it.
	# `yard_categories` is what the house already supplies (a cart, a barrel, a
	# bench), so a village that dresses the same ground can leave those out.
	if building.plan is HousePlan and HouseYard.applies(building.plan):
		out["yard"] = HouseGeometry.yard_rect(building.plan)
		out["yard_categories"] = HouseYard.categories(building.plan)
		out["yard_extent"] = HouseYard.extent(building.plan)
		out["yard_blocks"] = HouseYard.obstacles(building.plan)
	var family := BuildingFamilyAdapter.for_building(building)
	if family != null:
		out.merge(family.placement_metadata(building, bounds))
	return out


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
	out.errors.append_array(out.request._decode_errors)
	out.errors.append_array(BuildingLibrary.validate(out.request))


static func _add_error(out: GeneratedBuilding, code: StringName,
		field: StringName, message: String) -> void:
	out.errors.append({"code": code, "field": field, "message": message})
