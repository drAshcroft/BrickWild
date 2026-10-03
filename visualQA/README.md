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

A pin asks for a kind (collision, window, door, roof, wall, floor/stair,
furniture, other) and a note. Collision, window, door and roof pins tick the
matching rating box. Pins show as numbered red balls through walls. The list
can jump back to a pin's viewpoint or delete it.

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
