class_name ShopAssembler
extends RefCounted


static func build(plan: HousePlan, cutaway := false) -> Node3D:
	var root := HouseAssembler.build(plan, cutaway)
	root.name = "Shop"
	return root
