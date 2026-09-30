# CAS-REG-003 tower-house openings

## Change

`CastleTowerPlan._add_windows` rejected slit windows narrower than 0.35 m even
though the castle generator authors slit openings at 0.32 m. The planned
windows were therefore all discarded for Bologna 8803 and Scottish 8804.
The minimum is now 0.30 m. The windows still come from each storey's actual
wall edges in `HouseGeometry`; no openings are synthesized by the builder.

The raised door was already emitted on the actual wall face, with an explicit
`opening_kind="door"` and `tag="tower_house"`. `TowerCheck` only counted the
older `kind="window", tag="door"` convention. It now reads explicit opening
kinds and retains that legacy fallback for older part logs.

## Fixed-seed checks

- Baseline: `57f349c4c8d8c6399bd4ea5eac4554e26624b4f3`.
- `ctowerplan`: PASS, 990 checks.
- `ctowerhouse`: PASS, 20 checks across Bologna 8803 (8×8×45 m) and Scottish
  8804 (14×12×34 m). It verifies one raised door, planned/emitted window-count
  equality, a window in every occupied storey band, tower massing facade rules,
  mesh normals and opening normals. It removes all planned windows and the
  entrance in turn to prove the checks catch each omission.
- The baseline castle-change lane failed on Scottish 8804 with no emitted
  window surface and five missing occupied-storey windows. The pre-fix
  production probes also showed zero planned windows for Bologna 8803 and
  Scottish 8804.

The same-camera production renders use identical target, framing radius, yaw,
pitch, lighting, and 8803 seed. The before images have a blank shaft facade;
the after images show five rows of slit windows. The entrance and stair remain
visible in both versions.

| View | Baseline | Repaired |
|---|---|---|
| Front | ![Baseline front view](renders/before_front.jpg) | ![Repaired front view](renders/after_front.jpg) |
| Raking | ![Baseline raking view](renders/before_raking.jpg) | ![Repaired raking view](renders/after_raking.jpg) |

`render_before.log` and `render_after.log` record both render runs. Appearance
renders document facade appearance; focused plan and mesh checks establish
opening placement and emission.

## Limits

This fix is specific to tower-house planned slit openings. The broad castle
and voxel sweeps are outside this task; the repository has unrelated baseline
failures in those lanes. The root reviewer also reproduced independent access
failures on Crusader 9250/9118 and interior door/window placement failures on
Bavarian ridge 8805. This focused fix does not resolve those cases or claim
every castle family is clean.
