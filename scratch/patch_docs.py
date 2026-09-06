import io
p = "docs/CASTLES.md"
s = io.open(p, encoding="utf-8").read()
old = "## What the suites check\n"
new = """## Dressing

`CastleFurnisher` fills the shell with props from the same measured catalogue
the houses use (`assets/props/catalog.json`), and logs them on the builder as
`prop_log`. `CastleAssembler` is the only thing that turns one into a node.

| where | what goes in it |
|---|---|
| great hall | high table on the dais with a chalice and candles, chairs behind it, rows of trestles and benches down the length, a brazier on the long wall, barrels in the low corners |
| chapel | altar at the apse end, a candelabrum either side, benches facing it, torches on both walls |
| keep, manor wings, ridge lodgings | a table with stools, a chest, a weapon stand, a barrel, torches and a banner |
| bailey | a cart, an anvil and its fire, a training dummy, weapon stand, barrels, crates, sacks and rope, dealt round the inside of the curtain |
| defences | braziers along the wall walk and on every tower top, torches either side of the gate passage |

Two rules the placer will not break. The **way in** -- a corridor the width of
the gate, from the gate to the back of the bailey -- is reserved before any
clutter is set down, along with every building already standing in the yard.
And a **ridge range is furnished in its own frame**, not in its bounding box:
the spine runs at an angle to the world, and a trestle laid out on the box
stands outside the wall.

A range is logged as one mass from the ground to its eaves, so the dressing
treats a keep's ceiling as `ROOM_CEILING` (5.5 m) rather than the twenty metres
of the mass. It furnishes the ground floor; a banner hung at three quarters of
a keep would fly four storeys above the only floor there is.

## What the suites check
"""
assert s.count(old) == 1
io.open(p, "w", encoding="utf-8", newline="\n").write(s.replace(old, new))

old2 = "`castle voxel QA` -- run with\n`godot --headless --path . --script res://tests/run_all.gd -- castle cnormals cmassing clandmark cvoxelqa`."
new2 = ("`castle voxel QA` -- run with\n"
        "`godot --headless --path . --script res://tests/run_all.gd -- castle cnormals cmassing clandmark cvoxelqa`.\n\n"
        "`dressing` (shared with the churches) sweeps the same variants and asks\n"
        "whether every prop is a prop the catalogue knows, whether it stands inside\n"
        "the building, whether two of them are in the same place at the same height,\n"
        "and whether a person can still walk from the gate to the middle of the\n"
        "bailey with the clutter in the way.")
s = io.open(p, encoding="utf-8").read()
assert s.count(old2) == 1
io.open(p, "w", encoding="utf-8", newline="\n").write(s.replace(old2, new2))
print("patched")
