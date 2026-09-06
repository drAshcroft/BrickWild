class_name BuildingFamilyAdapter
extends RefCounted
## One family, behind one interface (API-004).
##
## `BuildingLibrary` holds what each kind IS -- its envelope, its options,
## its words. This holds what each kind DOES: generate its own
## representation, build its own mesh, assemble its own scene, and answer for
## its own footprint and its own front door. Between them the facade needs to
## know neither.
##
## Before this, `BigGlade` had a `match request.kind` for generation, a chain
## of `spec is ChurchSpec` for the mesh, another for the scene, another for
## the footprint and another for the door -- five places to edit, in five
## different orders, to add a family. `WorldFamilies` was already a registry
## of this shape for the `world` kind; this is the same idea for the six that
## came before it, so the facade is now dispatch and nothing else.
##
## An adapter answers about a GENERATED building -- anything with `spec`,
## `plan` and `request` fields, which is both `GeneratedBuilding` and
## `BuildingDocument`.

## Fill `out.spec` (and `out.plan` for the plan families) from `request`.
## False when this family cannot build what was asked for; the facade turns
## that into an error rather than an empty building.
func generate(_request: BuildingRequest, _out) -> bool:
	return false


## A fresh mesh from a generated representation.
func build_mesh(_building) -> ArrayMesh:
	return null


## A fresh scene, with the family's own props in it. Null falls back to the
## facade's plain mesh instance, which is what an adapter that has no
## assembler of its own wants.
func instantiate(_building, _cutaway: bool) -> Node3D:
	return null


## The walls' own outline in XZ, local space -- narrower than the mesh's
## `bounds`, which also covers roof eaves, porches and towers. `door()` sits
## on this rect's -Z edge by construction.
func footprint(_building) -> Rect2:
	return Rect2()


## Where this family's front door sits, in the same local space. Read from
## the plan or spec that produced the mesh, never re-detected from geometry.
func door(_building) -> Vector3:
	return Vector3.ZERO


# ------------------------------------------------------------- the registry

## Every family, by kind. Built once and shared; the adapters are stateless.
static var _registry: Dictionary = {}


## The adapter for a building that HAS been generated, chosen from the
## representation it retained and not from `request.kind`.
##
## The request a caller gets back is a mutable snapshot kept for diagnostics;
## editing it must not change what the building is. This is the one place the
## `spec is ChurchSpec` chain still lives, and the order matters: `HotelSpec`
## and `ShopSpec` both extend `HouseSpec`, so they are asked first or every
## hotel is a house.
static func for_building(building) -> BuildingFamilyAdapter:
	var spec: RefCounted = building.spec
	if spec is HotelSpec:
		return of(&"hotel")
	if spec is ShopSpec:
		return of(&"shop")
	if spec is HouseSpec:
		return of(&"house")
	if spec is ChurchSpec:
		return of(&"church")
	if spec is CastleSpec:
		return of(&"castle")
	if spec is TempleSpec:
		return of(&"temple")
	if spec is VillageSpec:
		return of(&"village")
	# a family whose spec is its own: the world kind, and whatever comes next
	return of(building.request.kind) if building.request != null else null


static func of(kind: StringName) -> BuildingFamilyAdapter:
	if _registry.is_empty():
		_registry = {
			&"church": ChurchFamily.new(),
			&"castle": CastleFamily.new(),
			&"house": HouseFamily.new(),
			&"shop": ShopFamily.new(),
			&"hotel": HotelFamily.new(),
			&"temple": TempleFamily.new(),
			&"world": WorldFamily.new(),
			&"village": VillageFamily.new(),
		}
	return _registry.get(kind, null)


# ---------------------------------------------------------- the plan family

## House, shop and hotel: three trades of one family. All three plan first --
## a `HousePlan` is their representation, not the shell mesh -- so all three
## answer the same way about their footprint and their door, and only the
## generator and the assembler differ.
class PlanFamily extends BuildingFamilyAdapter:
	func footprint(building) -> Rect2:
		return HouseGeometry.interior_rect(building.plan.spec)

	## `HousePlan.entrance()`'s own door position: the plan says where the
	## front door is, and the builder cuts it there.
	func door(building) -> Vector3:
		var plan: HousePlan = building.plan
		var d: int = plan.entrance()
		if d < 0:
			return Vector3(0.0, 1.0, 0.0)
		var pos: Vector2 = plan.doors[d]["pos"]
		return Vector3(pos.x, 1.0, pos.y)


class HouseFamily extends PlanFamily:
	func generate(request: BuildingRequest, out) -> bool:
		var spec := HouseSpec.new()
		_copy_size_and_style(request, spec)
		spec.trade = request.purpose
		spec.storeys = request.storeys
		out.plan = HouseGenerator.generate(spec, request.seed)
		out.spec = spec
		return true

	func build_mesh(building) -> ArrayMesh:
		return HouseBuilder.new().build(building.plan)

	func instantiate(building, cutaway: bool) -> Node3D:
		return HouseAssembler.build(building.plan, cutaway)


class ShopFamily extends PlanFamily:
	func generate(request: BuildingRequest, out) -> bool:
		var spec := ShopSpec.new()
		_copy_size_and_style(request, spec)
		spec.business = request.purpose
		spec.storeys = request.storeys
		out.plan = ShopGenerator.generate(spec, request.seed)
		out.spec = spec
		return true

	## A shop's shell is a house's shell: the plan is what differs.
	func build_mesh(building) -> ArrayMesh:
		return HouseBuilder.new().build(building.plan)

	func instantiate(building, cutaway: bool) -> Node3D:
		return ShopAssembler.build(building.plan, cutaway)


class HotelFamily extends PlanFamily:
	func generate(request: BuildingRequest, out) -> bool:
		var spec := HotelSpec.new()
		_copy_size_and_style(request, spec)
		out.plan = HotelGenerator.generate(spec, request.seed)
		out.spec = spec
		return true

	func build_mesh(building) -> ArrayMesh:
		return HotelBuilder.new().build(building.plan)

	func instantiate(building, cutaway: bool) -> Node3D:
		return HotelAssembler.build(building.plan, cutaway)


# ------------------------------------------------------------ the churches

class ChurchFamily extends BuildingFamilyAdapter:
	func generate(request: BuildingRequest, out) -> bool:
		var spec := ChurchSpec.new()
		_copy_size_and_style(request, spec)
		ChurchGenerator.generate(spec, request.seed)
		out.spec = spec
		return true

	func build_mesh(building) -> ArrayMesh:
		return ChurchBuilder.new().build(building.spec as ChurchSpec)

	func instantiate(building, cutaway: bool) -> Node3D:
		return ChurchAssembler.build(building.spec as ChurchSpec, cutaway)

	## The nave rect, EXCEPT when a single axial tower carries the door out
	## past the nave's own west wall (see `door_z` below): then the front edge
	## follows the door out to that tower's own west face, since the tower is
	## a real mass of the building and not applique on the nave.
	func footprint(building) -> Rect2:
		var church := building.spec as ChurchSpec
		var front_z: float = door_z(church)
		return Rect2(Vector2(-church.width / 2.0, front_z),
			Vector2(church.width, church.length / 2.0 - front_z))

	func door(building) -> Vector3:
		var church := building.spec as ChurchSpec
		return Vector3(0.0, ChurchGeometry.door_height(church) / 2.0, door_z(church))

	## ChurchBuilder's own door_z formula (see its "main door" section): the
	## west door sits on the nave's own front wall, UNLESS a single axial
	## tower carries it out to that tower's own west face instead.
	static func door_z(church: ChurchSpec) -> float:
		var l: float = church.length
		var out: float = -l / 2.0 - 0.02
		if church.tower and church.west_towers == 1:
			out = -l / 2.0 + ChurchGeometry.TOWER_EMBED - church.tower_width - 0.02
		return out


# ------------------------------------------------------------- the castles

class CastleFamily extends BuildingFamilyAdapter:
	func generate(request: BuildingRequest, out) -> bool:
		var spec := CastleSpec.new()
		_copy_size_and_style(request, spec)
		CastleGenerator.generate(spec, request.seed)
		out.spec = spec
		return true

	func build_mesh(building) -> ArrayMesh:
		return CastleBuilder.new().build(building.spec as CastleSpec)

	func instantiate(building, cutaway: bool) -> Node3D:
		return CastleAssembler.build(building.spec as CastleSpec, cutaway)

	## The outer ring the gatehouse is cut into.
	func footprint(building) -> Rect2:
		return CastleGeometry.enceinte_rect(building.spec as CastleSpec, 0)

	func door(building) -> Vector3:
		var castle := building.spec as CastleSpec
		var g: AABB = CastleGeometry.gatehouse_aabb(castle, 0)
		return Vector3(0.0, g.size.y / 2.0, g.position.z)


# -------------------------------------------------------------- the temples

class TempleFamily extends BuildingFamilyAdapter:
	func generate(request: BuildingRequest, out) -> bool:
		var spec := TempleSpec.new()
		spec.form = request.style
		spec.cult = request.purpose
		spec.width = request.width
		spec.length = request.length
		spec.height = request.height
		TempleGenerator.generate(spec, request.seed)
		out.spec = spec
		return true

	func build_mesh(building) -> ArrayMesh:
		return TempleBuilder.new().build(building.spec as TempleSpec)

	func instantiate(building, cutaway: bool) -> Node3D:
		return TempleAssembler.build(building.spec as TempleSpec, cutaway)

	## The outer wall face the gate is cut through -- used uniformly across
	## forms, including the ziggurat, whose gate void is voxel-recessed behind
	## the outermost terrace but whose public-facing gate is still this edge.
	func footprint(building) -> Rect2:
		return TempleGeometry.site_rect(building.spec as TempleSpec)

	func door(building) -> Vector3:
		var temple := building.spec as TempleSpec
		var r: Rect2 = TempleGeometry.site_rect(temple)
		var gh: float = minf(TempleGeometry.GATE_H, temple.height - 0.6)
		return Vector3(0.0, gh / 2.0, r.position.y)


# ------------------------------------------------ the buildings of the world

## The `world` kind is itself a registry (WLD-000), so its adapter is a
## forwarder: `WorldFamilies` decides which of its own families answers.
class WorldFamily extends BuildingFamilyAdapter:
	func generate(request: BuildingRequest, out) -> bool:
		return WorldFamilies.generate(request, out)

	func build_mesh(building) -> ArrayMesh:
		return WorldFamilies.build_mesh(building)


# ------------------------------------------------------------ the villages

## A village asked for like any building (VIL-019).
##
## Its inputs are not a width and a length, so the request's dimension fields
## carry the two numbers a person actually chooses -- `width` is the
## POPULATION and `length` is the WEALTH as a percentage. That is not a
## liberty taken here: it is the mapping the Studio has used for the village
## since it grew a village entry, and `BuildingLibrary` labels the sliders
## accordingly so nobody has to guess.
##
## `style` is the culture and `purpose` is the purpose, exactly as they are
## for every other family.
class VillageFamily extends BuildingFamilyAdapter:
	func generate(request: BuildingRequest, out) -> bool:
		var spec := VillageSpec.new(request.seed)
		spec.population = int(round(request.width))
		spec.wealth = clampf(request.length / 100.0, 0.0, 1.0)
		spec.culture = request.style
		spec.purpose = request.purpose
		if not spec.valid():
			return false
		spec.generate(request.seed)
		var plan: VillagePlan = VillageLotPlanner.plan(spec)
		if plan.roads.is_empty():
			return false          # a form with no planner yet
		out.spec = spec
		out.village = plan
		return true

	func build_mesh(building) -> ArrayMesh:
		return VillageBuilder.new().build(building.village)

	func instantiate(building, cutaway: bool) -> Node3D:
		return VillageAssembler.build(building.village, cutaway)

	## The ground the village stands on.
	func footprint(building) -> Rect2:
		return building.village.site

	## Where you arrive. Every family's front is its local -Z, so a village's
	## is the middle of the -Z edge of its own site -- the point on that edge
	## nearest the common, which is what a road coming in would aim at.
	func door(building) -> Vector3:
		var plan: VillagePlan = building.village
		var site: Rect2 = plan.site
		var x: float = VillageMeasure.common_centre(plan).x
		return Vector3(clampf(x, site.position.x, site.end.x), 1.0, site.position.y)


# ----------------------------------------------------------------- shared

## The three fields every family names the same way. A family whose spec
## calls them something else (the temple's `form`) copies them itself.
static func _copy_size_and_style(request: BuildingRequest, spec: RefCounted) -> void:
	spec.set("style", request.style)
	spec.set("width", request.width)
	spec.set("length", request.length)
	spec.set("height", request.height)
