class_name ShopFurnisher
extends RefCounted
## Occupational wrapper around the shared rule-based furniture placer.


static func furnish(plan: HousePlan, spec: ShopSpec) -> void:
	HouseFurnisher.furnish(plan, spec)
