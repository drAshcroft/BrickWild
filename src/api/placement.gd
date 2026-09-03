class_name Placement
extends RefCounted
## Small geometry helper for `BigGlade.placement()` results. Kept separate from
## BigGlade itself so scene-based consumers (lots, fire gaps, canopies) can
## work with the footprint without touching the generation facade.


## The four corners of a `placement` result's XZ rect, rotated and translated
## by `transform`, in winding order. `transform` is typically the Transform3D
## a village places the building's scene root at.
##
## `use_footprint` picks which rect: false (default) is `placement.bounds`
## (the full emitted architecture -- roof eaves, porches, towers and all --
## for fire gaps and canopies to clear); true is `placement.footprint` (the
## walls' own outline, narrower, the rect `placement.door` sits on the -Z edge
## of) for lots that want to hug the building itself.
static func world_rect(placement: Dictionary, transform: Transform3D,
		use_footprint := false) -> PackedVector2Array:
	var rect: Rect2
	if use_footprint:
		rect = placement.get("footprint", Rect2())
	else:
		var bounds: AABB = placement.get("bounds", AABB())
		rect = Rect2(Vector2(bounds.position.x, bounds.position.z),
			Vector2(bounds.size.x, bounds.size.z))
	var corners := [
		Vector3(rect.position.x, 0.0, rect.position.y),
		Vector3(rect.position.x + rect.size.x, 0.0, rect.position.y),
		Vector3(rect.position.x + rect.size.x, 0.0, rect.position.y + rect.size.y),
		Vector3(rect.position.x, 0.0, rect.position.y + rect.size.y),
	]
	var out := PackedVector2Array()
	for c in corners:
		var w: Vector3 = transform * c
		out.append(Vector2(w.x, w.z))
	return out
