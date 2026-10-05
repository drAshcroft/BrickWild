class_name BuildingRequest
extends RefCounted
## Public inputs for one deterministic BrickWild building.
##
## Prefer the family-named factories below. They keep `style` and `purpose`
## transport-friendly while preserving the vocabulary callers actually use:
## a temple has a form and cult; a house has a style and trade; a shop has a
## shell style and business.

var kind: StringName
var seed: int
var width: float
var length: float
var height: float
var style: StringName
var purpose: StringName = &""
## Number of plan-based storeys (houses and shops). Kept on the request rather
## than inferred from height, so callers can change levels without ceiling scale.
var storeys: int = 1
var material: StringName = &"timber"
## Yaw in radians describing local -Z relative to world north. Zero faces south.
var orientation: float = 0.0
## Period metadata carried to family specs for downstream consumers.
var period: int = 1200
## Village-only landscape controls; vocabulary comes from describe_kind().
var water: StringName = &"none"
var enclosure: StringName = &"none"
## Opt-in compact presentation for villages. It preserves metre-scale
## buildings and is valid only with no water or enclosure.
var compact_display: bool = false
## Village-only exterior ornament intensity, from bare/basic to lush/storybook.
var decoration_level: float = 0.5
## Village-only condition of buildings, from worn/slum to clean.
var upkeep: float = 1.0
var _decode_errors: Array[Dictionary] = []

const SCHEMA := "brickwild.request"
const SCHEMA_VERSION := 1


func to_dict() -> Dictionary:
	var out := {"schema": SCHEMA, "schema_version": SCHEMA_VERSION,
		"kind": String(kind), "seed": str(seed), "style": String(style),
		"purpose": String(purpose), "width": width, "length": length,
		"height": height, "storeys": storeys, "material": String(material),
		"water": String(water), "enclosure": String(enclosure),
		"orientation": orientation, "period": period}
	# Omit the opt-in when false so old requests keep their original JSON shape.
	# from_dict treats a missing field as the false default.
	if compact_display:
		out["compact_display"] = true
	if decoration_level != 0.5:
		out["decoration_level"] = decoration_level
	if upkeep != 1.0:
		out["upkeep"] = upkeep
	return out


func to_json() -> String:
	return JSON.stringify(to_dict(), "\t", true, true) + "\n"


static func from_json(text: String) -> BuildingRequest:
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		var bad := BuildingRequest.new()
		bad._decode_errors.append({"code": "invalid_json", "field": "request",
			"message": "Expected a JSON object containing a building request."})
		return bad
	return from_dict(parser.data)


static func from_dict(data: Dictionary) -> BuildingRequest:
	var out := BuildingRequest.new()
	if data.get("schema", SCHEMA) != SCHEMA or data.get("schema_version", 1) != SCHEMA_VERSION:
		out._decode_errors.append({"code": "unsupported_schema", "field": "schema_version",
			"message": "Only brickwild.request schema 1 is supported."})
	var kinds: Variant = data.get("kind", "")
	if kinds is String and StringName(kinds) in BuildingLibrary.kinds():
		out = BuildingLibrary.defaults(StringName(kinds), 0) if out._decode_errors.is_empty() else out
	for field in ["kind", "style", "purpose", "material", "water", "enclosure"]:
		if not data.has(field):
			continue
		if not data[field] is String and not data[field] is StringName:
			out._decode_errors.append(_field_error(field, "must be text"))
		else:
			out.set(field, StringName(data[field]))
	for field in ["width", "length", "height", "storeys", "orientation", "period"]:
		if not data.has(field):
			continue
		var v: Variant = data[field]
		if not (v is int or v is float) or not is_finite(float(v)):
			out._decode_errors.append(_field_error(field, "must be a finite number"))
		elif field in ["storeys", "period"] and float(v) != floorf(float(v)):
			out._decode_errors.append(_field_error(field, "must be an integer"))
		else:
			out.set(field, int(v) if field in ["storeys", "period"] else float(v))
	if data.has("compact_display"):
		if data["compact_display"] is bool:
			out.compact_display = data["compact_display"]
		else:
			out._decode_errors.append(_field_error("compact_display", "must be a boolean"))
	for field in ["decoration_level", "upkeep"]:
		if not data.has(field):
			continue
		var value: Variant = data[field]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			out._decode_errors.append(_field_error(field, "must be a finite number"))
		else:
			out.set(field, float(value))
	var seed_value: Variant = data.get("seed", "0")
	if seed_value is String and seed_value.is_valid_int() and str(int(seed_value)) == seed_value:
		out.seed = int(seed_value)
	elif seed_value is int:
		out.seed = seed_value
	elif seed_value is float and is_finite(seed_value) and absf(seed_value) <= 9007199254740991.0 and seed_value == floorf(seed_value):
		out.seed = int(seed_value)
	else:
		out._decode_errors.append(_field_error("seed", "must be a signed 64-bit decimal string or an exact JSON integer"))
	return out


static func _field_error(field: String, reason: String) -> Dictionary:
	return {"code": "invalid_type", "field": field, "message": "%s %s." % [field, reason]}


static func church(p_seed: int, p_style: StringName = &"romanesque",
		p_width := 10.0, p_length := 20.0, p_height := 12.0) -> BuildingRequest:
	return _make(&"church", p_seed, p_style, &"", p_width, p_length, p_height)


static func castle(p_seed: int, p_style: StringName = &"norman",
		p_width := 40.0, p_length := 50.0, p_height := 10.0) -> BuildingRequest:
	return _make(&"castle", p_seed, p_style, &"", p_width, p_length, p_height)


static func house(p_seed: int, p_style: StringName = &"cottage",
		p_trade: StringName = &"none", p_width := 8.0, p_length := 10.0,
		p_height := 2.6, p_storeys: int = 1) -> BuildingRequest:
	return _make(&"house", p_seed, p_style, p_trade, p_width, p_length, p_height,
		p_storeys)


static func shop(p_seed: int, p_business: StringName = &"general_store",
		p_style: StringName = &"townhouse", p_width := 11.0, p_length := 14.0,
		p_height := 2.8, p_storeys: int = 1) -> BuildingRequest:
	return _make(&"shop", p_seed, p_style, p_business, p_width, p_length, p_height,
		p_storeys)


static func hotel(p_seed: int, p_style: StringName = &"grand_budapest",
		p_width := 48.0, p_length := 24.0, p_height := 3.6) -> BuildingRequest:
	return _make(&"hotel", p_seed, p_style, &"", p_width, p_length, p_height, 3)


static func temple(p_seed: int, p_form: StringName = &"basilica",
		p_cult: StringName = &"blood", p_width := 26.0, p_length := 44.0,
		p_height := 12.0) -> BuildingRequest:
	return _make(&"temple", p_seed, p_form, p_cult, p_width, p_length, p_height)


## A windmill. `p_sail_span` is the rotor's diameter, `p_body` the width of
## the mill's own body, and `p_height` how tall it stands -- for a post mill
## that is its burr, for a tower mill its tower, for a windpump its lattice.
static func windmill(p_seed: int, p_type: StringName = &"tower",
		p_sail_span := 12.0, p_body := 6.0, p_height := 12.0) -> BuildingRequest:
	return _make(&"windmill", p_seed, p_type, &"", p_sail_span, p_body, p_height)


## A village uses width for population and length for wealth percent, as
## published by `describe_kind(&"village")`. Compact villages have no water or
## enclosure; they remain ordinary metre-scale village plans.
static func village(p_seed: int, p_population: int = 40,
		p_culture: StringName = &"english", p_purpose: StringName = &"farming",
		p_wealth: float = 0.4, p_compact_display: bool = false,
		p_decoration_level: float = 0.5, p_upkeep: float = 1.0) -> BuildingRequest:
	var out := _make(&"village", p_seed, p_culture, p_purpose,
		float(p_population), p_wealth * 100.0, 1.0)
	out.compact_display = p_compact_display
	out.decoration_level = p_decoration_level
	out.upkeep = p_upkeep
	return out


## The common presentation request for close rows in an external display.
static func compact_village(p_seed: int, p_population: int = 40,
		p_culture: StringName = &"english", p_purpose: StringName = &"market",
		p_wealth: float = 0.4, p_decoration_level: float = 0.5,
		p_upkeep: float = 1.0) -> BuildingRequest:
	return village(p_seed, p_population, p_culture, p_purpose, p_wealth, true,
		p_decoration_level, p_upkeep)


## A detached copy lets the library retain the request without retaining
## mutable caller-owned state.
func copy() -> BuildingRequest:
	var out := _make(kind, seed, style, purpose, width, length, height, storeys)
	out.material = material
	out.water = water
	out.enclosure = enclosure
	out.compact_display = compact_display
	out.decoration_level = decoration_level
	out.upkeep = upkeep
	out.orientation = orientation
	out.period = period
	out._decode_errors = _decode_errors.duplicate(true)
	return out


static func _make(p_kind: StringName, p_seed: int, p_style: StringName,
		p_purpose: StringName, p_width: float, p_length: float,
		p_height: float, p_storeys: int = 1) -> BuildingRequest:
	var out := BuildingRequest.new()
	out.kind = p_kind
	out.seed = p_seed
	out.style = p_style
	out.purpose = p_purpose
	out.width = p_width
	out.length = p_length
	out.height = p_height
	out.storeys = p_storeys
	return out
