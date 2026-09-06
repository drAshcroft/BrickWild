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

	match out.request.kind:
		&"church":
			var spec := ChurchSpec.new()
			_copy_size_and_style(out.request, spec)
			ChurchGenerator.generate(spec, out.request.seed)
			out.spec = spec
		&"castle":
			var spec := CastleSpec.new()
			_copy_size_and_style(out.request, spec)
			CastleGenerator.generate(spec, out.request.seed)
			out.spec = spec
		&"house":
			var spec := HouseSpec.new()
			_copy_size_and_style(out.request, spec)
			spec.trade = out.request.purpose
			spec.storeys = out.request.storeys
			out.plan = HouseGenerator.generate(spec, out.request.seed)
			out.spec = spec
		&"shop":
			var spec := ShopSpec.new()
			_copy_size_and_style(out.request, spec)
			spec.business = out.request.purpose
			spec.storeys = out.request.storeys
			out.plan = ShopGenerator.generate(spec, out.request.seed)
			out.spec = spec
		&"hotel":
			var spec := HotelSpec.new()
			_copy_size_and_style(out.request, spec)
			out.plan = HotelGenerator.generate(spec, out.request.seed)
			out.spec = spec
		&"temple":
			var spec := TempleSpec.new()
			spec.form = out.request.style
			spec.cult = out.request.purpose
			spec.width = out.request.width
			spec.length = out.request.length
			spec.height = out.request.height
			TempleGenerator.generate(spec, out.request.seed)
			out.spec = spec
		&"world":
			if not WorldFamilies.generate(out.request, out):
				_add_error(out, &"family_not_built", &"style",
					"World family '%s' has no generator yet." % String(out.request.style))
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
	if building.spec is ChurchSpec:
		return ChurchBuilder.new().build(building.spec as ChurchSpec)
	if building.spec is CastleSpec:
		return CastleBuilder.new().build(building.spec as CastleSpec)
	if building.spec is HotelSpec:
		return HotelBuilder.new().build(building.plan)
	if building.spec is HouseSpec:
		return HouseBuilder.new().build(building.plan)
	if building.spec is TempleSpec:
		return TempleBuilder.new().build(building.spec as TempleSpec)
	if building.request.kind == &"world":
		return WorldFamilies.build_mesh(building)
	return null


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


## The walls' own outline in XZ, local space -- narrower than `bounds` because
## `bounds` also covers roof eaves, porches and chimney stacks (house/shop/
## hotel), battlements and towers (castle), or a facade tower's own footprint
## (church). `door` always sits on this rect's -Z edge, by construction:
##  - house, shop, hotel: HouseGeometry.interior_rect(spec), the same rect
##    HousePlanner places the front door's z on (HousePlan.entrance()'s "pos").
##  - castle: CastleGeometry.enceinte_rect(spec, 0), the outer ring the
##    gatehouse is cut into.
##  - temple: TempleGeometry.site_rect(spec), the outer wall face the gate is
##    cut through -- used uniformly across forms, including the ziggurat,
##    whose gate void is voxel-recessed behind the outermost terrace but whose
##    public-facing gate is still this edge.
##  - church: the nave rect, EXCEPT when a single axial tower carries the door
##    out past the nave's own west wall (see `_church_door_z`): then the front
##    edge follows the door out to that tower's own west face, since the tower
##    is a real mass of the building, not applique on the nave.
static func _footprint(building) -> Rect2:
	var spec: RefCounted = building.spec
	if building.plan != null:
		return HouseGeometry.interior_rect(building.plan.spec)
	if spec is ChurchSpec:
		var church := spec as ChurchSpec
		var front_z: float = _church_door_z(church)
		return Rect2(Vector2(-church.width / 2.0, front_z),
			Vector2(church.width, church.length / 2.0 - front_z))
	if spec is CastleSpec:
		return CastleGeometry.enceinte_rect(spec as CastleSpec, 0)
	if spec is TempleSpec:
		return TempleGeometry.site_rect(spec as TempleSpec)
	return Rect2()


## Where a family's front door sits, in the same local space as `bounds`. Each
## family authors its entrance on its own -Z-facing front, so this is read from
## the plan/spec that produced the mesh rather than re-detected from geometry:
##  - house, shop, hotel: HousePlan.entrance()'s door position (a HouseGenerator/
##    ShopGenerator/HotelGenerator all return a HousePlan).
##  - church: the west door offset ChurchBuilder itself places on -Z, including
##    the single-axial-tower case where the door rides out on the tower's own
##    west face.
##  - castle: the outer ring's gatehouse, CastleGeometry.gatehouse_aabb(spec, 0).
##  - temple: the gate on the site's front edge (TempleGeometry.site_rect);
##    used uniformly across forms, including the ziggurat, whose gate void is
##    voxel-recessed behind the outermost terrace but whose public-facing gate
##    is still this edge.
static func _door(building) -> Vector3:
	var spec: RefCounted = building.spec
	if building.plan != null:
		var plan: HousePlan = building.plan
		var d: int = plan.entrance()
		if d >= 0:
			var pos: Vector2 = plan.doors[d]["pos"]
			return Vector3(pos.x, 1.0, pos.y)
		return Vector3(0.0, 1.0, 0.0)
	if spec is ChurchSpec:
		var church := spec as ChurchSpec
		return Vector3(0.0, ChurchGeometry.door_height(church) / 2.0, _church_door_z(church))
	if spec is CastleSpec:
		var castle := spec as CastleSpec
		var g: AABB = CastleGeometry.gatehouse_aabb(castle, 0)
		return Vector3(0.0, g.size.y / 2.0, g.position.z)
	if spec is TempleSpec:
		var temple := spec as TempleSpec
		var r: Rect2 = TempleGeometry.site_rect(temple)
		var gh: float = minf(TempleGeometry.GATE_H, temple.height - 0.6)
		return Vector3(0.0, gh / 2.0, r.position.y)
	return Vector3.ZERO


## ChurchBuilder's own door_z formula (see its "main door" section): the west
## door sits on the nave's own front wall, UNLESS a single axial tower carries
## it out to that tower's own west face instead.
static func _church_door_z(church: ChurchSpec) -> float:
	var l: float = church.length
	var door_z: float = -l / 2.0 - 0.02
	if church.tower and church.west_towers == 1:
		door_z = -l / 2.0 + ChurchGeometry.TOWER_EMBED - church.tower_width - 0.02
	return door_z


## Create a fresh scene instance. Every family includes its prop models: a
## house and a hotel their furniture, a temple its braziers and cages, a church
## its pews and candelabra, a castle its trestles, banners and courtyard.
## When `with_collision` is true, only the generated architectural shell gets
## trimesh collision; furniture and dressing remain visual details.
static func instantiate(building, cutaway := false,
		with_collision := false) -> Node3D:
	if building == null or not building.is_ok():
		return null
	var root: Node3D
	if building.spec is HotelSpec:
		root = HotelAssembler.build(building.plan, cutaway)
	elif building.spec is ShopSpec:
		root = ShopAssembler.build(building.plan, cutaway)
	elif building.spec is HouseSpec:
		root = HouseAssembler.build(building.plan, cutaway)
	elif building.spec is TempleSpec:
		root = TempleAssembler.build(building.spec as TempleSpec, cutaway)
	elif building.spec is ChurchSpec:
		root = ChurchAssembler.build(building.spec as ChurchSpec, cutaway)
	elif building.spec is CastleSpec:
		root = CastleAssembler.build(building.spec as CastleSpec, cutaway)
	else:
		var mesh: ArrayMesh = build_mesh(building)
		if mesh == null:
			return null
		var instance := MeshInstance3D.new()
		instance.name = building.name()
		instance.mesh = mesh
		var colors := [building.spec.get("stone_color"), building.spec.get("trim_color"),
			building.spec.get("roof_color"), Color("1a1c20")]
		for surface in range(mesh.get_surface_count()):
			var material := StandardMaterial3D.new()
			material.albedo_color = colors[surface]
			material.roughness = 0.9
			instance.set_surface_override_material(surface, material)
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


static func _copy_size_and_style(request: BuildingRequest, spec: RefCounted) -> void:
	spec.set("style", request.style)
	spec.set("width", request.width)
	spec.set("length", request.length)
	spec.set("height", request.height)


## Every request is refused on its own terms before a family generator sees
## it, against the same rows describe_kind() publishes (API-002).
static func _validate(out: GeneratedBuilding) -> void:
	out.errors.append_array(BuildingLibrary.validate(out.request))


static func _add_error(out: GeneratedBuilding, code: StringName,
		field: StringName, message: String) -> void:
	out.errors.append({"code": code, "field": field, "message": message})
