import io

def edit(path, pairs):
    s = io.open(path, encoding="utf-8").read()
    for old, new in pairs:
        assert s.count(old) == 1, (path + " anchor not unique: " + old[:70])
        s = s.replace(old, new)
    io.open(path, "w", encoding="utf-8", newline="\n").write(s)
    print("patched " + path)

# HouseSpec now declares dormer_count itself, so the hotel inherits it rather
# than redeclaring it (which GDScript rejects outright).
edit("src/hotel/hotel_spec.gd", [
("var dormer_count: int = 9\n", ""),
("""	super(p_seed)
	style = &"grand_budapest\"""",
 """	super(p_seed)
	# dormer_count is HouseSpec's now; a hotel simply has more of them
	dormer_count = 9
	style = &"grand_budapest\""""),
])

# HouseBuilder gained a _build_dormers of its own with a different signature.
# A hotel dormer is a different piece of architecture, not an override of it.
edit("src/hotel/hotel_builder.gd", [
("	_build_dormers(top, hs)\n", "	_build_hotel_dormers(top, hs)\n"),
("func _build_dormers(top: float, hs: HotelSpec) -> void:",
 """## The hotel's own dormers: a long even row across a mansard, which is not
## the same piece of architecture as HouseBuilder._build_dormers -- that one
## sets them on one pitch of a cottage roof, in the roof's own frame.
func _build_hotel_dormers(top: float, hs: HotelSpec) -> void:"""),
])
