extends RefCounted
## A house or shop on piles over shallow water (VTER-FORM-WATER, HousePiles).
##
##   the request contract: the ground (the default) serialises exactly as
##     before, piles round-trip and survive copy(), and the refusals: water
##     over HousePiles.MAX_WATER_M (`water_too_deep`), piles under a temple, a
##     fall under piles, an unknown foundation, pile fields without piles
##   foundation "" is vertex-identical to a request that never heard of it
##   the house on its ground is all still there, triangle for triangle: the
##     piles only ADD the deck, the bearers and the posts (the reference is the
##     same plan built with the foundation switched off)
##   every pile reaches through the water into the bed (its foot EMBED_M under
##     the bed) and stops under the bearers; nothing of the platform stands
##     above the floor
##   the deck's top is at y = 0 outside the entrance door and the landing
##     reaches pile_deck_m from the wall; every point of the deck is within a
##     pile spacing of a post
##   no yard; every facade piece set on the ground stands on the deck
##   component_check: every logged part is in the mesh
##   the bound contains every vertex, down to the piles' feet
##   the plan's own nav check passes

const WATERS := [0.5, 2.0, 4.0]
const TOL := 0.002


static func run() -> SuiteResult:
	var res := SuiteResult.new("hpiles")
	_contract(res)
	for kind in [&"house", &"shop"]:
		_family(res, kind)
	return res


static func _request(kind: StringName) -> BuildingRequest:
	if kind == &"shop":
		return BuildingRequest.shop(4410, &"general_store", &"townhouse", 11.0, 14.0, 2.8, 1)
	return BuildingRequest.house(8102, &"cottage", &"none", 8.0, 10.0, 2.6, 1)


static func _piled(kind: StringName, water: float, freeboard := 0.0, deck := 0.0) -> BuildingRequest:
	var r := _request(kind)
	r.foundation = &"piles"
	r.pile_water_m = water
	r.pile_freeboard_m = freeboard
	r.pile_deck_m = deck
	return r


# ------------------------------------------------------------- the contract

static func _contract(res: SuiteResult) -> void:
	var plain := _request(&"house")
	var grounded := _request(&"house")
	grounded.foundation = &""
	res.checked += 1
	if plain.to_json() != grounded.to_json() or plain.to_json().contains("pile") \
			or plain.to_json().contains("foundation"):
		res.fail("contract: a request on the ground must serialise exactly as before, without pile fields")
	var piled := _piled(&"house", 1.5, 2.0, 3.0)
	var back := BuildingRequest.from_json(piled.to_json())
	res.checked += 1
	if not back._decode_errors.is_empty() or back.foundation != &"piles" or back.pile_water_m != 1.5 \
			or back.pile_freeboard_m != 2.0 or back.pile_deck_m != 3.0 or back.to_json() != piled.to_json():
		res.fail("contract: foundation / pile_* do not round-trip")
	var copy := piled.copy()
	res.checked += 1
	if copy.foundation != &"piles" or copy.pile_water_m != 1.5 or copy.pile_freeboard_m != 2.0 \
			or copy.pile_deck_m != 3.0:
		res.fail("contract: copy() drops the piles")
	res.checked += 1
	if not BuildingLibrary.validate(piled).is_empty():
		res.fail("contract: a valid pile request is refused: %s" % BuildingLibrary.validate(piled))
	# the refusals, each with its code
	var cases := []
	cases.append(["5 m of water", _piled(&"house", 5.0), &"water_too_deep"])
	var temple := BuildingRequest.temple(5)
	temple.foundation = &"piles"
	cases.append(["a temple on piles", temple, &"unsupported_option"])
	var fall := _piled(&"house", 1.0)
	fall.ground_fall_m = 1.0
	cases.append(["piles on a fall", fall, &"unsupported_option"])
	var stilts := _request(&"house")
	stilts.foundation = &"stilts"
	cases.append(["an unknown foundation", stilts, &"invalid_ground"])
	var orphan := _request(&"house")
	orphan.pile_water_m = 1.0
	cases.append(["pile fields without piles", orphan, &"unsupported_option"])
	cases.append(["a negative depth", _piled(&"house", -1.0), &"invalid_ground"])
	cases.append(["a 0.2 m freeboard", _piled(&"house", 1.0, 0.2), &"invalid_ground"])
	for c in cases:
		res.checked += 1
		var errs: Array = BuildingLibrary.validate(c[1])
		if not _has_code(errs, c[2]):
			res.fail("contract: %s must be refused with %s, got %s" % [c[0], c[2], errs])
	var deep := BrickWild.generate(_piled(&"shop", 6.0))
	res.checked += 1
	if deep.is_ok():
		res.fail("contract: a shop in 6 m of water generated")
	else:
		res.note("6 m refused: %s" % deep.errors[0]["message"])


static func _has_code(errors: Array, code: StringName) -> bool:
	for e in errors:
		if StringName(e.get("code", "")) == code:
			return true
	return false


# -------------------------------------------------------------- the family

static func _family(res: SuiteResult, kind: StringName) -> void:
	var plain := BrickWild.generate(_request(kind))
	var zero_req := _request(kind)
	zero_req.foundation = &""
	var zero := BrickWild.generate(zero_req)
	res.checked += 1
	if not plain.is_ok() or not zero.is_ok() \
			or not _same_mesh(HouseBuilder.new().build(plain.plan), HouseBuilder.new().build(zero.plan)):
		res.fail("%s: foundation '' is not vertex-identical to a request without the field" % kind)
	for water in WATERS:
		for variant in [[0.0, 0.0], [2.0, 3.0]]:
			var req := _piled(kind, water, variant[0], variant[1])
			var label := "%s water %.1f m freeboard %s deck %s" % [kind, water,
				"default" if variant[0] == 0.0 else "%.1f" % variant[0],
				"default" if variant[1] == 0.0 else "%.1f" % variant[1]]
			var t0 := Time.get_ticks_msec()
			var made := BrickWild.generate(req)
			res.checked += 1
			if not made.is_ok():
				res.fail("%s: did not generate: %s" % [label, made.errors])
				continue
			_case(res, label, made)
			res.note("%s: %d ms" % [label, Time.get_ticks_msec() - t0])


static func _case(res: SuiteResult, label: String, made: GeneratedBuilding) -> void:
	var plan: HousePlan = made.plan
	var spec: HouseSpec = plan.spec
	var hb := HouseBuilder.new()
	var mesh := hb.build(plan)
	res.checked += 1
	if not HousePiles.on_piles(spec):
		res.fail("%s: the spec did not receive the foundation" % label)
		return

	# 1. the house on the ground is all still there: the same plan, built with
	#    the foundation switched off, is a subset of the pile house's triangles
	spec.foundation = &""
	var ground_mesh := HouseBuilder.new().build(plan)
	spec.foundation = &"piles"
	var missing := 0
	for s in mesh.get_surface_count():
		if s >= ground_mesh.get_surface_count():
			break
		var want := ComponentCheck._triangle_vertices(ground_mesh.surface_get_arrays(s))
		var have := ComponentCheck._triangle_vertices(mesh.surface_get_arrays(s))
		missing += ComponentCheck.missing_triangles(have, want)
	res.checked += 1
	if missing > 0:
		res.fail("%s: %d triangles of the house on the ground are gone" % [label, missing])

	# 2. the posts reach into the bed and stop under the bearers
	var foot := HousePiles.foot_y(spec)
	var bed := HousePiles.bed_y(spec)
	var under := -HousePiles.DECK_T - HousePiles.BEARER_H
	var posts := hb.components("pile")
	var bad_posts := 0
	var post_xz: Array[Vector2] = []
	for row in posts:
		if String(row["role"]) != "pile":
			continue
		var box := MassBuilder.component_aabb(row)
		post_xz.append(Vector2(box.get_center().x, box.get_center().z))
		if absf(box.position.y - foot) > TOL or absf(box.end.y - under) > TOL or box.position.y > bed - 0.5:
			bad_posts += 1
	res.checked += 2
	if post_xz.size() < 4:
		res.fail("%s: %d piles" % [label, post_xz.size()])
	if bad_posts > 0:
		res.fail("%s: %d piles do not run from %.2f (the bed %.2f less the embedment) to the bearers at %.2f"
			% [label, bad_posts, foot, bed, under])
	var above := 0
	for row in hb.components_of("piles"):
		if String(row["role"]) == "pile_ladder":
			continue
		if MassBuilder.component_aabb(row).end.y > 1e-4:
			above += 1
	res.checked += 1
	if above > 0:
		res.fail("%s: %d parts of the platform stand above the floor" % [label, above])

	# 3. the deck: at y = 0 outside the entrance, the landing to pile_deck_m,
	#    every point of it carried
	var rects := HousePiles.deck_rects(plan)
	var decks := hb.components("pile_deck")
	res.checked += 1
	if decks.size() != rects.size():
		res.fail("%s: %d deck parts for %d deck rectangles" % [label, decks.size(), rects.size()])
	var top := -INF
	for row in decks:
		top = maxf(top, MassBuilder.component_aabb(row).end.y)
	res.checked += 1
	if absf(top) > TOL:
		res.fail("%s: the deck's top is at %.3f, not at the floor's underside" % [label, top])
	var e := plan.entrance()
	if e >= 0:
		var door: Dictionary = plan.doors[e]
		var n: Vector2 = Vector2(door["normal"]).normalized()
		var reach := HousePiles.deck_reach(spec)
		# the wall's outer face under the door, where the landing is measured from
		var site := HouseGeometry.site_rect(spec)
		var face: Vector2 = Vector2(door["pos"])
		if absf(n.y) > 0.5:
			face.y = site.position.y if n.y < 0.0 else site.end.y
		else:
			face.x = site.position.x if n.x < 0.0 else site.end.x
		for d in [0.3, maxf(reach - 0.1, 0.3)]:
			var p: Vector2 = face + n * d
			res.checked += 1
			if not _on_deck(rects, p):
				res.fail("%s: no deck %.1f m out from the entrance (the landing reaches %.1f)" % [label, d, reach])
		res.checked += 1
		if _on_deck(rects, face + n * (maxf(reach, HousePiles.GALLERY_M) + 0.15)):
			res.fail("%s: the deck reaches past its own landing" % label)
	var worst := 0.0
	for r in rects:
		for k in range(0, 11):
			for j in range(0, 11):
				var p := r.position + r.size * Vector2(float(k) / 10.0, float(j) / 10.0)
				var near := INF
				for q in post_xz:
					near = minf(near, p.distance_to(q))
				worst = maxf(worst, near)
	res.checked += 1
	if worst > HousePiles.PILE_SPACING:
		res.fail("%s: a point of the deck is %.2f m from the nearest pile" % [label, worst])

	# 4. no yard; the facade pieces on the ground stand on the deck
	res.checked += 1
	if not plan.yard.is_empty() or not plan.yard_pieces.is_empty():
		res.fail("%s: a house on piles planned a yard (%d props, %d pieces)" % [label, plan.yard.size(), plan.yard_pieces.size()])
	var off_deck: Array[String] = []
	for row in plan.exterior:
		var pos: Vector3 = row["pos"]
		if bool(row.get("mounted", false)) or pos.y > 0.05:
			continue
		if not _on_deck(rects, Vector2(pos.x, pos.z)):
			off_deck.append(String(row.get("key", "?")))
	res.checked += 1
	if not off_deck.is_empty():
		res.fail("%s: facade pieces stand off the deck, over the water: %s" % [label, off_deck])

	# 5. every logged part is in the mesh; the bound holds every vertex
	var comp := ComponentCheck.check(hb, mesh)
	res.checked += 1
	if not comp["ok"]:
		res.fail("%s: component_check: %s" % [label, comp["failures"]])
	var bound := HouseGeometry.exterior_bounds(plan).grow(0.01)
	var outside := 0
	var first_out := Vector3.INF
	for s in mesh.get_surface_count():
		for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if not bound.has_point(v):
				outside += 1
				first_out = v if first_out == Vector3.INF else first_out
	res.checked += 1
	if outside > 0:
		res.fail("%s: %d vertices outside exterior_bounds %s, e.g. %s" % [label, outside, bound, first_out])

	# 6. the plan walks
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	res.checked += 1
	if not (nav["failures"] as Array).is_empty():
		res.fail("%s: nav: %s" % [label, nav["failures"]])
	res.note("%s: %d piles, %d deck parts, landing %.1f m, feet at %.2f" % [label, post_xz.size(),
		decks.size(), HousePiles.deck_reach(spec), foot])


static func _on_deck(rects: Array[Rect2], p: Vector2) -> bool:
	for r in rects:
		if r.grow(0.01).has_point(p):
			return true
	return false


static func _same_mesh(a: ArrayMesh, b: ArrayMesh) -> bool:
	if a.get_surface_count() != b.get_surface_count():
		return false
	for s in a.get_surface_count():
		var x: Array = a.surface_get_arrays(s)
		var y: Array = b.surface_get_arrays(s)
		if x[Mesh.ARRAY_VERTEX] != y[Mesh.ARRAY_VERTEX] or x[Mesh.ARRAY_INDEX] != y[Mesh.ARRAY_INDEX]:
			return false
	return true
