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
	# HOUSE-CULTURE. These three carry a house style the other seven do not
	# have. Their castle, church and temple rows are BORROWED from the nearest
	# culture that has one, because those families have no Mediterranean, East
	# Asian or Saharan entry yet: a shared castle is a smaller lie than a
	# castle style that does not exist, and the house is the part that matters.
	&"mediterranean": {"house": &"mediterranean", "castle": &"moorish",
		"church": &"romanesque", "temple_form": &"basilica", "temple_cult": &"blood"},
	&"east_asian": {"house": &"asian", "castle": &"japanese",
		"church": &"byzantine", "temple_form": &"pylon", "temple_cult": &"serpent"},
	&"saharan": {"house": &"african", "castle": &"moorish",
		"church": &"byzantine", "temple_form": &"pylon", "temple_cult": &"serpent"},
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
	{"kind": &"butcher", "min_pop": 100, "business": &"butcher", "civic": true},
	{"kind": &"tailor", "min_pop": 100, "business": &"tailor", "civic": true},
	{"kind": &"town_hall", "min_pop": 100, "business": &"town_hall", "civic": true},
	{"kind": &"apothecary", "min_pop": 120, "business": &"apothecary"},
	{"kind": &"tavern_2", "min_pop": 120, "business": &"tavern"},
	{"kind": &"guildhall", "min_pop": 150, "business": &"guildhall", "civic": true},
]

## A waterside mill keeps the bakery's usable workrooms and storage. The lot
## planner adds its race and the dresser its wheel; the building is still a
## measured request, rather than an empty decorative mass.
const BAKERY_MIN_POP := 50
## §4: "a well per 60 people", "a shrine at 20", "a church + store at 60".
const SHRINE_MIN_POP := 20
const CHURCH_MIN_POP := 60
const MANOR_MIN_POP := 200
## A seat below MANOR_MIN_POP is a HOLD: one fortified house at the castle
## family's house tier (<= 300 m2), not a 40 x 50 m enceinte. Its lot is a
## fifth of the manor's, and its own interior QA has a sixth of the defects.
const HOLD_SIZE := Vector3(12.0, 14.0, 8.0)
## mythsim's monuments. Each is a castle mass in this renderer, and none of
## them is the ruler's seat (owner decision 2026-10-10).
const MONUMENTS := ["great-tomb", "ziggurat"]


## Every `BuildingRequest` the population/purpose/culture/wealth/water earns:
## the households first (one per household), then the landmark (church,
## shrine or, for `pilgrim`, a temple that takes its place), then the shop
## rows, then the lord's house. Order is stable given the same spec.
static func programme(spec: VillageSpec) -> Array[BuildingRequest]:
	var out: Array[BuildingRequest] = []
	var styles: Dictionary = CULTURE_STYLES.get(spec.effective_culture(), CULTURE_STYLES[&"english"])
	var character: Dictionary = spec.ground_character()
	var house_style := StringName(String(character.get("house_style", "")))
	if house_style != &"" and HouseSpec.STYLES.has(house_style):
		styles = styles.duplicate()
		styles["house"] = house_style
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("programme|%d" % spec.seed)

	var areas: Array[float] = house_areas(spec)
	var fs: VillageVernacular = spec.feature_set()
	if fs != null:
		# VILLAGE-VERNACULAR: every household draws its genome from the blend;
		# the landmark is the blend's, and the shops are rebuilt below
		styles = styles.duplicate()
		styles["church"] = fs.landmark()["church"]
		_vernacular_houses(out, spec, areas, fs)
	else:
		var mix: Array[StringName] = _mixed_styles(spec, styles, areas)
		for i in range(spec.households):
			out.append(_make_house(spec, styles, rng, i, mix[i] if not mix.is_empty() else &"", areas[i]))

	_append_landmark(out, spec, styles)
	_append_shops(out, spec, styles)
	if spec.site_brief:
		_append_site_brief(out, spec, styles)

	# A brief's seat already is the lord's house: one castle per village.
	if (spec.civic_population() >= MANOR_MIN_POP or spec.purpose == &"garrison") \
			and not _has_seat(out, spec):
		out.append(BuildingRequest.castle(
			_seed_for(spec, "manor"), styles["castle"], 40.0, 50.0, 10.0))

	if fs != null:
		_vernacular_civic(out, fs)
	_raise_landmark(out)
	return out


## VILLAGE-VERNACULAR (docs/VILLAGE_VERNACULAR.md). Each household's tier
## comes from its footprint's rank (the biggest are the rich), its genome from
## the blend: the house type, so the chassis style and the storeys, a size
## factor on its real footprint, and the look the request carries. The plain
## path's stair rule still holds; the culture's style mixing does not, because
## the type IS the mix. Nor does a real site's character (VillageTerrain.
## character: its house_style and storeys_min): a vernacular names the
## buildings, so on Manarola's ground a Cycladic village keeps its one and two
## storeys and does not take the Cinque Terre's three (walk bake, 15 Nov). The
## ground's layout traits -- form, fire_m, setback_m -- are the lot planner's
## and still apply.
static func _vernacular_houses(out: Array[BuildingRequest], spec: VillageSpec,
		areas: Array[float], fs: VillageVernacular) -> void:
	var tiers: Array[StringName] = fs.tiers_by_area(areas, spec.wealth)
	for i in range(spec.households):
		var trade := _trade_for(spec, i)
		var g: Dictionary = fs.house("%d|%d" % [spec.seed, i], tiers[i], spec.purpose, trade)
		var style: StringName = g["style"]
		var storeys := int(g["storeys"])
		var seed_i := _seed_for(spec, "house|%d" % i)
		var request: BuildingRequest
		if spec.compact_display:
			var ramp := _ramp_dims(spec, i)
			request = BuildingRequest.house(seed_i, style, trade, ramp.x, ramp.y, 2.6, storeys)
		else:
			var area: float = areas[i] * float(g["area"])
			if area < STAIR_MIN_AREA and style != &"townhouse":
				storeys = 1
			var dims := house_dims(style, area, seed_i)
			request = BuildingRequest.house(seed_i, style, trade, dims.x, dims.y, 2.6, storeys)
		request.look = g["look"]
		out.append(request)


## The landmark's colours and the shops' shells. A shop is the region's shop
## type, roofed and painted from the blend like a middling house; a church is
## the landmark region's own (its style was asked for before it was measured).
static func _vernacular_civic(out: Array[BuildingRequest], fs: VillageVernacular) -> void:
	var lm: Dictionary = fs.landmark()
	for request in out:
		if request.kind == &"church" and request.style == lm["church"]:
			request.look = (lm["look"] as Dictionary).duplicate(true)
		elif request.kind == &"shop":
			# the shop is on the ground floor of its type's house: a Provencal
			# shop under three storeys, a machiya's under two
			var g: Dictionary = fs.shop(str(request.seed))
			request.style = g["style"]
			request.look = g["look"]
			request.storeys = int(g["storeys"])


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
	# VILLAGE-VERNACULAR: a look may steepen the roof, so the bound reads the
	# row the generator will (the row itself when there is no look)
	var style: Dictionary = HouseSpec.patched_row(request.style, request.look)
	if style.is_empty():
		return 0.0
	spec.roof_pitch = float(style["roof_pitch"][1])
	spec.chimney = true
	spec.porch = true
	spec.bargeboards = true
	spec.roof_type = &"gable"
	# a parapet stands over a level roof; the bound only ever rises for it
	spec.parapet = not request.look.is_empty() and float(style.get("parapet", 0.0)) > 0.0
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
	# Ziggurat is a stepped civic monument in this renderer. It uses a castle
	# mass; only the explicit `temple` key earns TempleSpec geometry.
	for word in MONUMENTS:
		if float(built.get(word, 0.0)) > 0.0:
			_append_monument(out, spec, styles, word, float(built[word]))
	_append_seat(out, spec, styles, spec.regime, 1.0)


static func _append_seat(out: Array[BuildingRequest], spec: VillageSpec,
		styles: Dictionary, requested_regime: StringName, fraction: float) -> void:
	match requested_regime:
		&"royal":
			if not _has_seat(out, spec):
				_append_seat_castle(out, spec, styles, "seat|royal", fraction)
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
			if not _has_seat(out, spec):
				_append_seat_castle(out, spec, styles, "seat|military", fraction)


static func _append_shop(out: Array[BuildingRequest], spec: VillageSpec, key: String,
	business: StringName, style: StringName, fraction: float) -> void:
	var size: float = lerpf(0.72, 1.0, clampf(fraction, 0.0, 1.0))
	out.append(BuildingRequest.shop(_seed_for(spec, "brief|" + key), business, style,
		11.0 * size, 14.0 * size, 2.8, 1))


## A city's seat: a hold until the village earns a manor, then a castle.
static func _append_seat_castle(out: Array[BuildingRequest], spec: VillageSpec,
	styles: Dictionary, key: String, fraction: float) -> void:
	if spec.civic_population() >= MANOR_MIN_POP:
		_append_castle(out, spec, styles, key, fraction)
		return
	var size: float = lerpf(0.8, 1.0, clampf(fraction, 0.0, 1.0))
	out.append(BuildingRequest.castle(_seed_for(spec, "brief|" + key), styles["castle"],
		HOLD_SIZE.x * size, HOLD_SIZE.y * size, HOLD_SIZE.z))


## A monument is sized to the settlement as its seat is: the castle mass for
## a city that earns a castle, the hold's footprint below that.
static func _append_monument(out: Array[BuildingRequest], spec: VillageSpec,
		styles: Dictionary, word: String, fraction: float) -> void:
	_append_seat_castle(out, spec, styles, word, fraction)


## The kept word when `request` is one of the brief's monuments, else "".
static func monument_of(spec: VillageSpec, request: BuildingRequest) -> String:
	if spec == null or not spec.site_brief or request.kind != &"castle":
		return ""
	for word in MONUMENTS:
		if request.seed == _seed_for(spec, "brief|" + word):
			return word
	return ""


## Whom a request serves: "visible" for the homes and the everyday trades of
## the people shown, "implied" for the civic programme the implied population
## sizes (seat, monuments, landmark, temples, halls, market and every kept
## building of the brief).
static func serves(spec: VillageSpec, request: BuildingRequest) -> String:
	if request.kind == &"house":
		return "visible"
	if request.kind != &"shop":
		return "implied"
	for key in ["granary", "forge-hall", "seat|council"]:
		if request.seed == _seed_for(spec, "brief|" + key):
			return "implied"
	for row in SHOP_RULES:
		if row.get("civic", false) and request.seed == _seed_for(spec, row["kind"]):
			return "implied"
	return "visible"


static func _append_castle(out: Array[BuildingRequest], spec: VillageSpec,
	styles: Dictionary, key: String, fraction: float) -> void:
	var size: float = lerpf(0.65, 1.0, clampf(fraction, 0.0, 1.0))
	out.append(BuildingRequest.castle(_seed_for(spec, "brief|" + key), styles["castle"],
		40.0 * size, 50.0 * size, 10.0))


static func _has_kind(requests: Array[BuildingRequest], kind: StringName) -> bool:
	return requests.any(func(request: BuildingRequest) -> bool: return request.kind == kind)


static func _has_seat(requests: Array[BuildingRequest], spec: VillageSpec) -> bool:
	return requests.any(func(request: BuildingRequest) -> bool:
		return request.kind == &"castle" and monument_of(spec, request).is_empty())


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
		if spec.civic_population() >= CHURCH_MIN_POP:
			out.append(BuildingRequest.church(_seed_for(spec, "church"), styles["church"], 10.0, 20.0, 12.0))
		elif spec.civic_population() >= SHRINE_MIN_POP:
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
	elif spec.civic_population() >= CHURCH_MIN_POP:
		out.append(BuildingRequest.church(_seed_for(spec, "church"), styles["church"], 10.0, 20.0, 12.0))
	elif spec.civic_population() >= SHRINE_MIN_POP:
		# "a shrine ... small form, or church at 12 m" (§4): the small
		# envelope of the same family, at the shrine's own request seed.
		out.append(BuildingRequest.church(_seed_for(spec, "shrine"), styles["church"], 6.0, 10.0, 6.0))


static func _append_shops(out: Array[BuildingRequest], spec: VillageSpec, styles: Dictionary) -> void:
	for row in SHOP_RULES:
		var people: int = spec.civic_population() if row.get("civic", false) else spec.population
		var earns: bool = people >= int(row["min_pop"])
		if row.get("mining_any_size", false) and spec.purpose == &"mining":
			earns = true
		if row.get("pilgrim_any_size", false) and spec.purpose == &"pilgrim":
			earns = true
		if not earns:
			continue
		var dims := shop_dims(spec, row["business"], _seed_for(spec, row["kind"]))
		out.append(BuildingRequest.shop(
			_seed_for(spec, row["kind"]), row["business"], styles["house"], dims.x, dims.y, 2.8, 1))

	if spec.population >= BAKERY_MIN_POP:
		var bakery := shop_dims(spec, &"bakery", _seed_for(spec, "bakery"))
		out.append(BuildingRequest.shop(
			_seed_for(spec, "bakery"), &"bakery", styles["house"], bakery.x, bakery.y, 2.8, 1))


## A shop is the size of its trade (VREAL-SIZE), not one 11 x 14 m hall for a
## smithy and a guildhall alike: a forge and a tailor's are cottages with a
## workroom, an inn and a guildhall are the big houses of the place. Frontage
## x depth at the historic pool's median house (VillageRealLayout.POOL), scaled
## by the culture's own median, a seeded +-SHOP_JITTER, and never under the
## library's shop envelope.
const SHOP_SIZE := {
	&"blacksmith": Vector2(7.5, 9.5), &"tavern": Vector2(9.0, 12.0),
	&"general_store": Vector2(7.5, 10.0), &"inn": Vector2(11.0, 14.0),
	&"stable": Vector2(8.0, 12.0), &"carpenter": Vector2(8.0, 11.0),
	&"butcher": Vector2(7.5, 9.5), &"tailor": Vector2(7.5, 9.5),
	&"town_hall": Vector2(10.0, 14.0), &"apothecary": Vector2(7.5, 9.5),
	&"guildhall": Vector2(11.0, 15.0), &"bakery": Vector2(7.5, 10.0),
}
const SHOP_JITTER := 0.06

static func shop_dims(spec: VillageSpec, business: StringName, shop_seed: int) -> Vector2:
	if spec.compact_display:
		return Vector2(11.0, 14.0)   # the compact grid's own measured size (see _make_house)
	var base: Vector2 = SHOP_SIZE.get(business, Vector2(11.0, 14.0))
	var scale: float = sqrt(float(VillageRealLayout.of(spec.effective_culture())["area_p50"])
		/ float(VillageRealLayout.POOL["area_p50"]))
	var r := RandomNumberGenerator.new()
	r.seed = hash("shop_size|%d" % shop_seed)
	scale *= 1.0 + SHOP_JITTER * (2.0 * r.randf() - 1.0)
	var envelope: Dictionary = BuildingLibrary.KIND_ROWS[&"shop"]
	return Vector2(
		snappedf(clampf(base.x * scale, float(envelope["width"]["min"]), float(envelope["width"]["max"])), 0.1),
		snappedf(clampf(base.y * scale, float(envelope["length"]["min"]), float(envelope["length"]["max"])), 0.1))


## Households come in sizes (VILLAGES 6, "hovels and big houses"), and the
## sizes are what real old villages measure (VREAL-SIZE,
## docs/VILLAGE_REAL_LAYOUT.md), not a ramp. Each household's footprint is
## the culture's median main building (VillageRealLayout, from the survey's
## cached OSM answers) times exp(sd * z): z a seeded normal draw, redrawn
## beyond HOUSE_Z_MAX, and sd HOUSE_SD_SHARE of the real per-site log spread
## (the rest of that spread is barns and sheds OSM maps as plain buildings,
## which a village of homes does not draw). Wealth moves the median, never
## the spread. How the areas are dealt to households is house_areas'.
const HOUSE_SD_SHARE := 0.7
const HOUSE_Z_MAX := 1.75
const WEALTH_AREA_K := 0.3
## A house's plan, long side over short side (its frontage is the short
## side, as before): a longhall and a farmhouse with its byre are long, a
## cottage nearly square. Drawn inside the range from the house's own seed.
const STYLE_ASPECT := {
	&"cottage": Vector2(1.2, 1.55), &"thatch_cottage": Vector2(1.25, 1.6),
	&"farmhouse": Vector2(1.45, 2.1), &"longhall": Vector2(1.9, 2.6),
	&"townhouse": Vector2(1.45, 1.9), &"witch_hut": Vector2(1.1, 1.35),
}
const ASPECT_DEFAULT := Vector2(1.2, 1.6)
## A townhouse is narrow and tall (HS-TOWNHOUSE): its frontage is drawn in
## this band, and its depth at most TOWNHOUSE_DEEP times its own aspect.
const TOWNHOUSE_FRONT_MIN := 5.5
const TOWNHOUSE_FRONT_MAX := 7.5
const TOWNHOUSE_DEEP := 1.15


## Every household's footprint, m2, by household index. The special trades
## (smith, scholar, innkeeper, alchemist: the first households) take sizes
## from the middle of the village, spread over its central half -- a smith
## is not the richest man in the place -- and everyone else the rest,
## biggest first. Pure in (spec.seed, culture, wealth, households, population).
static func house_areas(spec: VillageSpec) -> Array[float]:
	var real: Dictionary = VillageRealLayout.of(spec.effective_culture())
	var median: float = float(real["area_p50"]) * exp(WEALTH_AREA_K * (clampf(spec.wealth, 0.0, 1.0) - 0.5))
	var sd: float = float(real["log_sd"]) * HOUSE_SD_SHARE
	var draw := RandomNumberGenerator.new()
	draw.seed = hash("house_area|%d" % spec.seed)
	var sorted: Array[float] = []
	var n: int = spec.households
	for i in range(n):
		var z: float = draw.randfn(0.0, 1.0)
		while absf(z) > HOUSE_Z_MAX:
			z = draw.randfn(0.0, 1.0)
		sorted.append(median * exp(sd * z))
	sorted.sort()
	sorted.reverse()
	var specials: int = mini(_special_trades(spec).size(), n)
	var middle: Array[int] = []
	for k in range(specials):
		var rank: int = clampi(int(floorf(float(n) * (0.25 + 0.5 * (float(k) + 0.5) / float(specials)))), 0, n - 1)
		while middle.has(rank):
			rank = (rank + 1) % n
		middle.append(rank)
	var out: Array[float] = []
	for k in range(specials):
		out.append(sorted[middle[k]])
	for rank in range(n):
		if not middle.has(rank):
			out.append(sorted[rank])
	return out


static func _make_house(spec: VillageSpec, styles: Dictionary, rng: RandomNumberGenerator, i: int,
		forced_style: StringName = &"", area: float = 0.0) -> BuildingRequest:
	var trade := _trade_for(spec, i)
	# the draw is always taken, so a forced style leaves every later house and
	# shop exactly where it was
	var style := _house_style(spec, styles, rng)
	if forced_style != &"":
		style = forced_style
	var storeys := _storeys_for(spec.wealth, rng)
	if spec.compact_display:
		# The compact display is a fixed grid other projects show many of; its
		# lots, churchyard and common were measured on these sizes, so it keeps
		# them (VREAL-SIZE; its own suite, vcompact, failed on the real draw).
		var ramp := _ramp_dims(spec, i)
		return BuildingRequest.house(_seed_for(spec, "house|%d" % i), style, trade,
			ramp.x, ramp.y, 2.6, maxi(storeys, int(spec.ground_character().get("storeys_min", 0))))
	var real: Dictionary = VillageRealLayout.of(spec.effective_culture())
	if area <= 0.0:
		area = float(real["area_p50"])
	# in the middle of the wealth band a house bigger than the real p75 is the
	# long low farmhouse: it spreads, it does not also climb (VREAL-SIZE)
	if spec.wealth <= 0.6 and area > float(real["area_p75"]) and style != &"townhouse":
		storeys = 1
	# a house too small for a climbable flight is a cottage with a loft, not
	# two storeys on a ladder: the house planner falls back to its legacy stair
	# below about this (DBGSTAIR in house_plan_levels.gd; walk pin "stuck in
	# the stairs" in a 6.6 x 8.6 m house)
	if area < STAIR_MIN_AREA and style != &"townhouse":
		storeys = 1
	storeys = maxi(storeys, int(spec.ground_character().get("storeys_min", 0)))
	var dims := house_dims(style, area, _seed_for(spec, "house|%d" % i))
	return BuildingRequest.house(_seed_for(spec, "house|%d" % i), style, trade,
		dims.x, dims.y, 2.6, storeys)


const STAIR_MIN_AREA := 55.0

## The sizes before VREAL-SIZE, kept for the compact display: the first
## households biggest, HOUSE_SIZE_SPREAD either way about the wealth's size.
const HOUSE_SIZE_SPREAD := 0.22

static func _ramp_dims(spec: VillageSpec, i: int) -> Vector2:
	var w: float = lerp(7.0, 10.0, clampf(spec.wealth, 0.0, 1.0))
	var l: float = lerp(9.0, 13.0, clampf(spec.wealth, 0.0, 1.0))
	var t: float = 0.5 if spec.households <= 1 else 1.0 - float(i) / float(spec.households - 1)
	var size: float = 1.0 + HOUSE_SIZE_SPREAD * (2.0 * t - 1.0)
	return Vector2(snappedf(w * size, 0.1), snappedf(l * size, 0.1))


## Width (the frontage) and length of a house of `area` m2 in `style`, inside
## the library's house envelope. The aspect is drawn from the house's seed.
static func house_dims(style: StringName, area: float, house_seed: int) -> Vector2:
	var range_: Vector2 = STYLE_ASPECT.get(style, ASPECT_DEFAULT)
	var r := RandomNumberGenerator.new()
	r.seed = hash("house_aspect|%d" % house_seed)
	var aspect: float = lerpf(range_.x, range_.y, r.randf())
	var w: float = sqrt(area / aspect)
	var envelope: Dictionary = BuildingLibrary.KIND_ROWS[&"house"]
	var l_max: float = float(envelope["length"]["max"])
	if style == &"townhouse":
		# narrow, and no deeper than its own plan allows: a big merchant's
		# household goes UP (it has two storeys at least), never 25 m back.
		# The frontage cap is the house's own, so a street of them is not one
		# box repeated.
		w = minf(w, lerpf(TOWNHOUSE_FRONT_MIN, TOWNHOUSE_FRONT_MAX, r.randf()))
		l_max = minf(l_max, w * aspect * TOWNHOUSE_DEEP)
	w = clampf(w, float(envelope["width"]["min"]), float(envelope["width"]["max"]))
	var l: float = clampf(area / w, maxf(float(envelope["length"]["min"]), w), l_max)
	return Vector2(snappedf(w, 0.1), snappedf(l, 0.1))


## Which house each household lives in (VREAL-TYPES, docs/VILLAGE_REAL_LAYOUT.md):
## the style follows the household's TRADE and SIZE and the village's
## PURPOSE, never a coin. It used to be a draw (townhouse with probability
## wealth, in any village), and a rich farming hamlet came out half
## townhouses, which is a market town's house.
##
## * A farmer's household is a farmhouse when it is one of the bigger half
##   of the farmers (the yeoman with byre and barn); the smaller half are
##   smallholders in cottages.
## * A townhouse is a merchant's or a craftsman's house in a place that
##   trades: only in a TOWN_PURPOSES village (or one of
##   TOWN_POPULATION), only for a household that does not farm, and the
##   wealth's share of those households, at most STYLE_SHARE_CAP of the
##   village, the biggest first. The smith keeps his cottage by the forge.
## * Everyone else lives in a cottage; in a culture whose vernacular is the
##   farmhouse (frankish, alpine) the bigger half of them keep that, and in
##   any culture a household bigger than the real p75 house is a farmhouse
##   (the big vernacular house, with its workshop), never a 190 m2 cottage.
## Empty when the culture's base style is not cottage/farmhouse: those keep
## their fixed style.
const MIXING_WEALTH := 0.55
const MIXING_MIN_HOUSES := 5
const STYLE_SHARE_CAP := 0.45
const FARMHOUSE_SHARE := 0.5
const TOWN_PURPOSES: Array[StringName] = [&"market", &"crossroads", &"pilgrim", &"garrison"]
const TOWN_POPULATION := 100

static func _mixed_styles(spec: VillageSpec, styles: Dictionary, areas: Array[float]) -> Array[StringName]:
	var out: Array[StringName] = []
	var base: StringName = styles["house"]
	var n: int = spec.households
	if base not in MIXABLE_HOUSE_STYLES or n <= 0:
		return out
	var big: float = float(VillageRealLayout.of(spec.effective_culture())["area_p75"])
	var trades: Array[StringName] = []
	var farmers: int = 0
	for i in range(n):
		trades.append(_trade_for(spec, i))
		if trades[i] == &"farmer":
			farmers += 1
	var town: bool = spec.purpose in TOWN_PURPOSES or spec.population >= TOWN_POPULATION
	var others: int = n - farmers
	var cap: int = int(floorf(STYLE_SHARE_CAP * float(n) - 0.0001)) if n >= MIXING_MIN_HOUSES else n
	var townhouses: int = mini(cap, int(roundf(clampf(spec.wealth, 0.0, 1.0) * float(others)))) if town else 0
	var farmhouses: int = int(ceilf(float(farmers) * FARMHOUSE_SHARE))
	var vernacular: int = int(ceilf(float(others - townhouses) * 0.5)) if base == &"farmhouse" else 0
	# after the special trades, households are dealt biggest first
	# (house_areas), so a running count IS the farmers' size rank
	var farm_rank := 0
	for i in range(n):
		var style: StringName = &"cottage"
		if trades[i] == &"farmer":
			style = &"farmhouse" if farm_rank < farmhouses else &"cottage"
			farm_rank += 1
		elif townhouses > 0 and trades[i] != &"smith":
			style = &"townhouse"
			townhouses -= 1
		elif vernacular > 0:
			style = &"farmhouse"
			vernacular -= 1
		elif i < areas.size() and areas[i] > big:
			style = &"farmhouse"
		out.append(style)
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
