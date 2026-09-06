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

## The request this was generated from -- a detached copy, so a caller that
## edits its own request afterwards does not change what was built.
var request: BuildingRequest
## The family's own spec. Always present on a document that is ok.
var spec: RefCounted
## The plan families' own plan (house, shop, hotel); null for the rest.
var plan: HousePlan
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
		"api_version": API_VERSION,
		"kind": String(kind()),
		"seed": request.seed if request != null else 0,
		"name": name(),
		"ok": is_ok(),
	}
	if request != null:
		out["request"] = {
			"kind": String(request.kind), "seed": request.seed,
			"style": String(request.style), "purpose": String(request.purpose),
			"width": request.width, "length": request.length,
			"height": request.height, "storeys": request.storeys,
		}
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
	var rooms: Array = []
	for room in from.rooms:
		rooms.append({"kind": str(room["kind"]), "rect": _rect(room["rect"]),
			"storey": int(room.get("storey", 0))})
	var doors: Array = []
	for d in from.doors:
		doors.append({"a": int(d["a"]), "b": int(d["b"]), "pos": _vec2(d["pos"]),
			"normal": _vec2(d["normal"]), "width": float(d["width"]),
			"exterior": bool(d["exterior"]), "storey": int(d.get("storey", 0))})
	var windows: Array = []
	for w in from.windows:
		windows.append({"room": int(w["room"]), "pos": _vec2(w["pos"]),
			"normal": _vec2(w["normal"]), "width": float(w["width"]),
			"sill": float(w["sill"]), "head": float(w["head"]),
			"storey": int(w.get("storey", 0)), "hatch": bool(w.get("hatch", false))})
	var furniture: Array = []
	for f in from.furniture:
		furniture.append({"key": str(f["key"]), "room": int(f["room"]),
			"pos": _vec3(f["pos"]), "yaw": float(f["yaw"]),
			"rect": _rect(f["rect"]), "cat": str(f.get("cat", "")),
			"storey": int(f.get("storey", 0))})
	var stairs: Array = []
	for s in from.stairs:
		stairs.append({"a": int(s["a"]), "b": int(s["b"]),
			"storey": int(s["storey"]), "to_storey": int(s["to_storey"]),
			"lower_rect": _rect(s["lower_rect"]), "upper_rect": _rect(s["upper_rect"]),
			"width": float(s["width"]), "run": float(s["run"])})
	return {
		"rooms": rooms, "doors": doors, "windows": windows,
		"furniture": furniture, "stairs": stairs,
		"hearth": from.hearth.duplicate() if not from.hearth.is_empty() else {},
		"focus": _plain(from.focus),
		"compromises": _plain(from.compromises),
	}


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
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
	# Anything else a family might one day put on its spec -- a Transform3D, a
	# Quaternion -- comes out as its own text rather than as something JSON
	# would refuse. Better a readable string than a serialiser that throws.
	return str(value)


static func _vec2(v: Vector2) -> Array:
	return [v.x, v.y]


static func _vec3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _rect(r: Rect2) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]


static func _aabb(b: AABB) -> Array:
	return [b.position.x, b.position.y, b.position.z, b.size.x, b.size.y, b.size.z]
