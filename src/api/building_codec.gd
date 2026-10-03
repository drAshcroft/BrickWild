class_name BuildingCodec
extends RefCounted
## Lossless, data-only state for schema 1. Never loads a script from input.
## Variant bytes are used only for engine VALUE types, with objects disabled.
## The public document also carries readable plan/spec projections.

var errors: Array[Dictionary] = []


static func fields(value: Object) -> Dictionary:
	var out := {}
	for p in value.get_property_list():
		var key := String(p["name"])
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and not key.begins_with("_"):
			var item: Variant = value.get(key)
			if item is RandomNumberGenerator or item is Callable or item is Signal:
				continue
			out[key] = item
	return out


static func encode(value: Variant) -> Variant:
	if value == null or value is bool or value is String:
		return value
	if value is Dictionary:
		var pairs: Array = []
		for key in value:
			if value[key] is RandomNumberGenerator:
				continue
			pairs.append([encode(key), encode(value[key])])
		return {"type": "Dictionary", "items": pairs}
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(encode(item))
		return {"type": "Array", "items": items}
	if value is Object:
		var script: Script = value.get_script()
		var cls := String(script.get_global_name()) if script != null else ""
		if cls not in CLASSES:
			return null # RNGs, nodes, resources and other runtime machinery never travel.
		return {"type": cls, "fields": encode(fields(value))}
	# bytes_to_var(..., false) cannot construct objects or execute code.
	return {"type": "Value", "data": Marshalls.raw_to_base64(var_to_bytes(value))}


const CLASSES := ["BuildingRequest", "HouseSpec", "ShopSpec", "HotelSpec",
	"ChurchSpec", "CastleSpec", "TempleSpec", "WindmillSpec", "TimberHallSpec",
	"VillageSpec", "InsulaSpec", "HousePlan", "VillagePlan"]


func decode(value: Variant, depth := 0) -> Variant:
	if depth > 64:
		return _bad("State nesting exceeds 64 levels.")
	if value == null or value is bool or value is String:
		return value
	if not value is Dictionary:
		return _bad("Expected a tagged value.")
	var tag: String = str(value.get("type", ""))
	if tag == "Value":
		if not value.get("data") is String:
			return _bad("Value data must be base64 text.")
		var data: PackedByteArray = Marshalls.base64_to_raw(value["data"])
		var decoded: Variant = bytes_to_var(data)
		if decoded == null or decoded is Object or decoded is Array or decoded is Dictionary:
			return _bad("Invalid engine value encoding.")
		return decoded
	if tag in ["Array", "Dictionary"]:
		if not value.get("items") is Array:
			return _bad("Container items must be an array.")
		if tag == "Array":
			var items: Array = []
			for item in value["items"]:
				items.append(decode(item, depth + 1))
			return items
		var out := {}
		for pair in value["items"]:
			if not pair is Array or pair.size() != 2:
				return _bad("Dictionary entries must be key/value pairs.")
			out[decode(pair[0], depth + 1)] = decode(pair[1], depth + 1)
		return out
	var object: RefCounted
	match tag:
		"BuildingRequest": object = BuildingRequest.new()
		"HouseSpec": object = HouseSpec.new(0)
		"ShopSpec": object = ShopSpec.new(0)
		"HotelSpec": object = HotelSpec.new(0)
		"ChurchSpec": object = ChurchSpec.new(0)
		"CastleSpec": object = CastleSpec.new(0)
		"TempleSpec": object = TempleSpec.new(0)
		"WindmillSpec": object = WindmillSpec.new(0)
		"TimberHallSpec": object = TimberHallSpec.new()
		"InsulaSpec": object = InsulaSpec.new(0)
		"VillageSpec": object = VillageSpec.new(0)
		"HousePlan": object = HousePlan.new()
		"VillagePlan": object = VillagePlan.new()
		_: return _bad("Unknown state type: %s." % tag)
	var props: Variant = decode(value.get("fields"), depth + 1)
	if not props is Dictionary:
		return _bad("Object fields must be a dictionary.")
	var allowed := fields(object)
	var declarations := {}
	for declaration in object.get_property_list():
		declarations[String(declaration["name"])] = declaration
	for key in props:
		if not allowed.has(key):
			continue # additive schema evolution; never writes native properties.
		var existing: Variant = object.get(key)
		var incoming: Variant = props[key]
		var declaration: Dictionary = declarations[key]
		var expected := int(declaration["type"])
		if expected != TYPE_NIL and incoming != null and typeof(incoming) != expected:
			return _bad("Wrong declared type for %s.%s." % [tag, key])
		if expected == TYPE_OBJECT and incoming != null:
			var wanted := String(declaration.get("class_name", ""))
			var incoming_script: Script = incoming.get_script()
			while incoming_script != null and incoming_script.get_global_name() != wanted:
				incoming_script = incoming_script.get_base_script()
			if wanted != "" and incoming_script == null:
				return _bad("Wrong object type for %s.%s." % [tag, key])
		if existing is Array and incoming is Array:
			# Preserve Array[Dictionary], Array[StringName], etc. on the object.
			var typed: Array = existing.duplicate()
			typed.clear()
			for item in incoming:
				if typed.is_typed() and typeof(item) != typed.get_typed_builtin():
					return _bad("Wrong array item type for %s.%s." % [tag, key])
				typed.append(item)
			object.set(key, typed)
		elif existing != null and typeof(existing) != typeof(incoming):
			return _bad("Wrong value type for %s.%s." % [tag, key])
		else:
			object.set(key, incoming)
	return object


func _bad(message: String) -> Variant:
	errors.append({"code": "invalid_document", "field": "state", "message": message})
	return null
