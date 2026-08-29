class_name ShopArchetypeSuite
extends RefCounted
## Occupational landmarks: each business must read through rooms and fixtures,
## then pass the same physical, daylight, furnishing, and walking rules as a house.

const REQUIRED := {
	&"blacksmith": ["workshop", "anvil", "workbench"],
	&"stable": ["stable", "stall"],
	&"restaurant": ["dining_room", "table", "seat"],
	&"tavern": ["dining_room", "table", "barrel"],
	&"inn": ["dining_room", "table", "bed"],
	&"bakery": ["sales_floor", "counter", "hearth"],
	&"butcher": ["sales_floor", "counter", "blade"],
	&"apothecary": ["sales_floor", "counter", "alchemy"],
	&"general_store": ["sales_floor", "counter", "crate"],
	&"tailor": ["sales_floor", "counter", "sack"],
	&"carpenter": ["workshop", "workbench", "rack"],
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
	return res


static func _has_category(plan: HousePlan, category: String) -> bool:
	for placement in plan.furniture:
		if PropCatalog.category(placement["key"]) == category:
			return true
	return false
