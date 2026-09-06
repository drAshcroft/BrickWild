import io

def edit(path, pairs):
    s = io.open(path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path + " anchor not unique: " + old[:70])
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8", newline="\n").write(s)
    print("patched " + path)

# ---- MassBuilder owns the dressing log, alongside the other two ----
edit("core/mass_builder.gd", [
("""## QA log: one entry per STRUCTURAL MASS""",
 """## QA log: one entry per PROP the building is dressed with, in the form
## PropCatalog.placement() returns. Empty on a family that emits no dressing.
## Like the other two logs it records what the builder ACTUALLY placed, which
## is what DressingCheck measures and what the assembler instantiates.
var prop_log: Array[Dictionary] = []
## QA log: one entry per STRUCTURAL MASS"""),
("""	part_log.clear()
	mass_log.clear()""",
 """	part_log.clear()
	mass_log.clear()
	prop_log.clear()"""),
])

# ---- TempleBuilder inherits it now ----
edit("src/temple/temple_builder.gd", [
("""var spec: TempleSpec
## {key, pos: Vector3, yaw, scale, kind: StringName}
var prop_log: Array[Dictionary] = []
""",
 """var spec: TempleSpec
"""),
("""	begin(4)
	prop_log.clear()
	total_height = spec.height""",
 """	begin(4)
	total_height = spec.height"""),
])

# ---- ChurchBuilder: dress the church once the masons have finished ----
edit("src/church/church_builder.gd", [
("""	_build_narthex()
	_build_ambulatory_and_chapels()
	_build_flying_buttresses()
	_build_crossing_tower()
	_build_dome()

	return commit()""",
 """	_build_narthex()
	_build_ambulatory_and_chapels()
	_build_flying_buttresses()
	_build_crossing_tower()
	_build_dome()

	# The masons are finished; the parish moves in. The dressing is prop
	# PLACEMENTS rather than geometry, so it costs the mesh nothing and
	# ChurchAssembler is the only thing that ever loads a model.
	prop_log = ChurchFurnisher.dress(spec)

	return commit()"""),
])

# ---- CastleBuilder: same, at every one of its exits ----
edit("src/castle/castle_builder.gd", [
("""	if CastleGeometry.is_tower_house(spec):
		_build_tower_house()
		return commit()
	if CastleGeometry.is_ridge(spec):
		_build_ridge()
		return commit()
	match spec.tier:
		&"house":
			_build_house()
		&"manor":
			_build_manor()
		_:
			_build_enclosure()
	return commit()""",
 """	if CastleGeometry.is_tower_house(spec):
		_build_tower_house()
		return _dressed()
	if CastleGeometry.is_ridge(spec):
		_build_ridge()
		return _dressed()
	match spec.tier:
		&"house":
			_build_house()
		&"manor":
			_build_manor()
		_:
			_build_enclosure()
	return _dressed()


## The garrison moves in. The dressing is prop PLACEMENTS rather than geometry,
## so it costs the mesh nothing and CastleAssembler is the only thing that ever
## loads a model. Every tier leaves through here, so no tier can be given a
## shell and then quietly forgotten.
func _dressed() -> ArrayMesh:
	prop_log = CastleFurnisher.dress(spec)
	return commit()"""),
])
