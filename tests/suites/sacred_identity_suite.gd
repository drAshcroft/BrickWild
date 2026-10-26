extends RefCounted
## SACRED-IDENTITY: every frozen rotunda and pylon request in the sacred matrix
## carries its named traits (qa/sacred_identity_check.gd), each measured from
## the logs. For each trait, a REMOVAL CONTROL: the same measure on logs with
## that trait's rows deleted must fail. And a cross-form control: a rotunda
## measured as a pylon (and the reverse) must miss every trait.

const MATRIX := "res://tests/fixtures/sacred_sequence_requests.json"
const Id = preload("res://qa/sacred_identity_check.gd")

## trait -> mass-name prefixes and component-role prefixes its control deletes
const REMOVE := {
	"drum": {"m": ["wall_rotunda_"], "c": []},
	"roof": {"m": [], "c": ["rotunda_drum_crown"]},
	"colonnade": {"m": ["rotunda_arcade_pier_"], "c": []},
	# the door-level ring is also part of the colonnade trait
	"peristyle": {"trait": "colonnade", "m": ["rotunda_peristyle_column_"], "c": []},
	"towers": {"m": ["pylon_0", "pylon_1"], "c": ["pylon_battered_face"]},
	"hypostyle": {"m": ["column_"], "c": []},
}


static func run() -> SuiteResult:
	var res := SuiteResult.new("sacred identity")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MATRIX))
	if not parsed is Dictionary:
		res.fail("matrix %s did not parse" % MATRIX)
		return res
	var cases := 0
	var by_form := {}
	for c in parsed["cases"]:
		if c["family"] != "temple" or not (c["style"] == "rotunda" or c["style"] == "pylon"):
			continue
		var req := BuildingRequest.from_dict(c["request"])
		var built := BrickWild.generate(req)
		res.checked += 1
		if not built.is_ok():
			res.fail("%s: generate failed %s" % [c["id"], str(built.errors)])
			continue
		var spec := built.spec as TempleSpec
		var builder := TempleBuilder.new()
		builder.build(spec)
		cases += 1
		by_form[spec.form] = [spec, builder]
		var got: Dictionary = Id.measure(spec, builder.mass_log, builder.component_log)
		for t in Id.traits_for(spec.form):
			res.checked += 1
			var r: Dictionary = got[t]
			if r["ok"]:
				res.note("%-34s %-10s %s" % [c["id"], t, r["note"]])
			else:
				res.fail("%s: trait '%s' missing: %s" % [c["id"], t, r["note"]])
			_removal(res, c["id"], spec, builder, t)
			if t == "colonnade":
				_removal(res, c["id"], spec, builder, "peristyle")
	res.checked += 1
	if cases != 12:
		res.fail("expected 6 rotunda + 6 pylon frozen cases, measured %d" % cases)
	_cross(res, by_form)
	res.note("%d frozen rotunda/pylon cases" % cases)
	return res


static func _removal(res: SuiteResult, id: String, spec: TempleSpec, builder: TempleBuilder,
		trait_name: String) -> void:
	var rm: Dictionary = REMOVE[trait_name]
	var measured: String = rm.get("trait", trait_name)
	var masses: Array = []
	for m in builder.mass_log:
		var drop := false
		for p in rm["m"]:
			if (m["name"] as String).begins_with(p):
				drop = true
		if not drop:
			masses.append(m)
	var comps: Array = []
	for c in builder.component_log:
		var drop := false
		for p in rm["c"]:
			if (c["role"] as String).begins_with(p):
				drop = true
		if not drop:
			comps.append(c)
	res.checked += 1
	var r: Dictionary = Id.measure(spec, masses, comps)[measured]
	if r["ok"]:
		res.fail("%s: removal control for '%s' still passes; the measure cannot fail" % [id, trait_name])


static func _cross(res: SuiteResult, by_form: Dictionary) -> void:
	if not by_form.has(&"rotunda") or not by_form.has(&"pylon"):
		res.fail("cross control needs both a rotunda and a pylon build")
		return
	for pair in [[&"rotunda", &"pylon"], [&"pylon", &"rotunda"]]:
		var spec: TempleSpec = by_form[pair[0]][0]
		var builder: TempleBuilder = by_form[pair[0]][1]
		var saved: StringName = spec.form
		spec.form = pair[1]
		var got: Dictionary = Id.measure(spec, builder.mass_log, builder.component_log)
		spec.form = saved
		for t in got:
			if t not in Id.traits_for(pair[1]):
				continue
			res.checked += 1
			if got[t]["ok"]:
				res.fail("a %s passes the %s trait '%s': %s" % [pair[0], pair[1], t, got[t]["note"]])
