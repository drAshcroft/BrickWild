class_name LightKit
extends RefCounted
## Lights that light (LAY-011).
##
## Every prop the catalogue tags LIGHT -- a sconce, a candle, a chandelier, a
## brazier -- gets an OmniLight3D from here, and only from here: the house,
## shop and hotel assemblers and the temple's own fire-lighting all call the
## same function, so a lamp that is dark in one family is dark in all of them
## and fixed once. The light stands where the flame is: at the prop's measured
## `light_offset` (tools/build_prop_catalog.gd records the top centre of every
## model), turned with the prop and scaled with it.
##
## Range and energy come from a per-category table, so a candle is a candle
## and a chandelier fills the hall; a family may pass its own colour (a cult's
## glow) and its own reach.

## What each category of flame gives off. `reach` in metres, `energy` in
## Godot's units; a category not listed gets DEFAULT.
const TABLE := {
	"candle": {"reach": 3.5, "energy": 0.9},
	"sconce": {"reach": 6.5, "energy": 1.7},
	"chandelier": {"reach": 10.0, "energy": 2.4},
	"brazier": {"reach": 8.0, "energy": 2.2},
	# A cauldron IS the brazier in this pack: the church and the castle stand
	# them on the wall walk and at the chancel step, and a fire in a bowl
	# throws a fire in a bowl worth of light wherever it is standing.
	"hearth": {"reach": 8.0, "energy": 2.2},
	"lamp": {"reach": 6.0, "energy": 1.5},
}
const DEFAULT := {"reach": 5.0, "energy": 1.3}
## Firelight.
const FLAME := Color(1.0, 0.82, 0.58)
const ATTENUATION := 1.4


## The light for one placed prop. `origin` is where the model's own origin
## stands in the scene (the assembler has already dropped it to the floor),
## `yaw` and `scale` are the prop's. Nothing here loads the model: a lamp is
## a lamp whether or not its mesh could be found, which is what lets the
## assets suite count them against the plan.
static func for_prop(key: String, origin: Vector3, yaw: float, scale: float,
		color: Color = FLAME, reach_scale: float = 1.0,
		height_scale: float = -1.0) -> OmniLight3D:
	var row: Dictionary = TABLE.get(PropCatalog.category(key), DEFAULT)
	var vertical_scale: float = scale if height_scale < 0.0 else height_scale
	var raw_offset := PropCatalog.light_offset(key)
	var off := Vector3(raw_offset.x * scale, raw_offset.y * vertical_scale,
		raw_offset.z * scale)
	# a lamp hung from the ceiling burns at its middle, not its mount
	if PropCatalog.has_tag(key, PropCatalog.CEILING):
		raw_offset = PropCatalog.centre_offset(key)
		off = Vector3(raw_offset.x * scale, raw_offset.y * vertical_scale,
			raw_offset.z * scale)
	var turned := Vector3(off.x * cos(yaw) + off.z * sin(yaw), off.y,
		-off.x * sin(yaw) + off.z * cos(yaw))
	return make(origin + turned, color, float(row["energy"]),
		float(row["reach"]) * reach_scale)


## The light itself.
static func make(pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.name = "Light"
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.omni_attenuation = ATTENUATION
	lamp.position = pos
	return lamp


## Lights for every LIGHT-tagged piece of furniture in a plan, under one node.
## The count of lights equals the count of such pieces, by construction, and
## the assets suite checks it anyway.
static func light_the_plan(plan: HousePlan) -> Node3D:
	var lights := Node3D.new()
	lights.name = "Lights"
	for p in plan.furniture:
		var key: String = p["key"]
		if not PropCatalog.has_tag(key, PropCatalog.LIGHT):
			continue
		var s: float = float(p.get("scale", 1.0))
		var height_scale: float = PropCatalog.placement_height_scale(p)
		var origin := PropCatalog.house_origin(p)
		var lamp: OmniLight3D = for_prop(key, origin,
			float(p["yaw"]) + PropCatalog.face_offset(key), s,
			FLAME, 1.0, height_scale)
		# a flame cannot burn above the ceiling of the room it is in, however
		# tall the model that carries it was authored
		var storey: int = HousePlan.record_storey(p)
		var ceiling: float = (float(storey) + 1.0) * plan.spec.height - 0.15
		lamp.position.y = minf(lamp.position.y, ceiling)
		lights.add_child(lamp)
	return lights
