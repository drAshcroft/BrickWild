import io


def edit(path, pairs):
    s = io.open(path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path + " :: anchor not unique: " + old[:70])
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8", newline="\n").write(s)
    print("patched " + path)


# ---- the church: floor candles flank the ALTAR, not the chancel step ----
#
# At the step they were between the brazier and the rail, in a metre of floor
# that already had two things in it. Beside the altar there is nothing else at
# all, which is also where a church actually stands them.
edit("src/church/church_furnisher.gd", [
("""	# candles on the floor at the foot of the chancel, and the rail across it
	for side3 in [-1.0, 1.0]:
		var cand: String = FLOOR_CANDLES[0 if side3 < 0.0 else 1]
		var candle_x: float = AISLE_W / 2.0 + 0.55
		if candle_x + PropCatalog.footprint(cand).x / 2.0 <= half:
			_put(out, cand, Vector3(side3 * candle_x, 0.0, az - 2.2), 0.0, 1.0, &"light")
	_dress_rail(spec, out, az - CHANCEL + 0.35)""",
 """	# Standing candles either side of the altar, outboard of the candelabra.
	# The chancel step was the obvious place and the wrong one: the lectern, the
	# brazier and the rail are already in that metre of floor, and beside the
	# altar there is nothing at all.
	for side3 in [-1.0, 1.0]:
		var cand: String = FLOOR_CANDLES[0 if side3 < 0.0 else 1]
		var candle_x: float = cx + PropCatalog.footprint(CANDELABRUM).x / 2.0 \\
			+ PropCatalog.footprint(cand).x / 2.0 + 0.25
		if candle_x + PropCatalog.footprint(cand).x / 2.0 <= half:
			_put(out, cand, Vector3(side3 * candle_x, 0.0, az - 0.15), 0.0, 1.0, &"light")
	_dress_rail(spec, out, az - CHANCEL + 0.35)"""),
])


# ---- the castle: the bookcase stands clear of the table it shares a room with
edit("src/castle/castle_furnisher.gd", [
("""	# a tall bookcase against the long wall, where the room is tall enough to
	# stand two and a half metres of it up
	if float(room["ceiling"]) >= 3.2 and half_len > 2.4:
		_put(out, LIBRARY, _v3(c + across * (half_wide - 0.4) - along * 1.2),
			_yaw_facing(-across), 1.0, &"store")""",
 """	# A tall bookcase against the long wall, where the room is tall enough to
	# stand two and a half metres of it up and long enough to stand it clear of
	# the table. Its own long axis runs ALONG the room, so how far down the room
	# it has to go is its half length plus the table half depth -- measured, not
	# guessed: at a guessed 1.2 m it stood through the table in every manor.
	var case_half: float = PropCatalog.footprint(LIBRARY).x / 2.0
	var table_half: float = PropCatalog.footprint(HIGH_TABLE).y * scale / 2.0
	var case_off: float = table_half + case_half + 0.35
	if float(room["ceiling"]) >= 3.2 and half_len > case_off + case_half + 0.8:
		_put(out, LIBRARY, _v3(c + across * (half_wide - 0.4) - along * case_off),
			_yaw_facing(-across), 1.0, &"store")"""),
])
