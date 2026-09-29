class_name HouseFurnishProgrammeCheck
extends RefCounted
## Programme requirements for furnished rooms.

var failures: Array = []
var warnings: Array = []


func _init(report: Dictionary = {}) -> void:
	failures = report.get("failures", [])
	warnings = report.get("warnings", [])


## Does anybody sleep anywhere in this plan?
static func _anybody_sleeps(plan: HousePlan) -> bool:
	for kind in HouseGeometry.SLEEPING:
		if plan.has_kind(kind):
			return true
	return false


## A bedroom with no bed is a room, not a bedroom.
func check_program(plan: HousePlan) -> void:
	var spec: HouseSpec = plan.spec
	for i in range(plan.room_count()):
		var kind: StringName = plan.kind_of(i)
		var cats: Array = HouseFurnishCheck.REQUIRED.get(kind, [])
		# A house with nowhere to call a bedroom sleeps in the hall -- but
		# &"bedroom" is not the only room people sleep in, and a keep whose
		# lord has a chamber at the top was being told to bed down in its hall
		# as well. HouseFurnisher asks the same question the same way.
		if not spec is ShopSpec and kind == &"hall" and not _anybody_sleeps(plan):
			cats = cats + ["bed"]
		for cat in cats:
			if _room_has(plan, i, cat):
				continue
			if plan.was_dropped(i, cat):
				warnings.append("programme: room %d (%s) gave up its %s so the rooms beyond it could be reached"
					% [i, String(kind), cat])
			elif not could_hold(plan, i, cat):
				warnings.append("programme: room %d (%s) has no %s, and is too small to take one"
					% [i, String(kind), cat])
			else:
				failures.append("programme: room %d (%s) has no %s"
					% [i, String(kind), cat])
		if kind == &"hall" or kind == &"parlour":
			if _room_has(plan, i, "table") and _seat_count(plan, i) == 0 \
					and not plan.was_dropped(i, "seat"):
				if could_hold(plan, i, "seat"):
					failures.append("programme: room %d (%s) has a table and nothing to sit on"
						% [i, String(kind)])
				else:
					warnings.append("programme: room %d (%s) has a table and no room for a seat"
						% [i, String(kind)])
	var demands: Dictionary = HouseFurnishCheck.BUSINESS_REQUIRED.get((spec as ShopSpec).business, {}) \
		if spec is ShopSpec else HouseFurnishCheck.TRADE_REQUIRED.get(spec.trade, {})
	for kind in demands:
		for i in plan.rooms_of(kind):
			for cat in demands[kind]:
				if _room_has(plan, i, cat):
					continue
				if plan.was_dropped(i, cat):
					warnings.append("programme: a %s's %s could not fit a %s beside everything else it needed"
						% [_purpose(spec), String(kind), cat])
				elif not could_hold(plan, i, cat):
					warnings.append("programme: a %s's %s is too small for a %s"
						% [_purpose(spec), String(kind), cat])
				else:
					failures.append("programme: a %s's %s has no %s"
						% [_purpose(spec), String(kind), cat])


static func _purpose(spec: HouseSpec) -> String:
	return String((spec as ShopSpec).business) if spec is ShopSpec else String(spec.trade)


## Could ANY prop of this category physically fit in the room, footprint and
## use zone together? A 3 x 3 m hall genuinely cannot hold a 2.8 m table, and
## reporting that as a defect would be reporting the size of the house.
static func could_hold(plan: HousePlan, room: int, cat: String) -> bool:
	return HouseFurnishPlacement.could_place(plan, room, cat)


static func _room_has(plan: HousePlan, room: int, cat: String) -> bool:
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) == cat:
			return true
	return false


static func _seat_count(plan: HousePlan, room: int) -> int:
	var n := 0
	for f in plan.furniture_of(room):
		var c: String = PropCatalog.category(plan.furniture[f]["key"])
		if c == "seat" or c == "bench":
			n += 1
	return n
