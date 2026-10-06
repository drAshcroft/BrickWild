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

<!-- human-walk 1a10f7d03e2f9cffc3c house -->
## Walk — House: cottage / none, seed 1 — 2026-10-06T04:33:33Z

Building: Willowmill Cottage · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.6,"kind":"house","length":12.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"none","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"cottage","water":"none","width":9.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=house --seed=1 --style=cottage --purpose=none`

- [ ] pretty
- [ ] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (0)

None.

<!-- human-walk 1a10f80586ceca6d139 shop -->
## Walk — Shop: cottage / barracks, seed 1 — 2026-10-06T04:37:11Z

Building: Fox on Market Row · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.8,"kind":"shop","length":14.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"barracks","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"cottage","water":"none","width":11.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=shop --seed=1 --style=cottage --purpose=barracks`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (7)

1. **collision** — just a random diagonal here, does not match other side
   - at (3.92, 1.96, 7.00) (building-local), normal (0.00, 0.00, 1.00), hit `Shell`
   - camera (-1.17, 1.58, 11.60) looking (0.74, 0.05, -0.67)
   - ![pin 1](walk_shots/1a10f80586ceca6d139_1.png)
2. **collision** — z layering issue here.  flashes
   - at (5.32, 0.34, 6.87) (building-local), normal (1.00, 0.00, 0.00), hit `Shell`
   - camera (8.57, 1.58, 7.51) looking (-0.92, -0.35, -0.18)
   - ![pin 2](walk_shots/1a10f80586ceca6d139_2.png)
3. **collision** — need a texture on the roof.  flat does not make sense
   - at (4.89, 3.79, -4.80) (building-local), normal (0.67, 0.74, 0.00), hit `Shell`, room: office #1 (storey 0)
   - plan: doors[2] (0.83 m away)
   - camera (9.46, 1.58, -6.96) looking (-0.83, 0.40, 0.39)
   - ![pin 3](walk_shots/1a10f80586ceca6d139_3.png)
4. **collision** — two tables jammed against the entrance side of the room
   - at (1.01, 0.79, -1.97) (building-local), normal (0.00, 0.00, -1.00), hit `Furniture/Table_Large/Table_Large`, room: mess #2 (storey 0)
   - plan: furniture[10] Table_Large, furniture[11] Bench
   - camera (3.89, 1.72, -3.46) looking (-0.85, -0.28, 0.44)
   - ![pin 4](walk_shots/1a10f80586ceca6d139_4.png)
5. **collision** — bench length is wrong and blocks the room, and does match direction of table
   - at (0.37, 0.50, -2.77) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/@Node3D@143/Bench`, room: mess #2 (storey 0)
   - plan: furniture[14] Bench
   - camera (2.36, 1.72, -3.34) looking (-0.83, -0.51, 0.24)
   - ![pin 5](walk_shots/1a10f80586ceca6d139_5.png)
6. **collision** — this is an exterior light for a dungeon
   - at (-1.08, 1.92, -3.34) (building-local), normal (-0.00, -0.07, 1.00), hit `Furniture/Lantern_Wall/Lantern_Wall`, room: mess #2 (storey 0)
   - camera (-0.98, 1.72, -3.09) looking (-0.31, 0.59, -0.75)
   - ![pin 6](walk_shots/1a10f80586ceca6d139_6.png)
7. **collision** — no ceiling
   - at (-1.01, 7.08, -2.70) (building-local), normal (0.67, -0.74, 0.00), hit `Shell`
   - camera (3.44, 1.72, 3.54) looking (-0.48, 0.57, -0.67)
   - ![pin 7](walk_shots/1a10f80586ceca6d139_7.png)

<!-- human-walk 1a10f89a6dbf74a26f6 hotel -->
## Walk — Hotel: grand_budapest / , seed 1 — 2026-10-06T04:47:21Z

Building: Imperial Alpine Hotel · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":3.6,"kind":"hotel","length":24.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":3,"style":"grand_budapest","water":"none","width":48.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=hotel --seed=1 --style=grand_budapest --purpose=`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (16)

1. **collision** — z ordering problems
   - at (-0.90, 1.52, -11.87) (building-local), normal (1.00, 0.00, 0.00), hit `Shell`
   - plan: doors[11] (0.93 m away)
   - camera (0.63, 1.58, -13.12) looking (-0.78, -0.03, 0.63)
   - ![pin 1](walk_shots/1a10f89a6dbf74a26f6_1.png)
2. **collision** — why are these here.  they either need a door on the wall or not exist (a door is better
   - at (-0.71, 5.39, -12.00) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`
   - plan: windows[75] (0.79 m away)
   - camera (-6.38, 1.58, -17.48) looking (0.65, 0.43, 0.63)
   - ![pin 2](walk_shots/1a10f89a6dbf74a26f6_2.png)
3. **collision** — need to line up with the features that are behind them
   - at (-5.70, 4.30, -13.02) (building-local), normal (0.00, -1.00, 0.00), hit `Shell`
   - camera (-6.38, 1.58, -17.48) looking (0.13, 0.52, 0.85)
   - ![pin 3](walk_shots/1a10f89a6dbf74a26f6_3.png)
4. **collision** — does not join wall behind it
   - at (23.79, 1.97, -12.15) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - camera (19.65, 1.58, -16.13) looking (0.72, 0.07, 0.69)
   - ![pin 4](walk_shots/1a10f89a6dbf74a26f6_4.png)
5. **collision** — this wall needs some variety or decoration to break it up
   - at (24.00, 7.57, -2.77) (building-local), normal (1.00, 0.00, 0.00), hit `Shell`
   - plan: windows[185] (0.57 m away)
   - camera (30.47, 1.58, -13.62) looking (-0.46, 0.43, 0.78)
   - ![pin 5](walk_shots/1a10f89a6dbf74a26f6_5.png)
6. **collision** — same problem, boring and needs to be broken up
   - at (12.99, 5.45, 11.96) (building-local), normal (1.00, 0.00, 0.00), hit `Shell`
   - plan: windows[102] (0.61 m away)
   - camera (26.39, 1.58, 15.94) looking (-0.92, 0.27, -0.27)
   - ![pin 6](walk_shots/1a10f89a6dbf74a26f6_6.png)
7. **collision** — door is hard to get through
   - at (0.76, 0.12, -11.96) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - plan: doors[11] (0.82 m away)
   - camera (-0.60, 1.72, -7.86) looking (0.30, -0.35, -0.89)
   - ![pin 7](walk_shots/1a10f89a6dbf74a26f6_7.png)
8. **collision** — room is empty, we have furnashing and lots of props
   - at (4.38, 0.12, -8.70) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: lobby #1 (storey 0)
   - camera (-4.55, 1.72, -8.68) looking (0.98, -0.18, -0.00)
   - ![pin 8](walk_shots/1a10f89a6dbf74a26f6_8.png)
9. **collision** — stairway to no where
   - at (-1.74, 2.51, 1.28) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`, room: gallery #3 (storey 0)
   - camera (-4.59, 1.72, 0.37) looking (0.92, 0.26, 0.29)
   - ![pin 9](walk_shots/1a10f89a6dbf74a26f6_9.png)
10. **collision** — huge room with nothing in it
   - at (-7.46, 0.12, 6.41) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: office #5 (storey 0)
   - camera (-6.66, 1.72, 1.34) looking (-0.15, -0.30, 0.94)
   - ![pin 10](walk_shots/1a10f89a6dbf74a26f6_10.png)
11. **collision** — what is this?
   - at (-18.96, 0.12, -10.71) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: dining_room #0 (storey 0)
   - plan: furniture[1] Table_Large, windows[2] (0.97 m away)
   - camera (-17.19, 1.72, -8.38) looking (-0.53, -0.48, -0.70)
   - ![pin 11](walk_shots/1a10f89a6dbf74a26f6_11.png)
12. **collision** — zordering problems
   - at (-16.92, 3.60, -4.25) (building-local), normal (0.00, -1.00, 0.00), hit `Shell`, room: dining_room #0 (storey 0), guest_room #10 (storey 1), guest_room #11 (storey 1)
   - camera (-16.90, 1.72, -5.28) looking (-0.01, 0.88, 0.48)
   - ![pin 12](walk_shots/1a10f89a6dbf74a26f6_12.png)
13. **collision** — a bar??? room does not make sense
   - at (-10.45, 0.12, 9.96) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: kitchen #4 (storey 0)
   - camera (-17.31, 1.72, 4.26) looking (0.76, -0.18, 0.63)
   - ![pin 13](walk_shots/1a10f89a6dbf74a26f6_13.png)
14. **collision** — door is impossible to pass
   - at (-22.54, 0.12, 11.90) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - plan: doors[12] (0.40 m away)
   - camera (-22.80, 1.58, 13.62) looking (0.11, -0.64, -0.76)
   - ![pin 14](walk_shots/1a10f89a6dbf74a26f6_14.png)
15. **collision** — why are there tiny carrots here?
   - at (-23.08, 0.16, 2.41) (building-local), normal (0.00, 0.00, 1.00), hit `Furniture/FarmCrate_Carrot/FarmCrate_Carrot`, room: kitchen #4 (storey 0)
   - plan: furniture[37] FarmCrate_Carrot, windows[48] (0.87 m away)
   - camera (-23.18, 1.72, 4.28) looking (0.04, -0.64, -0.77)
   - ![pin 15](walk_shots/1a10f89a6dbf74a26f6_15.png)
16. **collision** — what is this?
   - at (0.91, 3.60, -0.43) (building-local), normal (0.00, -1.00, 0.00), hit `Furniture/@Node3D@231/Bookcase_2`, room: gallery #3 (storey 0), gallery #17 (storey 1)
   - plan: furniture[91] Bookcase_2
   - camera (-0.49, 1.72, -0.19) looking (0.59, 0.80, -0.10)
   - ![pin 16](walk_shots/1a10f89a6dbf74a26f6_16.png)

<!-- human-walk 1a10f8b2344acda7803 temple -->
## Walk — Temple: basilica / blood, seed 1 — 2026-10-06T04:48:59Z

Building: The Rustreliquary of the Long Sleep · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":12.0,"kind":"temple","length":44.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"blood","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"basilica","water":"none","width":26.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=temple --seed=1 --style=basilica --purpose=blood`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (2)

1. **collision** — looks like a barn
   - at (-13.00, 8.94, -6.22) (building-local), normal (-1.00, 0.00, 0.00), hit `Stone`
   - camera (-40.01, 1.58, -14.50) looking (0.93, 0.25, 0.28)
   - ![pin 1](walk_shots/1a10f8b2344acda7803_1.png)
2. **collision** — this is funny. I like it
   - at (1.08, 3.49, 18.25) (building-local), normal (1.00, 0.00, 0.00), hit `Stone`
   - camera (4.71, 2.26, 15.77) looking (-0.80, 0.27, 0.54)
   - ![pin 2](walk_shots/1a10f8b2344acda7803_2.png)

<!-- human-walk 1a10f8c7e57ac727ae3 windmill -->
## Walk — Windmill: tower / , seed 1 — 2026-10-06T04:50:28Z

Building: Rook Mill · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":12.0,"kind":"windmill","length":6.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"tower","water":"none","width":12.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=windmill --seed=1 --style=tower --purpose=`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (4)

1. **collision** — window is not in the wall
   - at (-1.65, 5.17, -1.85) (building-local), normal (-0.55, 0.09, -0.83), hit `Shell`
   - camera (-3.33, 1.58, -8.53) looking (0.22, 0.46, 0.86)
   - ![pin 1](walk_shots/1a10f8c7e57ac727ae3_1.png)
2. **collision** — vanes are really small
   - at (-0.79, 12.00, -1.74) (building-local), normal (0.00, -1.00, 0.00), hit `Shell`
   - camera (-3.33, 1.58, -8.53) looking (0.20, 0.82, 0.54)
   - ![pin 2](walk_shots/1a10f8c7e57ac727ae3_2.png)
3. **collision** — door is not a door
   - at (0.14, 1.50, -3.00) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`
   - camera (0.17, 1.58, -5.27) looking (-0.01, -0.04, 1.00)
   - ![pin 3](walk_shots/1a10f8c7e57ac727ae3_3.png)
4. **collision** — I can see the gap
   - at (0.01, 2.15, -2.90) (building-local), normal (0.00, 0.00, 1.00), hit `Shell`
   - camera (3.43, 1.58, -2.51) looking (-0.98, 0.16, -0.11)
   - ![pin 4](walk_shots/1a10f8c7e57ac727ae3_4.png)

<!-- human-walk 1a10f8e7682668f8189 world -->
## Walk — World: courtyard_house / domus, seed 1 — 2026-10-06T04:52:37Z

Building: Merchant's Domus · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":6.0,"kind":"world","length":30.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"domus","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"courtyard_house","water":"none","width":20.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=world --seed=1 --style=courtyard_house --purpose=domus`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (7)

1. **collision** — what is this?
   - at (5.70, 2.89, -15.00) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`
   - plan: windows[1] (0.69 m away), doors[2] (0.69 m away)
   - camera (2.32, 1.58, -24.18) looking (0.00, -0.05, 1.00)
   - ![pin 1](walk_shots/1a10f8e7682668f8189_1.png)
2. **collision** — same here
   - at (6.20, 1.60, -15.00) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`
   - plan: windows[1] (0.62 m away), doors[2] (0.62 m away)
   - camera (2.32, 1.58, -24.18) looking (0.00, -0.05, 1.00)
   - ![pin 2](walk_shots/1a10f8e7682668f8189_2.png)
3. **collision** — really big empty wall?
   - at (-10.00, 2.45, -8.88) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - camera (-14.11, 1.58, -16.54) looking (0.47, 0.10, 0.88)
   - ![pin 3](walk_shots/1a10f8e7682668f8189_3.png)
4. **collision** — z order problem. hard to get through the door
   - at (0.47, 1.18, -14.57) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - plan: doors[0] (0.51 m away)
   - camera (-0.49, 1.72, -11.83) looking (0.33, -0.18, -0.93)
   - ![pin 4](walk_shots/1a10f8e7682668f8189_4.png)
5. **collision** — what is this?
   - at (2.59, 0.92, -11.87) (building-local), normal (-1.00, 0.00, 0.00), hit `Furniture/Banner_2_Cloth/Banner_2_Cloth`, room: gallery #1 (storey 0), sales_floor #2 (storey 0)
   - camera (-0.49, 1.72, -11.83) looking (0.97, -0.25, -0.01)
   - ![pin 5](walk_shots/1a10f8e7682668f8189_5.png)
6. **collision** — what are these
   - at (-2.68, 1.43, -1.72) (building-local), normal (1.00, 0.00, 0.00), hit `Shell`, room: gallery #3 (storey 0)
   - plan: windows[5] (0.21 m away)
   - camera (-0.26, 1.60, -1.12) looking (-0.97, -0.07, -0.24)
   - ![pin 6](walk_shots/1a10f8e7682668f8189_6.png)
7. **collision** — empty building?
   - at (4.74, 0.12, 6.39) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: gallery #4 (storey 0)
   - camera (5.54, 1.72, 2.22) looking (-0.18, -0.35, 0.92)
   - ![pin 7](walk_shots/1a10f8e7682668f8189_7.png)

<!-- human-walk 1a10f969d1e9468a0ef village -->
## Walk — Village: english / farming, seed 1 — 2026-10-06T05:01:31Z

Building: Wolfmarch Green · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":1.0,"kind":"village","length":35.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"farming","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"english","water":"none","width":40.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=village --seed=1 --style=english --purpose=farming`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (16)

1. **collision** — floating bush
   - at (-7.36, 0.51, -41.46) (building-local), normal (-0.09, 1.00, -0.01), hit `Plants/Wild_Bush_Common_86/Bush_Common`
   - camera (-4.27, 1.60, -44.03) looking (-0.74, -0.26, 0.62)
   - ![pin 1](walk_shots/1a10f969d1e9468a0ef_1.png)
2. **collision** — really empty
   - at (-15.27, 0.00, -40.46) (building-local), normal (0.00, 1.00, 0.00), hit `Ground`
   - camera (-4.27, 1.60, -44.03) looking (-0.94, -0.14, 0.31)
   - ![pin 2](walk_shots/1a10f969d1e9468a0ef_2.png)
3. **collision** — flying wagon?
   - at (-61.83, 0.81, -38.70) (building-local), normal (-0.65, 0.04, -0.76), hit `Buildings/house_9/Exterior/yard_1/Cart`
   - camera (-63.77, 1.61, -40.24) looking (0.75, -0.31, 0.59)
   - ![pin 3](walk_shots/1a10f969d1e9468a0ef_3.png)
4. **collision** — shutters are not over the beams and not under the beams
   - at (-67.55, 3.89, -32.62) (building-local), normal (-0.99, 0.00, -0.17), hit `Buildings/house_9/Shell`
   - camera (-69.83, 1.61, -31.29) looking (0.65, 0.65, -0.38)
   - ![pin 4](walk_shots/1a10f969d1e9468a0ef_4.png)
5. **collision** — stairs do not work like this.  cant get on them when they start in the wall
   - at (-63.66, 1.58, -31.83) (building-local), normal (-0.17, 0.00, 0.99), hit `Buildings/house_9/Shell`
   - camera (-66.70, 1.72, -31.74) looking (1.00, -0.04, -0.03)
   - ![pin 5](walk_shots/1a10f969d1e9468a0ef_5.png)
6. **collision** — tables do not go directly in front of the door in the entrance
   - at (-65.17, 0.81, -33.99) (building-local), normal (0.00, 1.00, 0.00), hit `Buildings/house_9/Furniture/Table_Large/Table_Large`
   - camera (-65.70, 1.72, -34.51) looking (0.45, -0.77, 0.44)
   - ![pin 6](walk_shots/1a10f969d1e9468a0ef_6.png)
7. **collision** — collision, people normally only have 1 dinning table per house
   - at (-61.64, 0.81, -35.16) (building-local), normal (0.00, 1.00, 0.00), hit `Buildings/house_9/Furniture/@Node3D@792/Table_Large`
   - camera (-62.12, 1.72, -34.13) looking (0.33, -0.62, -0.71)
   - ![pin 7](walk_shots/1a10f969d1e9468a0ef_7.png)
8. **collision** — big gaps
   - at (-65.55, 0.00, 2.74) (building-local), normal (0.00, 1.00, 0.00), hit `Ground`
   - camera (-68.34, 1.60, -14.29) looking (0.16, -0.09, 0.98)
   - ![pin 8](walk_shots/1a10f969d1e9468a0ef_8.png)
9. **collision** — ground lights?
   - at (-79.43, 0.15, -3.78) (building-local), normal (0.16, 0.00, -0.99), hit `Buildings/shop_2/Shell`
   - camera (-76.06, 1.62, -6.03) looking (-0.78, -0.34, 0.52)
   - ![pin 9](walk_shots/1a10f969d1e9468a0ef_9.png)
10. **collision** — table blocked by beer
   - at (-74.11, 0.71, -1.81) (building-local), normal (0.00, 1.00, 0.00), hit `Buildings/shop_2/Furniture/Table_Large/Table_Large`
   - camera (-76.22, 1.72, -0.99) looking (0.85, -0.41, -0.33)
   - ![pin 10](walk_shots/1a10f969d1e9468a0ef_10.png)
11. **collision** — ghost float beer?
   - at (-76.37, 2.71, 1.13) (building-local), normal (-0.20, 0.02, -0.98), hit `Buildings/shop_2/Furniture/Mug/Mug`
   - camera (-77.41, 1.72, 0.02) looking (0.57, 0.55, 0.61)
   - ![pin 11](walk_shots/1a10f969d1e9468a0ef_11.png)
12. **collision** — ghost eating ?
   - at (-75.74, 2.64, 1.20) (building-local), normal (-0.69, 0.00, -0.72), hit `Buildings/shop_2/Furniture/Table_Spoon/Table_Spoon`
   - camera (-77.41, 1.72, 0.02) looking (0.74, 0.41, 0.53)
   - ![pin 12](walk_shots/1a10f969d1e9468a0ef_12.png)
13. **collision** — so many tables in this house.  not sure I can get to the other room behind this
   - at (-64.11, 0.81, 32.10) (building-local), normal (0.00, 1.00, 0.00), hit `Buildings/house_4/Furniture/Table_Large/Table_Large`
   - camera (-63.65, 1.72, 33.07) looking (-0.33, -0.65, -0.69)
   - ![pin 13](walk_shots/1a10f969d1e9468a0ef_13.png)
14. **collision** — interesting entrance? pillar right through the door
   - at (18.32, 1.03, 15.95) (building-local), normal (-1.00, 0.00, 0.00), hit `Buildings/church_0/Shell`
   - camera (13.85, 1.61, 14.54) looking (0.95, -0.12, 0.30)
   - ![pin 14](walk_shots/1a10f969d1e9468a0ef_14.png)
15. **collision** — random rope? church bondage
   - at (20.27, 0.10, 17.46) (building-local), normal (0.22, -0.02, -0.97), hit `Buildings/church_0/Dressing/Rope_2/Rope_2`
   - camera (19.94, 1.63, 16.27) looking (0.16, -0.78, 0.60)
   - ![pin 15](walk_shots/1a10f969d1e9468a0ef_15.png)
16. **collision** — hidden candles?
   - at (30.72, 1.31, 11.87) (building-local), normal (1.00, 0.00, -0.00), hit `Buildings/church_0/Shell`
   - camera (32.65, 1.61, 9.15) looking (-0.58, -0.09, 0.81)
   - ![pin 16](walk_shots/1a10f969d1e9468a0ef_16.png)

<!-- human-walk 1a10f984ec6f729daf3 church -->
## Walk — Church: romanesque / , seed 1 — 2026-10-06T05:03:22Z

Building: Abbey Ivo · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":12.0,"kind":"church","length":22.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"romanesque","water":"none","width":10.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=church --seed=1 --style=romanesque --purpose=`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (2)

1. **collision** — gaps
   - at (-4.71, 7.52, -1.19) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - camera (-11.96, 1.58, -2.07) looking (0.77, 0.63, 0.09)
   - ![pin 1](walk_shots/1a10f984ec6f729daf3_1.png)
2. **collision** — stuck in door
   - at (0.36, 0.10, -18.44) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - camera (0.42, 1.58, -17.77) looking (-0.04, -0.91, -0.41)
   - ![pin 2](walk_shots/1a10f984ec6f729daf3_2.png)

<!-- human-walk 1a10f9d8fd5f7eaa1a5 castle -->
## Walk — Castle: norman / , seed 1 — 2026-10-06T05:09:06Z

Building: Thorncliffe Tower · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":18.0,"kind":"castle","length":50.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"norman","water":"none","width":55.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=castle --seed=1 --style=norman --purpose=`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (14)

1. **collision** — mostly ok, but really close to wall
   - at (-6.81, -0.02, -20.24) (building-local), normal (0.00, 1.00, 0.00), hit `ground`
   - camera (-9.74, 1.58, -20.37) looking (0.88, -0.48, 0.04)
   - ![pin 1](walk_shots/1a10f9d8fd5f7eaa1a5_1.png)
2. **collision** — really small landing
   - at (-6.20, 2.28, -16.42) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - camera (-6.49, 3.69, -17.33) looking (0.17, -0.83, 0.53)
   - ![pin 2](walk_shots/1a10f9d8fd5f7eaa1a5_2.png)
3. **collision** — no rails?
   - at (-6.97, 11.41, -16.08) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - camera (-6.48, 12.80, -17.43) looking (-0.24, -0.70, 0.67)
   - ![pin 3](walk_shots/1a10f9d8fd5f7eaa1a5_3.png)
4. **collision** — weird thing here?
   - at (-4.53, 14.26, -20.88) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - camera (-5.72, 14.82, -19.10) looking (0.54, -0.25, -0.80)
   - ![pin 4](walk_shots/1a10f9d8fd5f7eaa1a5_4.png)
5. **collision** — really hard to climb stairs
   - at (-5.48, 17.68, -19.02) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - camera (-5.66, 19.85, -21.39) looking (0.05, -0.67, 0.74)
   - ![pin 5](walk_shots/1a10f9d8fd5f7eaa1a5_5.png)
6. **collision** — z order problems
   - at (-6.31, 18.25, -20.90) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - camera (-5.66, 19.85, -21.46) looking (-0.36, -0.88, 0.31)
   - ![pin 6](walk_shots/1a10f9d8fd5f7eaa1a5_6.png)
7. **collision** — gap problems
   - at (-10.82, 18.25, -21.21) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - camera (-8.34, 19.85, -21.59) looking (-0.83, -0.54, 0.13)
   - ![pin 7](walk_shots/1a10f9d8fd5f7eaa1a5_7.png)
8. **collision** — in walls
   - at (-24.03, 18.58, -1.79) (building-local), normal (0.77, -0.24, -0.59), hit `Dressing/@Node3D@972/Cauldron`
   - camera (-21.41, 19.85, -4.63) looking (-0.65, -0.31, 0.70)
   - ![pin 8](walk_shots/1a10f9d8fd5f7eaa1a5_8.png)
9. **collision** — in wlal
   - at (-13.37, 18.81, 21.08) (building-local), normal (0.13, -0.15, -0.98), hit `Dressing/@Node3D@967/Cauldron`
   - camera (-13.96, 19.85, 17.73) looking (0.17, -0.29, 0.94)
   - ![pin 9](walk_shots/1a10f9d8fd5f7eaa1a5_9.png)
10. **collision** — gap problems
   - at (-11.04, 18.25, 21.16) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - camera (-12.16, 19.85, 20.48) looking (0.54, -0.78, 0.33)
   - ![pin 10](walk_shots/1a10f9d8fd5f7eaa1a5_10.png)
11. **collision** — weird lines?
   - at (7.13, 4.87, 0.40) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`
   - camera (6.42, 1.58, -2.83) looking (0.15, 0.71, 0.69)
   - ![pin 11](walk_shots/1a10f9d8fd5f7eaa1a5_11.png)
12. **collision** — ok spot for these
   - at (8.86, 2.23, 1.98) (building-local), normal (-1.00, -0.04, -0.00), hit `hall/Furniture/Lantern_Wall/Lantern_Wall`
   - camera (7.98, 1.72, 3.75) looking (0.43, 0.25, -0.87)
   - ![pin 12](walk_shots/1a10f9d8fd5f7eaa1a5_12.png)
13. **collision** — why only 2 benches in room with this many tables
   - at (9.58, 0.51, 8.94) (building-local), normal (0.01, 1.00, -0.02), hit `hall/Furniture/@Node3D@1042/Bench`
   - camera (7.58, 1.72, 8.77) looking (0.85, -0.52, 0.07)
   - ![pin 13](walk_shots/1a10f9d8fd5f7eaa1a5_13.png)
14. **collision** — these are arrow holes, but no way to get to the inside of the walls?
   - at (-14.32, 11.25, -15.75) (building-local), normal (0.88, 0.00, 0.48), hit `Shell`
   - camera (-0.54, 1.58, -7.89) looking (-0.74, 0.52, -0.42)
   - ![pin 14](walk_shots/1a10f9d8fd5f7eaa1a5_14.png)

