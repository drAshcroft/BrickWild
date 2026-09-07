import io

p = 'docs/HOUSES.md'
s = io.open(p, encoding='utf-8').read()

anchor = '## Furnishing'
assert anchor in s, 'anchor'

block = '''## Buildings round a yard

`HousePlan.courts` is a list of holes: `{rect, storey, outline?}`. A court is
**floor** to the walk grid, **sky** to the roof, and **outside** to the daylight
rule — a window onto a courtyard is a window. The rooms and the courts together
tile the footprint: what a court takes is not floor nobody owns, it is floor
that belongs to the weather.

It is what a monastery, an inn with a yard and a caravanserai are, and none of
them can be said with rooms alone.

`qa/court_check.gd` says what makes a courtyard building, in four rules — and
what makes one is not that it has a hole:

| | |
|---|---|
| **sky** | nothing is built in the court: no furniture, no stair. The plan check already forbids a *room* there; this catches a yard filled with the hall's tables, which is a hall with the roof off |
| **inward** | more windows onto the court than away from it. A courtyard building turns its back on the street, and one that put its glass outside has the plan inside out |
| **ring** | every range standing on the yard has a door onto it |
| **proportion** | the court is a room, not a light well and not a field: its narrow side ≥ 3 m, ≥ 4% of the footprint, and a warning when the ranges stand too tall for sky to reach the ground |

Three existing rules had to learn that a court **joins** rooms rather than
separating them:

* `HousePlan.door_graph()` joins every range that opens onto the same yard.
  You walk out of one door, across the paving and in at the other — without
  that, four ranges round a hole are four buildings and `connected` says so.
* `privacy` follows from the same graph.
* `doors_in_line` skips two doors facing each other across a yard. That rule is
  about a house you can see straight through from the street; a cloister is
  meant to look like that.

The builder roofs each **range** rather than the whole box — one sloping plate
falling from the outer wall in to the courtyard eaves, which is the only roof
shape that leaves the yard open — and lays the floor in four bands round the
hole, with the court itself paved a hand's breadth down.

'''
s = s.replace(anchor, block + anchor, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('houses ok')

p = 'README.md'
s = io.open(p, encoding='utf-8').read()
a = '| `assets` | measured prop catalogue still matches imported models |'
b = ('| `court` | buildings round a yard: the four court rules, each shown firing, and a hundred courtyard houses |\n'
     '| `assets` | measured prop catalogue still matches imported models |')
assert a in s, 'readme'
io.open(p, 'w', encoding='utf-8', newline='\n').write(s.replace(a, b, 1))
print('readme ok')
