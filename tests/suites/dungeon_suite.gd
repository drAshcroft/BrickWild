extends RefCounted
## Realised dungeons: every room of every fixture plan against DungeonRoomCheck,
## the contract a consumer reads, and a negative control for each rule so none
## of them is a tautology.
##
## The fixtures are real exports from the planner (C:\Projects\dungeon,
## tools/export_plan.gd) plus one of VoxelGames' baked plans, which predates
## the export's `spaces` and so exercises the inferred archetypes.

const FIXTURES := "res://tests/fixtures/dungeon"


static func run() -> SuiteResult:
	var res := SuiteResult.new("dungeon")
	var geo := DungeonGeometry.new()
	var used := {"ceiling": {}, "walls": {}, "floor": {}}
	var sample_room: Dictionary = {}
	var pit_room: Dictionary = {}
	for path in _fixtures():
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var name := path.get_file()
		var result := DungeonRealiser.realise(payload, geo)
		_expect(res, bool(result["ok"]), "%s: refused: %s" % [name, result["errors"]])
		if not bool(result["ok"]):
			continue
		for w in result["warnings"]:
			res.note("%s: %s" % [name, w])
		var doc: Dictionary = result["document"]
		var again: Dictionary = DungeonRealiser.realise(payload, geo)["document"]
		_expect(res, JSON.stringify(doc, "", true) == JSON.stringify(again, "", true),
			"%s: the same plan realised two different dungeons" % name)
		_contract(res, name, payload, doc)
		for room: Dictionary in doc["rooms"]:
			var rep := DungeonRoomCheck.check(room, geo)
			_expect(res, (rep["failures"] as Array).is_empty(),
				"%s: %s" % [name, "; ".join(rep["failures"])])
			for part in used:
				used[part][room["grammar"][part]] = true
			if sample_room.is_empty() and (room["doorways"] as Array).size() >= 2 \
					and not (room["sockets"]["fixtures"] as Array).is_empty() \
					and String(room["grammar"]["floor"]) == "flat":
				sample_room = room
			if pit_room.is_empty() and String(room["grammar"]["floor"]) == "pit":
				pit_room = room
	for part in used:
		_expect(res, (used[part] as Dictionary).size() >= 3,
			"variety: the fixtures used only %s for %s" % [(used[part] as Dictionary).keys(), part])
	_expect(res, not sample_room.is_empty(), "no flat room with two doorways and a fixture to perturb")
	if not sample_room.is_empty():
		_negative_controls(res, sample_room, pit_room, geo)
	return res


## What a consumer relies on: one doorway at each end of every link, every
## fixture given a socket, every lock given a gate, the source echoed.
static func _contract(res: SuiteResult, name: String, payload: Dictionary, doc: Dictionary) -> void:
	_expect(res, String(doc["schema"]) == DungeonRealiser.SCHEMA, "%s: wrong schema" % name)
	_expect(res, (doc["rooms"] as Array).size() == (payload["rooms"] as Array).size(),
		"%s: %d rooms realised of %d" % [name, (doc["rooms"] as Array).size(),
			(payload["rooms"] as Array).size()])
	var ends := {}
	for room: Dictionary in doc["rooms"]:
		for d: Dictionary in room["doorways"]:
			var portal := String(d["portal"])
			ends[portal] = int(ends.get(portal, 0)) + 1
			_expect(res, String(d["gate"]) != "", "%s: %s has no gate" % [name, portal])
	for link: Dictionary in payload["links"]:
		_expect(res, int(ends.get(String(link["portal"]), 0)) == 2,
			"%s: link %s has %d doorway ends" % [name, link["portal"],
				int(ends.get(String(link["portal"]), 0))])
	var by_key := {}
	for room: Dictionary in doc["rooms"]:
		by_key[String(room["key"])] = room
	for room: Dictionary in payload["rooms"]:
		var wanted := (room.get("fixtures", []) as Array).size()
		var got := (by_key[String(room["key"])]["sockets"]["fixtures"] as Array).size()
		_expect(res, got == wanted, "%s: %s placed %d of %d fixtures"
			% [name, room["key"], got, wanted])
	_expect(res, (doc["source"] as Dictionary).has("request"), "%s: the source is not echoed" % name)


## Each rule made to fail on a real room. A check that cannot fail checks nothing.
static func _negative_controls(res: SuiteResult, room: Dictionary, pit_room: Dictionary,
		geo: DungeonGeometry) -> void:
	var d0: Dictionary = room["doorways"][0]
	var n := DungeonGeometry.normal(StringName(String(d0["wall"])))
	var m := Vector2(float(d0["mouth"][0]), float(d0["mouth"][2]))

	var blocked := room.duplicate(true)
	var p := m - n * 2.5
	(blocked["carve"] as Array).append(DungeonCarve.box(&"fill", "faulty_block",
		Vector3(p.x, 2.0, p.y), Vector3(8.0, 4.0, 8.0)))
	_expect_rule(res, blocked, geo, "walk", "a block filling the first doorway's approach")

	var low := room.duplicate(true)
	var half: Array = room["size"]["half"]
	(low["carve"] as Array).append(DungeonCarve.box(&"fill", "faulty_ceiling",
		Vector3(0, 6.0, 0), Vector3(float(half[0]) * 2.0, 8.0, float(half[1]) * 2.0)))
	_expect_rule(res, low, geo, "headroom", "a ceiling at 2 m")

	var huge := room.duplicate(true)
	(huge["carve"] as Array)[0]["size"] = [120.0, 6.0, 20.0]
	_expect_rule(res, huge, geo, "budget", "a chamber wider than its rock")

	var moved := room.duplicate(true)
	moved["doorways"][0]["along"] = float(d0["along"]) + 3.0
	_expect_rule(res, moved, geo, "doors", "a doorway row moved off its tunnel")

	var shut := room.duplicate(true)
	var tunnel_tag := "tunnel:" + String(d0["portal"])
	shut["carve"] = (shut["carve"] as Array).filter(func(op): return String(op["tag"]) != tunnel_tag)
	_expect_rule(res, shut, geo, "mouth", "a doorway whose tunnel was never carved")

	var buried := room.duplicate(true)
	var s: Dictionary = buried["sockets"]["fixtures"][0]
	# Behind a corner: no tunnel ever runs there.
	s["position"] = [float(half[0]) + 1.0, 0.0, float(half[1]) + 1.0]
	s["on"] = "floor"
	s.erase("wall")
	_expect_rule(res, buried, geo, "sockets", "a fixture placed inside the rock")

	if not pit_room.is_empty():
		var over := pit_room.duplicate(true)
		over["sockets"]["fixtures"] = [{"id": "faulty", "kind": "key", "on": "floor",
			"position": [0.0, 0.0, 0.0]}]
		_expect_rule(res, over, geo, "sockets", "a key placed over the pit")
		var sheer := pit_room.duplicate(true)
		sheer["carve"] = (sheer["carve"] as Array).filter(
			func(op): return not String(op["tag"]).begins_with("pitstep"))
		_expect_rule(res, sheer, geo, "pit", "a pit with its stair taken away")
	else:
		res.warn("negative controls: no pit room in the fixtures to place a key over")


static func _expect_rule(res: SuiteResult, room: Dictionary, geo: DungeonGeometry,
		rule: String, what: String) -> void:
	var rep := DungeonRoomCheck.check(room, geo)
	var hit := false
	for f in rep["failures"]:
		if String(f).begins_with(rule + ":"):
			hit = true
	_expect(res, hit, "negative control: %s passed the %s rule (%s)" % [what, rule, rep["failures"]])


static func _fixtures() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(FIXTURES):
		if f.ends_with(".plan.json"):
			out.append(FIXTURES + "/" + f)
	out.sort()
	return out


static func _expect(res: SuiteResult, ok: bool, why: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(why)
