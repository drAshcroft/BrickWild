class_name HouseFurnishPlacement
extends RefCounted
## Candidate construction and placement rules for furnished rooms.

## These bounds keep a large hall from turning a placement search into a
## quarter million floor probes.
const WALL_ESSENTIAL := ["bed", "hearth", "bookcase", "nightstand", "chest"]
const PROBE_STEP := 0.12
const MAX_PROBES := 128
const SCALE_STEPS := [1.0, 0.88, 0.76, 0.62]
const BAR_FRACTION := 0.55

## Vertical origin of a room. Older hand-authored plans have no `storey`, so
## they remain ordinary ground-floor plans.
static func _storey_base(plan: HousePlan, room: int) -> float:
	if room < 0 or room >= plan.rooms.size():
		return 0.0
	return float(HousePlan.record_storey(plan.rooms[room])) * plan.spec.height


static func _seating_probe(plan: HousePlan, room: int, table: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2]) -> Dictionary:
	var probe := HousePlan.new()
	probe.spec = plan.spec
	probe.rooms = plan.rooms
	probe.doors = plan.doors
	probe.windows = plan.windows
	# The candidate table is the only host being tested. Existing counters or
	# workbenches remain in blocked, but must not steal this trial's chair.
	var occupied := blocked.duplicate()
	var used := zones.duplicate()
	_commit(probe, room, table.duplicate(), occupied, used)
	var count := probe.furniture.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	for key in PropCatalog.of_category("seat"):
		_place_around(probe, room, key, occupied, used, rng)
		if probe.furniture.size() > count:
			var seat: Dictionary = probe.furniture[-1].duplicate()
			seat["pos"].y = 0.0 # the final commit supplies the room elevation
			return seat
	return {}


## Is there already something in this room that the room could not do without?
static func _has_other_must(plan: HousePlan, room: int) -> bool:
	for f in plan.furniture_of(room):
		if plan.furniture[f].get("must", false):
			return true
	return false


## Could this room take a piece of that kind AT ALL -- in an empty version of
## itself, with only its doors to work round?
##
## The furnishing check needs to tell "the generator failed to place a bed"
## from "no bed will fit in this room", and the only honest way to answer that
## is to run the real placer on an empty copy of the room. A rule of thumb
## about areas gets it wrong in exactly the rooms that matter: the small ones
## with two doors in them.
static func could_place(plan: HousePlan, room: int, cat: String) -> bool:
	var choices: Array[String] = PropCatalog.of_category(cat)
	if choices.is_empty():
		return false
	var probe := HousePlan.new()
	probe.spec = plan.spec
	probe.rooms = plan.rooms
	probe.doors = plan.doors
	probe.windows = plan.windows
	probe.hearth = plan.hearth.duplicate(true)
	if cat == "hearth":
		probe.hearth.erase("breast")
	probe.focus = plan.focus.duplicate()
	probe.furniture = []
	var r := RandomNumberGenerator.new()
	r.seed = 1
	var blocked: Array[Rect2] = _initial_blocked(probe, room)
	var zones: Array[Rect2] = []
	for key in choices:
		var before: int = probe.furniture.size()
		# a bed, a hearth or a bookcase is only ever placed against a wall
		# (WALL_ESSENTIAL): a room that could take one in its middle and
		# nowhere else cannot take one
		var rules: Array = [&"wall"] if cat in WALL_ESSENTIAL else [&"wall", &"free", &"corner"]
		for rule in rules:
			match rule:
				&"wall":
					_place_against_wall(probe, room, key, blocked, zones, r)
				&"free":
					_place_free(probe, room, key, blocked, zones, r)
				&"corner":
					_place_corner(probe, room, key, blocked, zones, r)
			if probe.furniture.size() > before:
				return true
	return false


## The floor that is spoken for before any furniture arrives: the swing of
## every door into this room, and a strip in front of every window.
static func _initial_blocked(plan: HousePlan, room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var breast := HouseGeometry.hearth_breast(plan)
	if not breast.is_empty() and int(breast["room"]) == room:
		out.append(breast["rect"])
	# Floor the plan itself keeps clear -- a screens passage, a processional
	# aisle. It is occupied ground before the first piece is placed, so a
	# passage the plan drew is a passage the furnishing cannot fill in.
	out.append_array(plan.zones_of(room))
	for d in plan.doors_of(room):
		var door: Dictionary = plan.doors[d]
		for side in [-1.0, 1.0]:
			out.append(HouseGeometry.door_clear_rect(door, side))
	# A stair landing is circulation infrastructure, not furniture space. Keep
	# both landings clear while placing rooms on either end of the stair.
	for stair in plan.stairs:
		if int(stair.get("a", -1)) == room:
			if stair.has("lower_rect"):
				out.append(Rect2(stair["lower_rect"]))
			elif stair.has("rect"):
				out.append(Rect2(stair["rect"]))
		if int(stair.get("b", -1)) == room:
			if stair.has("upper_rect"):
				out.append(Rect2(stair["upper_rect"]))
			elif stair.has("rect"):
				out.append(Rect2(stair["rect"]))
	return out


## Windows only block furniture that would stand IN them. A chest under a
## window is fine; a bookcase across it is not.
static func _window_blocks(plan: HousePlan, room: int, key: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if PropCatalog.height(key) <= HouseGeometry.WINDOW_SILL:
		return out
	for w in plan.windows_of(room):
		out.append(HouseGeometry.window_clear_rect(plan.windows[w]))
	return out


static func _place_one(plan: HousePlan, spec: HouseSpec, room: int, cat: String,
		rule: StringName, blocked: Array[Rect2], zones: Array[Rect2],
		r: RandomNumberGenerator, step: Dictionary = {}) -> void:
	var choices: Array[String] = PropCatalog.of_category(cat)
	if choices.is_empty():
		return
	var key: String = choices[r.randi_range(0, choices.size() - 1)]
	var before_place: int = plan.furniture.size()
	match rule:
		&"wall":
			var had: int = plan.furniture.size()
			_place_against_wall(plan, room, key, blocked, zones, r)
			if plan.furniture.size() == had and not cat in WALL_ESSENTIAL:
				# no wall will take it. A workbench can stand out in the room --
				# a bed cannot, which is what WALL_ESSENTIAL is for -- and the
				# placement records that it did, so the check that wants a wall
				# behind it knows why there is none.
				_place_free(plan, room, key, blocked, zones, r)
				if plan.furniture.size() > had:
					plan.furniture[-1]["free_standing"] = true
			elif plan.furniture.size() == had and _forced_wall(plan, room, key) >= 0:
				# the wall the flue rises on would not take it, and a fire
				# under no chimney is worse than no fire: the room goes
				# without and writes down that it did
				plan.note_compromise(room, cat)
		&"free":
			var before: int = plan.furniture.size()
			_place_free(plan, room, key, blocked, zones, r)
			if plan.furniture.size() == before:
				# no room to stand it clear of the walls; against one is better
				# than not at all, and is what a small cottage does
				_place_against_wall(plan, room, key, blocked, zones, r)
		&"corner":
			_place_corner(plan, room, key, blocked, zones, r)
		&"around":
			_place_around(plan, room, key, blocked, zones, r,
				String(step.get("host", "")) == "row")
		&"behind":
			_place_behind(plan, room, key, blocked, zones, r)
		&"mounted":
			_place_mounted(plan, room, key, r)
		&"ceiling":
			_place_ceiling(plan, room, key)
		&"on":
			_place_on_surface(plan, room, key, r)
	# The first focus piece placed writes back where it actually stood, so the
	# check compares the plan with the furniture rather than with itself.
	if plan.furniture.size() > before_place and plan.focus_room() == room \
			and plan.focus_cat() == cat and not plan.focus.get("placed", false):
		var placed: Dictionary = plan.furniture[-1]
		plan.focus["pos"] = Rect2(placed["rect"]).get_center()
		plan.focus["facing"] = float(placed["yaw"])
		plan.focus["placed"] = true
	# A room that could not fit something it needed, because it was already
	# holding the other things it needed, has made a compromise rather than a
	# mistake -- and it is only a compromise if there WAS something else. A bed
	# missing from an empty bedroom is still a defect, and still fails.
	if float(step.get("opt", 0.0)) >= 1.0 and plan.furniture.size() == before_place \
			and _has_other_must(plan, room):
		plan.note_compromise(room, cat)


# ------------------------------------------------------------ floor pieces

## Back to a wall, sliding along it until somewhere fits.
static func _place_against_wall(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var best: Dictionary = {}
	var best_score := -INF
	var extra: Array[Rect2] = _window_blocks(plan, room, key)
	var hearth_only: int = _forced_wall(plan, room, key)
	for wi in range(walls.size()):
		if hearth_only >= 0 and wi != hearth_only:
			continue
		var wall: Dictionary = walls[wi]
		var n: Vector2 = wall["normal"]
		var yaw: float = _yaw_facing(n)
		var a: Vector2 = wall["from"]
		var b: Vector2 = wall["to"]
		# The direction the wall actually runs, not the nearest axis to it.
		# Taking absf() of the perpendicular was right for the four walls of a
		# rectangle and meaningless on the diagonal of an octagon, where it
		# walked the piece off the wall it was meant to be against (GEO-002).
		var along: Vector2 = (b - a).normalized()
		# A piece backed to a wall stands across it by its own width and into
		# the room by its own depth, whichever way the wall runs.
		var raw: Vector2 = PropCatalog.footprint(key)
		var span: float = raw.x
		var depth: float = raw.y
		var run: float = (b - a).length()
		var small: float = span * PropCatalog.min_scale(key)
		var bed_on_facet := plan.is_polygonal(room) and PropCatalog.category(key) == "bed" \
			and maxf(absf(n.x), absf(n.y)) > 0.999
		if run < small + 0.1 and not bed_on_facet:
			continue
		var steps: int = clampi(int((run - small) / PROBE_STEP), 1, MAX_PROBES)
		for s in range(steps + 1):
			var t: float = (small / 2.0) + float(s) * (run - small) / float(steps)
			if run < small:
				t = run * 0.5
			var centre: Vector2 = a + along * t + n * (depth / 2.0 + HouseGeometry.WALL_GAP)
			# a bed can be got into from either side, so try both before
			# deciding this stretch of wall will not do
			var cand := {}
			for sc in _scales(key):
				# Scaling changes depth as well as width. Re-seat the back on
				# the host wall; keeping the full-size centre leaves a smaller
				# bed floating away from its headboard and wastes the aisle.
				var scaled_centre: Vector2 = a + along * t \
					+ n * (depth * float(sc) / 2.0 + (HouseGeometry.BREAST_DEPTH if hearth_only >= 0 else HouseGeometry.WALL_GAP))
				for zs in [1.0, -1.0]:
					var try_cand: Dictionary = _candidate(key, scaled_centre, yaw, zs, sc)
					if hearth_only >= 0:
						var breast := HouseGeometry.breast_for_hearth(plan, room, try_cand, wi)
						if not _breast_fits(plan, room, breast, floor_rect, blocked, zones):
							continue
						try_cand["breast"] = breast
					if _fits(plan, room, try_cand, floor_rect, blocked, zones, extra):
						cand = try_cand
						break
					if bed_on_facet:
						# A short polygon facet can hold the bed while the access
						# strip beside its head clips the next corner. Try a small
						# setback within the existing headboard-to-wall limit;
						# the footprint and use zone must both stay on real floor.
						for inset_step in range(1, 4):
							var inset := HouseGeometry.BED_HEAD_TOL * float(inset_step) / 3.0
							try_cand = _candidate(key, scaled_centre + n * inset, yaw, zs, sc)
							if _fits(plan, room, try_cand, floor_rect, blocked, zones, extra):
								cand = try_cand
								break
						if not cand.is_empty():
							break
				if not cand.is_empty():
					break
			if cand.is_empty():
				continue
			var mid: float = 1.0 - absf(t - run / 2.0) / maxf(run / 2.0, 0.01)
			var score: float = mid * 0.6 + r.randf() * HouseFurnishScore.JITTER + float(wi) * 0.01
			score += HouseFurnishScore._affinity(plan, room, cand)
			var placed: Vector3 = cand.pos
			score -= Vector2(placed.x, placed.z).distance_to(centre)
			if hearth_only >= 0 and wi != hearth_only:
				# the flue rises on one wall only, so a hearth on any other is
				# not a worse placement but no placement at all
				score = -INF
			if score > best_score:
				best_score = score
				best = cand
	_commit(plan, room, best, blocked, zones)


## N copies of the same prop, evenly spaced along a line, all facing the same
## shared aisle: beds in a barracks, pews in a chapel, trestles in a hall.
##
## This is `_place_against_wall`'s own fit test (a candidate footprint clear
## of the floor already spoken for) run along a straight run instead of
## slid one piece at a time -- so the row it finds is straight and evenly
## pitched by construction, not by measuring afterwards. `along: "wall"`
## (the default) tries each wall of the room in turn, backs to it, the way a
## row of pews or beds does; `along: "axis"` runs the row down the middle of
## the room instead, for a row nothing is backed onto, such as trestle tables
## with an aisle down both sides.
##
## If fewer than `min_n` fit, nothing is placed and the room records the
## compromise, the same as any other step that could not be met.
static func _place_row(plan: HousePlan, room: int, step: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var cat: String = String(step["cat"])
	var choices: Array[String] = PropCatalog.of_category(cat)
	if choices.is_empty():
		return
	var key: String = choices[r.randi_range(0, choices.size() - 1)]
	var n_max: int = int(step["n"][1])
	var n_want: int = n_max if n_max > 0 else 999
	var min_n: int = int(step.get("min_n", step["n"][0]))
	var pitch: float = float(step.get("pitch", 0.0))
	var aisle: float = maxf(float(step.get("aisle", HouseGeometry.PATH_MIN)), HouseGeometry.PATH_MIN)
	# Room left in front of the row before the aisle starts: a trestle table's
	# aisle is the walkway past the benches, not the space the benches stand
	# and pull back in, and a later "around" step needs that space left clear
	# of the aisle zone or it will never find anywhere to seat anyone.
	var seat_gap: float = float(step.get("seat_clearance", 0.0))
	var along_mode: String = String(step.get("along", "wall"))
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var extra: Array[Rect2] = _window_blocks(plan, room, key)
	var lines: Array[Dictionary] = []
	if along_mode == "axis":
		# Down the middle of the room, along its longer side, facing outward
		# to one side -- the trestle-table case, where nothing backs onto a
		# wall and the aisle is what the row is FOR.
		var c: Vector2 = floor_rect.get_center()
		var horizontal: bool = floor_rect.size.x >= floor_rect.size.y
		var a: Vector2 = c - (Vector2(floor_rect.size.x / 2.0, 0.0) if horizontal
			else Vector2(0.0, floor_rect.size.y / 2.0))
		var b: Vector2 = c + (Vector2(floor_rect.size.x / 2.0, 0.0) if horizontal
			else Vector2(0.0, floor_rect.size.y / 2.0))
		var n2: Vector2 = Vector2(0.0, 1.0) if horizontal else Vector2(1.0, 0.0)
		lines = [{"from": a, "to": b, "normal": n2}]
	else:
		lines = HouseGeometry.room_walls(plan, room)
	var best_row: Array = []
	var best_zone := Rect2()
	var best_score := -INF
	# Largest size first, the same as every other placer here: a row of
	# full-size tables is a better fit than a row of shrunk ones, and a small
	# room should only get the shrunk row if the full-size one will not go in
	# at all.
	for sc in _scales(key):
		for wi in range(lines.size()):
			var wall: Dictionary = lines[wi]
			var n: Vector2 = wall["normal"]
			var yaw: float = _yaw_facing(n)
			var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw) * sc
			var along := Vector2(n.y, -n.x).abs()
			var span: float = along.x * foot.x + along.y * foot.y
			var depth: float = absf(n.x) * foot.x + absf(n.y) * foot.y
			var a2: Vector2 = wall["from"]
			var b2: Vector2 = wall["to"]
			var run: float = (b2 - a2).length()
			var use_pitch: float = maxf(pitch, span + 0.1) if pitch > 0.01 else span + 0.3
			if run < span:
				continue
			var out: float = depth / 2.0 + HouseGeometry.WALL_GAP
			var max_count: int = mini(n_want, int((run + 0.001) / use_pitch))
			var row: Array = []
			# Fewer copies first only if the full count will not go in anywhere;
			# and for each count, slide the row along the wall -- a door swing
			# or a window sill in the middle of the wall should cost the row a
			# few centimetres of centring, not the whole row.
			for count in range(max_count, min_n - 1, -1):
				if count < 1:
					continue
				var span_len: float = float(count - 1) * use_pitch + span
				var slack: float = run - span_len
				if slack < -0.001:
					continue
				var slides: int = clampi(int(slack / PROBE_STEP), 0, MAX_PROBES)
				for si in range(slides + 1):
					var shift: float = -slack / 2.0 + (slack * float(si) / float(maxi(slides, 1)))
					var start_t: float = span / 2.0 + slack / 2.0 + shift
					var try_row: Array = []
					for i in range(count):
						var t: float = start_t + float(i) * use_pitch
						var centre: Vector2 = a2 + along * t + n * out
						var cand: Dictionary = _candidate(key, centre, yaw, 1.0, sc)
						# A ROW SHARES ONE AISLE, and that aisle is its use
						# zone -- it is assigned below, once the row is known.
						# The per-piece zone must not be tested here: a seat
						# carries its pull-back space BEHIND it, so a pew
						# backed to a wall has a zone inside the masonry and
						# not one bench of a row would ever fit. Pews in a
						# chapel are the case the row rule was written for
						# (INT-001) and could not do until this line.
						cand["zone"] = Rect2()
						if not _fits(plan, room, cand, floor_rect, blocked, zones, extra):
							break
						try_row.append(cand)
					if try_row.size() == count:
						row = try_row
						break
				if not row.is_empty():
					break
			if row.size() < min_n:
				continue
			# One aisle the whole row shares, deep enough to walk and wide enough
			# to cover every copy actually placed -- not the run the wall offered,
			# so a short row does not claim an aisle it never reaches the end of.
			var first: Rect2 = row[0]["rect"]
			var last: Rect2 = row[row.size() - 1]["rect"]
			var row_c: Vector2 = (first.get_center() + last.get_center()) / 2.0
			var row_len: float = (last.get_center() - first.get_center()).length() + span
			var facing: Vector2 = HouseFurnishScore._facing_of(yaw)
			var across: Vector2 = Vector2(facing.y, -facing.x).abs()
			var half_span: Vector2 = across * (row_len / 2.0)
			# The aisle the recipe asked for first; failing that, the narrowest
			# the nav check will still call a way through -- a shallow room
			# should not lose its whole row of trestles for want of a few
			# centimetres it was never going to spare.
			var aisle_rect := Rect2()
			for try_aisle in [aisle, HouseGeometry.PATH_MIN]:
				var aisle_a: Vector2 = row_c + facing * (out + seat_gap)
				var aisle_b: Vector2 = row_c + facing * (out + seat_gap + try_aisle)
				var ra: Vector2 = aisle_a - half_span
				var rb: Vector2 = aisle_b + half_span
				var candidate_rect := Rect2(ra.min(rb), (rb - ra).abs())
				if not floor_rect.grow(0.02).encloses(candidate_rect):
					continue
				var clash := false
				for bz in blocked:
					if bz.intersects(candidate_rect):
						clash = true
						break
				if clash:
					continue
				aisle_rect = candidate_rect
				break
			if aisle_rect.size.x <= 0.0:
				continue
			# scale is the primary ordering: a smaller-scale row never beats a
			# larger one, however many more copies it manages to fit
			var score: float = sc * 1000.0 + float(row.size()) * 10.0 + r.randf()
			if score > best_score:
				best_score = score
				best_row = row
				best_zone = aisle_rect
		if not best_row.is_empty():
			break
	if best_row.size() < min_n:
		if float(step["opt"]) >= 1.0 and _has_other_must(plan, room):
			plan.note_compromise(room, cat)
		return
	var row_group: String = "%d_%s_%d" % [room, cat, plan.furniture.size()]
	for cand in best_row:
		cand["zone"] = best_zone
		cand["row"] = row_group
		_commit(plan, room, cand, blocked, zones)


## The one wall a piece may stand against, or -1 when any will do. The planner
## names the hearth wall (HousePlan.hearth) and the builder raises the chimney
## on it, so a hearth anywhere else is a fire with no flue: every other wall
## scores -INF rather than a penalty that a lucky roll could overcome.
static func _forced_wall(plan: HousePlan, room: int, key: String) -> int:
	if PropCatalog.category(key) != "hearth":
		return -1
	if plan.hearth_room() != room:
		return -1
	return plan.hearth_wall()


## Room in the middle of the floor, for a table or an anvil.
static func _place_free(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator,
		require_seat := false) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var extra: Array[Rect2] = _window_blocks(plan, room, key)
	var result := {"best": {}, "score": -INF, "require_seat": require_seat}
	# Where the fire is does not change while the table hunts for a spot, and
	# the hunt looks at thousands of spots. Found once here and carried on the
	# candidate; leaving it inside the grid made every table in the sweep walk
	# the room's furniture list a few thousand times.
	var focus: Vector2 = HouseFurnishScore._hearth_point(plan, room)
	# A footprint turned half round is the same footprint, so two yaws cover
	# every rectangle -- unless the piece must LOOK somewhere, in which case
	# all four matter.
	var yaws: Array = [0.0, PI / 2.0]
	if plan.focus_room() == room and plan.focus_faces_door() \
			and PropCatalog.category(key) == plan.focus_cat():
		yaws = [0.0, PI / 2.0, PI, -PI / 2.0]
	# A piece the plan PINS does not need the whole room searched: the pin
	# already says where it goes, and every probe a stride away from it loses
	# to the pin anyway. Searching a 12 x 30 m great hall at 12 cm for a table
	# the plan had already placed cost ten seconds a hall.
	var pin: Rect2 = _pin_box(plan, room, key)
	for yaw in yaws:
		for sc in _scales(key):
			_free_at_scale(plan, room, key, yaw, sc, floor_rect, blocked, zones,
				extra, r, result, focus, pin)
	var best: Dictionary = result["best"]
	var seat: Dictionary = best.get("paired_seat", {})
	best.erase("paired_seat")
	_commit(plan, room, best, blocked, zones)
	if not seat.is_empty():
		seat["host"] = plan.furniture.size() - 1
		_commit(plan, room, seat, blocked, zones)


static func _breast_fits(plan: HousePlan, room: int, breast: Dictionary, floor_rect: Rect2,
		blocked: Array[Rect2], zones: Array[Rect2]) -> bool:
	var rect: Rect2 = breast["rect"]
	if not floor_rect.grow(0.01).encloses(rect) or not _inside_outline(plan, room, rect):
		return false
	for obstacle in blocked + zones:
		if rect.intersects(obstacle):
			return false
	for window in plan.windows_of(room):
		if rect.intersects(HouseGeometry.window_clear_rect(plan.windows[window])):
			return false
	return true


## The patch of floor a pinned piece is searched in, or an empty rect when the
## plan has not pinned this one. A stride either way, so the probe can still
## slide the piece off a door swing or out of a window.
static func _pin_box(plan: HousePlan, room: int, key: String) -> Rect2:
	if plan.focus_room() != room or plan.focus.get("placed", false):
		return Rect2()
	if PropCatalog.category(key) != plan.focus_cat():
		return Rect2()
	var at: Vector2 = plan.focus_pos()
	if not at.is_finite():
		return Rect2()
	return Rect2(at - Vector2.ONE * HouseFurnishScore.PIN_SEARCH, Vector2.ONE * HouseFurnishScore.PIN_SEARCH * 2.0)


## One pass of the free-standing search at a single size. Split out only
## because trying four sizes at two yaws over a grid is four levels of loop,
## and nesting them all in one function made the body unreadable.
static func _free_at_scale(plan: HousePlan, room: int, key: String, yaw: float,
		sc: float, floor_rect: Rect2, blocked: Array[Rect2], zones: Array[Rect2],
		extra: Array[Rect2], r: RandomNumberGenerator, result: Dictionary,
		focus := Vector2(INF, INF), pin := Rect2()) -> void:
	var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw) * sc
	var pad: float = HouseGeometry.PATH_MIN * 0.5
	var lo := Vector2(floor_rect.position.x + foot.x / 2.0 + pad,
		floor_rect.position.y + foot.y / 2.0 + pad)
	var hi := Vector2(floor_rect.end.x - foot.x / 2.0 - pad,
		floor_rect.end.y - foot.y / 2.0 - pad)
	if pin.size.x > 0.0:
		lo = lo.max(pin.position)
		hi = hi.min(pin.end)
	if lo.x > hi.x or lo.y > hi.y:
		return
	var nx: int = clampi(int((hi.x - lo.x) / PROBE_STEP), 1, MAX_PROBES)
	var nz: int = clampi(int((hi.y - lo.y) / PROBE_STEP), 1, MAX_PROBES)
	# The measured model, yaw, scale and category are constant for this pass.
	# Preserve the same candidates and RNG calls while doing those catalogue
	# lookups once instead of once at every point of the search grid.
	var prototype := _candidate(key, Vector2.ZERO, yaw, 1.0, sc)
	var has_zone := PropCatalog.zone_depth(key) > 0.0
	# A customer can stand in the clear approach to the shop's entrance while
	# using its counter or stall. The piece itself must still clear that door;
	# treating the empty approach as solid furniture forced small stalls to
	# turn their service side away from the customer.
	if plan.focus_room() == room and plan.focus_faces_door() \
			and not plan.focus.get("placed", false) and PropCatalog.category(key) == plan.focus_cat():
		var entry := HouseFurnishScore.focus_door(plan, room)
		if entry >= 0:
			prototype["zone_passages"] = [HouseGeometry.door_clear_rect(plan.doors[entry], -1.0),
				HouseGeometry.door_clear_rect(plan.doors[entry], 1.0)]
	for ix in range(nx + 1):
		for iz in range(nz + 1):
			var centre := Vector2(lerpf(lo.x, hi.x, float(ix) / nx),
				lerpf(lo.y, hi.y, float(iz) / nz))
			var cand := prototype.duplicate()
			cand["pos"] = Vector3(centre.x, 0.0, centre.y)
			cand["rect"] = Rect2(centre - foot / 2.0, foot)
			if has_zone:
				cand["zone"] = _zone_rect(key, cand["rect"], yaw)
			if not _fits(plan, room, cand, floor_rect, blocked, zones, extra):
				continue
			cand["focus_point"] = focus
			# the middle of the room, at the biggest size that fits there
			var d: float = centre.distance_to(floor_rect.get_center())
			var score: float = -d + r.randf() * HouseFurnishScore.JITTER + sc * 4.0 \
				+ HouseFurnishScore._affinity(plan, room, cand)
			if score > float(result["score"]):
				if bool(result.get("require_seat", false)):
					var seat := _seating_probe(plan, room, cand, blocked, zones)
					if seat.is_empty():
						continue
					cand["paired_seat"] = seat
				result["score"] = score
				result["best"] = cand


## Tucked into whichever corner is emptiest.
static func _place_corner(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var foot: Vector2 = PropCatalog.footprint(key)
	var g: float = HouseGeometry.WALL_GAP
	var corners := [
		Vector2(floor_rect.position.x + foot.x / 2.0 + g, floor_rect.position.y + foot.y / 2.0 + g),
		Vector2(floor_rect.end.x - foot.x / 2.0 - g, floor_rect.position.y + foot.y / 2.0 + g),
		Vector2(floor_rect.position.x + foot.x / 2.0 + g, floor_rect.end.y - foot.y / 2.0 - g),
		Vector2(floor_rect.end.x - foot.x / 2.0 - g, floor_rect.end.y - foot.y / 2.0 - g),
	]
	var extra: Array[Rect2] = _window_blocks(plan, room, key)
	var best: Dictionary = {}
	var best_score := -INF
	# All four corners are scored rather than shuffled: a barrel belongs in
	# the corner nobody walks through, and which one that is depends on
	# where the doors are, not on the roll of a die.
	for ci in range(4):
		var jitter: float = r.randf() * HouseFurnishScore.JITTER
		var found: Dictionary = {}
		var slid := 0.0
		# slide out of the corner along both walls until it fits
		for slide in range(6):
			for dir in [Vector2(1, 0), Vector2(0, 1)]:
				var sign_x: float = 1.0 if ci == 0 or ci == 2 else -1.0
				var sign_z: float = 1.0 if ci == 0 or ci == 1 else -1.0
				var off := Vector2(dir.x * sign_x, dir.y * sign_z) * (float(slide) * 0.25)
				var cand: Dictionary = _candidate(key, corners[ci] + off, 0.0)
				if _fits(plan, room, cand, floor_rect, blocked, zones, extra):
					found = cand
					slid = float(slide)
					break
			if not found.is_empty():
				break
		if found.is_empty():
			continue
		# a piece slid a long way out of the corner is not in the corner
		var score: float = HouseFurnishScore._affinity(plan, room, found) + jitter - slid * 0.05
		if score > best_score:
			best_score = score
			best = found
	_commit(plan, room, best, blocked, zones)


## Seats at a table, facing it, with pull-back space behind them.
static func _place_around(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator,
		want_row := false) -> void:
	var host: int = _find_host(plan, room, ["table", "workbench", "counter"], want_row)
	if host < 0:
		return
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var host_rect: Rect2 = plan.furniture[host]["rect"]
	var hc: Vector2 = host_rect.get_center()
	var best: Dictionary = {}
	var best_score := -INF
	# the four sides of the table, each sampled along its length, first drawn
	# up to it and then -- if the room is too tight for that -- tucked under it
	var sides := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
	for tucked in [false, true]:
		if not best.is_empty():
			break
		for n in sides:
			var yaw: float = _yaw_facing(-n)        # face back toward the table
			var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw)
			var half: Vector2 = host_rect.size / 2.0
			var depth: float = absf(n.x) * foot.x + absf(n.y) * foot.y
			var out: float = absf(n.x) * half.x + absf(n.y) * half.y + depth / 2.0 + 0.04
			if tucked:
				# under the table, the way a stool lives. Only as far as its own
				# front edge: pushed further it passes the middle of the table
				# and ends up facing away from it. The pull-back space behind it
				# is still required either way -- a seat you cannot get out of
				# is not a seat, and the walking check would say so.
				out -= depth * 0.4
			var along := Vector2(n.y, -n.x)
			var seat_span: float = absf(along.x) * foot.x + absf(along.y) * foot.y
			var run: float = absf(along.x) * host_rect.size.x \
				+ absf(along.y) * host_rect.size.y
			var steps: int = maxi(int(run / 0.45), 1)
			for s in range(steps + 1):
				var t: float = lerpf(-run / 2.0 + seat_span / 2.0, run / 2.0 - seat_span / 2.0,
					float(s) / float(steps))
				var centre: Vector2 = hc + n * out + along * t
				var cand: Dictionary = _candidate(key, centre, yaw)
				if not _fits(plan, room, cand, floor_rect, blocked, zones, [],
						host_rect if tucked else Rect2()):
					continue
				var score: float = r.randf() - absf(t) * 0.2
				if score > best_score:
					best_score = score
					best = cand
	if not best.is_empty():
		best["host"] = host
	_commit(plan, room, best, blocked, zones)


## Which piece a seat is drawn up to.
##
## The first one of the right kind, except when the step asks for a row: a
## great hall seats the trestles, not the high table, and among the trestles it
## seats whichever has the fewest people at it already, so a second bench goes
## to the next table rather than crowding the first.
static func _find_host(plan: HousePlan, room: int, cats: Array,
		want_row := false) -> int:
	var pool: Array[int] = []
	for f in plan.furniture_of(room):
		if PropCatalog.category(plan.furniture[f]["key"]) in cats:
			pool.append(f)
	if pool.is_empty():
		return -1
	if not want_row:
		return pool[0]
	var rows: Array[int] = []
	for f2 in pool:
		if String(plan.furniture[f2].get("row", "")) != "":
			rows.append(f2)
	# A step that seats a ROW and finds no row seats nobody. Falling back to
	# the first table in the room put a bench in front of a great hall high
	# table on every hall too small for its trestles -- which is the one place
	# in the room nobody sits.
	if rows.is_empty():
		return -1
	var best: int = rows[0]
	var fewest: int = 1 << 20
	for f3 in rows:
		var n := 0
		for g in plan.furniture_of(room):
			if int(plan.furniture[g]["host"]) == f3:
				n += 1
		if n < fewest:
			fewest = n
			best = f3
	return best


## The seat that belongs on the far side of its host, looking the same way it
## looks: the lord bench behind the high table, the clerk stool behind the
## counter.
##
## `around` puts a chair on whichever side of a table has room, which is right
## for a kitchen table and wrong for anything with a front and a back. Nobody
## sits between the high table and the hall. (CAS-010)
##
## The bench stands on its own feet -- no `host` -- because it is not drawn up
## to the table and pushed back in again: it is where the lord sits, the walk
## has to reach it, and a body crossing the dais has to go round it.
static func _place_behind(plan: HousePlan, room: int, key: String,
		blocked: Array[Rect2], zones: Array[Rect2], r: RandomNumberGenerator) -> void:
	var host: int = _find_host(plan, room, ["table", "workbench", "counter"])
	if host < 0:
		return
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	var host_rect: Rect2 = plan.furniture[host]["rect"]
	var hc: Vector2 = host_rect.get_center()
	var yaw: float = float(plan.furniture[host]["yaw"])
	var back: Vector2 = -HouseFurnishScore._facing_of(yaw)          # away from what the host faces
	var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw)
	var half: Vector2 = host_rect.size / 2.0
	var out: float = absf(back.x) * (half.x + foot.x / 2.0) \
		+ absf(back.y) * (half.y + foot.y / 2.0) + 0.04
	var along := Vector2(back.y, -back.x)
	var run: float = absf(along.x) * host_rect.size.x + absf(along.y) * host_rect.size.y
	var span: float = absf(along.x) * foot.x + absf(along.y) * foot.y
	var best: Dictionary = {}
	var best_score := -INF
	var steps: int = maxi(int(run / 0.45), 1)
	for si in range(steps + 1):
		var t: float = lerpf(-run / 2.0 + span / 2.0, run / 2.0 - span / 2.0,
			float(si) / float(steps))
		var centre: Vector2 = hc + back * out + along * t
		var cand: Dictionary = _candidate(key, centre, yaw)
		if not _fits(plan, room, cand, floor_rect, blocked, zones, []):
			continue
		# the middle of the table first: that is where the lord sits
		var score: float = r.randf() * 0.2 - absf(t)
		if score > best_score:
			best_score = score
			best = cand
	_commit(plan, room, best, blocked, zones)


# ---------------------------------------------------- wall and ceiling kit

## A shelf, rack or sconce on a wall, above the furniture already there.
static func _place_mounted(plan: HousePlan, room: int, key: String,
		r: RandomNumberGenerator) -> void:
	var walls: Array[Dictionary] = HouseGeometry.room_walls(plan, room)
	var y: float = HouseGeometry.SCONCE_HEIGHT if PropCatalog.category(key) == "sconce" \
		else HouseGeometry.SHELF_HEIGHT
	var width: float = PropCatalog.size(key).x
	# Worked out once, not once per candidate: where a pair of these hangs is
	# a fact about the room, and HouseFurnishScore._flank_anchor() scans the walls to find it.
	# Leaving it inside the scoring loop made the house suites four times as
	# slow for an answer that never changed.
	var anchor: Dictionary = HouseFurnishScore._flank_anchor(plan, room,
		HouseFurnishScore._widest_of(PropCatalog.category(key)), PropCatalog.category(key)) \
		if PropCatalog.affinity(key).has("flank") else {}
	var best_pos := Vector2.ZERO
	var best_yaw := 0.0
	var best_score := -INF
	# Every clear stretch of every wall is scored. A shelf wants the wall
	# above the bench it serves and a sconce wants to mirror its mate about
	# the door; neither is findable by trying six positions at random.
	for wi in range(walls.size()):
		var wall: Dictionary = walls[wi]
		var n: Vector2 = wall["normal"]
		var a: Vector2 = wall["from"]
		var b: Vector2 = wall["to"]
		var run: float = (b - a).length()
		var along: Vector2 = (b - a) / maxf(run, 0.01)
		if run < width + 0.4:
			continue
		var lo: float = width / 2.0 + 0.2
		var hi: float = run - width / 2.0 - 0.2
		# Keep the same fixed probe phase as HouseFurnishCheck's availability
		# search. Re-dividing the run into `steps` almost-0.06m intervals can
		# skip a narrow but valid station between two openings (seed 60068 has
		# 4cm of wall where the shelf can cover its workbench).
		var steps: int = maxi(int((hi - lo) / HouseFurnishScore.MOUNT_STEP), 0)
		for s in range(steps + 1):
			var t: float = lo + float(s) * HouseFurnishScore.MOUNT_STEP
			var pos: Vector2 = a + along * t
			if HouseFurnishScore._on_opening(plan, room, pos, n, width):
				continue
			if HouseFurnishScore._crowds_mounted(plan, room, pos, width):
				continue
			var cand := {
				"key": key, "pos": Vector3(pos.x, 0.0, pos.y),
				"yaw": _yaw_facing(n), "scale": 1.0,
				"rect": Rect2(pos - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
				"host": -1, "mounted": true, "flank_anchor": anchor,
			}
			var score: float = HouseFurnishScore._affinity(plan, room, cand) + r.randf() * HouseFurnishScore.JITTER
			if score > best_score:
				best_score = score
				best_pos = pos
				best_yaw = _yaw_facing(n)
	if best_score == -INF:
		return
	plan.furniture.append({
		"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
		"pos": Vector3(best_pos.x, _storey_base(plan, room) + y, best_pos.y),
		"yaw": best_yaw,
		"rect": Rect2(best_pos - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
		"zone": Rect2(), "host": -1, "cat": PropCatalog.category(key),
		"mounted": true, "scale": 1.0,
	})


static func _place_ceiling(plan: HousePlan, room: int, key: String) -> void:
	var floor_rect: Rect2 = HouseGeometry.room_floor_rect(plan, room)
	if minf(floor_rect.size.x, floor_rect.size.y) < 2.6:
		return                                   # no room to hang anything
	# The middle of the room, unless there is a table to hang over -- which
	# is what a chandelier is for, and is decided by the same scorer as
	# everything else rather than by a special case here.
	var spots: Array[Vector2] = [floor_rect.get_center()]
	for f in plan.furniture_of(room):
		var p: Dictionary = plan.furniture[f]
		if p.get("mounted", false) or int(p["host"]) >= 0:
			continue
		var pc: Vector2 = Rect2(p["rect"]).get_center()
		if floor_rect.grow(0.05).has_point(pc):
			spots.append(pc)
	var c: Vector2 = spots[0]
	var best_score := -INF
	for spot in spots:
		var cand := {
			"key": key, "pos": Vector3(spot.x, 0.0, spot.y),
			"rect": Rect2(spot - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
			"host": -1, "mounted": true,
		}
		var score: float = HouseFurnishScore._affinity(plan, room, cand)
		if score > best_score:
			best_score = score
			c = spot
	plan.furniture.append({
		"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
		"pos": Vector3(c.x, _storey_base(plan, room) + plan.spec.height, c.y),
		"yaw": 0.0, "rect": Rect2(c - Vector2.ONE * 0.05, Vector2.ONE * 0.1),
		"zone": Rect2(), "host": -1, "cat": PropCatalog.category(key),
		"mounted": true, "scale": 1.0,
	})


## A mug, a candle, a stack of books -- set ON something, never on the floor.
static func _place_on_surface(plan: HousePlan, room: int, key: String,
		r: RandomNumberGenerator) -> void:
	var hosts: Array[int] = []
	for f in plan.furniture_of(room):
		var host_key: String = plan.furniture[f]["key"]
		if PropCatalog.has_tag(host_key, PropCatalog.SURFACE) \
				and not plan.furniture[f].get("mounted", false):
			hosts.append(f)
	if hosts.is_empty():
		return
	var host: int = hosts[r.randi_range(0, hosts.size() - 1)]
	var host_rect: Rect2 = plan.furniture[host]["rect"]
	var top: float = float(plan.furniture[host]["pos"].y) \
		+ PropCatalog.surface_height(plan.furniture[host]["key"]) \
		* float(plan.furniture[host].get("scale", 1.0))
	var foot: Vector2 = PropCatalog.footprint(key)
	var margin := 0.06
	var lo := Vector2(host_rect.position.x + foot.x / 2.0 + margin,
		host_rect.position.y + foot.y / 2.0 + margin)
	var hi := Vector2(host_rect.end.x - foot.x / 2.0 - margin,
		host_rect.end.y - foot.y / 2.0 - margin)
	if lo.x > hi.x or lo.y > hi.y:
		return
	for tries in range(10):
		var p := Vector2(lerpf(lo.x, hi.x, r.randf()), lerpf(lo.y, hi.y, r.randf()))
		var rect := Rect2(p - foot / 2.0, foot)
		var clash := false
		for f2 in plan.furniture_of(room):
			if plan.furniture[f2]["host"] != host:
				continue
			if plan.furniture[f2]["rect"].intersects(rect):
				clash = true
				break
		if clash:
			continue
		plan.furniture.append({
			"key": key, "room": room, "storey": HousePlan.record_storey(plan.rooms[room]),
			"pos": Vector3(p.x, top, p.y),
			"yaw": r.randf() * TAU, "rect": rect, "zone": Rect2(), "host": host,
			"cat": PropCatalog.category(key), "mounted": false, "scale": 1.0,
		})
		return


# ------------------------------------------------------------- mechanics

## A placement, before it is known whether it fits.
static func _candidate(key: String, centre: Vector2, yaw: float,
		zone_side := 1.0, scale := 1.0) -> Dictionary:
	var foot: Vector2 = PropCatalog.footprint_rotated(key, yaw) * scale
	var rect := Rect2(centre - foot / 2.0, foot)
	return {
		"key": key, "pos": Vector3(centre.x, 0.0, centre.y), "yaw": yaw,
		"rect": rect, "zone": _zone_rect(key, rect, yaw, zone_side), "host": -1,
		"cat": PropCatalog.category(key), "mounted": false, "scale": scale,
	}


## The floor a person needs to USE the piece.
##
## Which side that is depends on the piece: you stand in front of a cabinet,
## you push a chair BACK from the table to sit down, and you get into a bed
## from its long side. Getting this wrong is not a cosmetic matter -- the
## navigation check requires every one of these to be reachable, so a zone on
## the wrong side of a chair reports the whole room as unusable.
static func _zone_rect(key: String, rect: Rect2, yaw: float, side := 1.0) -> Rect2:
	var depth: float = PropCatalog.zone_depth(key)
	if depth <= 0.0:
		return Rect2()
	var cat: String = PropCatalog.category(key)
	var facing: Vector2 = HouseFurnishScore._facing_of(yaw)
	var dir: Vector2 = facing
	if cat == "seat" or cat == "bench":
		dir = -facing                      # pull-back space, behind the seat
	elif cat == "bed":
		dir = Vector2(facing.y, -facing.x) * side  # you get in from the side
	var c: Vector2 = rect.get_center()
	var measured := PropCatalog.footprint_rotated(key, yaw)
	var scale := rect.size.x / maxf(measured.x, 0.001)
	var raw := PropCatalog.footprint(key) * scale
	var out: float = raw.x * 0.5 if cat == "bed" else raw.y * 0.5
	var width: float = raw.y if cat == "bed" else raw.x
	var span := Vector2(dir.y, -dir.x) * width * 0.5
	# Bound all four corners of the rotated strip. Bounding just two opposite
	# corners with an absolute tangent can collapse a diagonal use zone.
	return Poly.bounding_rect(PackedVector2Array([
		c + dir * out - span, c + dir * out + span,
		c + dir * (out + depth) + span, c + dir * (out + depth) - span]))


## Does this candidate fit: inside the room, clear of everything already
## placed, and with its use zone on real floor rather than inside a wall?
static func _fits(plan: HousePlan, room: int, cand: Dictionary, floor_rect: Rect2, blocked: Array[Rect2],
		zones: Array[Rect2], extra: Array[Rect2], ignore := Rect2()) -> bool:
	var rect: Rect2 = cand["rect"]
	if not floor_rect.grow(0.01).encloses(rect):
		return false
	for b in blocked:
		# a seat tucked under its own table overlaps it on purpose, so the
		# table is passed in as the one rectangle this placement may share
		if ignore.size.x > 0.0 and b.is_equal_approx(ignore):
			continue
		if b.intersects(rect):
			return false
	for z in zones:
		if z.intersects(rect):
			return false
	for e in extra:
		if e.intersects(rect):
			return false
	if not _no_slivers(rect, floor_rect):
		return false
	var zone: Rect2 = cand["zone"]
	if zone.size.x > 0.0:
		# the zone may overlap another zone -- two people can share a gangway --
		# but it may not be inside a wall or under other furniture
		if not floor_rect.grow(0.02).encloses(zone):
			return false
		for b2 in blocked:
			if b2 in cand.get("zone_passages", []):
				continue
			if b2.intersects(zone):
				return false
	# Polygon corner tests are pure and substantially dearer than rectangle
	# rejection. Only candidates clear of every inexpensive obstruction need
	# the exact same outline tests; no accepted candidate or RNG draw changes.
	if not _inside_outline(plan, room, rect):
		return false
	if zone.size.x > 0.0 and not _inside_outline(plan, room, zone):
		return false
	return true


## Are all four corners of `rect` inside the room being furnished? True when
## the room is a plain rectangle -- the enclosing test above has said so
## already.
static func _inside_outline(plan: HousePlan, room: int, rect: Rect2) -> bool:
	if not plan.is_polygonal(room):
		return true
	var outline: PackedVector2Array = plan.outline_of(room)
	for p in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		if not Poly.contains_point(outline, p, 0.01):
			return false
	return true


static func _commit(plan: HousePlan, room: int, cand: Dictionary,
		blocked: Array[Rect2], zones: Array[Rect2]) -> void:
	if cand.is_empty():
		return
	cand["room"] = room
	cand["storey"] = HousePlan.record_storey(plan.rooms[room])
	var pos: Vector3 = cand["pos"]
	# Candidates are planar (Y=0) while searching. Stamp world elevation only
	# after the placement is accepted, keeping all rectangle logic 2D. A dais
	# is part of that elevation: the high table stands ON the step, and
	# everything in plan still measures as though the step were flat floor.
	pos.y += _storey_base(plan, room)
	if plan.on_dais(room, Vector2(pos.x, pos.z)):
		pos.y += plan.dais_rise()
	cand["pos"] = pos
	cand["must"] = false
	plan.furniture.append(cand)
	if cand.has("breast"):
		plan.hearth["breast"] = cand["breast"]
		blocked.append(cand["breast"]["rect"])
		cand.erase("breast")
	blocked.append(cand["rect"])
	var zone: Rect2 = cand["zone"]
	if zone.size.x > 0.0:
		zones.append(zone)


## The sizes this piece may be built at, largest first.
static func _scales(key: String) -> Array:
	var floor_scale: float = PropCatalog.min_scale(key)
	if floor_scale >= 1.0:
		return [1.0]
	var out: Array = []
	for s in SCALE_STEPS:
		if float(s) >= floor_scale - 0.001:
			out.append(float(s))
	return out


## No dead slivers.
##
## The gap between a piece and each wall must be either nothing -- the piece is
## against that wall -- or wide enough to walk down. A table left 38 cm from the
## wall behind it is what cut one test house in half: the room stayed walkable
## on paper and a person could not get past.
static func _no_slivers(rect: Rect2, floor_rect: Rect2) -> bool:
	# A gap beside a stool is a gap you step round. It only becomes a dead
	# sliver when the piece is long enough to bar the room across the other
	# axis, so that the sliver is the only way past.
	var bars_x: bool = rect.size.y > floor_rect.size.y * BAR_FRACTION
	var bars_z: bool = rect.size.x > floor_rect.size.x * BAR_FRACTION
	var gaps := []
	if bars_x:
		gaps.append(rect.position.x - floor_rect.position.x)
		gaps.append(floor_rect.end.x - rect.end.x)
	if bars_z:
		gaps.append(rect.position.y - floor_rect.position.y)
		gaps.append(floor_rect.end.y - rect.end.y)
	# And the ways round its ENDS. A table across most of the width of a room
	# is got past at its sides, not behind it, so those are the gaps that have
	# to be walkable -- a parlour with a bench drawn up to such a table is cut
	# in two by 49 cm of floor either side, and every repair pass in the world
	# will not open it again.
	if bars_z:
		gaps.append(rect.position.x - floor_rect.position.x)
		gaps.append(floor_rect.end.x - rect.end.x)
	if bars_x:
		gaps.append(rect.position.y - floor_rect.position.y)
		gaps.append(floor_rect.end.y - rect.end.y)
	for g in gaps:
		var gap: float = float(g)
		if gap > HouseGeometry.WALL_GAP + 0.06 and gap < HouseGeometry.PATH_MIN:
			return false
	return true


## Yaw that turns a prop's face (local -Z) toward `n`.
static func _yaw_facing(n: Vector2) -> float:
	return atan2(-n.x, -n.y)
