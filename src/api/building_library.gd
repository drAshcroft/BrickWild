class_name BuildingLibrary
extends RefCounted
## What the public API knows about each family, in one table (API-002).
##
## Every kind's label, its size envelope, its default request, the styles and
## purposes it offers and the words for them all live here, and both halves of
## the boundary read the SAME rows:
##
##   * `BigGlade.describe_kind()` publishes them, so a caller can discover
##     what to ask for without importing a single family header.
##   * `validate()` rejects a request against them BEFORE any family
##     generator runs, so an unknown trade is one error dictionary rather than
##     an index-out-of-bounds three files down.
##
## That is the whole point of centralising them. The old arrangement had the
## descriptor table publishing one set of options and `_validate` reading the
## family tables for another; the Studio then read the family tables a third
## time to fill its dropdowns, and a house style added to `HouseSpec.STYLES`
## appeared in two of the three. Now there is one row per kind and everything
## is derived from it.
##
## The family tables themselves stay where they are -- `HouseSpec.STYLES` is
## the house's business -- and this file only names which table is a kind's
## styles and which is its purposes.

const API_VERSION := 1

## Every kind, in the order a menu should show them.
const KINDS: Array[StringName] = [&"church", &"castle", &"house", &"shop",
	&"hotel", &"temple", &"world", &"village"]

## One row per kind:
##   label        what the kind is called
##   size_label   the noun the width/length sliders are labelled with
##   height_label what its height means, in its own words
##   width/length/height/storeys   {min, max, step, value} -- the envelope AND
##                the default, so `defaults()` and the range check cannot
##                disagree. The generic world maximum also expands to cover
##                every family's registered maximum; family validation then
##                applies the narrower limit for the selected family.
##   style_label / purpose_label   what the two option lists are CALLED in
##                this family: a temple has a form and a cult, a shop has a
##                shell style and a business. An empty purpose_label means
##                the family takes no purpose, and a request carrying one is
##                rejected.
const KIND_ROWS := {
	&"church": {
		"label": "Church", "size_label": "Nave", "height_label": "Eaves height (m)",
		"style_label": "Style", "purpose_label": "",
		"width": {"min": 6.0, "max": 24.0, "step": 0.5, "value": 10.0},
		"length": {"min": 10.0, "max": 60.0, "step": 1.0, "value": 22.0},
		"height": {"min": 6.0, "max": 30.0, "step": 0.5, "value": 12.0},
	},
	&"castle": {
		"label": "Castle", "size_label": "Site", "height_label": "Wall height (m)",
		"style_label": "Style", "purpose_label": "",
		"width": {"min": 6.0, "max": 320.0, "step": 1.0, "value": 55.0},
		"length": {"min": 8.0, "max": 400.0, "step": 1.0, "value": 50.0},
		"height": {"min": 3.0, "max": 40.0, "step": 0.5, "value": 18.0},
	},
	&"temple": {
		"label": "Temple", "size_label": "Temple", "height_label": "Hall height (m)",
		"style_label": "Form", "purpose_label": "Cult",
		"width": {"min": 14.0, "max": 60.0, "step": 1.0, "value": 26.0},
		"length": {"min": 22.0, "max": 100.0, "step": 1.0, "value": 44.0},
		"height": {"min": 6.0, "max": 26.0, "step": 0.5, "value": 12.0},
	},
	&"house": {
		"label": "House", "size_label": "House", "height_label": "Ceiling (m)",
		"style_label": "Style", "purpose_label": "Trade",
		"width": {"min": 5.0, "max": 20.0, "step": 0.5, "value": 9.0},
		"length": {"min": 6.0, "max": 26.0, "step": 0.5, "value": 12.0},
		"height": {"min": 2.2, "max": 3.6, "step": 0.1, "value": 2.6},
		"storeys": {"min": 1, "max": 3, "step": 1, "value": 1},
	},
	&"shop": {
		"label": "Shop / Civic Building", "size_label": "Building",
		"height_label": "Ceiling (m)",
		"style_label": "Style", "purpose_label": "Business",
		"width": {"min": 7.0, "max": 24.0, "step": 0.5, "value": 11.0},
		"length": {"min": 8.0, "max": 32.0, "step": 0.5, "value": 14.0},
		"height": {"min": 2.4, "max": 4.2, "step": 0.1, "value": 2.8},
		"storeys": {"min": 1, "max": 3, "step": 1, "value": 1},
	},
	&"hotel": {
		"label": "Grand Hotel", "size_label": "Hotel", "height_label": "Floor height (m)",
		"style_label": "Style", "purpose_label": "",
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
		"style_label": "Family", "purpose_label": "Kind",
		"width": {"min": 4.0, "max": 120.0, "step": 0.5, "value": 20.0},
		"length": {"min": 4.0, "max": 120.0, "step": 0.5, "value": 30.0},
		"height": {"min": 2.2, "max": 40.0, "step": 0.1, "value": 6.0},
	},
	# A village is not measured in metres (VIL-019). Its two numbers are the
	# population and the wealth, and they ride on `width` and `length`
	# because those are the request's own number fields -- `width_label` and
	# `length_label` say so, so a caller filling a form from the descriptor
	# asks for the right thing. `height` is unused and pinned to 1.
	&"village": {
		"label": "Village", "size_label": "Village",
		"height_label": "", "style_label": "Culture", "purpose_label": "Purpose",
		"width": {"min": 12, "max": 500, "step": 1, "value": 40},
		"length": {"min": 0, "max": 100, "step": 5, "value": 35},
		"height": {"min": 1, "max": 1, "step": 1, "value": 1},
		"width_label": "Population", "length_label": "Wealth (%)",
	},
}

## The dimensions every kind has. `storeys` is separate: it is an integer, and
## only the plan-based families carry one.
const DIMENSIONS: Array[StringName] = [&"width", &"length", &"height"]


## What a kind calls one of its dimension fields, for an error a person will
## read. Everything is metres except the village, whose `width` is a
## population and whose `length` is a percentage -- and telling somebody that
## a population must be between 12 and 500 METRES is telling them nothing.
static func _field_word(kind: StringName, field: StringName) -> String:
	var row: Dictionary = KIND_ROWS.get(kind, {})
	var named: String = String(row.get("%s_label" % String(field), ""))
	return named if not named.is_empty() else "%s in metres" % String(field)


static func kinds() -> Array[StringName]:
	return KINDS.duplicate()


static func has_kind(kind: StringName) -> bool:
	return KIND_ROWS.has(kind)


## What a kind's `style` may be: id -> {"label": String}. The family's own
## table, named here rather than copied, so a style added to HouseSpec.STYLES
## is offered and accepted the moment it is added.
static func styles(kind: StringName) -> Dictionary:
	match kind:
		&"church":
			return ChurchSpec.STYLES
		&"castle":
			return CastleSpec.STYLES
		&"house", &"shop":
			return HouseSpec.STYLES
		&"hotel":
			return HotelSpec.HOTEL_STYLES
		&"temple":
			return TempleSpec.FORMS
		&"village":
			return _named(VillageSpec.CULTURES)
	return {}


## What a kind's `purpose` may be. Empty for a family that takes none.
static func purposes(kind: StringName) -> Dictionary:
	match kind:
		&"house":
			return HouseSpec.TRADES
		&"shop":
			return ShopSpec.BUSINESSES
		&"temple":
			return TempleSpec.CULTS
		&"village":
			return _named(VillageSpec.PURPOSES)
	return {}


## A plain list of ids as an option table. The village's cultures and
## purposes are lists rather than tables of labelled rows, so they are given
## their labels here rather than the spec growing a table it has no other
## use for.
static func _named(ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		out[id] = {"label": String(id).capitalize()}
	return out


## The option-discovery contract, and the only shape a caller has to know:
## an ordered array of {"id": StringName, "label": String}. `field` is
## &"style" or &"purpose".
##
## `world` is the one kind whose options are not a constant table -- its
## families are a registry that grows -- so it answers from WorldFamilies
## rather than from `styles()`/`purposes()`.
static func options(kind: StringName, field: StringName) -> Array[Dictionary]:
	if kind == &"village" and field in [&"water", &"enclosure"]:
		return _rows(_named(VillageSpec.WATERS if field == &"water" else VillageSpec.ENCLOSURES))
	if kind == &"world":
		return _world_options(field)
	return _rows(styles(kind) if field == &"style" else purposes(kind))


## The word for one option, for a caller that has an id and wants to print
## it. Empty when the kind or the id is unknown, so a caller printing a
## label never has to guard a dictionary lookup that would crash.
static func option_label(kind: StringName, field: StringName, id: StringName) -> String:
	for row in options(kind, field):
		if row["id"] == id:
			return String(row["label"])
	return ""


## What the two option lists are called in this family: "Form" and "Cult" for
## a temple, "Style" and "Business" for a shop. An empty purpose label means
## the family takes no purpose at all.
static func field_label(kind: StringName, field: StringName) -> String:
	if not KIND_ROWS.has(kind):
		return ""
	return String(KIND_ROWS[kind]["%s_label" % String(field)])


## A valid request for a kind, filled from the envelope's own default values.
## One place decides what "a house, please" means, and it is the same place
## the range check reads, so a default can never be out of its own range.
static func defaults(kind: StringName, p_seed: int = 0) -> BuildingRequest:
	if not KIND_ROWS.has(kind):
		return null
	var row: Dictionary = KIND_ROWS[kind]
	var out := BuildingRequest.new()
	out.kind = kind
	out.seed = p_seed
	out.width = float(row["width"]["value"])
	out.length = float(row["length"]["value"])
	out.height = float(row["height"]["value"])
	out.storeys = int(row["storeys"]["value"]) if row.has("storeys") else 1
	var style_options: Array[Dictionary] = options(kind, &"style")
	out.style = style_options[0]["id"] if not style_options.is_empty() else &""
	var purpose_options: Array[Dictionary] = options(kind, &"purpose")
	out.purpose = purpose_options[0]["id"] if not purpose_options.is_empty() else &""
	return out


## The public description of one kind: its envelope, its labels and its
## options, detached from the library's tables so a consumer cannot mutate
## global state by editing what it was handed.
static func describe(kind: StringName) -> Dictionary:
	if not KIND_ROWS.has(kind):
		return {}
	var out: Dictionary = KIND_ROWS[kind].duplicate(true)
	if kind == &"world":
		for field in DIMENSIONS:
			out[field]["max"] = _dimension_max(kind, field,
				float(out[field]["max"]))
	out["kind"] = kind
	out["api_version"] = API_VERSION
	out["styles"] = options(kind, &"style")
	out["purposes"] = options(kind, &"purpose")
	if kind == &"village":
		out["waters"] = options(kind, &"water")
		out["enclosures"] = options(kind, &"enclosure")
		out["water_label"] = "Water"
		out["enclosure_label"] = "Edge"
	if kind == &"world":
		# a world family narrows the kind's envelope with its own, so the
		# families are published with theirs attached
		out["families"] = out["styles"]
	return out


# ------------------------------------------------------------------ checking

## Every reason this request cannot be built, as {"code", "field", "message"}
## dictionaries -- empty when it can. Nothing here calls a generator: a
## request is refused on its own terms, before any family sees it.
static func validate(request: BuildingRequest) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if request == null:
		out.append(_error(&"request_required", &"request", "A building request is required."))
		return out
	var known: bool = KIND_ROWS.has(request.kind)
	if not known:
		out.append(_error(&"unknown_kind", &"kind",
			"Unknown building kind '%s'." % String(request.kind)))
	for field in DIMENSIONS:
		var value: float = request.get(field)
		var zero_allowed: bool = request.kind == &"village" and field == &"length"
		if not is_finite(value) or value < 0.0 or (value == 0.0 and not zero_allowed):
			out.append(_error(&"invalid_dimension", field,
				"%s must be a positive finite number." % String(field)))
		elif known:
			var limits: Dictionary = KIND_ROWS[request.kind][field]
			var maximum := _dimension_max(request.kind, field, float(limits["max"]))
			if _outside_envelope(value, float(limits["min"]), maximum):
				out.append(_error(&"dimension_out_of_range", field,
					"%s must be between %s and %s for a %s." % [
						_field_word(request.kind, field), limits["min"], maximum,
						String(request.kind)]))
	if not known:
		return out
	var row: Dictionary = KIND_ROWS[request.kind]
	if row.has("storeys"):
		var limits2: Dictionary = row["storeys"]
		if request.storeys < int(limits2["min"]) or request.storeys > int(limits2["max"]):
			out.append(_error(&"storeys_out_of_range", &"storeys",
				"storeys must be between %d and %d for a %s." % [
					int(limits2["min"]), int(limits2["max"]), String(request.kind)]))
	_validate_options(request, out)
	if request.material not in [&"stone", &"timber"]:
		out.append(_error(&"invalid_material", &"material", "Shell material must be stone or timber."))
	if request.kind == &"village":
		for field in [&"water", &"enclosure"]:
			if not _has_option(&"village", field, request.get(field)):
				out.append(_error(&"unknown_option", field, "Unknown village %s '%s'." % [field, request.get(field)]))
		if request.width != floorf(request.width):
			out.append(_error(&"invalid_population", &"width", "Population must be a whole number."))
		if request.enclosure == &"wall" and request.width < VillageSpec.WALL_MIN_POPULATION and request.purpose != &"garrison":
			out.append(_error(&"invalid_enclosure", &"enclosure", "A wall needs at least %d people or a garrison purpose." % VillageSpec.WALL_MIN_POPULATION))
	if request.kind == &"world" and out.is_empty():
		# a world family narrows the kind's envelope with its own, and owns
		# which sub-kinds it comes in
		out.append_array(validate_world_envelope(request))
	return out


## The style and the purpose, against the same option lists `describe()`
## publishes -- so anything offered can be built and anything built was
## offered.
##
## The error CODES are the family's own words, not "unknown_option": callers
## switch on them, and `unknown_trade` said more than a generic code would.
static func _validate_options(request: BuildingRequest, out: Array[Dictionary]) -> void:
	var kind: StringName = request.kind
	if not _has_option(kind, &"style", request.style):
		out.append(_error(_style_code(kind), &"style" if kind != &"temple" else &"form",
			"Unknown %s '%s' for %s." % [field_label(kind, &"style").to_lower(),
				String(request.style), String(kind)]))
	# A world sub-kind belongs to ONE family, so "is it a sub-kind of any
	# family" is the wrong question; `validate_world_envelope` asks the right
	# one against the family this request actually named.
	if kind == &"world":
		return
	var purpose_word: String = field_label(kind, &"purpose")
	if purpose_word.is_empty():
		if request.purpose != &"":
			out.append(_error(&"unsupported_purpose", &"purpose",
				"%s requests do not use a purpose." % String(kind).capitalize()))
		return
	if not _has_option(kind, &"purpose", request.purpose):
		out.append(_error(_purpose_code(kind), &"purpose",
			"Unknown %s '%s'." % [purpose_word.to_lower(), String(request.purpose)]))


static func _has_option(kind: StringName, field: StringName, id: StringName) -> bool:
	for row in options(kind, field):
		if row["id"] == id:
			return true
	return false


## The historical error codes, kept because callers and the suite switch on
## them. Everything not listed reports in the same shape.
static func _style_code(kind: StringName) -> StringName:
	match kind:
		&"temple":
			return &"unknown_form"
		&"world":
			return &"unknown_family"
	return &"unknown_style"


static func _purpose_code(kind: StringName) -> StringName:
	match kind:
		&"house":
			return &"unknown_trade"
		&"shop":
			return &"unknown_business"
		&"temple":
			return &"unknown_cult"
	return &"unknown_kind"


# ----------------------------------------------------------------- internals

## A style/purpose table as the public option shape. Insertion order is the
## family's own, which is the order it means them in.
static func _rows(table: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in table:
		out.append({"id": id, "label": String(table[id]["label"])})
	return out


## The world kind's families and sub-kinds, from the registry. A family
## carries its own envelope and the sub-kinds it comes in, because a caller
## choosing a family needs both before it can make a request.
static func _world_options(field: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if field == &"style":
		for f in WorldFamilies.families():
			out.append({"id": f, "label": String(WorldFamilies.FAMILIES[f]["label"]),
				"envelope": WorldFamilies.envelope(f), "kinds": WorldFamilies.kinds_of(f)})
		return out
	for f2 in WorldFamilies.families():
		for k in WorldFamilies.kinds_of(f2):
			out.append({"id": k, "label": String(k).capitalize(), "family": f2})
	return out


## A world building is additionally held to its own family's envelope, which
## is narrower than the kind's. Separate from validate() because it needs the
## family to have been recognised first.
static func validate_world_envelope(request: BuildingRequest) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if request == null or request.kind != &"world" or not WorldFamilies.has_family(request.style):
		return out
	if not request.purpose in WorldFamilies.kinds_of(request.style):
		out.append(_error(&"unknown_kind", &"purpose",
			"Unknown %s kind '%s'." % [String(request.style), String(request.purpose)]))
		return out
	var env: Dictionary = WorldFamilies.envelope(request.style)
	for field in DIMENSIONS:
		var value: float = request.get(field)
		var lim: Dictionary = env[field]
		if _outside_envelope(value, float(lim["min"]), float(lim["max"])):
			out.append(_error(&"dimension_out_of_range", field,
				"%s must be between %s and %s metres for a %s." % [
					String(field), lim["min"], lim["max"], String(request.style)]))
	return out


## Treat representational drift at a published endpoint as that endpoint.
## `is_equal_approx` is tight enough to absorb binary float noise while still
## rejecting meaningful increments such as a centimetre past the limit.
static func _outside_envelope(value: float, minimum: float, maximum: float) -> bool:
	if not is_finite(value):
		return true
	return (value < minimum and not is_equal_approx(value, minimum)) \
		or (value > maximum and not is_equal_approx(value, maximum))


## The generic world envelope must include every registered family. The
## selected family's envelope remains the stricter request-level check.
static func _dimension_max(kind: StringName, field: StringName,
		base_max: float) -> float:
	if kind != &"world":
		return base_max
	var maximum := base_max
	for family in WorldFamilies.families():
		var env: Dictionary = WorldFamilies.envelope(family)
		if env.has(field):
			maximum = maxf(maximum, float(env[field]["max"]))
	return maximum


static func _error(code: StringName, field: StringName, message: String) -> Dictionary:
	return {"code": code, "field": field, "message": message}
