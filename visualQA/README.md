# Human visual QA

Run from the project root:

```powershell
python visualQA/server.py
```

Open http://127.0.0.1:8765. No packages or build step.

Eight public building classes, two existing renders each. Each image has its own
five checkboxes and optional notes. Pretty means approval; the other boxes mean
a problem was seen. Save & Next appends both ratings directly to
`visualQA/HumanRate.md` and advances only after the server confirms the write.
Reload resumes at the first unsaved class. The class dropdown lets you revisit
a class and append another review. Switching classes before saving discards
that page's unsaved selections.

These are existing captures, not a fresh render sweep. Capture dates are shown.
Edit `renders.json` to choose different fixtures. Recorded source paths and
SHA-256 hashes identify which images were reviewed. Do not replace captures
while this server is running; restart it after changing the render selection.

The server listens only on loopback and serves only the selected images and
the review page. Ctrl+C stops it. Change the port with `--port 8766`.

## Walking a building (Godot)

The images cannot be entered. The walk rig can:

```powershell
.\visualqa\walk.ps1
.\visualqa\walk.ps1 --kind=house --seed=8102 --style=cottage
```

(or `godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=...`). Not headless.
The launcher first registers any new `class_name` that other work has added
(it runs the editor headless once when a script is newer than Godot's class
cache), so the rig does not break when a new family lands.

The sidebar picks kind, style, purpose and seed, then **Build**. You start outside
the front door, facing it. Click the view to walk:

| key | does |
|---|---|
| WASD, mouse | walk, look |
| Shift / Space | run / jump |
| F | fly, no collision; Space and C go up and down |
| L | lantern on or off, for dark interiors |
| R | back to the front door |
| right-click | pin a problem on the surface under the crosshair |
| Esc | free the mouse; right-click then pins under the pointer |

The walker collides with the architecture's own mesh, and with every prop
when "Solid furniture" is ticked. A door you cannot get through is a real
finding. So is a chandelier that hits you in the face.

A pin asks for a kind, a severity and a note. The kind list opens on
"choose..." and will not pin until you pick one: collision, door, window,
stair / floor, roof, wall, furniture / prop, lighting, floating / gap,
z-fight / texture, missing / wrong for the style, ground / terrain, other.
(Before 26 Oct it opened on "collision", so every old pin says collision.)
Severity is blocker (cannot walk on; P1), bug (plainly wrong; P2, the default)
or polish (looks off; P3). Collision, window, door and roof pins tick the
matching rating box. Pins show as numbered red balls through walls. The list
can jump back to a pin's viewpoint or delete it.

Below the seed, the sidebar carries the request's extras, each shown only for
the kinds that accept it: **Jank** (0-1, `BuildingRequest.jank`, every kind
but a village), **Ground fall** in metres with the downhill direction (house,
shop, church, castle; the rig's ground plane tilts to match) and
**Foundation** ground / piles with the water depth (house, shop; the ground
drops to the bed and the water is drawn at its surface). The saved reopen
command carries every one of them.

**Save & next kind** or **Save & new seed** appends to `visualqa/HumanRate.md`,
under a `<!-- human-walk ID kind -->` marker. The web page ignores that marker.
Each review records:

- the request as JSON, and a command line that reopens the same building;
- the five boxes and the notes;
- for each pin: building-local position, surface normal, the node hit
  (`Shell`, `Stone`, `Furniture/Chandelier/...`), the house room under it,
  the plan records there (`furniture[19] Chair_1`, `windows[0]`, `doors[2]`
  -- stable indices into the HousePlan, unlike Godot's `@Node3D@124` names),
  the camera pose, and a screenshot in `visualqa/walk_shots/` with the hit ringed.

The same review goes to `visualqa/walk_pins.jsonl`, one JSON line per review,
for an agent to read back.

Smoke test without a person (writes to a scratch file, not HumanRate.md):

```
godot --path . res://visualqa/walk/walk_qa.tscn -- --kind=house --seed=8102 --walk=140 --autoshot=res://artifacts/walk_qa/shot.png --autopin --rate-file=res://artifacts/walk_qa/rate.md
```

## Bug walks

After a sprint, walk what the sprint touched and pin what is wrong. Every
pin becomes a todo in the backlog.

```powershell
.\visualqa\walk.ps1 -Tour sprint_2026_10_26
# or: godot --path . res://visualqa/walk/walk_qa.tscn -- --tour=sprint_2026_10_26
```

A tour is `visualqa/tours/<name>.json`: a list of request dicts (anything
`BuildingRequest.from_dict` takes -- kind, style, purpose, seed, width,
jank, ground_fall_m, foundation, ...), each with an optional `"why"`. The
sidebar shows `Stop i / n -- why`. **Save & next stop** saves and builds the
next stop; **Skip this stop** moves on without saving; **Save & new seed**
stays on the stop with another seed. `--stop=5` starts at stop 5. Write a new
tour per sprint; `sprint_2026_10_26.json` is the shops, the witch hut, the
minka / Sahel / roundhouse / rich / mediterranean / thatch styles, a house on
falling ground, one on piles, a crooked one and a windmill.

**What gets filed.** With "File pins as todos" ticked (the default; `--no-file`
unticks it), Save starts `tools/file_walk_bugs.py` for that review in the
background and the status line says `Filed: filed N, skipped M...` when it
ends (its log is `artifacts/walk_bugs/filer.log`). Each pin becomes one
waterfree todo:

- key `WALK-<first 8 of review_id>-<pin n>`; an existing key is skipped, so
  filing twice files nothing twice;
- priority from severity: blocker P1, bug P2, polish P3 (old pins: P2);
  phase `bug-walk`;
- title `<building>: <kind> -- <note>`; the description carries the note,
  kind, severity, tour stop, room, part hit, plan records, building-local
  position, camera, screenshot path, the request JSON and the reopen command;
- a target file only where the kind makes it obvious (furniture in a house or
  shop -> `house_furnisher.gd`, a door or window -> `house_plan_openings.gd`,
  ground under piles / on a slope -> `house_piles.gd` / `house_slope.gd`).

**Re-file, or look first.**

```powershell
python -I tools/file_walk_bugs.py --dry-run                     # every review, nothing filed
python -I tools/file_walk_bugs.py --dry-run --no-lookup         # same, without asking waterfree which keys exist
python -I tools/file_walk_bugs.py --review 1a17a33a             # one review (an id prefix is enough)
python -I tools/file_walk_bugs.py --since 2026-10-26T00:00:00Z  # everything walked since
python -I tools/file_walk_bugs.py --pins artifacts/walk_qa/walk_pins.jsonl --dry-run
```

The 109 pins from 3-7 Oct have NOT been filed. Each one says "collision"
whatever it was. File them only if you want them; `--dry-run` shows the list.

The jsonl record keeps its old shape and adds fields: `severity` per pin, and
`reopen`, `tour`, `stop`, `why`, `village_terrain` per review.

## Villages on real ground

```powershell
.\visualqa\walk.ps1 --village-terrain=manarola --seed=1
```

Plans a 40-person village on `tests/fixtures/terrain/<name>.json` (or
`real30/<name>.json`; `limone_sul_garda`, `varennes`, `masouleh`, ...) the way
the `vgroundterrain` suite does (`VillageSpec.terrain`, `VillageLotPlanner`,
`VillageAssembler`), makes every mesh solid and puts you outside the first
building's door, facing it. The rig's flat ground is put away; you walk the
village's own ground, terraces and steps. It takes about a minute and a half.
Pins carry the village-local position and the part hit; there is no house plan,
so no room or plan records. "Save & new seed" plans the same ground again with
another seed. The request field cannot carry a terrain, so the reopen command
is `--village-terrain=<name> --seed=<n>`, not the request JSON.

Smoke test of the tour, the dialog and the filer (`--autopin` first proves an
unchosen kind is refused, then pins a polish door and runs the filer with
`--dry-run`):

```
godot --path . res://visualqa/walk/walk_qa.tscn -- --tour=sprint_2026_10_26 --stop=19 --walk=140 --autoshot=res://artifacts/walk_qa/shot.png --autopin --rate-file=res://artifacts/walk_qa/rate.md
```
