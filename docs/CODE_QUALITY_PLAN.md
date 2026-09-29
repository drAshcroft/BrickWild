# Code quality plan

This plan follows the generation pipeline's existing boundaries: a family
chooses a spec, a planner makes a plan, a builder emits geometry, and QA checks
the result. Splits should preserve seed output and the public API. Line count
is a signal to inspect cohesion, not a reason to make one-line forwarding
classes.

## This pass

1. **Furnishing:** Keep the room loop in `HouseFurnisher`. Put recipe data,
   candidate placement, affinity scoring, and navigation repair in separate
   classes. Remove static mutable state so one plan cannot change the next
   furnishing run. Add a polygon outline regression check.
2. **Castle plans:** Move hall, chapel, and range planning out of
   `CastleGenerator`. Keep procedural spec generation there, and keep the
   occupied keep plan in `CastleKeepPlan`.
3. **Family API:** Dispatch quality checks through the same family adapter
   used for generation and building. A new family then has one place to define
   its QA behavior.
4. **Shared boundaries:** Let `MassBuilder` import mapped surfaces and
   `HouseBuilder` extend upper walls. Castle interiors should not access
   either builder's private mesh state. Share the repeated RNG draws used by
   house, castle, church, and temple generators. Remove the shop furnisher
   forwarding class.
5. **Lot rules:** Give site, lane, purpose, and neighbor constraints named
   functions. Commit a trimmed lot polygon and mill race only after the whole
   candidate passes.

## Completed follow-up splits

1. `HouseFurnishPlacement` now delegates surface placement and geometry to
   separate collaborators. Candidate validity remains shared, and public
   cross-class entry points replace calls to underscore-prefixed methods.
2. `HousePlanner` is now a 92-line coordinator over room, opening, level, and
   feature stages. A deterministic vertex fingerprint was unchanged by the
   split.
3. `VillageDresser` is now a 55-line coordinator over catalogue, context,
   host, rule, spot, and placement classes. The seeded call order is unchanged.
4. `HouseFurnishCheck` now dispatches physical, programme, arrangement,
   spatial, and affinity rules through callables into a shared report. The
   coordinator is 161 lines. No two-line forwarding methods were added.

## Remaining architectural work

The remaining large files need API work before extraction. A mechanical split
would create collaborators that reach into another object's mesh kit and logs,
which is smaller files with stronger coupling.

1. `HouseBuilder` has a coherent roof section of roughly 550 lines. Extract it
   after defining an emission context for component geometry, opening evidence,
   and mass logs. The roof emitter should depend on that context rather than on
   the builder's private fields.
2. `CastleBuilder` contains distinct sky, motte, ridge, tower-house, manor,
   enclosure, and keep emitters. Move one variant at a time behind the same
   `MassBuilder` emission boundary, with geometry and voxel fingerprints for
   each move.
3. `VillageLotPlanner` still combines retry policy, frontage search, candidate
   legality, and special landmark lanes. Its legality predicates are named;
   the next useful seam is a candidate object that can be tested before commit.
4. `VillageSitePlanner` can dispatch settlement forms to form-specific
   planners once road and landmark construction are represented by a small
   shared context.
5. Reusable fixture builders can leave the longest test suites. This remains
   below production coupling in priority.

`CastleGeometry`, `HouseGeometry`, and the other family geometry modules remain
large by design. They are the documented source of truth for their family and
contain geometry calculations rather than orchestration state. Line count
alone is not sufficient reason to distribute those formulas across classes.

## Verification for a split

Register any new `class_name` scripts with a headless editor pass. Run the
lane for the touched code, then compare deterministic seeds and warning counts
where a refactor claims to preserve behavior. The QA harness has expensive
furnishing searches, so use the named lanes in `tests/run_all.gd` instead of
running the full sweep after every edit.

## Baseline failures observed during this pass

- `vlot` passes its 50 seed street and green sweep, but its manor frontage
  fixture reports `the manor found no frontage`. The same fixture fails on a
  clean `HEAD` checkout.
- `ckfurnish` reports `stair_line` for the same five castle cases on both the
  edited tree and a clean `HEAD` checkout (55 checks, five failures, eight
  warnings). Keep this as a separate functional repair; changing the planner
  to make a refactor lane green would mix two causes.

## Verification completed

- The headless editor registered the new global classes without parse errors.
- Geometry and furnishing lanes: 13 suites, 8,131 checks, no failures.
- Castle range plans and polygon sconces: two suites, 89 checks, no failures.
- Temple and rite lane: two suites, 2,247 checks, no failures.
- Focused public quality dispatch probes returned well-formed reports for
  church, castle, house, shop, hotel, temple, world, and village.
- House planning split: `lane:plan shop` completed 406 checks with no failures;
  the before/after house vertex dumps were identical.
- Furnishing placement split: focused polygon/assembly checks completed 72
  checks, and `lane:dress` completed 1,170 checks, with no failures.
- Furnishing QA split: castle plan shell and polygon sconce fixtures completed
  916 checks with no failures. `ckfurnish` reproduced its clean baseline
  exactly: 55 checks, five `stair_line` failures, and eight warnings.
- Village dressing split: the complete `vcheck` 24-village sweep ran for 430
  seconds. It reached the existing planner/dressing follow-ups recorded by the
  suite; no parse or dispatch failure occurred.

The full castle sweep and the 200 case interior sweep were stopped after they
ran far beyond the documented lane estimates without a final summary. Their
completed focused checks are listed above; those exhaustive results remain
unverified in this pass.
