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

<!-- human-walk 1a113a20fda8c84783d house -->
## Walk — House: cottage / none, seed 1 — 2026-10-06T23:52:30Z

Building: Willowmill Cottage · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.6,"kind":"house","length":12.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"none","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"cottage","water":"none","width":9.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=house --seed=1 --style=cottage --purpose=none`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (3)

1. **collision** — collides with table.
   - at (2.61, 0.71, -4.01) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/Stool/Stool`, room: hall #1 (storey 0)
   - plan: furniture[7] Table_Large, furniture[10] Stool
   - camera (2.20, 1.72, -5.21) looking (0.25, -0.63, 0.74)
   - ![pin 1](walk_shots/1a113a20fda8c84783d_1.png)
2. **collision** — chairs face the wrong way
   - at (2.09, 0.62, -3.30) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/@Node3D@119/Chair_1`, room: hall #1 (storey 0)
   - plan: furniture[9] Chair_1
   - camera (2.20, 1.72, -5.21) looking (-0.05, -0.50, 0.87)
   - ![pin 2](walk_shots/1a113a20fda8c84783d_2.png)
3. **collision** — need to get some kitchen furnature from the assets
   - at (-0.49, 0.71, 3.98) (building-local), normal (1.00, 0.00, 0.00), hit `Shell`, room: bedroom #3 (storey 0), kitchen #5 (storey 0)
   - camera (3.30, 1.72, 4.29) looking (-0.96, -0.26, -0.08)
   - ![pin 3](walk_shots/1a113a20fda8c84783d_3.png)

<!-- human-walk 1a113a3c325506bad9a shop -->
## Walk — Shop: cottage / barracks, seed 1 — 2026-10-06T23:54:21Z

Building: Fox on Market Row · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.8,"kind":"shop","length":14.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"barracks","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"cottage","water":"none","width":11.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=shop --seed=1 --style=cottage --purpose=barracks`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (2)

1. **collision** — giant room with crowded two tables in the room
   - at (0.01, 0.62, -1.57) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/@Node3D@154/Bench`, room: mess #2 (storey 0)
   - plan: furniture[15] Bench
   - camera (2.27, 1.72, -3.21) looking (-0.75, -0.37, 0.55)
   - ![pin 1](walk_shots/1a113a3c325506bad9a_1.png)
2. **collision** — give the baracks some dressers?
   - at (-0.92, 0.12, 4.43) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: dormitory #3 (storey 0)
   - camera (4.81, 1.72, 4.37) looking (-0.96, -0.27, 0.01)
   - ![pin 2](walk_shots/1a113a3c325506bad9a_2.png)

<!-- human-walk 1a113eece1512b6faee hotel -->
## Walk — Hotel: grand_budapest / , seed 1 — 2026-10-07T01:16:19Z

Building: Imperial Alpine Hotel · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":3.6,"kind":"hotel","length":24.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":3,"style":"grand_budapest","water":"none","width":48.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=hotel --seed=1 --style=grand_budapest --purpose=`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (11)

1. **collision** — chair is backwards
   - at (0.15, 0.61, -7.44) (building-local), normal (-0.01, 0.00, -1.00), hit `Furniture/@Node3D@181/Chair_1`, room: lobby #1 (storey 0)
   - plan: furniture[22] Chair_1, furniture[33] CandleStick_Stand
   - camera (-1.06, 1.72, -9.75) looking (0.00, -0.05, 1.00)
   - ![pin 1](walk_shots/1a113eece1512b6faee_1.png)
2. **collision** — light is right in the way of the table
   - at (-0.22, 0.12, -6.99) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: lobby #1 (storey 0)
   - plan: furniture[33] CandleStick_Stand
   - camera (-1.06, 1.72, -9.75) looking (0.00, -0.05, 1.00)
   - ![pin 2](walk_shots/1a113eece1512b6faee_2.png)
3. **collision** — why two kinds of chairs?
   - at (-1.11, 0.71, -7.22) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/@Node3D@183/Stool`, room: lobby #1 (storey 0)
   - plan: furniture[25] Stool
   - camera (-1.06, 1.72, -8.82) looking (0.00, -0.05, 1.00)
   - ![pin 3](walk_shots/1a113eece1512b6faee_3.png)
4. **collision** — this is not very much like the lobby of a huge hotel.  find couches, plants, put a conseirge desk in
   - at (2.20, 0.12, -7.89) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: lobby #1 (storey 0)
   - camera (-2.80, 1.72, -8.82) looking (0.94, -0.30, 0.17)
   - ![pin 4](walk_shots/1a113eece1512b6faee_4.png)
5. **collision** — this does not work.  what is it and why is it right in the way
   - at (-1.04, 0.33, 0.08) (building-local), normal (1.00, 0.00, 0.00), hit `Furniture/BookStand/BookStand`, room: gallery #3 (storey 0)
   - plan: furniture[49] BookStand
   - camera (1.52, 1.72, 0.41) looking (-0.87, -0.48, -0.11)
   - ![pin 5](walk_shots/1a113eece1512b6faee_5.png)
6. **collision** — cannot get to the stairs
   - at (-0.50, 1.95, 1.07) (building-local), normal (1.00, 0.00, 0.00), hit `Shell`, room: gallery #3 (storey 0)
   - plan: doors[5] (0.82 m away)
   - camera (1.52, 1.72, 0.41) looking (-0.95, 0.10, 0.31)
   - ![pin 6](walk_shots/1a113eece1512b6faee_6.png)
7. **collision** — no rails, narrow hallways
   - at (-1.64, 3.72, 0.25) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: gallery #3 (storey 0), gallery #17 (storey 1)
   - camera (-0.25, 5.32, -0.41) looking (-0.63, -0.72, 0.30)
   - ![pin 7](walk_shots/1a113eece1512b6faee_7.png)
8. **collision** — z ordering problems
   - at (-1.36, 3.73, 1.63) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`, room: gallery #3 (storey 0), laundry #6 (storey 0), gallery #17 (storey 1), guest_room #21 (storey 1)
   - camera (-0.25, 5.32, -0.41) looking (-0.39, -0.56, 0.73)
   - ![pin 8](walk_shots/1a113eece1512b6faee_8.png)
9. **collision** — huge rooms with nothing inside
   - at (-13.42, 3.72, -5.78) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: dining_room #0 (storey 0), guest_room #11 (storey 1)
   - camera (-13.41, 5.32, -1.29) looking (-0.00, -0.34, -0.94)
   - ![pin 9](walk_shots/1a113eece1512b6faee_9.png)
10. **collision** — maybe the kitchen? needs a kitchen
   - at (-13.82, 0.12, 7.82) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: kitchen #4 (storey 0)
   - camera (-17.57, 1.72, 4.25) looking (0.69, -0.30, 0.66)
   - ![pin 10](walk_shots/1a113eece1512b6faee_10.png)
11. **collision** — these doors are not inside?
   - at (-4.97, 4.96, -11.84) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`
   - plan: windows[73] (0.26 m away)
   - camera (-5.70, 1.58, -17.41) looking (0.11, 0.52, 0.85)
   - ![pin 11](walk_shots/1a113eece1512b6faee_11.png)

<!-- human-walk 1a113ef8bedb9eed501 temple -->
## Walk — Temple: basilica / blood, seed 1 — 2026-10-07T01:17:08Z

Building: The Rustreliquary of the Long Sleep · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":12.0,"kind":"temple","length":44.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"blood","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"basilica","water":"none","width":26.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=temple --seed=1 --style=basilica --purpose=blood`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (1)

1. **collision** — zordering problems
   - at (-1.60, 2.09, -21.46) (building-local), normal (1.00, 0.00, 0.00), hit `Stone`
   - camera (-0.65, 1.72, -21.34) looking (-0.93, 0.36, -0.12)
   - ![pin 1](walk_shots/1a113ef8bedb9eed501_1.png)

<!-- human-walk 1a113f01037f263d777 windmill -->
## Walk — Windmill: tower / , seed 1 — 2026-10-07T01:17:42Z

Building: Rook Mill · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":12.0,"kind":"windmill","length":6.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"tower","water":"none","width":12.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=windmill --seed=1 --style=tower --purpose=`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (1)

1. **collision** — door is missing some ribs
   - at (-0.02, 1.23, -2.85) (building-local), normal (0.00, 0.09, -1.00), hit `Shell`
   - camera (-0.50, 1.58, -4.86) looking (0.23, -0.17, 0.96)
   - ![pin 1](walk_shots/1a113f01037f263d777_1.png)

<!-- human-walk 1a113f41f088a9b6f32 world -->
## Walk — World: courtyard_house / domus, seed 1 — 2026-10-07T01:22:08Z

Building: Merchant's Domus · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":6.0,"kind":"world","length":30.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"domus","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"courtyard_house","water":"none","width":20.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=world --seed=1 --style=courtyard_house --purpose=domus`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (4)

1. **collision** — this is a pretty boring facade.  missing a lot of information and details
   - at (0.98, 3.37, -15.00) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`
   - camera (-0.11, 1.58, -21.65) looking (0.16, 0.26, 0.95)
   - ![pin 1](walk_shots/1a113f41f088a9b6f32_1.png)
2. **collision** — no furnishing
   - at (-1.57, 0.12, -8.34) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: gallery #1 (storey 0)
   - camera (0.39, 1.72, -12.07) looking (-0.44, -0.35, 0.83)
   - ![pin 2](walk_shots/1a113f41f088a9b6f32_2.png)
3. **collision** — missing lights
   - at (2.78, 3.71, 2.91) (building-local), normal (1.00, 0.00, 0.00), hit `Shell`, room: dining_room #4 (storey 0), bedroom #5 (storey 0)
   - plan: furniture[23] Table_Large
   - camera (5.92, 1.72, 2.53) looking (-0.84, 0.53, 0.10)
   - ![pin 3](walk_shots/1a113f41f088a9b6f32_3.png)
4. **collision** — one bench, just a table in a huge room
   - at (-6.98, 0.12, 5.55) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: parlour #3 (storey 0)
   - camera (-5.25, 1.72, 0.10) looking (-0.29, -0.27, 0.92)
   - ![pin 4](walk_shots/1a113f41f088a9b6f32_4.png)

<!-- human-walk 1a113f86d10724c5a87 village -->
## Walk — Village: english / farming, seed 1 — 2026-10-07T01:26:50Z

Building: Wolfmarch Green · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":1.0,"kind":"village","length":35.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"farming","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"english","water":"none","width":40.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=village --seed=1 --style=english --purpose=farming`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (12)

1. **collision** — what is this?  a pear?
   - at (-26.29, 1.29, -35.77) (building-local), normal (-0.42, 0.23, 0.88), hit `Ground`
   - camera (-26.61, 1.60, -34.18) looking (0.20, -0.19, -0.96)
   - ![pin 1](walk_shots/1a113f86d10724c5a87_1.png)
2. **collision** — zordering problems
   - at (-63.42, 2.67, -31.76) (building-local), normal (-0.99, 0.00, -0.17), hit `Buildings/house_9/Shell`
   - camera (-64.12, 2.11, -32.71) looking (0.54, 0.43, 0.73)
   - ![pin 2](walk_shots/1a113f86d10724c5a87_2.png)
3. **collision** — bench on stairs
   - at (-63.52, 1.65, -32.09) (building-local), normal (0.04, 1.00, 0.01), hit `Buildings/house_9/Furniture/Shelf_Simple/Shelf_Simple`
   - camera (-63.56, 2.10, -32.66) looking (0.06, -0.62, 0.78)
   - ![pin 3](walk_shots/1a113f86d10724c5a87_3.png)
4. **collision** — cannot climb stairs
   - at (-63.89, 1.53, -31.63) (building-local), normal (0.17, 0.00, -0.99), hit `Buildings/house_9/Shell`
   - camera (-63.56, 2.10, -32.66) looking (-0.27, -0.47, 0.84)
   - ![pin 4](walk_shots/1a113f86d10724c5a87_4.png)
5. **collision** — no railing
   - at (-64.67, 2.72, -31.69) (building-local), normal (0.00, 1.00, 0.00), hit `Buildings/house_9/Shell`
   - camera (-65.13, 4.32, -33.34) looking (0.20, -0.68, 0.70)
   - ![pin 5](walk_shots/1a113f86d10724c5a87_5.png)
6. **collision** — stairs go directly into the wall
   - at (-64.12, 2.60, -30.46) (building-local), normal (0.00, 1.00, 0.00), hit `Buildings/house_9/Shell`
   - camera (-65.13, 4.32, -33.34) looking (0.29, -0.49, 0.82)
   - ![pin 6](walk_shots/1a113f86d10724c5a87_6.png)
7. **collision** — stuck in the floor?
   - at (-66.80, 2.72, -33.91) (building-local), normal (0.99, 0.00, 0.17), hit `Buildings/house_9/Shell`
   - camera (-64.34, 4.32, -34.17) looking (-0.83, -0.54, 0.09)
   - ![pin 7](walk_shots/1a113f86d10724c5a87_7.png)
8. **collision** — these should not have colliders
   - at (-2.45, 0.52, 7.65) (building-local), normal (0.41, 0.78, 0.48), hit `Plants/Wild_Clover_2_4/Clover_2`
   - camera (-4.20, 1.63, 11.28) looking (0.42, -0.27, -0.87)
   - ![pin 8](walk_shots/1a113f86d10724c5a87_8.png)
9. **collision** — why?
   - at (20.40, 0.01, 14.15) (building-local), normal (0.00, 1.00, 0.00), hit `Ground`
   - camera (19.81, 1.63, 16.23) looking (0.22, -0.60, -0.77)
   - ![pin 9](walk_shots/1a113f86d10724c5a87_9.png)
10. **collision** — really short door
   - at (19.56, 1.92, 15.61) (building-local), normal (-0.00, -1.00, 0.00), hit `Buildings/church_0/Shell`
   - camera (20.29, 1.63, 16.13) looking (-0.78, 0.31, -0.55)
   - ![pin 10](walk_shots/1a113f86d10724c5a87_10.png)
11. **collision** — no entrance
   - at (31.70, 1.66, 20.03) (building-local), normal (0.16, 0.00, 0.99), hit `Buildings/church_0/Shell`
   - camera (31.49, 1.61, 24.47) looking (0.05, 0.01, -1.00)
   - ![pin 11](walk_shots/1a113f86d10724c5a87_11.png)
12. **collision** — tables do not go right in front of main entrances (most of the time they do not go in the front room.  especially in a house this big
   - at (53.53, 0.74, 31.30) (building-local), normal (0.00, 1.00, 0.00), hit `Buildings/house_5/Furniture/Table_Large/Table_Large`
   - camera (54.02, 1.72, 29.90) looking (-0.28, -0.55, 0.78)
   - ![pin 12](walk_shots/1a113f86d10724c5a87_12.png)

<!-- human-walk 1a113f97860b8a160d1 house -->
## Walk — House: witch_hut / none, seed 1 — 2026-10-07T01:27:58Z

Building: Hollowbarrow Steading · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.6,"kind":"house","length":12.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"none","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"witch_hut","water":"none","width":9.0}`

Re-open: `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=house --seed=1 --style=witch_hut --purpose=none`

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (1)

1. **collision** — what makes this a witch's hut?  it is just a german style tract house from the 50s
   - at (-0.13, 3.13, -6.00) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`
   - plan: windows[2] (0.83 m away)
   - camera (-0.85, 1.58, -11.83) looking (0.12, 0.25, 0.96)
   - ![pin 1](walk_shots/1a113f97860b8a160d1_1.png)

<!-- human-walk 1a17a4d4878f601b119 house -->
## Walk — House: witch_hut / none, seed 1 — 2026-10-26T22:20:47Z

Building: Copperwell Steading · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.6,"jank":0.9,"kind":"house","length":12.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"none","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"witch_hut","water":"none","width":9.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=house --seed=1 --style=witch_hut --purpose=none --jank=0.9`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [x] roof problems

### Pins (1)

1. **roof** (bug) — hovering blocks
   - at (3.71, 2.25, -3.67) (building-local), normal (0.00, 0.09, -1.00), hit `Shell`
   - camera (3.84, 1.58, -7.17) looking (-0.03, 0.19, 0.98)
   - ![pin 1](walk_shots/1a17a4d4878f601b119_1.png)

<!-- human-walk 1a17a52f2f52bd9a39f house -->
## Walk — House: witch_hut / none, seed 62994 — 2026-10-26T22:26:58Z

Building: Millstonewell House · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.6,"jank":0.9,"kind":"house","length":12.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"none","schema":"brickwild.request","schema_version":1,"seed":"62994","storeys":1,"style":"witch_hut","water":"none","width":9.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=house --seed=62994 --style=witch_hut --purpose=none --jank=0.9`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [x] roof problems

### Pins (2)

1. **collision** (bug) — collision between patio and roof
   - at (3.62, 2.23, -4.72) (building-local), normal (-0.00, -0.05, -1.00), hit `Shell`
   - camera (3.17, 1.58, -6.59) looking (0.22, 0.32, 0.92)
   - ![pin 1](walk_shots/1a17a52f2f52bd9a39f_1.png)
2. **roof** (bug) — what is this?  I think it is supposed to be something with thatch, but does not make sense.  thatch has round corners and a brush end
   - at (-4.12, 2.76, -4.71) (building-local), normal (-0.50, -0.87, 0.00), hit `Shell`
   - camera (-4.96, 1.58, -6.35) looking (0.39, 0.54, 0.75)
   - ![pin 2](walk_shots/1a17a52f2f52bd9a39f_2.png)

<!-- human-walk 1a17a53cb7c3411d43d shop -->
## Walk — Shop: cottage / bakery, seed 1 — 2026-10-26T22:27:54Z

Building: Fox on Market Row · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.8,"kind":"shop","length":14.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"bakery","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"cottage","water":"none","width":11.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=2 --kind=shop --seed=1 --style=cottage --purpose=bakery`

Tour: sprint_2026_10_26, stop 2 / 22 — shop wares: oven, bread racks, counter

- [ ] pretty
- [ ] collisions
- [ ] window problems
- [ ] door problems
- [x] roof problems

### Pins (1)

1. **roof** (bug) — same floating roof things
   - at (-5.67, 2.70, -7.10) (building-local), normal (0.00, -1.00, 0.00), hit `Shell`
   - camera (-5.74, 1.58, -9.41) looking (0.03, 0.44, 0.90)
   - ![pin 1](walk_shots/1a17a53cb7c3411d43d_1.png)

<!-- human-walk 1a17a563bd6bda10403 church -->
## Walk — Church: russian / , seed 1 — 2026-10-26T22:30:34Z

Building: Grey Ninian-in-the-Wold · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":12.0,"jank":0.3,"kind":"church","length":22.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"russian","water":"none","width":10.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=3 --kind=church --seed=1 --style=russian --jank=0.3`

Tour: sprint_2026_10_26, stop 3 / 22 — shop wares: the block and the hanging rail

- [ ] pretty
- [x] collisions
- [x] window problems
- [ ] door problems
- [ ] roof problems

### Pins (4)

1. **lighting** (bug) — light sticking out of a window
   - at (-4.77, 2.44, -7.99) (building-local), normal (-1.00, -0.02, 0.00), hit `Shell`
   - camera (-9.85, 1.58, -9.65) looking (0.94, 0.16, 0.31)
   - ![pin 1](walk_shots/1a17a563bd6bda10403_1.png)
2. **window** (bug) — gap all aroung the window
   - at (1.50, 0.50, 8.35) (building-local), normal (0.64, -0.59, 0.49), hit `Dressing/Cauldron/Cauldron`
   - camera (7.53, 1.58, 7.32) looking (-0.97, -0.17, 0.17)
   - ![pin 2](walk_shots/1a17a563bd6bda10403_2.png)
3. **collision** (bug) — something sticking out the wall here
   - at (4.94, 2.63, -4.03) (building-local), normal (0.07, 0.03, 1.00), hit `Dressing/@Node3D@3823/Torch_Metal`
   - camera (7.09, 1.58, -3.00) looking (-0.83, 0.40, -0.40)
   - ![pin 3](walk_shots/1a17a563bd6bda10403_3.png)
4. **furniture / prop** (bug) — whats with the ropes in the church entrances?
   - at (3.22, 0.00, -12.30) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - camera (0.87, 1.60, -16.17) looking (0.49, -0.33, 0.81)
   - ![pin 4](walk_shots/1a17a563bd6bda10403_4.png)

<!-- human-walk 1a17a581a8b52680ca1 shop -->
## Walk — Shop: cottage / blacksmith, seed 1 — 2026-10-26T22:32:36Z

Building: Fox on Market Row · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.8,"kind":"shop","length":14.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"blacksmith","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"cottage","water":"none","width":11.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=4 --kind=shop --seed=1 --style=cottage --purpose=blacksmith`

Tour: sprint_2026_10_26, stop 4 / 22 — shop wares: bolts, cutting table, dummy

- [ ] pretty
- [ ] collisions
- [ ] window problems
- [x] door problems
- [ ] roof problems

### Pins (1)

1. **door** (bug) — there is only one door on a giant house
   - at (-0.89, 1.27, -6.82) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - plan: windows[1] (0.97 m away)
   - camera (-1.47, 1.72, -8.08) looking (0.40, -0.31, 0.86)
   - ![pin 1](walk_shots/1a17a581a8b52680ca1_1.png)

<!-- human-walk 1a17af8e3ccd02529bf shop -->
## Walk — Shop: rich / apothecary, seed 1 — 2026-10-27T01:28:14Z

Building: Fox on Market Row · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.8,"kind":"shop","length":14.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"apothecary","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"rich","water":"none","width":11.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=shop --seed=1 --style=rich --purpose=apothecary`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [ ] roof problems

### Pins (1)

1. **collision** (polish) — misaligned and collition between the shelf and dresser
   - at (-4.76, 1.11, -5.50) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/Cabinet/Cabinet`, room: sales_floor #0 (storey 0)
   - plan: furniture[8] Cabinet
   - camera (-2.64, 1.72, -6.09) looking (-0.93, -0.27, 0.26)
   - ![pin 1](walk_shots/1a17af8e3ccd02529bf_1.png)
<!-- /human-walk 1a17af8e3ccd02529bf -->

<!-- human-walk 1a17afb7cea2a7a9ef5 shop -->
## Walk — Shop: african / apothecary, seed 1 — 2026-10-27T01:31:04Z

Building: Bell on Market Row · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.8,"kind":"shop","length":14.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"apothecary","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"african","water":"none","width":11.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=shop --seed=1 --style=african --purpose=apothecary`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [x] roof problems

### Pins (2)

1. **roof** (bug) — floating beams
   - at (-5.50, 2.50, -6.89) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - camera (-6.17, 1.58, -8.59) looking (0.33, 0.45, 0.83)
   - ![pin 1](walk_shots/1a17afb7cea2a7a9ef5_1.png)
2. **furniture / prop** (blocker) — box right in front of door and the dispensor window
   - at (-0.40, 0.52, -5.78) (building-local), normal (0.08, 0.00, 1.00), hit `Furniture/@Node3D@1511/Crate_Metal`, room: sales_floor #0 (storey 0)
   - plan: furniture[13] Crate_Metal, windows[7] (0.91 m away)
   - camera (-2.18, 1.72, -4.80) looking (0.75, -0.51, -0.42)
   - ![pin 2](walk_shots/1a17afb7cea2a7a9ef5_2.png)
<!-- /human-walk 1a17afb7cea2a7a9ef5 -->

<!-- human-walk 1a17afcec5f5edef665 shop -->
## Walk — Shop: pueblo / apothecary, seed 1 — 2026-10-27T01:32:38Z

Building: Bell on Market Row · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.8,"kind":"shop","length":14.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"apothecary","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"pueblo","water":"none","width":11.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=shop --seed=1 --style=pueblo --purpose=apothecary`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [ ] door problems
- [x] roof problems

### Pins (1)

1. **missing / wrong for the style** (bug) — this is the same house as the sahel
   - at (-5.50, 2.42, -6.60) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - camera (-7.97, 1.58, -8.24) looking (0.49, -0.10, 0.86)
   - ![pin 1](walk_shots/1a17afcec5f5edef665_1.png)
<!-- /human-walk 1a17afcec5f5edef665 -->

<!-- human-walk 1a17afdf8d68c5bba38 windmill -->
## Walk — Windmill: tower / , seed 1 — 2026-10-27T01:33:47Z

Building: Rook Mill · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":12.0,"kind":"windmill","length":6.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"tower","water":"none","width":12.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=windmill --seed=1 --style=tower`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (1)

1. **door** (bug) — there is no inside or way inside
   - at (-0.43, 0.97, -2.87) (building-local), normal (0.00, 0.09, -1.00), hit `Shell`
   - camera (-0.03, 1.58, -4.78) looking (-0.20, -0.30, 0.93)
   - ![pin 1](walk_shots/1a17afdf8d68c5bba38_1.png)
<!-- /human-walk 1a17afdf8d68c5bba38 -->

<!-- human-walk 1a17afe6f8098c4a6c6 windmill -->
## Walk — Windmill: post / , seed 1 — 2026-10-27T01:34:17Z

Building: Hollow Green Mill · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":12.0,"kind":"windmill","length":6.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"post","water":"none","width":12.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=windmill --seed=1 --style=post`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (4)

1. **collision** (bug) — windmill collides with door, wall, railing and everything else.  angled for some reason
   - at (-0.05, 5.22, -3.78) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`
   - camera (-2.31, 1.58, -7.62) looking (0.39, 0.63, 0.67)
   - ![pin 1](walk_shots/1a17afe6f8098c4a6c6_1.png)
2. **floating / gap** (bug) — is this supposed to be a balcony? it is janky and messy
   - at (-3.59, 3.35, 0.24) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - camera (-5.61, 2.06, 0.88) looking (0.81, 0.52, -0.26)
   - ![pin 2](walk_shots/1a17afe6f8098c4a6c6_2.png)
3. **roof** (bug) — what is this?
   - at (2.46, 6.79, 2.92) (building-local), normal (0.00, -1.00, 0.00), hit `Shell`
   - camera (4.30, 1.58, 6.39) looking (-0.28, 0.80, -0.53)
   - ![pin 3](walk_shots/1a17afe6f8098c4a6c6_3.png)
4. **stair / floor** (bug) — is this supposed to be stairs?
   - at (3.35, 1.14, -4.54) (building-local), normal (-0.58, 0.00, -0.82), hit `Shell`
   - camera (4.69, 1.58, -8.31) looking (-0.33, -0.11, 0.94)
   - ![pin 4](walk_shots/1a17afe6f8098c4a6c6_4.png)
<!-- /human-walk 1a17afe6f8098c4a6c6 -->

<!-- human-walk 1a17b003df1dc34f9cd windmill -->
## Walk — Windmill: smock / , seed 1 — 2026-10-27T01:36:15Z

Building: Fenner End Mill · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":12.0,"kind":"windmill","length":6.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"smock","water":"none","width":12.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=windmill --seed=1 --style=smock`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (1)

1. **stair / floor** (bug) — how does the user get to the door? no stairs
   - at (-0.31, 3.42, -2.62) (building-local), normal (0.00, 0.10, -1.00), hit `Shell`
   - camera (-4.20, 1.58, -5.84) looking (0.72, 0.34, 0.60)
   - ![pin 1](walk_shots/1a17b003df1dc34f9cd_1.png)
<!-- /human-walk 1a17b003df1dc34f9cd -->

<!-- human-walk 1a17b00f6c498023895 windmill -->
## Walk — Windmill: windpump / , seed 1 — 2026-10-27T01:37:03Z

Building: Rook Mill · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":12.0,"kind":"windmill","length":6.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"windpump","water":"none","width":12.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=windmill --seed=1 --style=windpump`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (3)

1. **door** (bug) — door to nowhere?  why is this door here.  the windmill has no walls.  if a door is here, it needs to be mesh like the walls
   - at (-0.43, 1.29, -2.02) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`
   - camera (1.39, 1.58, -5.19) looking (-0.50, -0.08, 0.86)
   - ![pin 1](walk_shots/1a17b00f6c498023895_1.png)
2. **roof** (bug) — what is this? it is just sticking out
   - at (0.94, 3.03, -2.66) (building-local), normal (0.00, -1.00, 0.00), hit `Shell`
   - camera (-3.47, 1.58, -4.54) looking (0.88, 0.29, 0.38)
   - ![pin 2](walk_shots/1a17b00f6c498023895_2.png)
3. **collision** (bug) — windmill is colliding with the whole tower and in the wrong place
   - at (-1.29, 11.88, 0.23) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - camera (-5.31, 1.58, 2.28) looking (0.36, 0.92, -0.18)
   - ![pin 3](walk_shots/1a17b00f6c498023895_3.png)
<!-- /human-walk 1a17b00f6c498023895 -->

<!-- human-walk 1a17b0289c42f066502 windmill -->
## Walk — Windmill: paddle / , seed 1 — 2026-10-27T01:38:46Z

Building: Thistle Bridge Mill · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":12.0,"kind":"windmill","length":6.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"paddle","water":"none","width":12.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=windmill --seed=1 --style=paddle`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (2)

1. **floating / gap** (bug) — these are maybe a waterwheel?  they are rotated the wrong direction, not attached to the circle and floating
   - at (-1.72, 0.83, -3.98) (building-local), normal (-0.69, 0.69, -0.22), hit `Shell`
   - camera (-2.80, 1.58, -6.47) looking (0.38, -0.27, 0.88)
   - ![pin 1](walk_shots/1a17b0289c42f066502_1.png)
2. **collision** (bug) — door is impossible to reach
   - at (-0.11, 1.25, -2.89) (building-local), normal (0.00, 0.06, -1.00), hit `Shell`
   - camera (-0.70, 1.58, -8.14) looking (0.11, -0.06, 0.99)
   - ![pin 2](walk_shots/1a17b0289c42f066502_2.png)
<!-- /human-walk 1a17b0289c42f066502 -->

<!-- human-walk 1a17b049a269f39372b village -->
## Walk — Village: english / farming, seed 1 — 2026-10-27T01:41:01Z

Building: Wolfmarch Green · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":1.0,"kind":"village","length":35.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"farming","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"english","water":"none","width":40.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=village --seed=1 --style=english --purpose=farming`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (2)

1. **furniture / prop** (polish) — what is this???
   - at (-24.97, 1.15, -36.26) (building-local), normal (0.76, 0.23, 0.61), hit `Ground`
   - camera (-22.81, 1.60, -34.98) looking (-0.85, -0.18, -0.50)
   - ![pin 1](walk_shots/1a17b049a269f39372b_1.png)
2. **collision** (polish) — these should not have a collision mesh
   - at (-23.55, 0.00, -33.65) (building-local), normal (0.00, 1.00, 0.00), hit `Ground`
   - camera (-23.43, 1.90, -34.21) looking (-0.06, -0.96, 0.28)
   - ![pin 2](walk_shots/1a17b049a269f39372b_2.png)
<!-- /human-walk 1a17b049a269f39372b -->

<!-- human-walk 1a17b25f99128ae172 house -->
## Walk — House: rich / none, seed 1 — 2026-10-27T02:17:28Z

Building: Larkspurmill Steading · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.6,"kind":"house","length":12.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"none","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"rich","water":"none","width":9.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=house --seed=1 --style=rich --purpose=none`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (5)

1. **furniture / prop** (polish) — beds do not go in the entrance room. couches, card tables, entrace stuff
   - at (-0.06, 0.57, -4.59) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/Bed_Twin1/Bed_Twin1`, room: hall #0 (storey 0)
   - plan: furniture[0] Bed_Twin1
   - camera (-3.19, 1.72, -4.07) looking (0.93, -0.34, -0.16)
   - ![pin 1](walk_shots/1a17b25f99128ae172_1.png)
2. **z-fight / texture** (bug) — z order problem
   - at (1.45, 2.66, -2.13) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`, room: hall #0 (storey 0), kitchen #1 (storey 0), parlour #5 (storey 1), store #6 (storey 1)
   - camera (3.15, 4.32, -3.35) looking (-0.64, -0.62, 0.46)
   - ![pin 2](walk_shots/1a17b25f99128ae172_2.png)
3. **collision** (bug) — in the walk way
   - at (0.17, 3.24, -4.16) (building-local), normal (1.00, 0.00, -0.00), hit `Furniture/@Node3D@3124/Cabinet`, room: hall #0 (storey 0), parlour #5 (storey 1)
   - plan: furniture[44] Cabinet
   - camera (1.38, 4.32, -4.41) looking (-0.74, -0.66, 0.15)
   - ![pin 3](walk_shots/1a17b25f99128ae172_3.png)
4. **furniture / prop** (bug) — chair facing wall.  why is there a chair here?
   - at (-1.93, 3.22, -5.58) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/@Node3D@3115/Chair_1`, room: hall #0 (storey 0), parlour #5 (storey 1)
   - plan: furniture[35] Chair_1, windows[8] (0.91 m away)
   - camera (-2.75, 4.32, -3.91) looking (0.38, -0.51, -0.77)
   - ![pin 4](walk_shots/1a17b25f99128ae172_4.png)
5. **furniture / prop** (bug) — no beds in the rooms
   - at (2.17, 2.72, 3.93) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`, room: kitchen #1 (storey 0), store #6 (storey 1)
   - camera (3.16, 4.32, 0.51) looking (-0.25, -0.41, 0.88)
   - ![pin 5](walk_shots/1a17b25f99128ae172_5.png)
<!-- /human-walk 1a17b25f99128ae172 -->

<!-- human-walk 1a17b2a685be747ef1a house -->
## Walk — House: roundhouse / none, seed 1 — 2026-10-27T02:22:19Z

Building: Hollowhollow Steading · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":2.6,"kind":"house","length":12.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"none","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"roundhouse","water":"none","width":9.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=house --seed=1 --style=roundhouse --purpose=none`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (1)

1. **collision** (bug) — table clipped through the wall
   - at (-2.01, 0.45, -3.06) (building-local), normal (0.00, 1.00, 0.00), hit `Furniture/Culture_low_table/@MeshInstance3D@3197`, room: hall #0 (storey 0)
   - plan: furniture[2] Table_Large
   - camera (0.32, 1.72, -3.07) looking (-0.88, -0.48, 0.01)
   - ![pin 1](walk_shots/1a17b2a685be747ef1a_1.png)
<!-- /human-walk 1a17b2a685be747ef1a -->

<!-- human-walk 1a17b2b30152ad5c511 castle -->
## Walk — Castle: norman / , seed 1 — 2026-10-27T02:23:10Z

Building: Thorncliffe Tower · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":18.0,"kind":"castle","length":50.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"norman","water":"none","width":55.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=castle --seed=1 --style=norman`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (6)

1. **z-fight / texture** (bug) — flicker
   - at (9.29, 18.25, -20.40) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - camera (10.89, 19.85, -21.67) looking (-0.62, -0.62, 0.49)
   - ![pin 1](walk_shots/1a17b2b30152ad5c511_1.png)
2. **z-fight / texture** (bug) — flicker
   - at (13.93, 18.25, 22.53) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - camera (13.96, 19.85, 22.29) looking (-0.02, -0.99, 0.14)
   - ![pin 2](walk_shots/1a17b2b30152ad5c511_2.png)
3. **stair / floor** (bug) — stairs into the wall
   - at (15.57, 17.40, 26.66) (building-local), normal (0.00, 1.00, 0.00), hit `Shell`
   - camera (15.72, 19.85, 24.07) looking (-0.04, -0.69, 0.73)
   - ![pin 3](walk_shots/1a17b2b30152ad5c511_3.png)
4. **stair / floor** (bug) — table right in the walkway
   - at (13.90, 15.44, 24.97) (building-local), normal (0.00, 1.00, 0.00), hit `tower_0_corner_3/Furniture/@Node3D@3349/Table_Large`
   - camera (15.72, 17.91, 25.67) looking (-0.58, -0.78, -0.22)
   - ![pin 4](walk_shots/1a17b2b30152ad5c511_4.png)
5. **furniture / prop** (bug) — why are these here?  what are the solders doing?
   - at (13.61, 8.18, 24.31) (building-local), normal (0.00, 1.00, 0.00), hit `tower_0_corner_3/Furniture/@Node3D@3347/Table_Large`
   - camera (13.19, 8.97, 22.97) looking (0.26, -0.49, 0.83)
   - ![pin 5](walk_shots/1a17b2b30152ad5c511_5.png)
6. **door** (bug) — no exit for this weird tower
   - at (12.32, 1.41, 22.46) (building-local), normal (0.00, 0.00, 1.00), hit `Shell`
   - camera (11.90, 1.72, 25.50) looking (0.14, -0.10, -0.99)
   - ![pin 6](walk_shots/1a17b2b30152ad5c511_6.png)
<!-- /human-walk 1a17b2b30152ad5c511 -->

<!-- human-walk 1a17b2f263ee1d3b876 castle -->
## Walk — Castle: edwardian / , seed 1 — 2026-10-27T02:27:29Z

Building: Greywatch Keep · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":18.0,"kind":"castle","length":50.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"edwardian","water":"none","width":55.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=castle --seed=1 --style=edwardian`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (1)

1. **furniture / prop** (bug) — no fire
   - at (-16.13, 0.60, 8.10) (building-local), normal (1.00, 0.00, 0.00), hit `Shell`
   - camera (-13.11, 1.72, 9.59) looking (-0.85, -0.31, -0.42)
   - ![pin 1](walk_shots/1a17b2f263ee1d3b876_1.png)
<!-- /human-walk 1a17b2f263ee1d3b876 -->

<!-- human-walk 1a17b45849232be97e8 castle -->
## Walk — Castle: elven / , seed 1 — 2026-10-27T02:51:55Z

Building: Greywatch Keep · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":18.0,"kind":"castle","length":50.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"elven","water":"none","width":55.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=castle --seed=1 --style=elven`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (1)

1. **missing / wrong for the style** (bug) — all of the castles have been the exact same layout.   elven hall is nothing like it was speced to be
   - at (-0.25, 1.88, 3.23) (building-local), normal (0.00, 0.00, -1.00), hit `Shell`
   - camera (0.50, 1.58, -1.42) looking (-0.16, 0.06, 0.99)
   - ![pin 1](walk_shots/1a17b45849232be97e8_1.png)
<!-- /human-walk 1a17b45849232be97e8 -->

<!-- human-walk 1a17b7f6b85a72097d1 castle -->
## Walk — Castle: wizard / , seed 1 — 2026-10-27T03:55:10Z

Building: Ironfell Keep · cutaway: no · solid furniture: yes

Request: `{"enclosure":"none","height":18.0,"kind":"castle","length":50.0,"material":"timber","orientation":0.0,"period":1200,"purpose":"","schema":"brickwild.request","schema_version":1,"seed":"1","storeys":1,"style":"wizard","water":"none","width":55.0}`

Re-open: `.\visualqa\walk.ps1 --tour=sprint_2026_10_26 --stop=1 --kind=castle --seed=1 --style=wizard`

Tour: sprint_2026_10_26, stop 1 / 22 — shop wares: the mortar, the still and the jar shelves

- [ ] pretty
- [x] collisions
- [ ] window problems
- [x] door problems
- [x] roof problems

### Pins (1)

1. **missing / wrong for the style** (bug) — same thing here.  making it purple does not make it into a wizard tower.  it must makes it purple
   - at (8.36, 2.95, -17.48) (building-local), normal (-1.00, 0.00, 0.00), hit `Shell`
   - camera (3.65, 1.58, -15.99) looking (0.92, 0.27, -0.29)
   - ![pin 1](walk_shots/1a17b7f6b85a72097d1_1.png)
<!-- /human-walk 1a17b7f6b85a72097d1 -->

