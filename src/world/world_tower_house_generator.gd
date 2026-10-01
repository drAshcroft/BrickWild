extends RefCounted
## Merchant's tower house, using the CAS-006 shaft and its INT-004 floor plan.

const FAMILY := &"tower_house"
const MERCHANT_TOWER := &"merchant_tower"


static func generate(kind: StringName, seed: int, width: float, length: float,
		height: float) -> CastleSpec:
	var spec := CastleSpec.new()
	spec.style = &"norman"
	spec.seed = seed
	spec.width = width
	spec.length = length
	spec.height = height
	spec.plan_override = &"tower_house"
	spec.tier_override = &"house"
	CastleGenerator.generate(spec, seed)
	spec.variant_name = "Merchant's Tower"
	return spec
