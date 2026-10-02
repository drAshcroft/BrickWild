class_name VillageProgrammer
extends RefCounted
## Population -> programme, VILLAGES §4. Turns a `VillageSpec`'s population,
## purpose, culture, wealth and water into the `BuildingRequest`s a village
## earns: houses (one per household, trade and style by culture and wealth)
## plus the shops, church/temple and castle the population and purpose
## threshold table earns -- nothing more, nothing less.
##
## Deliberately independent of `VillageSpec.RECIPES` (which only sizes the
## spec's own approximate `site` rect, VILLAGES §1) so this file is the one
## place §4's actual building-earning rules live. It never draws a building
## of its own: every request is answered by `BrickWild.generate()`.

## Culture -> the style/form names that exist in each family's spec. VILLAGES
## §1's culture row: "which house, shop, church, castle and temple styles the
## buildings are asked for". Shops reuse `HouseSpec.STYLES` (ShopSpec extends
## HouseSpec), so "house" doubles as the shop shell style.
const CULTURE_STYLES := {
	&"english": {"house": &"cottage", "castle": &"norman", "church": &"gothic",
		"temple_form": &"basilica", "temple_cult": &"void"},
	&"frankish": {"house": &"farmhouse", "castle": &"french_chateau", "church": &"romanesque",
		"temple_form": &"basilica", "temple_cult": &"blood"},
	&"norse": {"house": &"longhall", "castle": &"edwardian", "church": &"nordic_stave",
		"temple_form": &"rotunda", "temple_cult": &"bone"},
	&"alpine": {"house": &"farmhouse", "castle": &"bavarian", "church": &"renaissance",
		"temple_form": &"rotunda", "temple_cult": &"flame"},
	&"moorish": {"house": &"townhouse", "castle": &"moorish", "church": &"byzantine",
		"temple_form": &"pylon", "temple_cult": &"serpent"},
	&"eastern": {"house": &"townhouse", "castle": &"japanese", "church": &"russian",
		"temple_form": &"pylon", "temple_cult": &"serpent"},
	&"blighted": {"house": &"witch_hut", "castle": &"crusader", "church": &"byzantine",
		"temple_form": &"ziggurat", "temple_cult": &"void"},
}

## House base styles that keep the cottage/farmhouse silhouette long enough
## for wealth to move some of them up to `townhouse` (VILLAGES §4's closing
## paragraph). Cultures whose base style is already something else
## (`longhall`, `witch_hut`, `townhouse`) keep it regardless of wealth.
const MIXABLE_HOUSE_STYLES: Array[StringName] = [&"cottage", &"farmhouse"]

## §4's shop-family rows, in table order: `min_pop` (inclusive), the
## programme `kind` (also used as the request seed key) and the
## `ShopSpec.BUSINESSES` key. `mining_any_size` lets the smithy ignore its
## threshold for a mining village ("a smithy at any size").
const SHOP_RULES := [
	{"kind": &"smithy", "min_pop": 30, "business": &"blacksmith", "mining_any_size": true},
	{"kind": &"tavern", "min_pop": 40, "business": &"tavern"},
	{"kind": &"general_store", "min_pop": 60, "business": &"general_store"},
	{"kind": &"inn", "min_pop": 80, "business": &"inn", "pilgrim_any_size": true},
	{"kind": &"stable", "min_pop": 80, "business": &"stable"},
	{"kind": &"carpenter", "min_pop": 80, "business": &"carpenter"},
	{"kind": &"butcher", "min_pop": 100, "business": &"butcher"},
	{"kind": &"tailor", "min_pop": 100, "business": &"tailor"},
	{"kind": &"town_hall", "min_pop": 100, "business": &"town_hall"},
	{"kind": &"apothecary", "min_pop": 120, "business": &"apothecary"},
	{"kind": &"tavern_2", "min_pop": 120, "business": &"tavern"},
	{"kind": &"guildhall", "min_pop": 150, "business": &"guildhall"},
]

## A waterside mill keeps the bakery's usable workrooms and storage. The lot
## planner adds its race and the dresser its wheel; the building is still a
## measured request, rather than an empty decorative mass.
const BAKERY_MIN_POP := 50
## §4: "a well per 60 people", "a shrine at 20", "a church + store at 60".
const SHRINE_MIN_POP := 20
const CHURCH_MIN_POP := 60
const MANOR_MIN_POP := 200


## Every `BuildingRequest` the population/purpose/culture/wealth/water earns:
## the households first (one per household), then the landmark (church,
## shrine or, for `pilgrim`, a temple that takes its place), then the shop
## rows, then the lord's house. Order is stable given the same spec.
static func programme(spec: VillageSpec) -> Array[BuildingRequest]:
	var out: Array[BuildingRequest] = []
	var styles: Dictionary = CULTURE_STYLES.get(spec.culture, CULTURE_STYLES[&"english"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("programme|%d" % spec.seed)

	var mix: Array[StringName] = _mixed_styles(spec, styles)
	for i in range(spec.households):
		out.append(_make_house(spec, styles, rng, i, mix[i] if not mix.is_empty() else &""))

	_append_landmark(out, spec, styles)
	_append_shops(out, spec, styles)
	if spec.site_brief:
		_append_site_brief(out, spec, styles)

	if spec.population >= MANOR_MIN_POP or spec.purpose == &"garrison":
		out.append(BuildingRequest.castle(
			_seed_for(spec, "manor"), styles["castle"], 40.0, 50.0, 10.0))

	_raise_landmark(out)
	return out


## The landmark is the tallest building in the village (VILLAGES §9.4; the
## place check measures it). A rich village builds two-storey houses 11 to
## 13 m high and a shrine asked for at 6 m measured 11.8, so it is asked for
## more height, a metre at a time, until it is measured clear of the highest
## roof any house or shop could have (EVAL-C11). The request carries the
## height, so the plan's building is exactly the one the programme named.
## A keep is its own landmark and is left alone, and a temple whose height
## does not answer the request is left as it is.
const LANDMARK_CLEAR := 0.3
const LANDMARK_LIFT_STEPS := 10

static func _raise_landmark(out: Array[BuildingRequest]) -> void:
	var landmark := -1
	var tallest := 0.0
	for i in range(out.size()):
		if out[i].kind in [&"church", &"temple"]:
			if landmark < 0:
				landmark = i
		elif out[i].kind in [&"house", &"shop"]:
			tallest = maxf(tallest, roof_top_bound(out[i]))
	if landmark < 0 or tallest <= 0.0:
		return
	var base_height: float = out[landmark].height
	for step in range(LANDMARK_LIFT_STEPS + 1):
		out[landmark].height = base_height + float(step)
		var placed: Dictionary = BrickWild.measure(out[landmark])
		if placed.is_empty():
			break
		if (placed["bounds"] as AABB).size.y > tallest + LANDMARK_CLEAR:
			return
	out[landmark].height = base_height


## The highest this house or shop can stand, from its request alone: the
## steepest pitch its style allows and every attachment that rises over the
## ridge, through the one function the builder's own bounds use. The
## generator draws a pitch inside the style's range and the draw is never
## above it, so this is never below the measured height.
static func roof_top_bound(request: BuildingRequest) -> float:
	var spec := HouseSpec.new()
	spec.style = request.style
	spec.width = request.width
	spec.length = request.length
	spec.height = request.height
	spec.storeys = clampi(request.storeys, 1, 3)
	var style: Dictionary = HouseSpec.STYLES.get(request.style, {})
	if style.is_empty():
		return 0.0
	spec.roof_pitch = float(style["roof_pitch"][1])
	spec.chimney = true
	spec.porch = true
	spec.bargeboards = true
	spec.roof_type = &"gable"
	return HouseGeometry.total_height(spec)


## Translate mythsim's kept words into real, placeable architecture. A kept
## fraction changes the requested footprint; it is not opaque metadata. The
## temple word alone creates a temple, so the C1 presence rule stays exact.
static func _append_site_brief(out: Array[BuildingRequest], spec: VillageSpec,
		styles: Dictionary) -> void:
	var built: Dictionary = spec.kept_buildings
	if float(built.get("granary", 0.0)) > 0.0:
		_append_shop(out, spec, "granary", &"general_store", styles["house"], float(built["granary"]))
	if float(built.get("forge-hall", 0.0)) > 0.0:
		_append_shop(out, spec, "forge-hall", &"blacksmith", styles["house"], float(built["forge-hall"]))
	if float(built.get("shrine", 0.0)) > 0.0:
		var fraction: float = float(built["shrine"])
		out.append(BuildingRequest.church(_seed_for(spec, "brief|shrine"), styles["church"],
			lerpf(6.0, 10.0, fraction), lerpf(10.0, 16.0, fraction), lerpf(6.0, 9.0, fraction)))
	if float(built.get("palace", 0.0)) > 0.0:
		_append_seat(out, spec, styles, &"royal", float(built["palace"]))
	if float(built.get("great-tomb", 0.0)) > 0.0:
		_append_castle(out, spec, styles, "great-tomb", float(built["great-tomb"]))
	if float(built.get("ziggurat", 0.0)) > 0.0:
		# Ziggurat is a stepped civic monument in this renderer. It uses a
		# castle mass; only the explicit `temple` key earns TempleSpec geometry.
		_append_castle(out, spec, styles, "ziggurat", float(built["ziggurat"]))
	_append_seat(out, spec, styles, spec.regime, 1.0)


static func _append_seat(out: Array[BuildingRequest], spec: VillageSpec,
		styles: Dictionary, requested_regime: StringName, fraction: float) -> void:
	match requested_regime:
		&"royal":
			if not _has_kind(out, &"castle"):
				_append_castle(out, spec, styles, "seat|royal", fraction)
		&"council":
			if not _has_shop_purpose(out, &"town_hall"):
				_append_shop(out, spec, "seat|council", &"town_hall", styles["house"], fraction)
		&"theocracy":
			if not _has_kind(out, &"temple") and not _has_kind(out, &"church"):
				# Theocracy gets a religious seat, but a temple is emitted only
				# when the request's `temple` kept fraction is positive.
				out.append(BuildingRequest.church(_seed_for(spec, "seat|theocracy"),
					styles["church"], 10.0, 20.0, 12.0))
		&"military":
			if not _has_kind(out, &"castle"):
				_append_castle(out, spec, styles, "seat|military", fraction)


static func _append_shop(out: Array[BuildingRequest], spec: VillageSpec, key: String,
	business: StringName, style: StringName, fraction: float) -> void:
	var size: float = lerpf(0.72, 1.0, clampf(fraction, 0.0, 1.0))
	out.append(BuildingRequest.shop(_seed_for(spec, "brief|" + key), business, style,
		11.0 * size, 14.0 * size, 2.8, 1))


static func _append_castle(out: Array[BuildingRequest], spec: VillageSpec,
	styles: Dictionary, key: String, fraction: float) -> void:
	var size: float = lerpf(0.65, 1.0, clampf(fraction, 0.0, 1.0))
	out.append(BuildingRequest.castle(_seed_for(spec, "brief|" + key), styles["castle"],
		40.0 * size, 50.0 * size, 10.0))


static func _has_kind(requests: Array[BuildingRequest], kind: StringName) -> bool:
	return requests.any(func(request: BuildingRequest) -> bool: return request.kind == kind)


static func _has_shop_purpose(requests: Array[BuildingRequest], purpose: StringName) -> bool:
	return requests.any(func(request: BuildingRequest) -> bool:
		return request.kind == &"shop" and request.purpose == purpose)


## `population -> households` earned kinds, independent of `programme()`'s
## own implementation, so a test can hold the two accountable to each other
## rather than to themselves. Excludes `house` (every village has one row of
## households, not a "kind" in this earned-set sense) and anything that is
## a `MeshKit` mass or a prop rather than a `BuildingRequest` (`well`, the
## market stalls, the mine adit, the strand racks, the mill wheel itself).
static func earned_kinds(population: int, purpose: StringName, water: StringName, culture: StringName = &"english") -> Array[StringName]:
	var out: Array[StringName] = []

	if purpose == &"pilgrim" or culture == &"blighted":
		out.append(&"temple")
	elif population >= CHURCH_MIN_POP:
		out.append(&"church")
	elif population >= SHRINE_MIN_POP:
		out.append(&"shrine")

	for row in SHOP_RULES:
		var earns := population >= int(row["min_pop"])
		if row.get("mining_any_size", false) and purpose == &"mining":
			earns = true
		if row.get("pilgrim_any_size", false) and purpose == &"pilgrim":
			earns = true
		if earns:
			out.append(row["kind"])

	if population >= BAKERY_MIN_POP:
		out.append(&"bakery")

	if population >= MANOR_MIN_POP or purpose == &"garrison":
		out.append(&"manor")

	return out


static func _append_landmark(out: Array[BuildingRequest], spec: VillageSpec, styles: Dictionary) -> void:
	if spec.site_brief:
		var temple_fraction: float = float(spec.kept_buildings.get("temple", 0.0))
		if temple_fraction > 0.0:
			out.append(BuildingRequest.temple(_seed_for(spec, "brief|temple"),
				styles["temple_form"], styles["temple_cult"], lerpf(14.0, 26.0, temple_fraction),
				lerpf(24.0, 44.0, temple_fraction), lerpf(10.0, 16.0, temple_fraction)))
			return
		if spec.population >= CHURCH_MIN_POP:
			out.append(BuildingRequest.church(_seed_for(spec, "church"), styles["church"], 10.0, 20.0, 12.0))
		elif spec.population >= SHRINE_MIN_POP:
			out.append(BuildingRequest.church(_seed_for(spec, "shrine"), styles["church"], 6.0, 10.0, 6.0))
		return
	elif spec.culture == &"blighted":
		# The stepped shrine is this settlement's landmark. Its summit rises
		# above the witch cottages, while the ritual chamber remains usable.
		out.append(BuildingRequest.temple(
			_seed_for(spec, "temple"), styles["temple_form"], styles["temple_cult"], 18.0, 24.0, 14.0))
	elif spec.purpose == &"pilgrim":
		out.append(BuildingRequest.temple(
			_seed_for(spec, "temple"), styles["temple_form"], styles["temple_cult"], 26.0, 44.0, 12.0))
	elif spec.population >= CHURCH_MIN_POP:
		out.append(BuildingRequest.church(_seed_for(spec, "church"), styles["church"], 10.0, 20.0, 12.0))
	elif spec.population >= SHRINE_MIN_POP:
		# "a shrine ... small form, or church at 12 m" (§4): the small
		# envelope of the same family, at the shrine's own request seed.
		out.append(BuildingRequest.church(_seed_for(spec, "shrine"), styles["church"], 6.0, 10.0, 6.0))


static func _append_shops(out: Array[BuildingRequest], spec: VillageSpec, styles: Dictionary) -> void:
	for row in SHOP_RULES:
		var earns: bool = spec.population >= int(row["min_pop"])
		if row.get("mining_any_size", false) and spec.purpose == &"mining":
			earns = true
		if row.get("pilgrim_any_size", false) and spec.purpose == &"pilgrim":
			earns = true
		if not earns:
			continue
		out.append(BuildingRequest.shop(
			_seed_for(spec, row["kind"]), row["business"], styles["house"], 11.0, 14.0, 2.8, 1))

	if spec.population >= BAKERY_MIN_POP:
		out.append(BuildingRequest.shop(
			_seed_for(spec, "bakery"), &"bakery", styles["house"], 11.0, 14.0, 2.8, 1))


## Households come in sizes (VILLAGES 6, "hovels and big houses"): the
## first households are the biggest and the last the one-room cottages, a
## spread of HOUSE_SIZE_SPREAD either way about the wealth's own size. The
## lot planner places them in this order, nearest the common first, which is
## the wealth gradient the PlaceCheck measures.
const HOUSE_SIZE_SPREAD := 0.22

static func _make_house(spec: VillageSpec, styles: Dictionary, rng: RandomNumberGenerator, i: int,
		forced_style: StringName = &"") -> BuildingRequest:
	var trade := _trade_for(spec, i)
	# the draw is always taken, so a forced style leaves every later house and
	# shop exactly where it was
	var style := _house_style(spec, styles, rng)
	if forced_style != &"":
		style = forced_style
	var storeys := _storeys_for(spec.wealth, rng)
	var w: float = lerp(7.0, 10.0, clampf(spec.wealth, 0.0, 1.0))
	var l: float = lerp(9.0, 13.0, clampf(spec.wealth, 0.0, 1.0))
	var t: float = 0.5 if spec.households <= 1 else 1.0 - float(i) / float(spec.households - 1)
	var size: float = 1.0 + HOUSE_SIZE_SPREAD * (2.0 * t - 1.0)
	return BuildingRequest.house(_seed_for(spec, "house|%d" % i), style, trade,
		snappedf(w * size, 0.1), snappedf(l * size, 0.1), 2.6, storeys)


## VILLAGES §9.3's `variety`: no one style is more than 45 % of the houses.
## `_house_style` draws each house on its own, which for a rich village gives
## townhouse and the base style two shares that cannot both be under 45 %, and
## a thorpe of six came out five townhouses to one (EVAL-C11). A village rich
## enough to mix (the check's own band, 0.55) and big enough to be judged
## (five houses) is given three styles, the culture's cottage and farmhouse
## as well as the townhouse, dealt in quotas: the townhouse the wealth's share
## of them, up to the cap, the rest shared between the other two, and the
## order shuffled from the seed so the big houses are not all one style.
## Empty when the village is not one of those, and the draws stand.
const MIXING_WEALTH := 0.55
const MIXING_MIN_HOUSES := 5
const STYLE_SHARE_CAP := 0.45

static func _mixed_styles(spec: VillageSpec, styles: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var base: StringName = styles["house"]
	var n: int = spec.households
	if base not in MIXABLE_HOUSE_STYLES or spec.wealth < MIXING_WEALTH or n < MIXING_MIN_HOUSES:
		return out
	var other: StringName = &"farmhouse" if base == &"cottage" else &"cottage"
	var cap: int = int(floorf(STYLE_SHARE_CAP * float(n) - 0.0001))
	var townhouses: int = mini(cap, int(roundf(clampf(spec.wealth, 0.0, 1.0) * float(n))))
	var rest: int = n - townhouses
	var bases: int = mini(cap, int(ceilf(float(rest) * 0.5)))
	for k in range(townhouses):
		out.append(&"townhouse")
	for k in range(bases):
		out.append(base)
	for k in range(rest - bases):
		out.append(other)
	var dealer := RandomNumberGenerator.new()
	dealer.seed = hash("styles|%d" % spec.seed)
	for k in range(out.size() - 1, 0, -1):
		var j: int = dealer.randi_range(0, k)
		var swap: StringName = out[k]
		out[k] = out[j]
		out[j] = swap
	return out


## §4: "wealth sets storeys (1 below 0.3, 2 above 0.6)"; between the two, the
## chance of a second storey rises linearly so the transition is not a
## single hard step for a village sitting right on 0.45.
static func _storeys_for(wealth: float, rng: RandomNumberGenerator) -> int:
	if wealth < 0.3:
		return 1
	if wealth > 0.6:
		return 2
	var t: float = (wealth - 0.3) / 0.3
	return 2 if rng.randf() < t else 1


## §4: "wealth ... moves the mix from cottage to townhouse". Only the
## cultures whose base style is `cottage`/`farmhouse` mix; the others
## (`longhall`, `witch_hut`, `townhouse`) keep their fixed style.
static func _house_style(spec: VillageSpec, styles: Dictionary, rng: RandomNumberGenerator) -> StringName:
	var base: StringName = styles["house"]
	if base in MIXABLE_HOUSE_STYLES and rng.randf() < clampf(spec.wealth, 0.0, 1.0):
		return &"townhouse"
	return base


## §4: "farmer fills most of a farming village, none most of a market town;
## smith, alchemist, scholar, innkeeper appear once the matching shop or the
## population justifies them." The special trades fill the first households
## (capped at however many the village actually has); everyone else gets the
## purpose's majority trade.
static func _trade_for(spec: VillageSpec, i: int) -> StringName:
	var specials := _special_trades(spec)
	if i < specials.size():
		return specials[i]
	return _majority_trade(spec.purpose)


static func _special_trades(spec: VillageSpec) -> Array[StringName]:
	var out: Array[StringName] = []
	if spec.population >= 30 or spec.purpose == &"mining":
		out.append(&"smith")
	if spec.population >= CHURCH_MIN_POP or spec.purpose == &"pilgrim":
		out.append(&"scholar")
	if spec.population >= 80 or spec.purpose == &"pilgrim":
		out.append(&"innkeeper")
	if spec.population >= 120:
		out.append(&"alchemist")
	return out


static func _majority_trade(purpose: StringName) -> StringName:
	if purpose in [&"farming", &"forest", &"mill"]:
		return &"farmer"
	return &"none"


static func _seed_for(spec: VillageSpec, key: String) -> int:
	return hash("%d|%s" % [spec.seed, key])
