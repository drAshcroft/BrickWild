# Dungeons

BrickWild realises dungeon plans. It does not plan them.

```
C:\Projects\dungeon          BrickWild                          VoxelGames
tools/export_plan.gd   -->   DungeonRealiser.realise()    -->   carves each room
dmv.dungeon.plan             brickwild.dungeon.rooms            from the ops, dresses
(cells, walls, locks)        (metres, carve ops, sockets)       the sockets
```

The planner decides where everything is: which rooms touch, on which wall, and
behind which lock. It also places the fixtures and proves the dungeon can be
finished. It says nothing about metres, ceiling heights or where along a wall a
door goes. BrickWild decides those once, here, and hands them over. The consumer
carves what it is told instead of guessing.

The output is a **plan**: data only, with no voxels and no meshes. BrickWild
does not depend on godot_voxel. A consumer applies the carve ops to its own
volume.

## Running it

```
# 1. the planner writes a plan (in C:\Projects\dungeon)
godot --headless --path . --script res://tools/export_plan.gd -- \
    --out plan.json --archetype temple --seed 42 --size medium \
    --theme flooded_ruin --complexity 2
# 2. BrickWild realises it
godot --headless --path . --script res://tools/realise_dungeon.gd -- \
    --plan plan.json --out rooms.json [--pretty]
# 3. look at it: plan and section of every room on one sheet
godot --headless --path . --script res://tools/draw_dungeon_sheet.gd -- \
    --plan plan.json --out artifacts/dungeon/sheet.png
# the gate
godot --headless --path . --script res://tests/run_all.gd -- lane:dungeon
```

The realise tool's exit codes: 2 means bad arguments, 3 means the plan could not
be read or realised, and 4 means the file could not be written. No file is
written unless the whole document was built.

## Input

A `dmv.dungeon.plan` export. It reads:

- `rooms`, `links`, `requires`, `plan_seed` and `request`;
- **`spaces`**: each room's spatial archetype, from the planner's skeleton;
- **`theme`**: the theme's materials, motifs and boss aesthetic;
- `voxelgames.surface_theme`, when the consumer baked its own.

`spaces` and `theme` were added to the export on 2026-10-14 for this purpose.
They sit beside the plan and do not change the plan hash. A plan without them
still realises: archetypes are inferred from role and span
(`DungeonRoomPlanner.infer_archetype`), and the realiser warns that it did so.

## Output: `brickwild.dungeon.rooms`, schema_version 1

| key | |
| --- | --- |
| `source` | the plan's schema, version, request, seed, entrance and goal, echoed |
| `style` | `{id, label, own, theme}`: which style built it, and whether the theme had its own |
| `geometry` | every number used: the rock budget, chamber sizes, tunnels, door spacing, headroom, stairs |
| `rooms` | one per plan room, in plan order (below) |
| `links` | `{portal, from, to, kind, lock}`, plus `one_way` and `shares_lock_with` |
| `requires` | the plan's, passed through |

**The frame of each room** is the consumer's own: x points east and z points
south (the planner's north is −z). The walked floor is at y = 0 and the chamber
is centred on the origin. The rock budget is 96 × 64 × 96 m with its corner at
(−48, −24, −48), which is VoxelGames' `RoomData` bounds. Every carve stays at
least 2 m inside it.

A room has these keys:

- `key`, `label`, `role`, `level`, `cell` and `span`: from the plan.
- `archetype` and `archetype_source`: `planner`, or `inferred`.
- `grammar`: `{ceiling, walls, floor}`, using the planner's own words from
  `spatial/architecture_grammar.gd`.
- `size`: `{half: [x, z], ceiling, springing}` in metres. The defaults are
  VoxelGames' former formulas (`DungeonGeometry`), so an unchanged room keeps
  its old size.
- `bands`: `{floor, wainscot, upper, ceiling}`, material **names**, plus an
  `accent` name. The consumer maps a name onto its palette and paints any name
  it does not know as its default rock.
- `doorways`: one entry per link end:
  - `portal`, `other`, `wall`;
  - `along`: metres from the middle of the wall;
  - `mouth`: the point on the wall;
  - `facing`;
  - `width` and `height`;
  - `rise`: a stair's climb, + or −;
  - `lock`, and `gate`: the dressing for that lock. An unknown lock gets
    `sealed_gate`, because unknown kinds are shut.
- `carve`: the ordered op list (below).
- `sockets`:
  - `fixtures`: each plan fixture, with `{id, kind, position, on: floor|wall}`;
  - `lights`: two at every doorway;
  - `set_pieces`: one in each hub, boss, goal, arena or landmark room.
- `water`: `{level, rect}`, only on a flooded floor. The water is shallow and
  the floor under it is walkable.

**Doorways** sit at the middle of the stretch two rooms share. Where several
are on one wall they are spread at least 6.5 m apart, and never less than
3.5 m. This is VoxelGames' former rule (`DungeonRealiser.doorways`).

Stairs and drops climb or descend `STAIR_RISE` (3 m) inside the threshold
tunnel, in 0.25 m risers. The lower room's end climbs; the upper room's end
descends. Two rooms on the same floor both climb, over a hump.

### Carve ops

Start with solid rock and apply each op in order. `carve` makes its shape air;
`fill` makes it rock again.

| shape | keys |
| --- | --- |
| `box` | `center`, `size` (full extents) |
| `cylinder` | `center`, `axis` (`x`, `y` or `z`), `length`, `radii`. `radii` is `[y, z]` for axis x, `[x, z]` for axis y, and `[x, y]` for axis z |
| `ellipsoid` | `center`, `radii` |

Every op has a `tag`:

- `chamber`, `vault`, `dome`
- `tunnel:<portal>`, `step:<portal>#n`
- `pit`, `bridge`, `pitstep#n`
- `column#n`, `niche#n`, `rubble#n`
- `dais`

`DungeonCarve.solid_at(ops, p)` is the reference reading of an op list. A
consumer that writes boxes with `fill_area` and the curved shapes per voxel
must agree with it.

## The grammar

| archetype | ceilings | walls | floors |
| --- | --- | --- | --- |
| great_hall | vaulted, enormous, domed | columns, alcove, solid | flat, stepped, flooded |
| shaft | enormous | solid, alcove | pit |
| chasm | vaulted, enormous, collapsed | solid, collapsed | pit (with a bridge) |
| courtyard | enormous, vaulted | columns, solid | flat, flooded |
| cavern | vaulted, collapsed, domed | solid, collapsed | flat, broken, flooded |
| tower | domed, enormous | solid, alcove | flat, stepped |
| atrium | domed, vaulted | columns, solid | flat, stepped, flooded |
| gallery | vaulted, flat | columns, alcove | flat |
| narrow_tunnel | vaulted, flat | alcove, solid | flat, flooded |
| bridge_space | enormous, vaulted | solid | pit (with a bridge) |
| chamber, corridor | vaulted, flat (and domed for a chamber) | solid, alcove (and columns for a chamber) | flat, flooded (and stepped for a chamber) |

Roles narrow the choice:

- An entrance never opens onto a pit or a step.
- A boss, goal or arena room gets a dais on a wall with no doorway.
- A room with four doorways gets no dais.

A pit always leaves a 3 m ledge around the walls, so every doorway can reach
every other. It also has a 2 m wide stair down one long wall, so a player who
falls in can climb out; VoxelGames' dungeon rooms do not respawn a fallen player.

A shape that meets the floor reaches 1 m through it (`ROOT`): a dais or step
fill is rooted below the floor, and a pit or descending-stair carve rises above
it. VoxelGames writes the ops as signed distances. Its min/max combination is
exact only outside a shape, so without the root a 0.45 m dais meshed at 0.1 m,
and a pit's mouth quantised to a skin of rock.

The style weights the choice. Each grammar word has a weight per style; a word
the style does not name has weight 0.2, so it is possible but rare.

## Styles (`DungeonStyles`)

Fantasy comes first. The styles are crypt, flooded_ruin, crystalline_sanctum,
overgrown_library and orrery_spire. A theme with no style of its own is built
as a crypt, with a warning. VoxelGames' `surface_theme: Crypt` outranks the
planner's theme, because the consumer baked the plan and chose its dress.

**Caves wait.** The abandoned mine, the living grove, and VoxelGames' Cave and
Castle surface themes have no style yet.

## The check (`qa/dungeon_room_check.gd`, ships under `runtime/qa`)

The check is judged from the carve ops, not from what the planner meant.

| rule | |
| --- | --- |
| budget | every carve fits inside the rock, with 2 m to spare |
| floor | at least half of the chamber floor stands at y = 0 (a pit room is exempt) |
| headroom | there is 2.6 m of clear height over every walked cell |
| mouth | each doorway is open just inside the wall, just outside it, and at its tunnel's end |
| doors | each mouth is on its wall at its `along`, within the wall's reach, and doorways on one wall are apart |
| walk | from the first doorway, through `WalkGrid`, every other doorway and every floor fixture is reached, and every wall fixture is within arm's reach |
| sockets | floor sockets stand on rock with air above; wall sockets have rock behind and air in front |
| pit | from the bottom of every pit a person can climb back to its rim, in steps no taller than WalkGrid's 0.6 m |
| bands | every surface band names a material |

`lane:dungeon` runs `tests/suites/dungeon_suite.gd` over the fixtures in
`tests/fixtures/dungeon/`:

- four planner exports in fantasy themes;
- one VoxelGames baked plan, which has no `spaces`.

The suite also checks:

- determinism;
- the contract: two doorway ends per link, a socket for every fixture, a gate
  for every lock;
- grammar variety: at least three words in use for each part;
- eight negative controls, one per rule.

## VoxelGames (done 2026-10-14)

VoxelGames plays its dungeons in these rooms. Its side is described in
`C:\Projects\VoxelGames\docs\brickwild_dungeons.md`.

- Its baker writes `spaces` and `theme` beside each plan.
- `game/tools/realise_dungeon_rooms.py` runs this realiser and stores
  `*.rooms.json` beside each `*.plan.json`.
- `scripts/dungeon/realised_room.gd` writes the ops as signed distances,
  paints the bands by name, and answers where the floor is.
- The builder takes doorways, gates and fixtures from the rooms and settles
  every other prop onto real floor.
- The setting `voxelgames/dungeon/brickwild_rooms` turns it off.

**Its checked-in rooms files were made from this working tree.** No release
has the realiser yet (VoxelGames todo `BRICKWILD-ROOMS-RELEASE-001`).

## Next phases

| # | |
| --- | --- |
| D2 | balconies, split levels, `wall_strip_wfc` variation around portals |
| D3 | dressing pieces (arches, ribs, sarcophagi, shelves) as meshes anchored to the carved surface |
| D4 | the mechanics `plan.requires` lists beyond keys and levers: water levels, light beams, moving platforms |
| D5 | shafts as real multi-floor rooms from `hero_space` |
| D6 | the Studio tab and walk QA |
| D7 | VoxelGames integration: done (above); a release with the realiser is still to cut |
| later | caves and mines |
