# Agent notes

## Godot executable

Not on PATH. Use:

```
C:\Projects\godot\Godot_v4.5.2-stable_mono_win64\Godot_v4.5.2-stable_mono_win64.exe
```

## Running things

```
# full test suite (fast, headless)
godot --headless --path . --script res://tests/run_all.gd
# one suite: church | normals | massing | blueprint | landmark | voxelqa
godot --headless --path . --script res://tests/run_all.gd -- normals

# reference renders -- must NOT be headless, the dummy renderer makes no image
godot --path . --script res://tools/render_shots.gd     # -> artifacts/renders/
godot --path . --script res://tools/shoot_studio.gd     # screenshot of the Studio UI
```

After adding a script with a NEW `class_name`, run the editor once so the
class is registered, or every suite fails with "Identifier not declared":

```
godot --headless --path . --editor --quit
```

## Gotchas

* A GDScript **parse error makes the headless runner hang** rather than exit.
  If a run stops producing output, read the top of the log for "Parse Error"
  instead of waiting on it.
* Godot's front faces are **clockwise**, so a triangle wound (a, b, c) has
  outward normal `(c - a).cross(b - a)` -- the opposite hand from the usual
  formula. `MeshKit._face_normal` is the single place this is decided.
* `MeshKit.commit()` deliberately does **not** call `generate_normals()`. Every
  emitter sets its own per-face normal, and generate_normals() smooths across a
  whole surface -- one smooth group spans the entire building.
