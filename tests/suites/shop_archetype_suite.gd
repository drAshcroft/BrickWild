class_name ShopArchetypeSuite
extends RefCounted
## Occupational landmarks: each business must read through rooms and fixtures,
## then pass the same physical, daylight, furnishing, and walking rules as a house.

const REQUIRED := {
	&"blacksmith": ["workshop", "anvil", "workbench"],
	&"stable": ["stable", "stall"],
	&"restaurant": ["dining_room", "table", "seat"],
	&"tavern": ["dining_room", "table", "barrel", "counter"],
	&"inn": ["dining_room", "table", "bed"],
	&"bakery": ["sales_floor", "counter", "hearth"],
	&"butcher": ["sales_floor", "counter", "blade"],
	&"apothecary": ["sales_floor", "counter", "alchemy"],
	&"general_store": ["sales_floor", "counter", "crate"],
	&"tailor": ["sales_floor", "counter", "sack", "rack", "shelf", "workbench"],
	&"carpenter": ["workshop", "workbench", "rack", "bench"],
	&"town_hall": ["council_chamber", "table", "seat"],
	&"guildhall": ["meeting_hall", "table", "bench"],
}


static func run() -> SuiteResult:
	var res := SuiteResult.new("shop archetypes")
	for business in REQUIRED:
		var spec := ShopSpec.new()
		spec.business = business
		spec.style = &"longhall" if business in [&"blacksmith", &"stable", &"carpenter"] else &"townhouse"
		spec.width = 14.0
		spec.length = 18.0
		spec.height = 2.9
		var plan := ShopGenerator.generate(spec, 33000 + absi(String(business).hash()) % 900)
		var builder := HouseBuilder.new()
		builder.build(plan)
		res.checked += 1
		var wants: Array = REQUIRED[business]
		if not plan.has_kind(StringName(wants[0])):
			res.fail("%s has no defining %s room" % [String(business), wants[0]])
		for cat in wants.slice(1):
			if not _has_category(plan, String(cat)):
				res.fail("%s has no defining %s fitting" % [String(business), cat])
		var report: Dictionary = HouseQA.new().check(plan, builder)
		for failure in report["failures"]:
			res.fail("%s: %s" % [String(business), failure])
		for warning in report["warnings"]:
			res.warn("%s: %s" % [String(business), warning])
		for failure2 in shopfront_rules(spec, plan, builder):
			res.fail("%s: %s" % [String(business), failure2])
	return res


## What a trade's front has to be (LAY-009), measured from the plan: the
## street door is in the front room and as wide as the trade needs; a stable
## has a door a horse fits through; a smithy opens to the street and its
## forge stands on the chimney wall under a real chimney; a shop with a
## shopfront has its hatch in the street wall; a tavern keeps its casks
## behind the bar.
static func shopfront_rules(spec: ShopSpec, plan: HousePlan, builder: HouseBuilder) -> Array[String]:
	var out: Array[String] = []
	var front: int = plan.entrance_room()
	var door: int = plan.entrance()
	if door < 0 or front < 0:
		return ["front: no street door"]
	var street_front: bool = spec.door_w() >= 1.2 or not spec.front_open().is_empty()
	if street_front and plan.kind_of(front) != spec.front_room():
		out.append("front: the street door opens into the %s, not the %s"
			% [String(plan.kind_of(front)), String(spec.front_room())])
	var w: float = float(plan.doors[door]["width"])
	if w < spec.door_w() - 0.01:
		out.append("door: the street door is %.2fm wide, the trade needs %.2fm" % [w, spec.door_w()])
	if spec.business == &"stable" and w < 1.2:
		out.append("door: a horse does not fit through a %.2fm door" % w)
	if spec.business == &"blacksmith":
		if w < 2.4:
			out.append("door: the forge opens to the street through %.2fm" % w)
		if plan.hearth_room() != front:
			out.append("forge: the chimney is in room %d, the forge room is %d" % [plan.hearth_room(), front])
		var stack := 0
		for m in builder.mass_log:
			if String(m["name"]).begins_with("chimney"):
				stack += 1
		if stack != 1:
			out.append("forge: %d chimneys" % stack)
	if not spec.front_open().is_empty():
		var hatch := false
		for win in plan.windows:
			if win.get("hatch", false) and int(win["room"]) == front:
				hatch = true
		if not hatch:
			out.append("shopfront: no hatch in the street wall of the %s" % String(spec.front_room()))
	if spec.business == &"tavern":
		var bar := Vector2(INF, INF)
		for p in plan.furniture:
			if int(p["room"]) == front and PropCatalog.category(p["key"]) == "counter":
				bar = Rect2(p["rect"]).get_center()
		if not bar.is_finite():
			out.append("bar: the tavern has no counter in its front room")
		else:
			var near := INF
			for p2 in plan.furniture:
				if int(p2["room"]) == front and PropCatalog.category(p2["key"]) == "barrel":
					near = minf(near, Rect2(p2["rect"]).get_center().distance_to(bar))
			if near > 3.5:
				out.append("bar: the nearest cask is %.2fm from the bar" % near)
	return out


static func _has_category(plan: HousePlan, category: String) -> bool:
	for placement in plan.furniture:
		if PropCatalog.category(placement["key"]) == category:
			return true
	return false
