class_name BuildingRequest
extends RefCounted
## Public inputs for one deterministic BigGlade building.
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


## A detached copy lets the library retain the request without retaining
## mutable caller-owned state.
func copy() -> BuildingRequest:
	return _make(kind, seed, style, purpose, width, length, height, storeys)


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
