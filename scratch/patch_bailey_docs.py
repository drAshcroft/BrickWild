import io

p = 'docs/CASTLES.md'
s = io.open(p, encoding='utf-8').read()

anchor = '## Dressing'
assert anchor in s, 'anchor'

block = '''## The bailey is a yard, not a lawn

A castle was a village that happened to have a wall round it. The bailey here
held the keep, the hall and the chapel and nothing else, which is a picture of
a castle nobody worked in: no stable for the horses that got you there, no
kitchen away from the hall it feeds, no smithy, no store, no well.

`CastleGenerator.bailey_buildings(spec)` fills it, and fills it with **shops** --
the shop family already knows how to plan a stable, a cookshop, a smithy and a
store, so the bailey invents no building kinds of its own. Each entry is
`{business, rect, yaw}`; `bailey_shop()` turns one into a generated `ShopSpec`.

| tier | what stands in the yard |
|---|---|
| castle | stable, cookshop |
| fortress | stable, cookshop, smithy, store |

They stand **along the side walls**, marching back from the gate, turned a
quarter so the front looks across the yard rather than up it. The middle stays
empty on purpose: `CastleGeometry.gate_axis_strip()` is the way from the gate
to the keep -- the gate opening plus a wagon either side -- and a yard built
across the middle is a yard you cannot cross. `bailey_well()` then sinks a
`PropKit` well in the open ground nearest the centre, six metres clear of
everything built.

Two rules had to learn that a courtyard building is not part of the
fortification, and both learned it the same way an existing rule already
worked:

* `MassRules.gaps` takes a `free` list, as `grounded` already takes `carried`.
  That rule is about a mass that FLOATS; a building standing on its own in a
  yard is not floating, it is a separate building, and `grounded` is what says
  it must stand on something.
* `CastleQA`'s `connected_mass` seeds its flood from each free-standing
  building as well as from the curtain. It cannot skip by name -- it works on
  voxels -- so instead every grounded component gets a seed. Geometry attached
  to nothing at all is still unreachable from all of them.

`CastleMassingCheck`'s new `bailey_clear` rule measures the LOGGED masses, not
the layout that produced them: a layout pass that agrees with itself and
disagrees with the builder is exactly what it is there to catch, and it caught
three such disagreements while this was being written.

'''
s = s.replace(anchor, block + anchor, 1)

old = '''| bailey | a cart, an anvil and its fire, a training dummy, weapon stand, barrels, crates, sacks and rope, dealt round the inside of the curtain |'''
new = '''| bailey | a cart, an anvil and its fire, a training dummy, weapon stand, barrels, crates, sacks and rope, dealt round the inside of the curtain -- and the yard buildings and well of CAS-012 above |'''
assert old in s, 'dressing row'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
