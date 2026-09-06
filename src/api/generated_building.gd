class_name GeneratedBuilding
extends RefCounted
## The engine-native representation produced by BigGlade.generate().
##
## `spec` remains family-specific. Houses, shops, and hotels additionally retain
## their HousePlan, because the plan -- not the shell mesh -- is their representation.

var request: BuildingRequest
var spec: RefCounted
var plan: HousePlan
## The village kind's own representation (VIL-019). A village is a plan of
## BigGlade buildings on lots, so it needs its own field rather than the
## house plan's -- and `representation()` hands back whichever a family
## actually filled.
var village: VillagePlan
var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []


func is_ok() -> bool:
	if not errors.is_empty() or request == null or spec == null:
		return false
	if spec is HouseSpec:
		return plan != null and plan.spec == spec
	return plan == null


func representation() -> RefCounted:
	if village != null:
		return village
	if plan != null:
		return plan
	return spec


func name() -> String:
	if spec == null:
		return ""
	return str(spec.get("variant_name"))
