extends RefCounted
## Public API discovery, validation and spec resolution for vernacular styles.

const STYLE_IDS: Array[StringName] = [&"mediterranean", &"asian",
	&"thatch_cottage", &"pueblo"]

static func run() -> SuiteResult:
	var res := SuiteResult.new("cultural style API")
	var house_descriptor: Dictionary = BrickWild.describe_kind(&"house")
	var shop_descriptor: Dictionary = BrickWild.describe_kind(&"shop")
	var house_options: Array = house_descriptor.get("styles", [])
	var shop_options: Array = shop_descriptor.get("styles", [])
	var house_rows := {}
	var shop_rows := {}
	for row in house_options:
		house_rows[row["id"]] = row["label"]
	for row in shop_options:
		shop_rows[row["id"]] = row["label"]

	for style in STYLE_IDS:
		res.checked += 1
		if not house_rows.has(style) or not shop_rows.has(style):
			res.fail("house/shop descriptors do not publish %s" % String(style))
			continue
		var expected_label: String = String(HouseSpec.STYLES[style]["label"])
		if String(house_rows[style]) != expected_label or String(shop_rows[style]) != expected_label:
			res.fail("house/shop descriptor label differs for %s" % String(style))
		if BrickWild.option_label(&"house", &"style", style) != expected_label \
				or BrickWild.option_label(&"shop", &"style", style) != expected_label:
			res.fail("public style label lookup differs for %s" % String(style))

		var house_request := BrickWild.default_request(&"house", 8800 + STYLE_IDS.find(style))
		house_request.style = style
		res.checked += 1
		if not BuildingLibrary.validate(house_request).is_empty():
			res.fail("house request rejects published style %s" % String(style))
		else:
			var house: GeneratedBuilding = BrickWild.generate(house_request)
			res.checked += 1
			if not house.is_ok() or not (house.spec is HouseSpec) \
					or (house.spec as HouseSpec).style != style:
				res.fail("house generation did not resolve style %s" % String(style))

		var shop_request := BrickWild.default_request(&"shop", 9900 + STYLE_IDS.find(style))
		shop_request.style = style
		res.checked += 1
		if not BuildingLibrary.validate(shop_request).is_empty():
			res.fail("shop request rejects published style %s" % String(style))
		else:
			var shop: GeneratedBuilding = BrickWild.generate(shop_request)
			res.checked += 1
			if not shop.is_ok() or not (shop.spec is ShopSpec) \
					or (shop.spec as ShopSpec).style != style:
				res.fail("shop generation did not resolve style %s" % String(style))
	return res
