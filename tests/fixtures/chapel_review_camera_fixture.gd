extends RefCounted
## Geometry-derived camera stations for the native Gothic chevet review.
## Keeping these here makes the camera axes and walking-band clearance inspectable.

const BODY_RADIUS := 0.28
const CHAPEL_BODY_RADIUS := 0.28
const EYE_ABOVE_FLOOR := 1.58
const CHAPEL_REVIEW_FOV := 72.0
const CHAPEL_REVIEW_ASPECT := 1.6


static func radial(spec: ChurchSpec, chapel_index: int) -> Vector3:
	var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
	return Vector3(sin(angle), 0.0, cos(angle))


static func ambulatory_view(spec: ChurchSpec, chapel_index: int) -> Dictionary:
	var direction := radial(spec, chapel_index)
	var inner: float = ChurchGeometry.ambulatory_inner_radius(spec)
	var outer_inner_face: float = ChurchGeometry.ambulatory_radius(spec) - ChurchBuilder.NAVE_WALL_T
	var body_clear_width: float = outer_inner_face - inner - BODY_RADIUS * 2.0
	var station_radius: float = inner + BODY_RADIUS + maxf(0.35, body_clear_width * 0.42)
	station_radius = clampf(station_radius, inner + BODY_RADIUS, outer_inner_face - BODY_RADIUS)
	var origin := Vector3(0.0, 0.0, ChurchGeometry.apse_springing_z(spec))
	var floor_y: float = ChurchGeometry.FLOOR_LIFT - ChurchGeometry.FLOOR_T * 0.5
	var eye := origin + direction * station_radius + Vector3.UP * (floor_y + EYE_ABOVE_FLOOR)
	var chapel_center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
	var target := chapel_center + direction * minf(0.35, spec.chapel_radius * 0.12) \
		+ Vector3.UP * (floor_y + EYE_ABOVE_FLOOR)
	return {
		"eye": eye,
		"target": target,
		"clearance": {
			"source": "ChurchGeometry ambulatory floor radii and inner wall face",
			"camera_body_radius_m": BODY_RADIUS,
			"floor_top_y_m": floor_y + ChurchGeometry.FLOOR_T,
			"station_radius_m": station_radius,
			"floor_inner_radius_m": inner,
			"wall_inner_face_radius_m": outer_inner_face,
			"body_clearance_inner_m": station_radius - inner - BODY_RADIUS,
			"body_clearance_outer_m": outer_inner_face - station_radius - BODY_RADIUS,
		}
	}


static func chapel_view(spec: ChurchSpec, chapel_index: int,
		placements: Array[Dictionary]) -> Dictionary:
	var direction := radial(spec, chapel_index)
	var floor_y: float = ChurchGeometry.FLOOR_LIFT - ChurchGeometry.FLOOR_T * 0.5
	var mouth_radius: float = ChurchGeometry.ambulatory_radius(spec) - ChurchBuilder.NAVE_WALL_T
	var mouth_width: float = ChurchGeometry.chapel_mouth_width(spec, chapel_index)
	var mouth_height: float = ChurchGeometry.chapel_mouth_height(spec, chapel_index)
	var ring_center := Vector3(0.0, 0.0, ChurchGeometry.chapel_ring_center_z(spec))
	var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
	var tangent := Vector3(cos(angle), 0.0, -sin(angle))
	var toward_nave := tangent * (-1.0 if angle < 0.0 else 1.0)
	var station := _chapel_station(spec, chapel_index, toward_nave, placements)
	var center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
	var eye := center + direction * float(station.depth) \
		- toward_nave * float(station.side_offset) \
		+ Vector3.UP * (floor_y + EYE_ABOVE_FLOOR)
	var altar_center := center + direction * (spec.chapel_radius * 0.55)
	for placement in placements:
		if int(placement.get("chapel_index", -1)) == chapel_index \
				and String(placement.get("key", "")) == ChurchFurnisher.ALTAR:
			var plan_center: Vector2 = PropCatalog.plan_centre(String(placement.key),
				placement.pos, float(placement.yaw), float(placement.scale))
			altar_center = Vector3(plan_center.x, 0.0, plan_center.y)
			break
	var target := altar_center + Vector3.UP * (floor_y + 1.05)
	return {
		"eye": eye,
		"target": target,
		"purpose": "walkable chapel interior view toward measured altar and paired benches",
		"clearance": {
			"source": "measured ChurchFurnisher altar/bench placements and emitted ChurchBuilder chapel shell",
			"camera_body_radius_m": CHAPEL_BODY_RADIUS,
			"floor_top_y_m": floor_y + ChurchGeometry.FLOOR_T,
			"camera_station_radius_m": (eye - ring_center).dot(direction),
			"station_depth_from_chapel_face_m": station.depth,
			"station_side_offset_m": station.side_offset,
			"station_found_from_measured_floor_rectangles": station.found,
			"mouth_wall_inner_radius_m": mouth_radius,
			"target_plan_center": Vector2(altar_center.x, altar_center.z),
			"mouth_width_m": mouth_width,
			"mouth_height_m": mouth_height,
			"camera_fov_degrees": CHAPEL_REVIEW_FOV,
			"camera_aspect": CHAPEL_REVIEW_ASPECT,
			"body_clearance_requires_triangle_and_floor_prop_probes": true,
		}
	}


static func chapel_cutaway_view(spec: ChurchSpec, chapel_index: int,
		placements: Array[Dictionary]) -> Dictionary:
	var radial_dir: Vector3 = radial(spec, chapel_index)
	var angle: float = ChurchGeometry.chapel_angle(spec, chapel_index)
	var tangent := Vector3(cos(angle), 0.0, -sin(angle))
	var floor_y: float = ChurchGeometry.FLOOR_LIFT - ChurchGeometry.FLOOR_T * 0.5
	var floor_top: float = floor_y + ChurchGeometry.FLOOR_T
	var focal_sum := Vector2.ZERO
	var focal_count := 0
	for placement in placements:
		if int(placement.get("chapel_index", -1)) != chapel_index:
			continue
		var key: String = String(placement.get("key", ""))
		if key != ChurchFurnisher.ALTAR and key != ChurchFurnisher.PEW:
			continue
		var plan_center: Vector2 = PropCatalog.plan_centre(key, placement.pos,
			float(placement.yaw), float(placement.scale))
		focal_sum += plan_center
		focal_count += 1
	var focal: Vector2 = focal_sum / float(maxi(focal_count, 1))
	var target := Vector3(focal.x, floor_y + 1.05, focal.y)
	var radius: float = spec.chapel_radius
	var body_height: float = ChurchGeometry.chapel_body_height(spec, chapel_index)
	var chapel_center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
	var eye_height: float = minf(body_height * 0.30, 1.8)
	# Place the review camera outside the mouth at a low three-quarter angle.
	# The renderer removes the camera-side stone wall from this chapel only.
	var eye := chapel_center - radial_dir * (radius * 0.65) \
		+ tangent * (radius * 0.45) + Vector3.UP * (floor_y + eye_height)
	return {
		"eye": eye,
		"target": target,
		"purpose": "low three-quarter chapel detail with the camera-side wall clipped",
		"clearance": {
			"source": "chapel radius/body height and measured ChurchFurnisher altar/bench plan centres",
			"cutaway_view": true,
			"camera_side_wall_clipped": true,
			"floor_top_y_m": floor_top,
			"target_plan_center": focal,
			"chapel_radius_m": radius,
			"chapel_body_height_m": body_height,
			"camera_fov_degrees": 70.0,
			"camera_aspect": CHAPEL_REVIEW_ASPECT,
			"camera_elevated_height_m": eye_height,
			"projected_furnishing_count": focal_count,
		}
	}


static func _chapel_station(spec: ChurchSpec, chapel_index: int,
		toward_nave: Vector3, placements: Array[Dictionary]) -> Dictionary:
	var center: Vector3 = ChurchGeometry.chapel_center(spec, chapel_index)
	var radial_dir: Vector3 = radial(spec, chapel_index)
	var tangent_dir := Vector3(cos(ChurchGeometry.chapel_angle(spec, chapel_index)), 0.0,
		-sin(ChurchGeometry.chapel_angle(spec, chapel_index)))
	var usable_radius: float = spec.chapel_radius \
		- minf(ChurchBuilder.NAVE_WALL_T, spec.chapel_radius * 0.24) - 0.06
	var depth_steps: int = int(maxf(0.0, spec.chapel_radius * 0.72 - 0.30) / 0.05)
	var side_steps: int = int(maxf(0.0, spec.chapel_radius * 0.72) / 0.05)
	# Search outward from the mouth. The first station is the shallowest measured
	# floor-clear point; side offsets are tested against the actual turned props.
	for depth_index in range(depth_steps + 1):
		var depth: float = 0.30 + float(depth_index) * 0.05
		for side_index in range(side_steps + 1):
			var side_offset: float = float(side_index) * 0.05
			if Vector2(depth, side_offset).length() + CHAPEL_BODY_RADIUS > usable_radius:
				continue
			var position := center + radial_dir * depth - toward_nave * side_offset
			if _floor_rects_clear(position, placements, chapel_index):
				return {"position": position, "depth": depth,
					"side_offset": side_offset, "found": true}
	return {"position": center + radial_dir * 0.30, "depth": 0.30,
		"side_offset": 0.0, "found": false}


static func _floor_rects_clear(position: Vector3, placements: Array[Dictionary],
		chapel_index: int) -> bool:
	var disk_center := Vector2(position.x, position.z)
	for placement in placements:
		if int(placement.get("chapel_index", -1)) != chapel_index:
			continue
		var rect: Rect2 = placement.get("rect", Rect2())
		if rect.size == Vector2.ZERO:
			continue
		var closest := Vector2(clampf(disk_center.x, rect.position.x, rect.end.x),
			clampf(disk_center.y, rect.position.y, rect.end.y))
		if disk_center.distance_to(closest) < CHAPEL_BODY_RADIUS:
			return false
	return true


static func context_view(spec: ChurchSpec) -> Dictionary:
	var ring_radius: float = ChurchGeometry.ambulatory_radius(spec) + spec.chapel_radius
	var body_height: float = ChurchGeometry.chapel_body_height(spec, 0)
	var target := Vector3(0.0, body_height * 0.42,
		ChurchGeometry.apse_springing_z(spec) + ring_radius * 0.48)
	return {
		"target": target,
		"eye": target + Vector3(ring_radius * 1.75,
			maxf(5.0, body_height * 0.72), ring_radius * 1.85),
	}
