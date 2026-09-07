import io

# ---- the suite itself: retitle, and sweep keeps beside halls
p = 'tests/suites/castle_interior_suite.gd'
s = io.open(p, encoding='utf-8').read()

s = s.replace('class_name HallSuite', 'class_name CastleInteriorSuite', 1)

old = '''## 12b. The great hall interior over a wide band of castles (CAS-010).'''
new = '''## 12b. The castle interiors -- great hall and keep -- over a wide band of
##      castles (CAS-010, CAS-011).'''
assert old in s, 'title'
s = s.replace(old, new, 1)

old = 'var res := SuiteResult.new("great hall")'
new = 'var res := SuiteResult.new("castle interiors")'
assert old in s, 'result name'
s = s.replace(old, new, 1)

old = '''	for key in WANT:
		var rate: float = float(int(tally[key])) / float(halls)
		res.checked += 1
		var line := "%-11s %5.1f%% (want %.0f%%)" % [key, rate * 100.0,
			float(WANT[key]) * 100.0]
		if rate < float(WANT[key]) - 0.001:
			res.fail("great hall: %s" % line)
		else:
			res.note("great hall  %s" % line)
	return res'''
new = '''	for key in WANT:
		var rate: float = float(int(tally[key])) / float(halls)
		res.checked += 1
		var line := "%-11s %5.1f%% (want %.0f%%)" % [key, rate * 100.0,
			float(WANT[key]) * 100.0]
		if rate < float(WANT[key]) - 0.001:
			res.fail("great hall: %s" % line)
		else:
			res.note("great hall  %s" % line)
	_keeps(res)
	return res


## The keeps of the same band of castles (CAS-011).
##
## Structure is asserted in the castle suite, on the canonical twelve of every
## style and tier. What this adds is the SHAPES the canonical set never
## visits -- and the one thing worth stating as a rate rather than a rule:
## how often a keep comes out of a castle at all.
static func _keeps(res: SuiteResult) -> void:
	var built := 0
	var levels := {}
	var styles: Array = CastleSpec.STYLES.keys()
	var r := RandomNumberGenerator.new()
	r.seed = 20261101
	for i in range(COUNT):
		var spec := CastleSpec.new()
		spec.style = styles[i % styles.size()]
		spec.width = r.randf_range(10.0, 90.0)
		spec.length = spec.width * r.randf_range(1.0, 2.0)
		spec.height = r.randf_range(6.0, 24.0)
		var sd: int = 41000 + i
		CastleGenerator.generate(spec, sd)
		var plan: HousePlan = CastleGenerator.keep_plan(spec)
		res.checked += 1
		if plan.spec == null:
			continue
		built += 1
		levels[plan.spec.storeys] = int(levels.get(plan.spec.storeys, 0)) + 1
		var who := "keep %s %.0f x %.0fm seed=%d" % [String(spec.style),
			spec.width, spec.length, sd]
		for rep in [HousePlanCheck.new().check(plan),
				HouseFurnishCheck.new().check(plan), HouseNavCheck.new().check(plan)]:
			for m in rep["failures"]:
				res.fail("%s: %s" % [who, str(m)])
			for w in rep["warnings"]:
				res.warn("%s: %s" % [who, str(w)])
	res.note("keep        %d of %d castles have one, storeys %s"
		% [built, COUNT, str(levels)])
	res.checked += 1
	if built < COUNT / 5:
		res.fail("keep: only %d of %d castles produced one" % [built, COUNT])'''
assert old in s, 'tail'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('suite ok')

# ---- the runner
p = 'tests/run_all.gd'
s = io.open(p, encoding='utf-8').read()
for a, b in [
    ('## 12b hall       - the great hall interior, over two hundred castles',
     '## 12b interior   - the castle interiors, hall and keep, over two hundred castles'),
    ('"dressing", "hall",', '"dressing", "interior",'),
    ('\t\t"hall":\n\t\t\treturn HallSuite.run()',
     '\t\t"interior":\n\t\t\treturn CastleInteriorSuite.run()'),
]:
    assert a in s, a
    s = s.replace(a, b, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('runner ok')

# ---- the docs
p = 'README.md'
s = io.open(p, encoding='utf-8').read()
a = '`rite`, `hall` | spatial, circulation and ritual correctness'
b = '`rite`, `interior` | spatial, circulation and ritual correctness'
assert a in s, 'readme'
io.open(p, 'w', encoding='utf-8', newline='\n').write(s.replace(a, b, 1))
print('readme ok')

p = 'docs/CASTLES.md'
s = io.open(p, encoding='utf-8').read()
for a, b in [
    ('`great hall` and `castle voxel QA`', '`castle interiors` and `castle voxel QA`'),
    ('clandmark hall cvoxelqa`', 'clandmark interior cvoxelqa`'),
    ('`castle` proves the great hall arrangement on the twelve canonical castles of\nevery style and tier; `hall` is the sweep, two hundred halls at sizes the\ncanonical set does not visit, and reports the rate at which each part of the\narrangement actually comes out.',
     '`castle` proves the great hall and the keep on the twelve canonical castles of\nevery style and tier; `interior` is the sweep -- two hundred halls and two\nhundred keeps at sizes the canonical set does not visit -- and reports the rate\nat which each part of the arrangement actually comes out.'),
]:
    assert a in s, a[:40]
    s = s.replace(a, b, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('castles doc ok')
