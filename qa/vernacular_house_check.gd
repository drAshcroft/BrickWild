class_name VernacularHouseCheck
extends RefCounted
## What makes a VERNACULAR house vernacular, measured over what the builder
## actually emitted (HOUSE-CULTURE).
##
## Six of the styles in `HouseSpec.STYLES` are a timber cottage with the
## colours changed. The other five are not: a limewashed tile house, a stilted
## timber house under one very deep roof, a thatched compound house, a thatched
## cottage, a mud hut. Each of those five owes at least one PIECE of
## architecture the European six have no name for -- an eaves parapet, a
## veranda, an upturned eave, a combed thatch roll, a rounded mud corner, and a
## cone over the plan rather than a ridge along it.
##
## That is what this file holds them to. A switch the spec asked for and the
## builder did not emit fails here; so does a piece in the wrong place, in the
## wrong number, or on a roof that has nothing to carry it. The two rules about
## the class rather than the pieces are `european` and `declared`: `european`
## proves the six European styles still emit nothing at all, and `declared`
## stops "vernacular" from becoming a label on a cottage.
##
## Every piece is a NAMED COMPONENT in `MassBuilder.component_log`, which is the
## same evidence exterior QA re-emits against the mesh, so a piece that is
## logged but never built fails here for exactly the reason it fails there.
##
## report = {"ok": bool, "failures": [...], "warnings": [...], "stats": {...}}

## The named rules, in the order they run. A culture that is a correct building
## and breaks one replaces it through `overrides` rather than switching it off
## (RuleSet, INT-020), exactly as `RichHouseCheck` does.
const RULES: Array[StringName] = [&"european", &"declared", &"parapet", &"veranda",
	&"sweep", &"thatch", &"cone", &"piers"]

## The five style-row switches that make a house vernacular, and the component
## role each one owes. Kept here so the check names the whole vocabulary in one
## place and the suite can require every cell of it to be exercised.
const SWITCHES := {
	"parapet": &"parapet",
	"veranda": &"veranda_deck",
	"eave_sweep": &"eave_sweep",
	"thatch_roll": &"thatch_eave",
	"corner_piers": &"corner_pier",
}

## How close a piece has to be to where it belongs, in metres. A millimetre is a
## rounding difference; a centimetre is a piece in the wrong place.
const PLACE_TOL := 0.01

var failures: Array[String] = []
var warnings: Array[String] = []
var stats: Dictionary = {}


func check(plan: HousePlan, builder: HouseBuilder, overrides: Dictionary = {}) -> Dictionary:
	failures.clear()
	warnings.clear()
	stats.clear()
	stats["style"] = String(plan.spec.style)
	stats["culture"] = _row(plan.spec).has("culture")
	RuleSet.run(self, RULES, {}, overrides, [plan, builder], [plan, builder],
		failures, warnings)
	return _report()


func _report() -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures, "warnings": warnings,
		"stats": stats}


## This spec's own row in the style table.
static func _row(spec: HouseSpec) -> Dictionary:
	return HouseSpec.STYLES.get(spec.style, {})


## Is `role` one of this vocabulary's pieces, whole or prefixed?
static func _is_culture_role(role: String) -> bool:
	return role == "parapet" or role == "corner_pier" or role == "thatch_eave" \
		or role.begins_with("eave_sweep") or role.begins_with("thatch_roll_") \
		or role == "veranda_deck" or role == "veranda_post" or role == "veranda_beam" \
		or role.begins_with("veranda_roof_")


## Every component of the culture vocabulary, whatever host it sits on.
static func _vocabulary(builder: HouseBuilder) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in builder.component_log:
		if _is_culture_role(String(row.get("role", ""))):
			out.append(row)
	return out


## Every component whose role starts with `prefix`.
static func _prefixed(builder: HouseBuilder, prefix: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in builder.component_log:
		if String(row.get("role", "")).begins_with(prefix):
			out.append(row)
	return out


# ----------------------------------------------------------------- the rules

## The European styles emit NOTHING from this vocabulary. This is the rule that
## makes "vernacular" mean something: a style added to the table that quietly
## started emitting parapets is noticed here and nowhere else.
func _check_european(plan: HousePlan, builder: HouseBuilder) -> void:
	if _row(plan.spec).has("culture"):
		return
	var leaked := _vocabulary(builder)
	if not leaked.is_empty():
		failures.append("european: %s is not a vernacular style but emitted %d culture components"
			% [String(plan.spec.style), leaked.size()])
	stats["european_leaked"] = leaked.size()


## A style row that claims the vocabulary must actually ask for something. A row
## carrying `"culture": 1.0` and five zeros is a cottage with a foreign name, and
## no amount of geometry will make it anything else.
func _check_declared(plan: HousePlan, builder: HouseBuilder) -> void:
	var row := _row(plan.spec)
	if not row.has("culture"):
		return
	var asked := 0
	for key in SWITCHES:
		if float(row.get(key, 0.0)) > 0.0:
			asked += 1
	if asked == 0:
		failures.append("declared: %s claims a vernacular vocabulary and asks for no piece of it"
			% String(plan.spec.style))
	stats["declared_switches"] = asked


## A parapet stands on the roof eave on EVERY elevation, with its outer face ON
## that eave rather than past it -- which is why it costs the plan bound nothing.
## A cone has no eave to carry a wall, and HouseGenerator drops the request for
## one; the rule checks both halves, because a parapet that was asked for and
## silently dropped and one that was never asked for are different defects.
func _check_parapet(plan: HousePlan, builder: HouseBuilder) -> void:
	var spec := plan.spec
	var rows := builder.components("parapet")
	if not spec.parapet:
		if not rows.is_empty():
			failures.append("parapet: none asked for, %d emitted" % rows.size())
		return
	if spec.roof_type == &"conical":
		failures.append("parapet: a conical roof has no eave to stand a wall on")
		return
	var level: int = maxi(int(spec.storeys) - 1, 0)
	var runs: int = HouseGeometry.shell_runs(plan, level).size()
	if rows.size() < runs:
		failures.append("parapet: %d pieces for %d elevations" % [rows.size(), runs])
	# The wall reaches the eave and stops there. The roof's own oversail is
	# added to the site rectangle on both axes, and the parapet's world AABB has
	# to land on it to within PLACE_TOL -- which also proves nothing reached
	# past the eave, because the pieces are the only thing being measured.
	var over := HouseGeometry.roof_oversail(spec)
	var want := HouseGeometry.site_rect(spec, level)
	want = want.grow_individual(over.x, over.y, over.x, over.y)
	var got := _union_plan_rect(rows)
	if not _rect_close(got, want, PLACE_TOL):
		failures.append("parapet: the wall stands at x %.3f..%.3f z %.3f..%.3f, the eave is at x %.3f..%.3f z %.3f..%.3f"
			% [got.position.x, got.end.x, got.position.y, got.end.y,
				want.position.x, want.end.x, want.position.y, want.end.y])
	stats["parapet"] = rows.size()


## A veranda is a house part, not a porch: a deck on the ground, at least
## VERANDA_POSTS posts, a head beam, and a shed rooflet over all three -- and it
## stands on the wall the entrance is actually on. That last clause catches the
## defect this rule was written for: a veranda built in local coordinates and
## never placed is a veranda in the middle of the house with a correct bound.
func _check_veranda(plan: HousePlan, builder: HouseBuilder) -> void:
	var spec := plan.spec
	var decks := builder.components("veranda_deck")
	var posts := builder.components("veranda_post")
	var beams := builder.components("veranda_beam")
	var roofs := _prefixed(builder, "veranda_roof_")
	if not spec.veranda:
		if not decks.is_empty() or not posts.is_empty() or not roofs.is_empty():
			failures.append("veranda: none asked for, %d components emitted"
				% (decks.size() + posts.size() + roofs.size()))
		return
	if decks.size() != 1:
		failures.append("veranda: %d decks, a house has one front" % decks.size())
		return
	if posts.size() < HouseGeometry.VERANDA_POSTS:
		failures.append("veranda: %d posts, the vocabulary is %d"
			% [posts.size(), HouseGeometry.VERANDA_POSTS])
	if beams.size() != 1:
		failures.append("veranda: %d head beams, one veranda has one" % beams.size())
	if roofs.is_empty():
		failures.append("veranda: a deck and posts under open sky is a balcony")
	var d: int = plan.entrance()
	if d < 0:
		failures.append("veranda: the house has no front door to stand against")
		return
	var door: Dictionary = plan.doors[d]
	var n: Vector2 = door["normal"]
	var want: Vector2 = door["pos"] + n * (HouseGeometry.wall_thickness(spec) * 0.5
		+ spec.veranda_depth * 0.5)
	var got: Vector3 = (decks[0]["xf"] as Transform3D).origin
	if Vector2(got.x, got.z).distance_to(want) > PLACE_TOL:
		failures.append("veranda: the deck stands at (%.2f, %.2f), the front door is at (%.2f, %.2f)"
			% [got.x, got.z, want.x, want.y])
	stats["veranda_posts"] = posts.size()


## The eave sweep is a fin at each of the four roof CORNERS, and a corner fin on
## an ordinary 0.35 m eave is a fin, not a sweep: the style row is required to
## have widened the roof, because the deep eave is what the sweep is for.
func _check_sweep(plan: HousePlan, builder: HouseBuilder) -> void:
	var spec := plan.spec
	var fins := _prefixed(builder, "eave_sweep")
	if not spec.eave_sweep:
		if not fins.is_empty():
			failures.append("sweep: none asked for, %d fins emitted" % fins.size())
		return
	if fins.size() != 4:
		failures.append("sweep: %d corner fins, a roof has four corners" % fins.size())
		return
	var over := HouseGeometry.roof_oversail(spec)
	if over.x <= HouseGeometry.ROOF_SPAN_OUT:
		failures.append("sweep: the eave oversails by %.2f m, the ordinary one by %.2f m; a sweep on an ordinary eave is a fin"
			% [over.x, HouseGeometry.ROOF_SPAN_OUT])
	var layout := HouseGeometry.roof_layout(plan)
	var xf: Transform3D = layout["transform"]
	var half := _roof_half(spec, layout)
	var run: float = HouseGeometry.SWEEP_RUN + PLACE_TOL
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner: Vector3 = xf * Vector3(float(sx) * half.x, 0.0, float(sz) * half.y)
			var found := false
			for fin in fins:
				for p in (fin["points"] as PackedVector3Array):
					if Vector2(p.x - corner.x, p.z - corner.z).length() <= run:
						found = true
			if not found:
				failures.append("sweep: no fin at the roof corner (%.2f, %.2f)"
					% [corner.x, corner.z])
	stats["sweep_fins"] = fins.size()


## Combed thatch: a thick rolled bundle capping BOTH eaves, and -- on a roof
## that has a ridge at all -- bundles along it. A roll on a cone is impossible,
## so the ridge half is required only where a ridge exists.
##
## The negative half matters as much: thatch has no verge board. A board is a
## thing that holds ON slates or tiles, and a thatcher finishes a gable by
## turning the reeds down and wiring them. A thatched gable that grew a board is
## a slate roof wearing a straw colour.
func _check_thatch(plan: HousePlan, builder: HouseBuilder) -> void:
	var spec := plan.spec
	var eaves := builder.components("thatch_eave")
	var rolls := _prefixed(builder, "thatch_roll_")
	if not spec.thatch_roll:
		if not eaves.is_empty() or not rolls.is_empty():
			failures.append("thatch: none asked for, %d roll pieces emitted"
				% (eaves.size() + rolls.size()))
		return
	if eaves.size() != 2:
		failures.append("thatch: %d eave rolls, a roof has two eaves" % eaves.size())
	var ridged: bool = HouseGeometry.ridge_half(spec) > 0.05
	if ridged and rolls.is_empty():
		failures.append("thatch: a roll on the eave and none along a %.2f m ridge"
			% HouseGeometry.ridge_half(spec))
	if not ridged and not rolls.is_empty():
		failures.append("thatch: %d ridge rolls on a roof with no ridge" % rolls.size())
	if not builder.components("verge_board").is_empty():
		failures.append("thatch: a thatched roof grew a verge board")
	stats["thatch_rolls"] = rolls.size()


## The cone. This is the one shape none of the European roofs can be, and the
## test reads the EMITTED FACES rather than re-deriving them from the spec.
##
## That distinction is the whole rule. `HouseGeometry.roof_layout` is a pure
## function of the spec, so a check that asked it what the roof was would only
## ever learn what the plan already claimed -- and would sit silent through a
## builder that laid something else entirely. The faces in
## `builder.roof_components` are what went into the mesh.
##
## A cone is `CONE_SIDES` facets all meeting at ONE point. A gable's two faces
## share two points, which is a ridge. A hip's four share two at the ridge and
## one at each hip end, so no point is in all of them; a hip on a square plan
## does collapse to four triangles on one point, and the face count is what
## tells that from a cone.
##
## The corollary is required too: no ridge cap and no finial on a roof with no
## ridge, because a cap on a cone is a bar laid across the top of a point.
func _check_cone(plan: HousePlan, builder: HouseBuilder) -> void:
	var spec := plan.spec
	var groups := _roof_faces(builder)
	if groups.size() < 2:
		return          # one face is a shed, and is no evidence either way
	var shared: Array[Vector3] = []
	for p in _first(groups):
		var on_every := true
		for face in groups.values():
			if not _has_point(face, p):
				on_every = false
				break
		if not on_every or _has_point(PackedVector3Array(shared), p):
			continue
		shared.append(p)
	var coned: bool = shared.size() == 1 and groups.size() == RoofShape.CONE_SIDES
	if spec.roof_type == &"conical":
		if not coned:
			failures.append("cone: %d facets sharing %d points; a cone is %d facets on one"
				% [groups.size(), shared.size(), RoofShape.CONE_SIDES])
		if not builder.components("ridge_cap").is_empty():
			failures.append("cone: a ridge cap was laid across a point")
		if not builder.components("ridge_crown").is_empty():
			failures.append("cone: a finial was set on a point with no ridge to stand on")
		if HouseGeometry.ridge_half(spec) > 0.05:
			failures.append("cone: ridge_half is %.2f on a roof with no ridge"
				% HouseGeometry.ridge_half(spec))
	elif coned:
		failures.append("cone: a %s roof was built as %d facets on one point; only a cone is that"
			% [String(spec.roof_type), groups.size()])
	stats["cone_faces"] = groups.size()


## The emitted roof faces, grouped by the face index the builder numbered them
## with. One face can be several components -- a dormer or an authored opening
## cuts it into pieces -- and those pieces belong to the same face.
static func _roof_faces(builder: HouseBuilder) -> Dictionary:
	var out := {}
	for row in builder.roof_components:
		var role := String(row.get("role", ""))
		if not role.begins_with("roof_face_"):
			continue
		var key := role.substr("roof_face_".length())
		# A Packed array is a VALUE in GDScript: appending to `out[key]` in
		# place leaves the dictionary holding the empty array it started with,
		# and every face then compares equal to no points at all.
		var acc: PackedVector3Array = out.get(key, PackedVector3Array())
		acc.append_array(row["points"])
		out[key] = acc
	return out


static func _first(groups: Dictionary) -> PackedVector3Array:
	for key in groups:
		return groups[key]
	return PackedVector3Array()


## Is `at` a vertex of `points`, within a millimetre?
static func _has_point(points: PackedVector3Array, at: Vector3) -> bool:
	for p in points:
		if p.distance_to(at) <= 0.001:
			return true
	return false



## Rounded mud corners: one pier per corner of each storey, and ROUND. A square
## pier is a post, and a daub wall's corners are the first thing the rain takes
## and the first thing rebuilt -- as a round pier, because a round corner sheds
## the water that took the square one.
func _check_piers(plan: HousePlan, builder: HouseBuilder) -> void:
	var spec := plan.spec
	var piers := builder.components("corner_pier")
	if not spec.corner_piers:
		if not piers.is_empty():
			failures.append("piers: none asked for, %d emitted" % piers.size())
		return
	var wanted: int = 4 * maxi(int(spec.storeys), 1)
	if piers.size() != wanted:
		failures.append("piers: %d piers for %d storey corners" % [piers.size(), wanted])
	for pier in piers:
		var pts: PackedVector3Array = pier["points"]
		if pts.size() != HouseGeometry.PIER_SIDES:
			failures.append("piers: a pier is a %d-gon; %d points is not round"
				% [HouseGeometry.PIER_SIDES, pts.size()])
			break
	stats["piers"] = piers.size()


# ------------------------------------------------------------------ helpers

## The roof's plan half-extents, span first -- the same resolution
## HouseBuilder._roof_half uses, read from the layout the builder laid out.
static func _roof_half(spec: HouseSpec, layout: Dictionary) -> Vector2:
	var over := HouseGeometry.roof_oversail(spec)
	return Vector2(float(layout["span"]) * 0.5 + over.x,
		float(layout["along"]) * 0.5 + over.y)


## The world AABB of a box component. The basis is orthonormal, so the world
## half-extent along an axis is the sum of the absolute basis terms times half
## the box's own size.
static func _box_aabb(row: Dictionary) -> AABB:
	var xf: Transform3D = row["xf"]
	var half_size: Vector3 = (row["size"] as Vector3) * 0.5
	var cols: Array[Vector3] = [xf.basis.x, xf.basis.y, xf.basis.z]
	var half := Vector3.ZERO
	for axis in 3:
		var acc := 0.0
		for i in 3:
			acc += absf(cols[i][axis]) * half_size[i]
		half[axis] = acc
	return AABB(xf.origin - half, half * 2.0)


## The union of a set of box components, as a plan rectangle (x against z).
static func _union_plan_rect(rows: Array[Dictionary]) -> Rect2:
	var out := Rect2()
	for i in rows.size():
		var a := _box_aabb(rows[i])
		var piece := Rect2(Vector2(a.position.x, a.position.z), Vector2(a.size.x, a.size.z))
		out = piece if i == 0 else out.merge(piece)
	return out


static func _rect_close(a: Rect2, b: Rect2, tol: float) -> bool:
	return a.position.distance_to(b.position) <= tol \
		and Vector2(a.size.x, a.size.y).distance_to(Vector2(b.size.x, b.size.y)) <= tol
