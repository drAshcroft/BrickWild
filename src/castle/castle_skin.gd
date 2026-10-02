class_name CastleSkin
extends RefCounted
## The thin vertex-coloured sheets a castle's ground is made of: water, moat
## bank, apron. All of them go on CastleBuilder.SURF_GROUND, which QA treats as
## it always treated water -- a skin, not masonry.


## A quad with its face up, in one colour. The winding is chosen from the
## normal, so a caller can name the corners in any order.
static func quad(b: CastleBuilder, p: Vector3, q: Vector3, r: Vector3, s: Vector3,
		colour: Color) -> void:
	var st: SurfaceTool = b._kit.surface(CastleBuilder.SURF_GROUND)
	st.set_color(colour)
	if MeshKit._face_normal(p, q, r).y < 0.0:
		b._kit._quad(st, p, s, r, q)
	else:
		b._kit._quad(st, p, q, r, s)
	st.set_color(Color.WHITE)


## The corners of `rect` pushed out by `d` on every side, front-left first and
## clockwise seen from above: front-left, front-right, back-right, back-left.
static func corners(rect: Rect2, d: float) -> Array[Vector2]:
	return [Vector2(rect.position.x - d, rect.position.y - d),
		Vector2(rect.end.x + d, rect.position.y - d),
		Vector2(rect.end.x + d, rect.end.y + d),
		Vector2(rect.position.x - d, rect.end.y + d)]


## Sweep a profile of (distance out, height) points round `rect`, mitred at the
## corners, one colour per segment. A positive `gap` cuts the FRONT side back
## at +-gap so the road can pass, and closes the cut with a vertical face.
static func sweep(b: CastleBuilder, rect: Rect2, profile: Array[Vector2],
		tones: Array[Color], gap := 0.0) -> void:
	for k in range(profile.size() - 1):
		var d0: float = profile[k].x
		var d1: float = profile[k + 1].x
		var y0: float = profile[k].y
		var y1: float = profile[k + 1].y
		var ca := corners(rect, d0)
		var cb := corners(rect, d1)
		for side in range(4):
			var a0: Vector2 = ca[side]
			var a1: Vector2 = ca[(side + 1) % 4]
			var b0: Vector2 = cb[side]
			var b1: Vector2 = cb[(side + 1) % 4]
			if side == 0 and gap > 0.0:
				_strip(b, a0, Vector2(-gap, a0.y), Vector2(-gap, b0.y), b0, y0, y1, tones[k])
				_strip(b, Vector2(gap, a0.y), a1, b1, Vector2(gap, b0.y), y0, y1, tones[k])
			else:
				_strip(b, a0, a1, b1, b0, y0, y1, tones[k])
	if gap > 0.0:
		for sgn in [-1.0, 1.0]:
			var pts := PackedVector3Array()
			for pr in profile:
				pts.append(Vector3(sgn * gap, pr.y, rect.position.y - pr.x))
			b._kit.surface(CastleBuilder.SURF_GROUND).set_color(tones[0])
			b._kit.slab_poly(pts, 0.02, CastleBuilder.SURF_GROUND, false)
			b._kit.surface(CastleBuilder.SURF_GROUND).set_color(Color.WHITE)


## One strip of a profile: from the edge at height y0 to the edge at y1.
static func _strip(b: CastleBuilder, a0: Vector2, a1: Vector2, b1: Vector2, b0: Vector2,
		y0: float, y1: float, colour: Color) -> void:
	quad(b, Vector3(a0.x, y0, a0.y), Vector3(a1.x, y0, a1.y),
		Vector3(b1.x, y1, b1.y), Vector3(b0.x, y1, b0.y), colour)
