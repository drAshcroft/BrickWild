class_name DungeonGeometry
extends RefCounted
## The one source of truth for how big a dungeon room is, in metres.
##
## The planner (C:\Projects\dungeon) places rooms on a grid of cells and counts
## height in floors; it never says what a cell measures. VoxelGames, the first
## consumer, carves each room into its own block of rock and used to decide the
## sizes itself (scripts/generation/dungeon_room_volume.gd). These defaults are
## VoxelGames' numbers, so a realised room is the room it already carves; they
## live here now, and BrickWild hands them over in the realised plan.
##
## Room-local frame, the consumer's: x east, z south (planner north is -z), the
## walked floor at y = 0, the chamber centred on the origin.

const EAST := &"east"
const WEST := &"west"
const NORTH := &"north"
const SOUTH := &"south"
const WALLS: Array[StringName] = [EAST, SOUTH, WEST, NORTH]

## The block of rock one room is carved from, and its corner. A room that does
## not fit inside it, with ROCK_MARGIN of rock to spare, is not a room.
var budget_size := Vector3(96.0, 64.0, 96.0)
var budget_origin := Vector3(-48.0, -24.0, -48.0)
const ROCK_MARGIN := 2.0

## A one-cell chamber's half-extents, what each further cell adds, and the cap.
var chamber_half_x := 10.0
var chamber_half_z := 8.0
var half_per_cell_x := 5.0
var half_per_cell_z := 4.0
var max_half := 34.0

## The ceiling climbs with the room's widest span.
var ceiling_y := 7.0
var ceiling_per_cell := 2.5
var max_ceiling_y := 16.0
## What an "enormous" ceiling may reach: a great hall or a shaft, still inside
## the budget with rock above it.
var max_enormous_y := 30.0

## Threshold tunnels: half-width, height, and how far they run out of the wall.
var tunnel_half := 1.5
var tunnel_height := 4.5
var tunnel_reach := 7.0

## Doorways on one wall: kept this far from the corners, this far apart when
## there is room, and never closer than the minimum.
var door_margin := 3.6
var door_gap := 6.5
var door_min_gap := 3.5

## A person with a torch: the least clear height over any walked floor.
const HEADROOM := 2.6
## A stair in a threshold tunnel climbs or drops this far, in risers this high.
const STAIR_RISE := 3.0
const STAIR_RISER := 0.25


func chamber_half(span: Vector2i) -> Vector2:
	return Vector2(
		minf(chamber_half_x + float(maxi(span.x, 1) - 1) * half_per_cell_x, max_half),
		minf(chamber_half_z + float(maxi(span.y, 1) - 1) * half_per_cell_z, max_half))


func chamber_ceiling(span: Vector2i) -> float:
	return minf(ceiling_y + float(maxi(maxi(span.x, span.y), 1) - 1) * ceiling_per_cell,
		max_ceiling_y)


## How far along a wall a doorway may sit from its middle.
func wall_reach(span: Vector2i, wall: StringName) -> float:
	var half := chamber_half(span)
	return (half.y if is_x_wall(wall) else half.x) - door_margin


func budget() -> AABB:
	return AABB(budget_origin, budget_size)


func to_dict() -> Dictionary:
	return {
		"frame": "x east, z south (planner north is -z), floor y 0, chamber centred",
		"budget": {"origin": _v3(budget_origin), "size": _v3(budget_size),
			"rock_margin": ROCK_MARGIN},
		"chamber": {"half": [chamber_half_x, chamber_half_z],
			"half_per_cell": [half_per_cell_x, half_per_cell_z], "max_half": max_half,
			"ceiling": ceiling_y, "ceiling_per_cell": ceiling_per_cell,
			"max_ceiling": max_ceiling_y, "max_enormous": max_enormous_y},
		"tunnel": {"half_width": tunnel_half, "height": tunnel_height, "reach": tunnel_reach},
		"doors": {"margin": door_margin, "gap": door_gap, "min_gap": door_min_gap},
		"headroom": HEADROOM,
		"stair": {"rise": STAIR_RISE, "riser": STAIR_RISER},
	}


## East and west walls run along z.
static func is_x_wall(wall: StringName) -> bool:
	return wall == EAST or wall == WEST


static func opposite(wall: StringName) -> StringName:
	match wall:
		EAST: return WEST
		WEST: return EAST
		NORTH: return SOUTH
		SOUTH: return NORTH
	return wall


## The planner's own rule (dungeon_geometry.gd exit_toward) for a link that
## names no wall: the axis of the larger step, east and south on a tie.
static func exit_toward(from: Vector2i, to: Vector2i) -> StringName:
	var delta := to - from
	if absi(delta.x) >= absi(delta.y):
		return EAST if delta.x >= 0 else WEST
	return SOUTH if delta.y >= 0 else NORTH


## Outward unit normal of a wall, in the room's XZ.
static func normal(wall: StringName) -> Vector2:
	match wall:
		EAST: return Vector2(1, 0)
		WEST: return Vector2(-1, 0)
		SOUTH: return Vector2(0, 1)
	return Vector2(0, -1)


## The point on the chamber wall `along` metres from its middle.
func mouth(span: Vector2i, wall: StringName, along: float) -> Vector2:
	var half := chamber_half(span)
	match wall:
		EAST: return Vector2(half.x, along)
		WEST: return Vector2(-half.x, along)
		SOUTH: return Vector2(along, half.y)
	return Vector2(along, -half.y)


static func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]
