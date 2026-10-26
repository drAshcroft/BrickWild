# Village water crossings

`VillagePlan.water_crossings` stores the road and water indices, bridge/ford
kind, width and full route. Site planning records crossings before lots are
cut; lot planning records them again after service lanes, mill races and lane
trimming settle. The typed document codec and equality contract retain them.
They are infrastructure, so clearing exterior props cannot erase them.

Clip each road segment against a water polygon expanded by the road half-width.
This puts oblique deck corners on dry banks. Sort boundary intersections and
test every interval midpoint: a concave water body can have separate wet
reaches, and a road endpoint can already be in water. Preserve intermediate
road bends instead of drawing a chord between the first and last crossing.

The builder emits adjoining mitered panels, gentle ramps, and timber boards,
posts and rails for bridges; shallow streams use stone fords. All crossing
parts have component identities. Their mass bounds come from the emitted
components, including rotation. `VillageRoadCheck` independently subtracts
deck polygons from the actual wet road area and rejects missing, too narrow,
off-road and stale-index crossings. The focused test also probes real upward
mesh triangles over wet road samples; a valid log alone is insufficient.

Godot omits empty surface streams. Village meshes therefore name each emitted
surface `material_slot:N`, remap component indices to the resulting mesh, and
let `ShellAssembler` resolve colours from the named slot. A village with no
common or stone still has blue water and brown timber. Other builders retain
their existing positional material contract.

Navigation restores the recorded deck polygons after marking water impassable,
at the actual bridge/ford surface elevation. Clearing a crossing removes that
walkable connection too; a visible bridge must not remain an invisible river
barrier in the walk grid.

Validation: 97 focused crossing checks, 201 water-plan checks and 752 enclosure
checks pass. Render real bridge/ford references with
`tools/render_village_crossings.gd` (without `--headless`); images are in
`artifacts/p1p2_village/crossing_river.png` and `crossing_stream.png`.

## On given ground (VTER-CROSSINGS)

With `plan.ground` a bridge is no longer a level deck at the higher landing:
`VillageBridge.measure(surface, crossing)` reads the finished ground and
fits it -- deck over the higher landing, its underside 0.45 m over the highest
water under the span, a ramp at each end no steeper than 12 %, and two
`bridge_abutment` boxes (host `bridge<i>`) from the lowest ground under each
end up to the deck. A ford stays level with the higher landing. The ground's
own reach of water that is long and thin (at most 40 m wide, three times
longer than wide, and not a lake clipped at the site edge) is plan water of
kind `river` with its measured `width`, and the spec's river is not laid
beside it. `VillageBridgeCheck` judges the result from the emitted mesh.
Flat villages never reach this code; see "Bridges on the ground" in
docs/VILLAGE_TERRAIN.md.
