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
## of its own: every request is answered by `BigGlade.generate()`.

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

## `bakery` only stands alone (as a `BuildingRequest`) when there is no
## water; when there is, the mill takes its place, and the mill itself is a
## `MeshKit` mass (VILLAGES §4), not a `BuildingRequest`, so it is out of
## this file's scope.
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

	for i in range(spec.households):
		out.append(_make_house(spec, styles, rng, i))

	_append_landmark(out, spec, styles)
	_append_shops(out, spec, styles)

	if spec.population >= MANOR_MIN_POP or spec.purpose == &"garrison":
		out.append(BuildingRequest.castle(
			_seed_for(spec, "manor"), styles["castle"], 40.0, 50.0, 10.0))

	return out


## `population -> households` earned kinds, independent of `programme()`'s
## own implementation, so a test can hold the two accountable to each other
## rather than to themselves. Excludes `house` (every village has one row of
## households, not a "kind" in this earned-set sense) and anything that is
## a `MeshKit` mass or a prop rather than a `BuildingRequest` (`well`, the
## market stalls, the mine adit, the strand racks, the mill mass itself).
static func earned_kinds(population: int, purpose: StringName, water: StringName) -> Array[StringName]:
	var out: Array[StringName] = []

	if purpose == &"pilgrim":
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

	if population >= BAKERY_MIN_POP and water == &"none":
		out.append(&"bakery")

	if population >= MANOR_MIN_POP or purpose == &"garrison":
		out.append(&"manor")

	return out


static func _append_landmark(out: Array[BuildingRequest], spec: VillageSpec, styles: Dictionary) -> void:
	if spec.purpose == &"pilgrim":
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

	if spec.population >= BAKERY_MIN_POP and spec.water == &"none":
		out.append(BuildingRequest.shop(
			_seed_for(spec, "bakery"), &"bakery", styles["house"], 11.0, 14.0, 2.8, 1))


## Households come in sizes (VILLAGES 6, "hovels and big houses"): the
## first households are the biggest and the last the one-room cottages, a
## spread of HOUSE_SIZE_SPREAD either way about the wealth's own size. The
## lot planner places them in this order, nearest the common first, which is
## the wealth gradient the PlaceCheck measures.
const HOUSE_SIZE_SPREAD := 0.22

static func _make_house(spec: VillageSpec, styles: Dictionary, rng: RandomNumberGenerator, i: int) -> BuildingRequest:
	var trade := _trade_for(spec, i)
	var style := _house_style(spec, styles, rng)
	var storeys := _storeys_for(spec.wealth, rng)
	var w: float = lerp(7.0, 10.0, clampf(spec.wealth, 0.0, 1.0))
	var l: float = lerp(9.0, 13.0, clampf(spec.wealth, 0.0, 1.0))
	var t: float = 0.5 if spec.households <= 1 else 1.0 - float(i) / float(spec.households - 1)
	var size: float = 1.0 + HOUSE_SIZE_SPREAD * (2.0 * t - 1.0)
	return BuildingRequest.house(_seed_for(spec, "house|%d" % i), style, trade,
		snappedf(w * size, 0.1), snappedf(l * size, 0.1), 2.6, storeys)


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
