class_name BuildingDocument
extends RefCounted
## What a building IS, before anything draws it (API-003).
##
## `BigGlade.generate()` already stops short of a mesh, but what it hands back
## is the family's own live object: a `HousePlan` full of `Rect2`s, or a
## `CastleSpec` whose fields only mean something to the castle. That is the
## right representation to BUILD from and the wrong one to hand across a
## boundary -- a consumer that wants to know how many rooms a shop has should
## not have to know what a `ShopSpec` is, and one in another process cannot
## hold either.
##
## A document is the stage in between, and it has two halves:
##
##   * `plan` / `spec` -- the FAMILY-NATIVE payload, untouched, so the mesh
##     built from a document is the mesh built from the generation that made
##     it, vertex for vertex. Nothing is re-derived and nothing is rounded.
##   * `to_dict()` -- the same building as plain Dictionaries, Arrays and
##     numbers, which is what serialises, diffs, travels between processes
##     and can be read without loading BigGlade at all.
##
## The pipeline is therefore three named stages rather than two:
##
##     request  --generate_document-->  document  --build_mesh-->  ArrayMesh
##                                          |
##                                       to_dict()  -->  JSON
##
## `placement` is measured here, once, and carried: it is the only field that
## needs a mesh to compute, so a caller holding a document never has to build
## one to find out where the door is.

const API_VERSION := BuildingLibrary.API_VERSION
const SCHEMA := "bigglade.building"
const SCHEMA_VERSION := 1

## The request this was generated from -- a detached copy, so a caller that
## edits its own request afterwards does not change what was built.
var request: BuildingRequest
## The family's own spec. Always present on a document that is ok.
var spec: RefCounted
## The plan families' own plan (house, shop, hotel); null for the rest.
var plan: HousePlan
## The village kind's own plan (VIL-019); null for the rest.
var village: VillagePlan
## `BigGlade.placement()` for this building: bounds, footprint, front, door.
var placement: Dictionary = {}
## Why this is not a building, when it is not. Same shape as
## `GeneratedBuilding.errors`: {"code", "field", "message"}.
var errors: Array[Dictionary] = []


func is_ok() -> bool:
	return errors.is_empty() and request != null and spec != null


func kind() -> StringName:
	return request.kind if request != null else &""


func name() -> String:
	return str(spec.get("variant_name")) if spec != null else ""


## The family-native payload: the plan for a plan family, the spec for the
## rest. This is what a builder is handed, and the reason a document can be
## built from without losing anything.
func payload() -> RefCounted:
	if village != null:
		return village
	return plan if plan != null else spec


# ------------------------------------------------------------- serialisation

## The whole document as plain data: no object references, no engine types
## except the numbers inside them, nothing that needs BigGlade to read.
##
## Vectors and rectangles come out as arrays of floats rather than as
## dictionaries with x/y keys, because that is half the bytes and every
## consumer of this shape is going to index them positionally anyway.
func to_dict() -> Dictionary:
	var out := {
		"schema": SCHEMA, "schema_version": SCHEMA_VERSION,
		"api_version": API_VERSION,
		"kind": String(kind()),
		"seed": str(request.seed) if request != null else "0",
		"name": name(),
		"ok": is_ok(),
	}
	if request != null:
		out["request"] = request.to_dict()
	if not errors.is_empty():
		out["errors"] = errors.duplicate(true)
	if not placement.is_empty():
		out["placement"] = {
			"bounds": _aabb(placement["bounds"]),
			"footprint": _rect(placement["footprint"]),
			"front": _vec3(placement["front"]),
			"door": _vec3(placement["door"]),
		}
	if spec != null:
		out["spec"] = _spec_dict(spec)
	if plan != null:
		out["plan"] = _plan_dict(plan)
	if village != null:
		out["village"] = _spec_dict(village)
	out["state"] = BuildingCodec.encode({"spec": spec, "plan": plan,
		"village": village, "placement": placement})
	return out


func to_json() -> String:
	return JSON.stringify(to_dict(), "\t", true, true) + "\n"


static func from_json(text: String) -> BuildingDocument:
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return _refused("invalid_json", "document", "Expected a building document JSON object (line %d: %s)." % [parser.get_error_line(), parser.get_error_message()])
	return from_dict(parser.data)


static func from_dict(data: Dictionary) -> BuildingDocument:
	if data.get("schema", "") != SCHEMA or data.get("schema_version", 0) != SCHEMA_VERSION:
		return _refused("unsupported_schema", "schema_version", "Only bigglade.building schema 1 is supported.")
	if not data.get("request") is Dictionary:
		return _refused("invalid_document", "request", "A document must carry its request.")
	var out := BuildingDocument.new()
	out.request = BuildingRequest.from_dict(data["request"])
	out.errors.append_array(out.request._decode_errors)
	out.errors.append_array(BuildingLibrary.validate(out.request))
	if not out.errors.is_empty():
		return out
	var codec := BuildingCodec.new()
	var state: Variant = codec.decode(data.get("state"))
	out.errors.append_array(codec.errors)
	if not state is Dictionary or not out.errors.is_empty():
		if out.errors.is_empty():
			out.errors.append({"code": "invalid_document", "field": "state", "message": "Missing document state."})
		return out
	if not state.get("spec") is RefCounted or not state.get("placement") is Dictionary:
		return _refused("invalid_document", "state", "The document has no spec or placement.")
	if state.get("plan") != null and not state["plan"] is HousePlan:
		return _refused("invalid_document", "plan", "Expected a HousePlan.")
	if state.get("village") != null and not state["village"] is VillagePlan:
		return _refused("invalid_document", "village", "Expected a VillagePlan.")
	out.spec = state["spec"]
	out.plan = state.get("plan")
	out.village = state.get("village")
	out.placement = state["placement"]
	if out.plan != null:
		if not out.spec is HouseSpec:
			return _refused("invalid_document", "spec", "A HousePlan requires a HouseSpec.")
		out.plan.spec = out.spec
	if out.village != null:
		if not out.spec is VillageSpec:
			return _refused("invalid_document", "spec", "A VillagePlan requires a VillageSpec.")
		out.village.spec = out.spec
	var spec_types := {&"church": "ChurchSpec", &"castle": "CastleSpec",
		&"house": "HouseSpec", &"shop": "ShopSpec", &"hotel": "HotelSpec",
		&"temple": "TempleSpec", &"village": "VillageSpec"}
	var actual_type := String(out.spec.get_script().get_global_name())
	if spec_types.has(out.request.kind) and actual_type != spec_types[out.request.kind]:
		return _refused("invalid_document", "spec", "Spec type does not match the request family.")
	if out.spec is HouseSpec and out.plan == null:
		return _refused("invalid_document", "plan", "Plan families require their generated HousePlan.")
	if out.spec is VillageSpec and out.village == null:
		return _refused("invalid_document", "village", "Village documents require their generated VillagePlan.")
	if out.request.kind == &"world" and not (out.spec is TimberHallSpec or
			(out.spec is HouseSpec and out.plan != null and out.plan.world_family in
				[&"courtyard_house", &"insula", &"mosque", &"caravanserai", &"hammam",
				&"cruciform_temple"]) or
			(out.spec is CastleSpec and out.request.style == &"tower_house"
				and CastleGeometry.is_tower_house(out.spec))):
		return _refused("invalid_document", "spec", "Unknown world-family state.")
	return out


static func _refused(code: String, field: String, message: String) -> BuildingDocument:
	var out := BuildingDocument.new()
	out.errors.append({"code": code, "field": field, "message": message})
	return out


## A spec as its own exported fields. Read from the object rather than
## enumerated by hand: a field added to a family's spec appears in its
## documents without this file changing, which is the only way this stays
## true of six families at once.
static func _spec_dict(from: RefCounted) -> Dictionary:
	var out := {}
	for prop in from.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var key: String = prop["name"]
		if key.begins_with("_"):
			continue
		var value: Variant = from.get(key)
		# the RNG a spec carries is machinery, not a fact about the building
		if value is RandomNumberGenerator or value is Object:
			continue
		out[key] = _plain(value)
	return out


## A house plan as plain data: the rooms, the openings, the stairs and what
## stands in them. Every list keeps its own order, because a plan's indices
## are its identity -- a door names rooms by number.
static func _plan_dict(from: HousePlan) -> Dictionary:
	return _spec_dict(from)


## Anything at all, as something JSON can hold.
static func _plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			return _vec2(value)
		TYPE_VECTOR3:
			return _vec3(value)
		TYPE_RECT2:
			return _rect(value)
		TYPE_AABB:
			return _aabb(value)
		TYPE_COLOR:
			return (value as Color).to_html()
		TYPE_STRING_NAME:
			return str(value)
		TYPE_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_BYTE_ARRAY:
			var list: Array = []
			for item in value:
				list.append(_plain(item))
			return list
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				out[str(key)] = _plain(value[key])
			return out
		TYPE_OBJECT:
			if value is BuildingRequest:
				return value.to_dict()
			if value is RefCounted and not value is RandomNumberGenerator:
				var script: Script = value.get_script()
				if script != null and String(script.get_global_name()) in BuildingCodec.CLASSES:
					return _plain(BuildingCodec.fields(value))
			return null
		TYPE_FLOAT:
			return value if is_finite(value) else str(value)
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return value
	# Engine values not used by the readable projection still have their exact
	# representation in `state`; this view uses their stable textual form.
	return str(value)


static func _vec2(v: Vector2) -> Array:
	return [_plain(v.x), _plain(v.y)]


static func _vec3(v: Vector3) -> Array:
	return [_plain(v.x), _plain(v.y), _plain(v.z)]


static func _rect(r: Rect2) -> Array:
	return _vec2(r.position) + _vec2(r.size)


static func _aabb(b: AABB) -> Array:
	return _vec3(b.position) + _vec3(b.size)
