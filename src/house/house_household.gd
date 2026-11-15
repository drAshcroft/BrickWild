class_name HouseHousehold
extends RefCounted
## Who lives in an ordinary house (HOME-BRIEF; docs/INTERIOR_DESIGN.md
## sections 1 and 6). A designer starts from the household: how many people,
## so how many beds and how many places at the one table. The furnisher used
## to start from the rooms -- two places per sleeping room -- so every table
## was laid for two and a 200 m2 house slept two.
##
## The brief is a pure function of the planned rooms, never a draw from the
## house's rng, and is recorded on `plan.domestic_layout["household"]`:
##   people         head-count, from floor area (M2_PER_HEAD), MIN..MAX_PEOPLE
##   places         places at the household table (people, at most MAX_PLACES)
##   beds           beds the household needs (SLEEPERS_PER_BED to a bed)
##   bed_rooms      {room index: beds that room is asked to hold}
##   unplaced_beds  beds no sleeping room had floor for (honest shortfall)
##   floor_m2       the floor the head-count was read from
##
## Numbers: early-modern English households averaged 4.75 people (Laslett);
## the real median is 4 places at a dining table (HSSD n=93, SUN RGB-D n=171;
## docs/interior/DATASETS.md). 24 m2 a head puts a 9 x 12 m cottage at four.

const M2_PER_HEAD := 24.0
const MIN_PEOPLE := 3
const MAX_PEOPLE := 8
## Places at the one household table, at most: 4 is the real median and 6 the
## next (HSSD, SUN RGB-D). Measured 14 Nov: laying 8 made the dining preflight
## six times slower on a two-storey townhouse (126.6 s against 20.8 s, same
## process and load); the rest of a large household eats in shifts or apart.
const MAX_PLACES := 6
## The catalogue's only bed (Bed_Twin*) is 1.88 m wide: a double.
const SLEEPERS_PER_BED := 2
## A sleeping room is asked for one bed per this much floor, at most
## MAX_BEDS_PER_ROOM: one chest stows clothes for two beds (check_stowage).
const M2_PER_BED := 8.0
const MAX_BEDS_PER_ROOM := 2


## Off only for A/B timing and fingerprint comparison of the brief itself
## (one process, same load, brief on and off). Generation never sets it.
static var enabled := true


## Does this plan get a household brief? Ordinary houses only: shops, inns,
## hotels, keeps and world families keep their own programmes, and the witch
## hut keeps its small, single-sleeper contract (WITCH-SIZE).
static func applies(plan: HousePlan) -> bool:
	return enabled and HouseFurnishingRecipes.is_ordinary_house(plan) \
		and plan.spec.style != &"witch_hut"


static func brief(plan: HousePlan) -> Dictionary:
	var floor_m2 := 0.0
	for i in range(plan.room_count()):
		if plan.storey_of_room(i) >= 0:
			floor_m2 += HouseGeometry.room_area(plan, i)
	var people: int = clampi(roundi(floor_m2 / M2_PER_HEAD), MIN_PEOPLE, MAX_PEOPLE)
	var beds: int = ceili(float(people) / float(SLEEPERS_PER_BED))
	var bed_rooms := {}
	var remaining := beds
	var sleeping: Array[int] = []
	for kind in HouseGeometry.SLEEPING:
		sleeping.append_array(plan.rooms_of(kind))
	sleeping.sort()
	# Every sleeping room holds its first bed (the recipe requires it), so each
	# is counted once before any room is asked for a second.
	for room in sleeping:
		bed_rooms[room] = 1
		remaining -= 1
	for room in sleeping:
		if remaining <= 0:
			break
		var fits: int = clampi(int(HouseGeometry.room_area(plan, room) / M2_PER_BED), 1, MAX_BEDS_PER_ROOM)
		var more: int = mini(fits - 1, remaining)
		if more > 0:
			bed_rooms[room] = 1 + more
			remaining -= more
	remaining = maxi(remaining, 0)
	return {"people": people, "places": mini(people, MAX_PLACES), "beds": beds, "bed_rooms": bed_rooms,
		"unplaced_beds": remaining, "floor_m2": snappedf(floor_m2, 0.1),
		"basis": "floor/%.0f m2 a head, %d-%d people; %d sleepers a bed" % [
			M2_PER_HEAD, MIN_PEOPLE, MAX_PEOPLE, SLEEPERS_PER_BED]}


## The recorded brief, or an empty Dictionary when the plan has none.
static func of(plan: HousePlan) -> Dictionary:
	return plan.domestic_layout.get("household", {})


## How many beds this room is asked to hold; 0 when the brief says nothing.
static func beds_for(plan: HousePlan, room: int) -> int:
	var rooms: Dictionary = of(plan).get("bed_rooms", {})
	return int(rooms.get(room, 0))
