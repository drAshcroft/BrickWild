class_name WitchAwningCheck
extends RefCounted
## WITCH-REVIEW-FOLLOWUPS item 4: a Witch work shelter must not run into the
## thatch. The shelter roof is a thin slab hung from the wall plate; the thatch
## eave stands out 0.6 m over the same wall and is lower than the plate, so a
## slab that starts at the wall pierces the thatch's edge. This check samples
## the underside and top of every `*_roof` part of the shelter and asks whether
## any sample lies inside the house roof slab (RoofShape.DEPTH thick about its
## mid-plane). Samples inside by more than TOL are intrusions.

const TOL := 0.01
const STEP := 0.1


## {ok, intrusions:Array[Dictionary], checked:int}; `intrusions` rows carry the
## part role, the sample point and how far inside the thatch it is.
static func check(plan: HousePlan) -> Dictionary:
	var layout := HouseGeometry.roof_layout(plan)
	var faces: Array[PackedVector3Array] = layout["faces"]
	var xf: Transform3D = layout["transform"]
	var inv := xf.affine_inverse()
	var out: Array[Dictionary] = []
	var checked := 0
	for piece in plan.yard_pieces:
		if String(piece.get("kind", "")) != "witch_work_lean_to" \
				and not String(piece.get("role", "")).begins_with("witch_work"):
			continue
		for part in piece["parts"]:
			var role := String(part.get("role", ""))
			if not role.ends_with("_roof"):
				continue
			checked += 1
			var pxf := HouseYard.part_xform(part)
			var half: Vector3 = (part["size"] as Vector3) * 0.5
			var x := -half.x
			while x <= half.x + 0.0001:
				var z := -half.z
				while z <= half.z + 0.0001:
					for y in [-half.y, 0.0, half.y]:
						var w: Vector3 = pxf * Vector3(x, y, z)
						var l: Vector3 = inv * w
						var h := RoofShape.height_at(faces, Vector2(l.x, l.z))
						if not is_nan(h):
							var inside := minf(l.y - (h - RoofShape.DEPTH * 0.5),
								(h + RoofShape.DEPTH * 0.5) - l.y)
							if inside > TOL:
								out.append({"role": role, "point": w, "inside": inside})
					z += STEP
				x += STEP
	return {"ok": out.is_empty(), "intrusions": out, "checked": checked}
