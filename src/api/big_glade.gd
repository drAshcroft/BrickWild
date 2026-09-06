class_name BigGlade
extends RefCounted
## Public entry point for deterministic building generation.
##
## Generation and mesh emission are deliberately separate. This first API
## boundary keeps every existing family representation and builder intact;
## later renderers and serializers can grow behind it without changing callers.

const API_VERSION := 1
const _KINDS: Array[StringName] = [&"church", &"castle", &"house", &"shop", &"hotel", &"temple", &"world"]
const _DESCRIPTORS := {
	&"church": {
		"label": "Church", "size_label": "Nave", "height_label": "Eaves height (m)",
		"width": {"min": 6.0, "max": 24.0, "step": 0.5, "value": 10.0},
		"length": {"min": 10.0, "max": 60.0, "step": 1.0, "value": 22.0},
		"height": {"min": 6.0, "max": 30.0, "step": 0.5, "value": 12.0},
	},
	&"castle": {
		"label": "Castle", "size_label": "Site", "height_label": "Wall height (m)",
		"width": {"min": 6.0, "max": 320.0, "step": 1.0, "value": 55.0},
		"length": {"min": 8.0, "max": 400.0, "step": 1.0, "value": 50.0},
		"height": {"min": 3.0, "max": 40.0, "step": 0.5, "value": 18.0},
	},
	&"temple": {
		"label": "Temple", "size_label": "Temple", "height_label": "Hall height (m)",
		"width": {"min": 14.0, "max": 60.0, "step": 1.0, "value": 26.0},
		"length": {"min": 22.0, "max": 100.0, "step": 1.0, "value": 44.0},
		"height": {"min": 6.0, "max": 26.0, "step": 0.5, "value": 12.0},
	},
	&"house": {
		"label": "House", "size_label": "House", "height_label": "Ceiling (m)",
		"width": {"min": 5.0, "max": 20.0, "step": 0.5, "value": 9.0},
		"length": {"min": 6.0, "max": 26.0, "step": 0.5, "value": 12.0},
		"height": {"min": 2.2, "max": 3.6, "step": 0.1, "value": 2.6},
		"storeys": {"min": 1, "max": 3, "step": 1, "value": 1},
	},
	&"shop": {
		"label": "Shop / Civic Building", "size_label": "Building", "height_label": "Ceiling (m)",
		"width": {"min": 7.0, "max": 24.0, "step": 0.5, "value": 11.0},
		"length": {"min": 8.0, "max": 32.0, "step": 0.5, "value": 14.0},
		"height": {"min": 2.4, "max": 4.2, "step": 0.1, "value": 2.8},
		"storeys": {"min": 1, "max": 3, "step": 1, "value": 1},
	},
	&"hotel": {
		"label": "Grand Hotel", "size_label": "Hotel", "height_label": "Floor height (m)",
		"width": {"min": 30.0, "max": 80.0, "step": 1.0, "value": 48.0},
		"length": {"min": 16.0, "max": 42.0, "step": 1.0, "value": 24.0},
		"height": {"min": 3.0, "max": 4.5, "step": 0.1, "value": 3.6},
		"storeys": {"min": 3, "max": 3, "step": 1, "value": 3},
	},
	# the buildings of the wider world (WLD-000): `style` is the family and
	# `purpose` its sub-kind; WorldFamilies is the registry and every family
	# narrows this envelope with its own
	&"world": {
		"label": "World building", "size_label": "Building", "height_label": "Height (m)",
		"width": {"min": 4.0, "max": 120.0, "step": 0.5, "value": 20.0},
		"length": {"min": 4.0, "max": 120.0, "step": 0.5, "value": 30.0},
		"height": {"min": 2.2, "max": 40.0, "step": 0.1, "value": 6.0},
	},
}


static func kinds() -> Array[StringName]:
	return _KINDS.duplicate()


## Public controls and supported envelopes for one family. The returned data is
## detached from the library's tables so consumers cannot mutate global state.
static func describe_kind(kind: StringName) -> Dictionary:
	if not _DESCRIPTORS.has(kind):
		return {}
	var out: Dictionary = _DESCRIPTORS[kind].duplicate(true)
	out["kind"] = kind
	out["api_version"] = API_VERSION
	var style_table: Dictionary
	var purpose_table: Dictionary = {}
	match kind:
		&"church":
			style_table = ChurchSpec.STYLES
		&"castle":
			style_table = CastleSpec.STYLES
		&"house":
			style_table = HouseSpec.STYLES
			purpose_table = HouseSpec.TRADES
		&"shop":
			style_table = HouseSpec.STYLES
			purpose_table = ShopSpec.BUSINESSES
		&"hotel":
			style_table = HotelSpec.HOTEL_STYLES
		&"temple":
			style_table = TempleSpec.FORMS
			purpose_table = TempleSpec.CULTS
		&"world":
			# families and their sub-kinds, with each family's own envelope
			var families: Array[Dictionary] = []
			var kinds: Array[Dictionary] = []
			for f in WorldFamilies.families():
				families.append({"id": f, "label": WorldFamilies.FAMILIES[f]["label"],
					"envelope": WorldFamilies.envelope(f), "kinds": WorldFamilies.kinds_of(f)})
				for k in WorldFamilies.kinds_of(f):
					kinds.append({"id": k, "label": String(k).capitalize()})
			out["styles"] = families
			out["purposes"] = kinds
			out["families"] = families
			return out
	out["styles"] = _options(style_table)
	out["purposes"] = _options(purpose_table)
	return out


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


## Emit a fresh mesh from a successful generated representation.
static func build_mesh(building: GeneratedBuilding) -> ArrayMesh:
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
static func placement(building: GeneratedBuilding) -> Dictionary:
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
static func _footprint(building: GeneratedBuilding) -> Rect2:
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
static func _door(building: GeneratedBuilding) -> Vector3:
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
static func instantiate(building: GeneratedBuilding, cutaway := false,
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


static func _validate(out: GeneratedBuilding) -> void:
	var request := out.request
	var known_kind := request.kind in _KINDS
	if not known_kind:
		_add_error(out, &"unknown_kind", &"kind",
			"Unknown building kind '%s'." % String(request.kind))
	for field in [&"width", &"length", &"height"]:
		var value: float = request.get(field)
		if not is_finite(value) or value <= 0.0:
			_add_error(out, &"invalid_dimension", field,
				"%s must be a positive finite number." % String(field))
		elif known_kind:
			var limits: Dictionary = _DESCRIPTORS[request.kind][field]
			if value < float(limits["min"]) or value > float(limits["max"]):
				_add_error(out, &"dimension_out_of_range", field,
					"%s must be between %s and %s metres for a %s." % [
						String(field), limits["min"], limits["max"], String(request.kind)])
	if not known_kind:
		return
	if request.kind == &"house" or request.kind == &"shop":
		if request.storeys < 1 or request.storeys > 3:
			_add_error(out, &"storeys_out_of_range", &"storeys",
				"storeys must be between 1 and 3 for a house.")

	match request.kind:
		&"church":
			_validate_style(out, ChurchSpec.STYLES, &"style")
			_validate_empty_purpose(out)
		&"castle":
			_validate_style(out, CastleSpec.STYLES, &"style")
			_validate_empty_purpose(out)
		&"house":
			_validate_style(out, HouseSpec.STYLES, &"style")
			if not HouseSpec.TRADES.has(request.purpose):
				_add_error(out, &"unknown_trade", &"purpose",
					"Unknown house trade '%s'." % String(request.purpose))
		&"shop":
			_validate_style(out, HouseSpec.STYLES, &"style")
			if not ShopSpec.BUSINESSES.has(request.purpose):
				_add_error(out, &"unknown_business", &"purpose",
					"Unknown shop business '%s'." % String(request.purpose))
		&"hotel":
			_validate_style(out, HotelSpec.HOTEL_STYLES, &"style")
			_validate_empty_purpose(out)
		&"temple":
			_validate_style(out, TempleSpec.FORMS, &"form")
			if not TempleSpec.CULTS.has(request.purpose):
				_add_error(out, &"unknown_cult", &"purpose",
					"Unknown temple cult '%s'." % String(request.purpose))
		&"world":
			if not WorldFamilies.has_family(request.style):
				_add_error(out, &"unknown_family", &"style",
					"Unknown world family '%s'." % String(request.style))
			elif not request.purpose in WorldFamilies.kinds_of(request.style):
				_add_error(out, &"unknown_kind", &"purpose",
					"Unknown %s kind '%s'." % [String(request.style), String(request.purpose)])
			else:
				var env: Dictionary = WorldFamilies.envelope(request.style)
				for field in [&"width", &"length", &"height"]:
					var value: float = request.get(field)
					var lim: Dictionary = env[field]
					if value < float(lim["min"]) or value > float(lim["max"]):
						_add_error(out, &"dimension_out_of_range", field,
							"%s must be between %s and %s metres for a %s." % [
								String(field), lim["min"], lim["max"], String(request.style)])


static func _validate_style(out: GeneratedBuilding, table: Dictionary,
		field: StringName) -> void:
	if not table.has(out.request.style):
		_add_error(out, &"unknown_%s" % String(field), field,
			"Unknown %s '%s' for %s." % [String(field), String(out.request.style),
				String(out.request.kind)])


static func _validate_empty_purpose(out: GeneratedBuilding) -> void:
	if out.request.purpose != &"":
		_add_error(out, &"unsupported_purpose", &"purpose",
			"%s requests do not use a purpose." % String(out.request.kind).capitalize())


static func _add_error(out: GeneratedBuilding, code: StringName,
		field: StringName, message: String) -> void:
	out.errors.append({"code": code, "field": field, "message": message})


static func _options(table: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in table:
		out.append({"id": id, "label": table[id]["label"]})
	return out
