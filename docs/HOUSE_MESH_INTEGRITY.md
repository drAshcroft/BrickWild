# House mesh integrity

`HouseQA` checks every emitted mesh surface with `qa/mesh_integrity_check.gd`.
The checker rejects non-finite vertices, missing or non-unit normals,
out-of-range indices, degenerate triangles, and normals that disagree with
Godot's clockwise face winding. It accepts indexed and non-indexed meshes.

The `hmesh` suite includes valid indexed and non-indexed controls, defects on
later surfaces, and a generated farmhouse. It proves that corrupt geometry is
rejected rather than relying on the builder's logs. `hmesh` is included in
`lane:geom`.

Verified on 2 October 2026:

- `hmesh`: 12 checks, no failures or warnings, 34.95 seconds of host time.
- `lane:geom`: 9,196 checks across 11 suites, no failures or warnings,
  native exit 0, 277.33 seconds of host time.
- Logs: `artifacts/qa_fast/hmesh/20261002_231006/` and
  `artifacts/qa_fast/lane_geom/20261002_231848/`.

These checks do not establish room completeness, entrance reachability, or
clearance between architectural parts. Those require the separate planning,
aperture, and movement checks. Castle repairs and fresh render review remain
unfinished.
