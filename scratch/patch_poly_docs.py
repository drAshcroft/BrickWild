import io

p = 'docs/HOUSES.md'
s = io.open(p, encoding='utf-8').read()

anchor = '## Furnishing'
assert anchor in s, 'anchor'

block = '''## Rooms a rectangle cannot say

A room may carry an **`outline`**, a `PackedVector2Array`, and when it does the
outline is the truth: `rect` stays as its bounding box so every
rectangle-shaped rule still has something to measure. A room WITHOUT one is the
four-sided case, which is every room in every house — the outline exists for
the shapes a rectangle cannot say: a round tower, an octagonal chapter house, a
pagoda.

An outline is the **clear floor**, not a partition centre-line. A rectangular
room is cut out of the interior and shares half of each partition with its
neighbour; a polygonal room is not produced by cutting, so there is no shared
partition to give half of, and what you draw is what you walk on.

| | |
|---|---|
| `HouseGeometry.room_walls` | one wall per edge for a shaped room; the fixed **front, back, left, right** labelling for a rectangle. That order is a labelling and not a traversal — "the hearth is on wall 2" has to keep meaning the left wall |
| `room_floor_poly`, `room_area` | the outline, and its true area |
| `polygon_runs`, `shell_runs` | the wall centre-lines the builder raises masonry along: the outline pushed out by half a wall, exactly what `exterior_runs` does to the site rectangle |
| `HouseFurnisher` | every corner of a piece has to be inside the outline, not merely inside the box round it |
| `HouseNavCheck` | rasterises the outline, so the corners a chamfer cuts off are wall and nobody stands in them |
| `HousePlanCheck` | shaped rooms are compared by polygon intersection. The "floor nobody owns" sum applies only to a storey of rectangles: the corners an octagon cuts off are masonry, and that is what makes it a tower |

Three rules turned out to be measuring the box rather than the room, and all
three were found by building an octagonal tower rather than by reading:

* the window rule only recognised a wall by its position on the interior
  rectangle's edge, so every window on a diagonal was "in a partition";
* `_back_gap` measured to the bounding box, and reported every piece in the
  room as standing a metre and a quarter off a wall it was flat against;
* `_place_against_wall` took `absf()` of the wall normal to get its along
  vector. That is right for the four walls of a rectangle and meaningless on a
  diagonal, where it walked the piece off the wall entirely. The corrected
  maths — the direction the wall actually runs, and the piece's own width and
  depth — gives identical results for all four rectangle cases, which is why
  the house suites did not move.

'''
s = s.replace(anchor, block + anchor, 1)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
