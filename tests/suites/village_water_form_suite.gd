extends RefCounted
## The `water` form (VTER-FORM-WATER; docs/VILLAGE_TERRAIN.md "The water
## form"): a fishing village standing in its shallows on piles, joined by
## boardwalks -- Ganvié, Kampong Ayer.
##
##   form        on the lagoon the ground derives `water` and the spec plans
##               it (no fallback); FORM_FALLBACK no longer maps water
##   boardwalks  at least two piers off the shore street and the far walk
##               joining them, every one a `path` with `"boardwalk"`, carried
##               over the water by crossings of kind `boardwalk`
##   piles       households on pile lots over the water, each request asked
##               for its lot's depth and a landing to its boardwalk
##               (VillageWaterCheck), every request valid
##   share       VillageShape's `over_water_share` over 0.5 (the acceptance:
##               Ganvié measures 0.542, Kampong Ayer 1.0)
##   walk        from a gate every door is walked to, the pile houses' over the
##               boardwalks and their landings (VillageNavCheck `arrive`, and
##               VillageWalk's export of the same ground); with the boardwalks'
##               decks taken away the pile houses cannot be reached (the control)
##   qa          VillageQA (scale, roads, lots, places, dressing, walking)
##   mesh        the village built and assembled: the boardwalks' components
##               are their triangles (ComponentCheck); every house on piles
##               stands at its deck over water with its piles in the bed and
##               no ground over the water under it or under a boardwalk, and
##               the rest of VillageGroundCheck
##   control     a pile building asked for no depth is caught (VillageWaterCheck)
##   export      form `water`, boardwalks and piles written
##   deep        on a shore whose water deepens at once (lake_shore, forced)
##               the shallows take no pier: the plan is the shore form, every
##               building dry
##   pure        the same spec on the same ground is the same site plan
##   flat        no terrain: a water spec plans as the straight strand
##
## `WATER_CASE=<fixture>` runs one case; `WATER_DUMP=1` prints the buildings.

const SYNTH := preload("res://tests/fixtures/terrain/synthetic_terrain.gd")
const EXPORTER := preload("res://tools/export_village_plan.gd")
const POPULATION := 50
const SEED := 4242
const SHARE_MIN := 0.5


static func run() -> SuiteResult:
	var res := SuiteResult.new("vwaterform")
	var t0 := Time.get_ticks_msec()
	var only := OS.get_environment("WATER_CASE")
	var jobs: Array[Dictionary] = VillageLotPlanner.measure_all(
		VillageProgrammer.programme(spec_for(null)))
	res.note("measured %d buildings once in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	if only.is_empty():
		_flat(res)
	if only.is_empty() or only == "lagoon":
		_lagoon(res, jobs)
	if only.is_empty() or only == "lake_shore":
		_deep(res, jobs)
	if only.is_empty():
		_pure(res)
	res.note("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return res


static func spec_for(ground: VillageTerrain, form := &"") -> VillageSpec:
	var s := VillageSpec.new(SEED)
	s.population = POPULATION
	s.purpose = &"fishing"
	s.water = &"lake"
	s.terrain = ground
	s.generate(SEED)
	if form != &"":
		s.form = form
	return s


# ----------------------------------------------------------------- the lagoon

static func _lagoon(res: SuiteResult, jobs: Array[Dictionary]) -> void:
	var name := "lagoon"
	var ground: VillageTerrain = SYNTH.make("lagoon")
	var spec := spec_for(ground)
	res.checked += 1
	if spec.form_intent != &"water" or spec.form != &"water":
		res.fail("%s: the ground derives '%s', planned '%s'; wants water, planned as itself"
			% [name, spec.form_intent, spec.form])
		return
	var t0 := Time.get_ticks_msec()
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	var plan_s := (Time.get_ticks_msec() - t0) / 1000.0
	res.checked += 1
	if plan.ground == null or plan.roads.is_empty() or plan.shoreline.is_empty():
		res.fail("%s: the plan was not sited on its shore" % name)
		return
	res.checked += 1
	if not EXPORTER.covers_plan(ground, plan):
		res.fail("%s: the sited site's corners leave the grid" % name)
	if OS.get_environment("WATER_DUMP") == "1":
		_dump(plan)

	# --- boardwalks
	var walks: Array[int] = []
	for r in range(plan.roads.size()):
		if VillageWaterForm.is_boardwalk(plan.roads[r]):
			walks.append(r)
	var carried := 0
	for c in plan.water_crossings:
		if c["kind"] == &"boardwalk":
			carried += 1
	res.checked += 2
	if walks.size() < 3:
		res.fail("%s: %d boardwalks; wants two piers and the far walk" % [name, walks.size()])
	if carried < walks.size():
		res.fail("%s: %d boardwalk crossings for %d boardwalks" % [name, carried, walks.size()])

	# --- piles and the share
	var water_check := VillageWaterCheck.new()
	var wr: Dictionary = water_check.check(plan)
	res.checked += 1
	if not wr["ok"]:
		res.fail("%s: VillageWaterCheck: %s" % [name, "; ".join((wr["failures"] as Array).slice(0, 4))])
	var piled: int = int(wr["stats"].get("pile_buildings", 0))
	var share: float = float(wr["stats"].get("over_water_share", 0.0))
	res.checked += 2
	if piled < 2:
		res.fail("%s: %d houses on piles" % [name, piled])
	if share <= SHARE_MIN:
		res.fail("%s: over_water_share %.3f, wants over %.2f" % [name, share, SHARE_MIN])
	res.checked += 1
	if plan.buildings.size() < jobs.size():
		res.fail("%s: %d of %d buildings placed" % [name, plan.buildings.size(), jobs.size()])

	# --- the walk: every door from a gate, over the boardwalks
	var nav := VillageNavCheck.new()
	var nr: Dictionary = nav.check(plan)
	res.checked += 1
	if int(nr["stats"].get("unreached_doors", -1)) != 0:
		res.fail("%s: %s doors cannot be walked to: %s" % [name, nr["stats"].get("unreached_doors"),
			"; ".join(nr["failures"] as Array)])
	var walk: Dictionary = VillageWalk.projection(plan, "test")
	var unreachable := 0
	var landed := 0
	for d in walk["doors"]:
		if not bool(d["reachable"]):
			unreachable += 1
	for f in walk["floor"]:
		if String(f["kind"]) == "landing":
			landed += 1
	res.checked += 2
	if unreachable > 0:
		res.fail("%s: the walk export has %d unreachable doors" % [name, unreachable])
	if landed != piled:
		res.fail("%s: the walk export has %d landings for %d houses on piles" % [name, landed, piled])
	_boardwalk_control(res, name, plan)

	# --- the village's own QA
	var t1 := Time.get_ticks_msec()
	var no_pure := func(_plan: VillagePlan) -> Array: return []
	var qa: Dictionary = VillageQA.new().check(plan, {&"pure": no_pure}, false)
	var qa_s := (Time.get_ticks_msec() - t1) / 1000.0
	res.checked += 1
	if not qa["ok"]:
		res.fail("%s: VillageQA: %s" % [name, "; ".join((qa["failures"] as Array).slice(0, 4))])

	# --- the control: a pile building asked for no depth
	_request_control(res, name, plan)

	# --- export
	var out: Dictionary = EXPORTER.site_plan(plan, {"name": name})
	res.checked += 1
	if String(out.get("form", "")) != "water" or String(out.get("form_intent", "")) != "water":
		res.fail("%s: the exporter writes form '%s' / '%s'" % [name, out.get("form"), out.get("form_intent")])
	res.checked += 1
	if not EXPORTER.form_intent_note(spec).is_empty():
		res.fail("%s: the exporter still notes a fallback: %s" % [name, EXPORTER.form_intent_note(spec)])
	var ex_walks := 0
	for r in out["roads"]:
		if (r as Dictionary).has("boardwalk"):
			ex_walks += 1
	var ex_piles := 0
	for l in out["lots"]:
		if (l as Dictionary).has("piles"):
			ex_piles += 1
	var ex_req := 0
	for b in out["buildings"]:
		if String((b["request"] as Dictionary).get("foundation", "")) == "piles":
			ex_req += 1
	res.checked += 1
	if ex_walks != walks.size() or ex_piles != piled or ex_req != piled:
		res.fail("%s: the exporter writes %d boardwalks (of %d), %d pile lots and %d pile requests (of %d)"
			% [name, ex_walks, walks.size(), ex_piles, ex_req, piled])

	# --- the mesh: built, assembled, judged
	t1 = Time.get_ticks_msec()
	var builder := VillageBuilder.new()
	var mesh := builder.build(plan)
	var comp: Dictionary = ComponentCheck.check(builder, mesh)
	res.checked += 2
	if not comp["ok"]:
		res.fail("%s: the boardwalks' components differ from their triangles: %s" % [name, str(comp.get("failures", comp)).left(300)])
	var decks := builder.components("boardwalk_deck").size()
	var posts := builder.components("boardwalk_pile").size()
	var ramps := builder.components("boardwalk_ramp").size()
	if decks < walks.size() or posts < 20 or ramps < 2:
		res.fail("%s: %d deck parts, %d posts, %d ramps for %d boardwalks" % [name, decks, posts, ramps, walks.size()])
	var scene: Node3D = VillageAssembler.build(plan)
	var assemble_s := (Time.get_ticks_msec() - t1) / 1000.0
	var gc := VillageGroundCheck.new()
	var gr: Dictionary = gc.check(plan, scene)
	res.checked += 1
	for f in (gr["failures"] as Array).slice(0, 10):
		res.fail("%s: ground: %s" % [name, f])
	var gs: Dictionary = gr["stats"]
	res.checked += 1
	if int(gs.get("pile_houses", 0)) != piled or int(gs.get("boardwalk_crossings", 0)) < walks.size():
		res.fail("%s: the ground check judged %d houses on piles (of %d) and %d boardwalk crossings"
			% [name, int(gs.get("pile_houses", 0)), piled, int(gs.get("boardwalk_crossings", 0))])
	var pile_parts := 0
	for node in scene.get_node("Buildings").get_children():
		if node.get_meta(&"piles", false):
			pile_parts += 1
	res.checked += 1
	if pile_parts != piled:
		res.fail("%s: %d assembled buildings are marked on piles, %d planned" % [name, pile_parts, piled])
	scene.free()

	var land := plan.buildings.size() - piled
	res.note("%-10s %s | %d boardwalks (%d crossings) | %d on piles, %d on land, over_water_share %.3f | piles %d deck parts %d posts %d ramps | ground over water under piles %.3f m, feet short %.3f m | site %s yaw %.0f | plan %.1f s, qa %.1f s, mesh+scene %.1f s"
		% [name, spec.form, walks.size(), carried, piled, land, share, decks, posts, ramps,
			float(gs.get("pile_ground_over_water", 0.0)), float(gs.get("pile_foot_short", 0.0)),
			plan.site, rad_to_deg(plan.site_yaw), plan_s, qa_s, assemble_s])


## Without the boardwalks' decks (their crossings taken away, the water
## left) the houses on piles are not reached: it is the boardwalks, not the
## water, that carry the walk to their doors.
static func _boardwalk_control(res: SuiteResult, name: String, plan: VillagePlan) -> void:
	var kept: Array[Dictionary] = plan.water_crossings.duplicate()
	var dry: Array[Dictionary] = []
	for c in kept:
		if c["kind"] != &"boardwalk":
			dry.append(c)
	plan.water_crossings = dry
	var r: Dictionary = VillageNavCheck.new().check(plan)
	plan.water_crossings = kept
	var piled := 0
	for lot in plan.lots:
		if lot.has("piles"):
			piled += 1
	res.checked += 1
	if int(r["stats"].get("unreached_doors", 0)) < piled:
		res.fail("%s: control: with no boardwalk decks only %d doors are unreached, %d houses stand on piles"
			% [name, int(r["stats"].get("unreached_doors", 0)), piled])
	else:
		res.note("%s: control: without the boardwalks %d doors are unreached" % [name, int(r["stats"].get("unreached_doors", 0))])


## A pile building whose request lost its depth is caught.
static func _request_control(res: SuiteResult, name: String, plan: VillagePlan) -> void:
	for b in plan.buildings:
		if not plan.lots[int(b["lot"])].has("piles"):
			continue
		var keep: BuildingRequest = b["request"]
		var bad := keep.copy()
		bad.pile_water_m = 0.0
		b["request"] = bad
		var r: Dictionary = VillageWaterCheck.new().check(plan)
		b["request"] = keep
		res.checked += 1
		if r["ok"]:
			res.fail("%s: control: a pile house asked for no depth passed VillageWaterCheck" % name)
		return


# ------------------------------------------------------------ the deep shore

## lake_shore falls 8 % into its lake: 3.5 m of water 44 m out. No pier is
## laid; the water form is the shore form, every building on dry ground.
static func _deep(res: SuiteResult, jobs: Array[Dictionary]) -> void:
	var name := "lake_shore (forced water)"
	var spec := spec_for(SYNTH.make("lake_shore"), &"water")
	var t0 := Time.get_ticks_msec()
	var plan := VillageLotPlanner.plan_measured(spec, jobs)
	var plan_s := (Time.get_ticks_msec() - t0) / 1000.0
	res.checked += 1
	if plan.ground == null or plan.shoreline.is_empty():
		res.fail("%s: not sited on its shore" % name)
		return
	var walks := 0
	for road in plan.roads:
		if VillageWaterForm.is_boardwalk(road):
			walks += 1
	var piled := 0
	var wet := 0
	for b in plan.buildings:
		if plan.lots[int(b["lot"])].has("piles"):
			piled += 1
		for w in plan.water:
			if bool(w.get("ground", false)) and VillageLotPlanner.overlap_area(VillageMeasure.footprint_poly(b), w["poly"]) > 0.05:
				wet += 1
	res.checked += 2
	if walks > 0 or piled > 0:
		res.fail("%s: %d boardwalks and %d houses on piles in water too deep for them" % [name, walks, piled])
	if wet > 0:
		res.fail("%s: %d buildings stand on the water" % [name, wet])
	var no_pure := func(_plan: VillagePlan) -> Array: return []
	var qa: Dictionary = VillageQA.new().check(plan, {&"pure": no_pure}, false)
	res.checked += 1
	if not qa["ok"]:
		res.fail("%s: VillageQA: %s" % [name, "; ".join((qa["failures"] as Array).slice(0, 4))])
	res.note("%s: %d buildings, all dry, no boardwalks | plan %.1f s" % [name, plan.buildings.size(), plan_s])


# ---------------------------------------------------------- flat and purity

static func _flat(res: SuiteResult) -> void:
	var flat := spec_for(null, &"water")
	var plan := VillageSitePlanner.plan(flat)
	res.checked += 1
	if not plan.shoreline.is_empty() or plan.roads.is_empty() or plan.water.is_empty():
		res.fail("flat: a water spec with no ground did not plan as the straight strand")
	res.checked += 1
	if VillageSpec.FORM_FALLBACK.has(&"water"):
		res.fail("flat: FORM_FALLBACK still maps water")
	res.checked += 1
	if not (&"water" in VillageSitePlanner.FORMS_SUPPORTED):
		res.fail("flat: FORMS_SUPPORTED lacks water")
	res.checked += 1
	if spec_for(null).form == &"water":
		res.fail("flat: a spec with no ground derived the water form")


static func _pure(res: SuiteResult) -> void:
	var a := VillageSitePlanner.plan(spec_for(SYNTH.make("lagoon")))
	VillageShoreForm.clear_cache()
	VillageSiting.clear_cache()
	var b := VillageSitePlanner.plan(spec_for(SYNTH.make("lagoon")))
	res.checked += 1
	if not a.equals(b):
		res.fail("pure: the same spec on the same ground planned twice gave two site plans")


static func _dump(plan: VillagePlan) -> void:
	print("site %s anchor %s yaw %.1f" % [plan.site, plan.site_anchor, rad_to_deg(plan.site_yaw)])
	for r in range(plan.roads.size()):
		var road: Dictionary = plan.roads[r]
		print("road %d %s %s %s" % [r, road["class"], "boardwalk" if VillageWaterForm.is_boardwalk(road) else "", road["points"]])
	for i in range(plan.buildings.size()):
		var b: Dictionary = plan.buildings[i]
		var req: BuildingRequest = b["request"]
		var lot: Dictionary = plan.lots[int(b["lot"])]
		print("b%02d %s %s/%s road %d %s %s" % [i, b["class"], req.kind, req.style, int(lot["road"]),
			VillageMeasure.centre(VillageMeasure.footprint_poly(b)),
			("piles %.2f m, landing %.2f" % [float(lot["piles"]["water_m"]), float(lot["piles"]["reach_m"])]) if lot.has("piles") else "land"])
