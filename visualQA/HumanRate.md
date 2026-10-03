# Human visual QA

Saved by the local review page. Pretty means approval; the other checked boxes mean a visible problem.
Unchecked problem boxes mean no problem was flagged in this image, not proof that the mesh is correct.

<!-- human-walk 1a1030ce0521e8a6361 house -->
## Walk — House: cottage / none, seed 1 — 2026-10-03T18:35:37Z

Building: Willowmill Cottage · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.6,"kind":"house","length":12.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"none","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"cottage","water":"none","width":9.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=house --seed=1 --style=cottage --purpose=none`

- [x] pretty
- [x] collisions
- [x] window problems
- [x] door problems
- [x] roof problems

### Pins (6)

1. **collision** — frame is colinear with wall and the z order is confused
   - at (-2.75, 1.57, -5.88) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - camera (-3.72, 1.58, -7.26) looking (0.58, -0.00, 0.82)
   - ![pin 1](walk_shots/1a1030ce0521e8a6361_1.png)
2. **roof** — no ceiling
   - at (-4.18, 3.01, -4.21) (building-local), normal (0.62, -0.78, 0.00), hit `Shell`, room: store #0 (storey 0)
   - camera (-0.21, 1.72, -4.70) looking (-0.94, 0.31, 0.12)
   - ![pin 2](walk_shots/1a1030ce0521e8a6361_2.png)
3. **other** — feng sui is bad to put bed right by door
   - at (-2.33, 0.45, 0.99) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/Bed_Twin1/Bed_Twin1`, room: bedroom #3 (storey 0)
   - camera (-1.65, 1.72, 1.95) looking (-0.40, -0.73, -0.55)
   - ![pin 3](walk_shots/1a1030ce0521e8a6361_3.png)
4. **other** — chair does not face table
   - at (-3.00, 0.95, -1.52) (building-local), normal (1.00, -0.03, 0.00), hit `Furniture/@Node3D@124/Chair_1`, room: parlour #2 (storey 0)
   - camera (-2.20, 1.72, -1.06) looking (-0.67, -0.64, -0.38)
   - ![pin 4](walk_shots/1a1030ce0521e8a6361_4.png)
5. **other** — have to jump over the table to get through the room
   - at (-1.96, 0.81, -1.99) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/@Node3D@123/Table_Large`, room: parlour #2 (storey 0)
   - camera (-2.60, 1.72, -2.71) looking (0.49, -0.69, 0.54)
   - ![pin 5](walk_shots/1a1030ce0521e8a6361_5.png)
6. **other** — same problem, chair is facing away from table
   - at (1.66, 0.50, -3.66) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/Chair_1/Chair_1`, room: hall #1 (storey 0)
   - camera (1.68, 1.72, -2.63) looking (-0.01, -0.76, -0.65)
   - ![pin 6](walk_shots/1a1030ce0521e8a6361_6.png)

