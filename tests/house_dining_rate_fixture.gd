extends SceneTree
## Replaces the room-name-only hall/table statistic with a bounded household
## dining completion rate over the same 24 deterministic stair-sweep requests.
## Run only after dining selection is promoted.

const REQUEST_COUNT := 24
const REQUIRED_POSITIVES: Array[int] = [72009, 72015, 72021]
const KNOWN_INFEASIBLE := 72000
const MIN_COMPLETION_RATE := 0.95

var failures: Array[String] = []
var eligible := 0
var completed := 0
var incomplete := 0
var not_applicable := 0
var outcomes: Dictionary = {}

func _initialize() -> void:
	var styles: Array = HouseSweep.styles()
	var trades: Array = HouseSweep.trades()
	for n in REQUEST_COUNT:
		var style: StringName = styles[n % styles.size()]
		var trade: StringName = trades[n % trades.size()]
		var spec := HouseSpec.new()
		spec.style = style
		spec.trade = trade
		spec.width = 6.0 + float(n % 5) * 2.0
		spec.length = 7.0 + float(n % 7) * 1.8
		spec.storeys = 2
		var seed_value: int = 72000 + n
		var plan: HousePlan = HouseGenerator.generate(spec, seed_value, true)
		_check_request(seed_value, spec, plan)
	var denominator: int = eligible - 1 # the named 72000 infeasible control
	var required: int = int(ceil(float(denominator) * MIN_COMPLETION_RATE))
	if denominator <= 0 or completed < required:
		failures.append("dining completion rate %d/%d is below %.0f%% (need %d)"
			% [completed, denominator, MIN_COMPLETION_RATE * 100.0, required])
	for seed_value in REQUIRED_POSITIVES:
		if not _positive_was_complete(seed_value):
			failures.append("required dining positive seed %d was not complete" % seed_value)
	print("dining rate: %d requests; %d applicable, %d complete, %d incomplete, %d not applicable; target %.0f%%"
		% [REQUEST_COUNT, eligible, completed, incomplete, not_applicable, MIN_COMPLETION_RATE * 100.0])
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)


func _check_request(seed_value: int, spec: HouseSpec, plan: HousePlan) -> void:
	var ordinary: bool = HouseFurnishingRecipes.is_ordinary_house(plan)
	var selection: String = String(plan.domestic_layout.get("dining_selection", ""))
	var selected: int = int(plan.domestic_layout.get("dining_room", -999))
	var tables: Array[int] = []
	var seats: Array[int] = []
	for index in plan.furniture.size():
		var piece: Dictionary = plan.furniture[index]
		if String(piece.get("activity_group", "")) != "eating":
			continue
		if String(piece.get("cat", "")) == "table":
			tables.append(index)
		elif String(piece.get("cat", "")) == "seat":
			seats.append(index)
	if not ordinary:
		not_applicable += 1
		outcomes[seed_value] = "not_applicable"
		if seed_value == KNOWN_INFEASIBLE:
			failures.append("named negative seed 72000 fell outside ordinary-house dining scope")
		print("DINING %d style=%s trade=%s scope=not_applicable" % [seed_value, spec.style, spec.trade])
		return
	eligible += 1
	outcomes[seed_value] = selection
	var capacity: int = HouseFurnisher._household_seat_capacity(plan)
	if seed_value == KNOWN_INFEASIBLE:
		if not bool(plan.domestic_layout.get("stair_unsatisfied", false)):
			failures.append("named negative 72000 no longer records its failed stair route")
		if selected >= 0 and selected < plan.room_count() and plan.storey_of_room(selected) > 0:
			failures.append("named negative 72000 selected an unreachable upper dining room")
		if selection != "unsatisfied":
			failures.append("named negative 72000 did not report its infeasible dining attempt")
	else:
		if selection == "complete":
			completed += 1
			_check_complete_group(seed_value, plan, selected, capacity, tables, seats)
		elif selection == "unsatisfied":
			incomplete += 1
			if String(plan.domestic_layout.get("dining_selection_reason", "")).is_empty():
				failures.append("seed %d incomplete dining has no reason" % seed_value)
			if selected >= 0 and not plan.was_dropped(selected, "activity:eating"):
				failures.append("seed %d incomplete dining has no activity:eating shortfall" % seed_value)
			if selected < 0:
				var has_no_room_shortfall := false
				for shortfall in plan.domestic_layout.get("activity_shortfalls", []):
					if int(shortfall.get("room", -999)) == -1 \
							and "activity:eating:no_verified_room" in shortfall.get("issues", []):
						has_no_room_shortfall = true
				if not has_no_room_shortfall:
					failures.append("seed %d no-room result lacks an activity:eating shortfall" % seed_value)
			if selected < -1 or selected >= plan.room_count():
				failures.append("seed %d incomplete dining names invalid room %d" % [seed_value, selected])
			if tables.size() > 1:
				failures.append("seed %d incomplete dining retained duplicate meal tables" % seed_value)
			if selected < 0 and not tables.is_empty():
				failures.append("seed %d has a meal table without an attempted room" % seed_value)
			if selected >= 0:
				for table_index in tables:
					if int(plan.furniture[table_index].get("room", -1)) != selected:
						failures.append("seed %d retained a meal table outside attempted room" % seed_value)
		else:
			failures.append("seed %d has no final dining classification (state=%s)" % [seed_value, selection])
		if seed_value in REQUIRED_POSITIVES and selection != "complete":
			failures.append("required positive seed %d is %s" % [seed_value, selection])
	var chosen_kind := "none"
	var chosen_storey := -1
	if selected >= 0 and selected < plan.room_count():
		chosen_kind = String(plan.kind_of(selected))
		chosen_storey = plan.storey_of_room(selected)
	print("DINING %d style=%s trade=%s size=%.1fx%.1f scope=ordinary state=%s room=%s/%d tables=%d seats=%d/%d probes=%d reason=%s"
		% [seed_value, spec.style, spec.trade, spec.width, spec.length, selection,
		chosen_kind, chosen_storey, tables.size(), seats.size(), capacity,
		int(plan.domestic_layout.get("dining_probe_count", 0)),
		String(plan.domestic_layout.get("dining_selection_reason", ""))])


func _check_complete_group(seed_value: int, plan: HousePlan, selected: int,
		capacity: int, tables: Array[int], seats: Array[int]) -> void:
	if selected < 0 or selected >= plan.room_count():
		failures.append("seed %d complete dining names invalid room %d" % [seed_value, selected])
		return
	if tables.size() != 1:
		failures.append("seed %d complete dining has %d meal tables" % [seed_value, tables.size()])
	if seats.size() != capacity:
		failures.append("seed %d complete dining has %d/%d seats" % [seed_value, seats.size(), capacity])
	for index in seats:
		var seat: Dictionary = plan.furniture[index]
		if int(seat.get("room", -1)) != selected:
			failures.append("seed %d complete meal seat is outside selected room" % seed_value)
		if tables.size() == 1 and int(seat.get("host", -1)) != tables[0]:
			failures.append("seed %d complete meal seat has stale table host" % seed_value)
	if tables.size() == 1 and int(plan.furniture[tables[0]].get("room", -1)) != selected:
		failures.append("seed %d complete meal table is outside selected room" % seed_value)
	var nav: Dictionary = HouseNavCheck.new().check(plan)
	if nav["unreached_rooms"].has(selected):
		failures.append("seed %d complete meal room is unreachable" % seed_value)
	for index in nav["unreachable_items"]:
		if int(plan.furniture[index].get("room", -1)) == selected \
				and index in tables + seats:
			failures.append("seed %d complete meal table/seat is unreachable" % seed_value)


func _positive_was_complete(seed_value: int) -> bool:
	return String(outcomes.get(seed_value, "")) == "complete"
