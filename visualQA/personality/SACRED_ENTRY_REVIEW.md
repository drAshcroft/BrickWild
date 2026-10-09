# Ziggurat ground entrance and chamber headroom

This closes LIVE-SACRED-ENTRY, a structural step within the still-open
LIVE-SACRED design work. It does not accept the appearance of every temple,
the summit stairs, or vertical movement onto the ritual dais.

The generator retains its seeded terrace draw, then limits terrace count so
the occupied first chamber has at least 2 m of headroom. The real forecourt
slab now continues through the terrace setback and overlaps the entry floor.
The previous slab ended at the outer footprint, leaving a gap before the
recessed chamber door.

Root reviewed the Luna source changes. The focused emitted-mesh fixture covers
five cults, three frozen size bands and seeds 1, 8102 and 21325: 45 cases,
zero failures, native exit 0 in 4.073 s. It removes actual upward paving
triangles to prove that missing floor is rejected, and injects an actual low
ceiling to prove that chamber obstruction is rejected. It makes no claim
about elevated stair traversal.

The required Temple lane passes 3,737 checks with no failures or warnings,
native exit 0 in 100.375 s. Logs are in
`artifacts/personality/resumed/temple_route_repairs_v2_lane/` and
`artifacts/personality/resumed/restart2_ziggurat_ground_entry_v2/`.

Fresh public-path renders of `temple/ziggurat/flame/default/21325` show the
continuous paved approach and recessed chamber entrance with roofs present.
Root inspected its axis and cutaway views. The complete seven-request render
batch produced 21 images with an unchanged source fingerprint, native exit 0
in 87.57 s. The renderer selects an existing reached cell inside the eroded
ground paving; it explicitly leaves shell/prop body clearance unmeasured.
Render and source records are in
`artifacts/personality/resumed/restart2_sacred_camera_render_v5/images/manifest.json`.

Broader sacred appearance is still pending. The church renders expose plain
wall volumes, incomplete dome/ambulatory interiors and weak Nordic identity.
The basilica remains a barn-shaped shell before its next architectural change.
