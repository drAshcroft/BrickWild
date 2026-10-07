# Inhabited-building review fixtures

The design contract is in `docs/INHABITED_BUILDINGS_PLAN.md` and
`docs/BUILDING_PERSONALITY_BRIEFS.md`. These files preserve repeatable requests
and separate historical reports from current design acceptance.

- `style_inventory.json`: public descriptor snapshot, nine families and 81
  style rows. All rows begin unreviewed; this is scope, not a passing score.
- `frozen_requests.json`: 90 complete requests. Nine representative family
  requests plus the witch hut, at three sizes and seeds 1, 8102 and 21325.
  Dimensions were frozen before the spatial implementation was accepted.
  Village width/length mean population/wealth, not metres.
- `baseline_requests.json`: the ten default-size, seed-1 representatives.
- `pin_status.json`: 109 historical pins with full requests and explicit
  evidence states. An unverified report is not a newly reopened defect.

Use the Godot executable in `AGENTS.md`, without `--headless`:

```powershell
godot --path . --script res://tools/render_personality_baseline.gd -- cases=res://visualqa/personality/baseline_requests.json out=res://artifacts/personality/baseline
```

The renderer preserves canonical requests, image paths, camera poses and
source fingerprints. `select=` accepts comma-separated fixture IDs. Keep
each run in a separate directory. If `source_changed` is true, the run is a
development observation, not an immutable before/after source baseline.

The first ten-case development batch is in
`artifacts/personality/current/baseline/manifest.json`. It produced all forty
requested images without generation/save failures. Sources changed during
the batch, which its manifest explicitly records. It exposed renderer issues
as well as building issues: the first straight-on church view obscured the
nave, the windmill was cropped, and a furniture-target camera faced a bench
too closely. Those views are not accepted identity evidence.

Root review of the usable views found:

| Subject | Observation | Design state |
|---|---|---|
| Cottage / witch hut | Plain walls, sparse isolated furniture; witch still shares the cottage's basic spatial and exterior read | Not accepted |
| Church | Strong front tower but tiny entrance in a broad blank lower face; tower view insufficient for whole-building judgement | Not accepted; improve camera and review nave |
| Castle | Recognizable fortified silhouette; repetitive broad wall surfaces | Interior and style variants unreviewed |
| Hotel | Guest rooms have large unused floors and very sparse bed groups | Not accepted |
| Basilica temple | Broad low gable and blank front wall still read as barn-like | Not accepted |
| Domus | Vast room strips and isolated furniture; current cutaway does not establish a convincing courtyard dwelling | Not accepted |
| Windmill | First exterior camera cropped roof and sails | Camera failure; no design conclusion from this view |
| Shop / village | Images generated; full purpose, route and constituent-building review pending | Unreviewed |

Complete design acceptance requires the remaining implementation todos and
fresh stable-source renders. It cannot be inferred from this baseline task.

The corrected camera verification is retained in `brief_evidence/`: four
requests (cottage, church, temple and windmill), sixteen images, zero render
failures, no script errors and `source_changed=false`. Its original artifact
paths remain in the manifest; the matching image basenames are copied here.
Root inspected the roof-on cottage room, church nave, temple axis and complete
windmill silhouette. These are usable review views. They visibly retain the
building design problems above. Unsupported family activity cameras are
explicitly labelled `front_threshold_fallback`; full review of those interiors
still requires a family-specific view.
