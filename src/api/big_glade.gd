class_name BigGlade
extends RefCounted
## Public entry point for deterministic building generation.
##
## Generation and mesh emission are deliberately separate. This first API
## boundary keeps every existing family representation and builder intact;
## later renderers and serializers can grow behind it without changing callers.

const API_VERSION := 1
const _KINDS: Array[StringName] = [&"church", &"castle", &"house", &"temple"]
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
		&"temple":
			style_table = TempleSpec.FORMS
			purpose_table = TempleSpec.CULTS
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
			out.plan = HouseGenerator.generate(spec, out.request.seed)
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
	return out


## Emit a fresh mesh from a successful generated representation.
static func build_mesh(building: GeneratedBuilding) -> ArrayMesh:
	if building == null or not building.is_ok():
		return null
	if building.spec is ChurchSpec:
		return ChurchBuilder.new().build(building.spec as ChurchSpec)
	if building.spec is CastleSpec:
		return CastleBuilder.new().build(building.spec as CastleSpec)
	if building.spec is HouseSpec:
		return HouseBuilder.new().build(building.plan)
	if building.spec is TempleSpec:
		return TempleBuilder.new().build(building.spec as TempleSpec)
	return null


## Placement facts shared by scene-based consumers. All families use local -Z
## as their public front: house doors, church entrances and castle gates are
## authored on that edge. `bounds` is measured from the emitted architecture,
## not merely copied from the requested envelope.
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
		"footprint": Rect2(
			Vector2(bounds.position.x, bounds.position.z),
			Vector2(bounds.size.x, bounds.size.z)
		),
		"front": Vector3(0.0, 0.0, -1.0),
	}


## Create a fresh scene instance. Houses and temples include their prop models;
## churches and castles receive the same material treatment as the Studio.
## When `with_collision` is true, only the generated architectural shell gets
## trimesh collision; furniture and dressing remain visual details.
static func instantiate(building: GeneratedBuilding, cutaway := false,
		with_collision := false) -> Node3D:
	if building == null or not building.is_ok():
		return null
	var root: Node3D
	if building.spec is HouseSpec:
		root = HouseAssembler.build(building.plan, cutaway)
	elif building.spec is TempleSpec:
		root = TempleAssembler.build(building.spec as TempleSpec, cutaway)
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
		&"temple":
			_validate_style(out, TempleSpec.FORMS, &"form")
			if not TempleSpec.CULTS.has(request.purpose):
				_add_error(out, &"unknown_cult", &"purpose",
					"Unknown temple cult '%s'." % String(request.purpose))


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
