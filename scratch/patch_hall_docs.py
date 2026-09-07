import io

# ------------------------------------------------------------------ HOUSES
p = 'docs/HOUSES.md'
s = io.open(p, encoding='utf-8').read()

old = '''| `around` | seats belong at a table, facing it, with room to push back |'''
new = '''| `around` | seats belong at a table, facing it, with room to push back |
| `behind` | the seat on the far side of a thing with a front and a back: the lord's bench behind the high table, the clerk's stool behind the counter |
| `row` | N copies along a wall or an axis at one pitch, sharing one aisle: pews, barrack beds, the trestles down a hall |'''
assert old in s
s = s.replace(old, new)

old = '''`opt: 1.0` marks a piece the room is not that room without. Those are placed
first, without a dice roll, and the passes that thin a room out will not touch
them. Everything else is dressing and can be taken back out.'''
new = '''`opt: 1.0` marks a piece the room is not that room without. Those are placed
first, without a dice roll, and the passes that thin a room out will not touch
them. Everything else is dressing and can be taken back out.

**Floor the plan keeps clear.** A use zone is the floor one piece needs and
belongs to that piece. `HousePlan.zones` is the other kind: floor kept clear
because of what the room is *for*, and kept clear if the room were empty — the
screens passage inside a great hall's door, so the way in is not through the
middle of dinner. The furnisher treats one as occupied ground before the first
piece is placed, the `clear` rule proves nothing ended up standing in it, and
the nav check proves it can actually be walked.

**Floor at another height.** `HousePlan.dais` is a raised rectangle in a room:
`{room, rect, rise}`. It is a step, not a wall — the walk grid keeps a level
per cell and joins two cells whose floors differ by up to `WalkGrid.MAX_STEP`
(0.6 m), so a person walks up onto a dais and does not walk off a mezzanine.
Anything standing on it is placed in plan exactly as if the floor were flat and
lifted by the rise when it is committed.'''
assert old in s
s = s.replace(old, new)

old = '''doors, into every room, and up to every use zone. A house passes only if every
room can be entered, both sides of every door can be stood on, and every piece
of furniture somebody is meant to use can be reached.'''
new = '''doors, into every room, and up to every use zone. A house passes only if every
room can be entered, both sides of every door can be stood on, and every piece
of furniture somebody is meant to use can be reached. Its `steps` rule adds the
two things a plan can ask for that are not furniture: the dais is walked onto,
and every passage the plan keeps clear is walked.'''
assert old in s
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('HOUSES ok')

# ----------------------------------------------------------------- CASTLES
p = 'docs/CASTLES.md'
s = io.open(p, encoding='utf-8').read()

old = '''## Dressing'''
new = '''## The great hall has an inside

`CastleGenerator.hall_plan(spec)` returns the hall range as a **`HousePlan`**:
one room, in the hall's own frame, whose rectangle is the hall mass footprint
less the wall it stands inside. `CastleGeometry.hall_aabb()` says where that
frame sits in the castle.

The point of doing it this way is that nothing new judges it. The hall is a
house plan, so `HousePlanCheck` measures its room and its openings,
`HouseFurnisher` furnishes it from a recipe like any other room,
`HouseFurnishCheck` judges what stands in it and `HouseNavCheck` walks it. What
makes it a *hall* is five arrangements, each of which is a rule the house
harness already had a name for:

| | |
|---|---|
| the **dais** | a raised rectangle at the end away from the door, a fifth of the hall deep and 0.4 m up. `HousePlan.dais`; the walk grid takes it as a step and a person walks onto it |
| the **high table** | on the dais, looking down the hall at the door. It is `plan.focus` (INT-002), so the furnisher pins it there and the `focus` rule proves it is there and facing the right way |
| the **lord's bench** | behind the high table, by the `behind` rule — and nobody sits between the high table and the hall |
| the **trestle rows** | down the length, by the `row` rule (INT-001), benches drawn up to them, each row with its own aisle |
| the **hearth** | on a long wall, on `plan.hearth.wall`, which is the wall the flue rises on (LAY-001) |
| the **screens passage** | a strip inside the door recorded in `plan.zones`, which the furnishing may not fill in and the walk has to reach |

A range too small to feast in — under 3 m across or 16 m² — gets no plan
rather than a bad one, and a hall that could not fit its second row of
trestles records a compromise the way any other room does.

`CastleFurnisher` still dresses the hall mass from the prop tables below;
CAS-013 is the task that switches `CastleBuilder` over to raising every
interior from its plan instead.

## Dressing'''
assert old in s
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('CASTLES ok')
