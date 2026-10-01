# CAS-013: curved castle walls

Elven castle plans are polygonal and set `CastleSpec.curved_edges`. Each
polygon curtain run bows outward between the existing vertex towers. The
bulge is a parabolic offset with a 0.16 edge-length sagitta; changing the
curtain does not move the polygon or its tower positions.

`MeshKit.curved_wall()` accepts a sampled X/Z centerline, wall height,
base/top thickness, and through-opening bands along the sampled path. It emits
per-triangle normals and returns the actual battered mass bounds. Callers must
include opening edges among the samples, place opening logs on the curve with
the local surface normal, and log the returned bounds rather than the straight
chord AABB. The wall walk and merlons follow the same bowed path.

Focused regression selector: `cas013`. It covers Elven plan selection,
outward mass bounds, arc-local slit placement, tower count, per-face normals,
and a non-Elven/degenerate-path negative control. Run only after editor class
registration; this change intentionally has no render or broad regression
result attached to its commit.
