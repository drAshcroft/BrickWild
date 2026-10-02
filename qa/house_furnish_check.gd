class_name HouseFurnishCheck
extends RefCounted
## Does the furnishing make sense?
##
## The physical rules first, because a room that fails those is not furnished
## at all:
##   PLACED     every piece is inside its own room, and nothing is inside
##              anything else
##   SUPPORTED  a mug is on a table, not hovering where a table used to be
##   DOORWAYS   nothing stands in the swing of a door
##   DAYLIGHT   nothing tall stands across a window
##
## Then the rules an interior designer would recognise:
##   PROGRAM    a bedroom has a bed, a kitchen has a hearth, a hall has
##              somewhere to sit, a smithy has an anvil
##   AGAINST    the pieces that want a wall have one behind them
##   SEATING    seats are at a table and facing it
##   LIGHT      every room people use has something to see by
##   DENSITY    the room is furnished, not filled
##
## And last the ones the brief called feng shui, which in a bedroom are simply
## the ones everybody already follows:
##   COMMAND    the bed's head is against solid wall, and the bed does not sit
##              in the line of the door
##   HEARTH     the fire is on the wall the planner gave the chimney, so the
##              smoke has somewhere to go
## and one rule per affinity in PropCatalog, each of them a sentence and a
## measurement (LAY-003):
##   WORKBENCH_DAYLIGHT  a bench is worked at in the light
##   BOOKCASE_HEAT       books keep off the chimney wall
##   BED_WINDOW          you do not sleep with your head under the window
##   TABLE_FOCUS         the table draws up toward the fire
##   SCONCE_PAIR         two lamps are a pair, not a scatter
##   SHELF_OVER          a shelf hangs over the bench it serves
##   CHANDELIER_OVER     the chandelier hangs over the table
##   CORNER_CLUTTER      barrels stand out of the traffic
## and the one the temple taught (INT-002):
##   FOCUS               the piece the plan is arranged around stands where
##                       the plan says, and looks at the door when it must
##
## report = {"ok": bool, "failures": [..], "warnings": [..], "stats": {...}}

const TOL := 0.03

## What each room kind must actually contain, by prop category.
const REQUIRED := {
	&"bedroom": ["bed"],
	&"kitchen": ["hearth"],
	&"hall": ["table"],
	&"parlour": ["table"],
	&"workshop": ["workbench"],
	&"sales_floor": ["counter"],
	&"stable": ["stall"],
	&"tack_room": ["storage"],
	&"dining_room": ["table"],
	&"guest_room": ["bed"],
	&"office": ["workbench"],
	&"records": ["bookcase"],
	&"council_chamber": ["table"],
	&"meeting_hall": ["table"],
	&"lobby": ["counter"],
	&"lounge": ["table"],
	&"suite": ["bed"],
	&"laundry": ["workbench"],
	&"great_hall": ["table"],
	&"lords_chamber": ["bed"],
	&"nave": ["table"],
	&"sanctuary": ["table"],
	&"guardroom": ["table"],
	&"cell": ["cage"],
}

## And what a trade must have in the room it works in.
const TRADE_REQUIRED := {
	&"smith": {&"workshop": ["anvil"]},
	&"alchemist": {&"workshop": ["bookcase"]},
	&"scholar": {&"parlour": ["bookcase"]},
}

const BUSINESS_REQUIRED := {
	&"blacksmith": {&"workshop": ["anvil"]},
	&"bakery": {&"kitchen": ["hearth"]},
	&"prison": {&"guardroom": ["stand"]},
	&"palace": {&"throne_room": ["seat"], &"treasury": ["chest"],
		&"royal_chamber": ["bed"]},
}

## Which rule each message prefix belongs to, so a report can group a house's
## complaints the way this file is laid out rather than by guessing at the
## words. HouseQA passes it straight through.
const GROUPS := {
	"physical": ["placed", "vertical", "supported", "doorway", "daylight"],
	"programme": ["programme", "light", "density"],
	"arrangement": ["against", "seating", "row", "clear"],
	"feng shui": ["command", "hearth", "workbench_daylight", "bookcase_heat",
		"bed_window", "table_focus", "sconce_pair", "shelf_over",
		"chandelier_over", "corner_clutter", "focus"],
}

## Every rule, in the order it runs, by the name its messages carry. A family
## may replace one through `check(plan, overrides)` (RuleSet, INT-020).
const RULES: Array[StringName] = [&"placed", &"vertical", &"supported", &"doorway",
	&"daylight", &"programme", &"against", &"seating", &"light", &"density",
	&"command", &"hearth", &"row", &"clear", &"workbench_daylight", &"bookcase_heat",
	&"bed_window", &"table_focus", &"sconce_pair", &"shelf_over",
	&"chandelier_over", &"corner_clutter", &"focus"]

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}
## {rule: replacement name} for the rules a family replaced this run.
var replaced: Dictionary = {}
## Callables do not retain their target object in GDScript. Keep each rule
## group alive for the duration of RuleSet.run().
var _rule_owners: Array[RefCounted] = []


func check(plan: HousePlan, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	stats["furniture"] = plan.furniture.size()
	var report := {"failures": failures, "warnings": warnings, "stats": stats}
	replaced = RuleSet.run(self, RULES, _rule_handlers(report), overrides,
		[plan], [plan], failures, warnings)
	_rule_owners.clear()
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats, "groups": GROUPS, "replaced": replaced}


func _rule_handlers(report: Dictionary) -> Dictionary:
	var physical := HouseFurnishPhysicalCheck.new(report)
	var programme := HouseFurnishProgrammeCheck.new(report)
	var arrangement := HouseFurnishArrangementCheck.new(report)
	var spatial := HouseFurnishSpatialCheck.new(report)
	var affinity := HouseFurnishAffinityCheck.new(report)
	_rule_owners.assign([physical, programme, arrangement, spatial, affinity])
	return {
		&"placed": physical.check_placed,
		&"vertical": physical.check_vertical,
		&"supported": physical.check_supported,
		&"doorway": physical.check_doorways,
		&"daylight": physical.check_windows,
		&"programme": programme.check_program,
		&"against": arrangement.check_against_wall,
		&"seating": arrangement.check_seating,
		&"light": arrangement.check_light,
		&"density": arrangement.check_density,
		&"command": spatial.check_command_position,
		&"hearth": spatial.check_hearth,
		&"row": spatial.check_row,
		&"clear": arrangement.check_clear,
		&"workbench_daylight": affinity.check_workbench_daylight,
		&"bookcase_heat": affinity.check_bookcase_heat,
		&"bed_window": affinity.check_bed_window,
		&"table_focus": affinity.check_table_focus,
		&"sconce_pair": affinity.check_sconce_pair,
		&"shelf_over": affinity.check_shelf_over,
		&"chandelier_over": affinity.check_chandelier_over,
		&"corner_clutter": affinity.check_corner_clutter,
		&"focus": affinity.check_focus,
	}


static func who(plan: HousePlan, f: int) -> String:
	var p: Dictionary = plan.furniture[f]
	return "%s in room %d (%s)" % [p["key"], p["room"], String(plan.kind_of(p["room"]))]
