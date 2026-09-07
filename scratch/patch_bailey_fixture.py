import io

p = 'tests/suites/castle_massing_suite.gd'
s = io.open(p, encoding='utf-8').read()

# find the run() tail to hang the fixture off
anchor = '\t_expect_rule(res, "slender", TowerCheck.new().check(spec, squat))'
assert anchor in s, 'anchor'

# add the call right before the tower fixtures block by appending to run()
call_anchor = None
for cand in ['\treturn res\n', '\treturn res']:
    if cand in s:
        call_anchor = cand
        break
assert call_anchor, 'return'
s = s.replace(call_anchor, '\t_bailey_fixture(res)\n' + call_anchor, 1)

body = '''

## The bailey_clear rule, shown to fire (CAS-012).
##
## A castle is generated properly -- the rule must be silent on it -- and then
## one yard building is shoved sideways into the curtain by hand. A rule that
## does not notice a stable built through the wall is measuring nothing.
static func _bailey_fixture(res: SuiteResult) -> void:
	var spec := CastleSpec.new()
	spec.style = &"edwardian"
	spec.width = 60.0
	spec.length = 90.0
	spec.height = 18.0
	CastleGenerator.generate(spec, 9001)
	var builder := CastleBuilder.new()
	builder.build(spec)
	res.checked += 1
	var yards: Array[Dictionary] = []
	for m in builder.mass_log:
		if String(m["name"]).begins_with("yard_"):
			yards.append(m)
	if yards.is_empty():
		res.fail("bailey fixture: the castle put nothing in its yard to test with")
		return
	for f in CastleMassingCheck.new().check(spec, builder)["failures"]:
		if String(f).begins_with("bailey_clear:"):
			res.fail("bailey fixture: a properly laid out bailey was reported: %s" % str(f))

	# now shove one building out through the curtain
	res.checked += 1
	var moved := CastleBuilder.new()
	moved.build(spec)
	for i in range(moved.mass_log.size()):
		if not String(moved.mass_log[i]["name"]).begins_with("yard_"):
			continue
		var a: AABB = moved.mass_log[i]["aabb"]
		var yard: Rect2 = CastleGeometry.bailey_rect(spec)
		a.position.x = yard.end.x + 1.0
		moved.mass_log[i]["aabb"] = a
		break
	var caught := false
	for f2 in CastleMassingCheck.new().check(spec, moved)["failures"]:
		if String(f2).begins_with("bailey_clear:"):
			caught = true
	if not caught:
		res.fail("bailey fixture: a yard building pushed out through the curtain was not caught")

	# and one parked across the way in from the gate
	res.checked += 1
	var blocked := CastleBuilder.new()
	blocked.build(spec)
	for j in range(blocked.mass_log.size()):
		if not String(blocked.mass_log[j]["name"]).begins_with("yard_"):
			continue
		var b: AABB = blocked.mass_log[j]["aabb"]
		b.position.x = -b.size.x / 2.0
		blocked.mass_log[j]["aabb"] = b
		break
	var caught2 := false
	for f3 in CastleMassingCheck.new().check(spec, blocked)["failures"]:
		if String(f3).begins_with("bailey_clear:") and String(f3).contains("way from the gate"):
			caught2 = true
	if not caught2:
		res.fail("bailey fixture: a yard building parked across the gate axis was not caught")
'''
s = s.rstrip('\n') + body
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('written')
