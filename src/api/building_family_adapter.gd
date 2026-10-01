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


## Internal placement preparation. Families may omit only work that cannot
## affect their emitted shell, exterior bounds, footprint or entrance.
func generate_for_placement(request: BuildingRequest, out) -> bool:
	return generate(request, out)


func placement_metadata(_building, _bounds: AABB) -> Dictionary:
	return {}


## A fresh mesh from a generated representation.
func build_mesh(_building) -> ArrayMesh:
	return null


## The family's existing quality checks, before public diagnostic formatting.
func quality_report(_building) -> Dictionary:
	return {"failures": ["unsupported_family: No QA adapter exists for this family."], "warnings": []}


static func plan_quality_report(plan: HousePlan) -> Dictionary:
	var builder := HouseBuilder.new()
	builder.build(plan)
	var report: Dictionary = HouseQA.new().check(plan, builder)
	if not plan.courts.is_empty():
		var court: Dictionary = CourtCheck.new().check(plan)
		report["failures"].append_array(court["failures"])
		report["warnings"].append_array(court["warnings"])
	return report


## A fresh scene, with the family's own props in it. Null falls back to the
## facade's plain mesh instance, which is what an adapter that has no
## assembler of its own wants.
func instantiate(_building, _cutaway: bool) -> Node3D:
	return null


## The walls' own outline in XZ, local space -- narrower than the mesh's
## `bounds`, which also covers roof eaves, porches and towers. An open manor's
## entrance is recessed inside its courtyard; door() retains that true location.
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
	if building.plan != null and building.plan.world_family in \
			[&"courtyard_house", &"insula", &"mosque", &"caravanserai", &"hammam",
			&"cruciform_temple", &"pagoda", &"vihara"]:
		return of(&"world")
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
	func quality_report(building) -> Dictionary:
		return plan_quality_report(building.plan)

	func footprint(building) -> Rect2:
		return HouseGeometry.storey_rect(building.plan,
			maxi(building.plan.spec.storeys - 1, 0)).grow(-HouseGeometry.wall_thickness(building.plan.spec))

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
		return _generate_plan(request, out, true)

	func generate_for_placement(request: BuildingRequest, out) -> bool:
		if not _generate_plan(request, out, false):
			return false
		if HouseFurnisher.shell_needs_furnishing(out.plan):
			HouseFurnisher.prepare_shell_focus(out.plan, out.spec)
		HouseExterior.dress(out.plan)
		return true

	func _generate_plan(request: BuildingRequest, out, furnish: bool) -> bool:
		var spec := HouseSpec.new()
		spec.material = request.material
		_copy_size_and_style(request, spec)
		spec.trade = request.purpose
		spec.storeys = request.storeys
		out.plan = HouseGenerator.generate(spec, request.seed, furnish)
		out.spec = spec
		return true

	func build_mesh(building) -> ArrayMesh:
		return HouseBuilder.new().build(building.plan)

	func instantiate(building, cutaway: bool) -> Node3D:
		return HouseAssembler.build(building.plan, cutaway)


class ShopFamily extends PlanFamily:
	func generate(request: BuildingRequest, out) -> bool:
		return _generate_plan(request, out, true)

	func generate_for_placement(request: BuildingRequest, out) -> bool:
		if not _generate_plan(request, out, false):
			return false
		# Rugs and chimney breasts are emitted shell geometry derived from the
		# final furnished plan. Shops without either feature retain the cheap
		# planning path; affected rooms must replay native furnishing exactly.
		if HouseFurnisher.shell_needs_furnishing(out.plan):
			HouseFurnisher.prepare_shell_focus(out.plan, out.spec)
		return true

	func _generate_plan(request: BuildingRequest, out, furnish: bool) -> bool:
		var spec := ShopSpec.new()
		spec.material = request.material
		_copy_size_and_style(request, spec)
		spec.business = request.purpose
		spec.storeys = request.storeys
		out.plan = ShopGenerator.generate(spec, request.seed, furnish)
		out.spec = spec
		return true

	## A shop's shell is a house's shell: the plan is what differs.
	func build_mesh(building) -> ArrayMesh:
		return HouseBuilder.new().build(building.plan)

	func instantiate(building, cutaway: bool) -> Node3D:
		return ShopAssembler.build(building.plan, cutaway)

	func placement_metadata(building, _bounds: AABB) -> Dictionary:
		if building.spec.business != &"bakery":
			return {}
		var openings: Array[Dictionary] = []
		for window in building.plan.windows:
			if HousePlan.record_storey(window) == 0:
				openings.append(window.duplicate(true))
		for door in building.plan.doors:
			if door["exterior"] and HousePlan.record_storey(door) == 0:
				var entry: Dictionary = door.duplicate(true)
				entry["sill"] = float(door.get("sill", 0.0))
				entry["head"] = float(door.get("head", HouseGeometry.DOOR_H))
				openings.append(entry)
		return {"mill_wall_rect": HouseGeometry.site_rect(building.spec),
			"mill_openings": openings}


class HotelFamily extends PlanFamily:
	func quality_report(building) -> Dictionary:
		var builder := HotelBuilder.new()
		builder.build(building.plan)
		return HotelQA.new().check(building.plan, builder)

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
	func quality_report(building) -> Dictionary:
		var builder := ChurchBuilder.new()
		var mesh: ArrayMesh = builder.build(building.spec)
		return BlueprintQA.new().check(building.spec, mesh, builder)

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
	func quality_report(building) -> Dictionary:
		var builder := CastleBuilder.new()
		var mesh: ArrayMesh = builder.build(building.spec)
		return CastleQA.new().check(building.spec, mesh, builder)

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
		# Houses and manors have a porch passage, not a curtain gatehouse.
		# Its actual mouth can project beyond the site or sit inside an open
		# courtyard; returning the empty gatehouse placed paths at the origin.
		var porch: AABB = CastleGeometry.porch_aabb(castle)
		if porch.size.x > 0.0:
			return Vector3(porch.get_center().x,
				minf(porch.size.y - 0.2, HouseGeometry.DOOR_H) * 0.5, porch.position.z)
		var g: AABB = CastleGeometry.gatehouse_aabb(castle, 0)
		return Vector3(0.0, g.size.y / 2.0, g.position.z)

	func placement_metadata(building, bounds: AABB) -> Dictionary:
		var castle := building.spec as CastleSpec
		var porch: AABB = CastleGeometry.porch_aabb(castle)
		var fp := footprint(building)
		if castle.tier != &"manor" or castle.courtyard or porch.size.x <= 0.0 \
				or porch.position.z <= fp.position.y + 1.0:
			return {}
		# This is an open arrival court between wings, not solid floor across
		# the bounding rectangle. Retain the actual recessed porch entrance.
		var width: float = minf(porch.size.x * 0.5, 2.0)
		return {"approach": Rect2(Vector2(porch.get_center().x - width * 0.5,
			bounds.position.z - 1.0), Vector2(width, porch.position.z - bounds.position.z + 1.0))}


# -------------------------------------------------------------- the temples

class TempleFamily extends BuildingFamilyAdapter:
	func quality_report(building) -> Dictionary:
		var builder := TempleBuilder.new()
		builder.build(building.spec)
		return TempleQA.new().check(building.spec, builder)

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

	## The ziggurat's twin stair flights are physical architecture outside its
	## terraces. Lots must retain their full depth even though the door recedes.
	func footprint(building) -> Rect2:
		var temple := building.spec as TempleSpec
		var rect := TempleGeometry.site_rect(temple)
		if temple.form == &"ziggurat":
			rect = rect.merge(TempleGeometry.stair_rect(temple))
		return rect

	func door(building) -> Vector3:
		var temple := building.spec as TempleSpec
		var r: Rect2 = TempleGeometry.site_rect(temple)
		var gh: float = minf(TempleGeometry.GATE_H, temple.height - 0.6)
		return Vector3(0.0, gh / 2.0, r.position.y)

	func placement_metadata(building, bounds: AABB) -> Dictionary:
		var temple := building.spec as TempleSpec
		if temple.form != &"ziggurat":
			return {}
		# The twin summit flights flank an open ground-level processional axis
		# to the chamber portal. Restore only this native passage through the
		# bounds rectangle; keep the actual door and both solid stairs intact.
		var width := minf(TempleGeometry.GATE_W - 2.0 * TempleGeometry.PERSON_RADIUS, 2.0)
		var front := bounds.position.z - 1.0
		return {"approach": Rect2(Vector2(-width * 0.5, front),
			Vector2(width, door(building).z - front))}


# ------------------------------------------------ the buildings of the world

## The `world` kind is itself a registry (WLD-000), so its adapter is a
## forwarder: `WorldFamilies` decides which of its own families answers.
class WorldFamily extends BuildingFamilyAdapter:
	func quality_report(building) -> Dictionary:
		if building.plan != null and building.plan.world_family == &"cruciform_temple":
			var builder := CruciformBuilder.new()
			builder.build(building.plan)
			return CruciformCheck.check(building.plan, builder)
		if building.plan != null and building.plan.world_family == &"mosque":
			return QiblaCheck.new().check(building.plan)
		if building.plan != null and building.plan.world_family == &"hammam":
			var builder := HammamBuilder.new()
			builder.build(building.plan)
			return HammamCheck.new().check(building.plan, builder)
		if building.plan != null and building.plan.world_family == &"pagoda":
			var pagoda_builder := PagodaBuilder.new()
			pagoda_builder.build(building.plan)
			return PagodaCheck.new().check(building.plan, pagoda_builder)
		if building.plan != null:
			if building.plan.world_subkind == &"sultan_han":
				return HanCheck.new().check(building.plan)
			if building.plan.world_subkind == &"monks_cloister":
				return ViharaCheck.new().check(building.plan)
			return plan_quality_report(building.plan)
		if building.spec is CastleSpec and CastleGeometry.is_tower_house(building.spec):
			var builder := CastleBuilder.new()
			builder.build(building.spec)
			return TowerCheck.new().check(building.spec, builder)
		if building.spec is TimberHallSpec:
			var builder := TimberHallBuilder.new()
			builder.build(building.spec)
			return HallCheck.check(building.spec, builder)
		if building.spec is StupaSpec:
			var builder := StupaBuilder.new()
			builder.build(building.spec)
			return StupaCheck.new().check(building.spec, builder)
		return super.quality_report(building)

	func generate(request: BuildingRequest, out) -> bool:
		return WorldFamilies.generate(request, out)

	func build_mesh(building) -> ArrayMesh:
		return WorldFamilies.build_mesh(building)

	func instantiate(building, cutaway: bool) -> Node3D:
		if building.plan != null and building.plan.world_family in \
				[&"courtyard_house", &"insula", &"caravanserai", &"vihara"]:
			return HouseAssembler.build(building.plan, cutaway)
		if building.spec is CastleSpec and CastleGeometry.is_tower_house(building.spec):
			return CastleAssembler.build(building.spec, cutaway)
		return null

	func footprint(building) -> Rect2:
		if building.plan != null and building.plan.world_family in \
				[&"courtyard_house", &"insula", &"caravanserai", &"hammam", &"vihara"]:
			return HouseGeometry.site_rect(building.plan.spec)
		if building.spec is CastleSpec and CastleGeometry.is_tower_house(building.spec):
			var bounds := CastleGeometry.tower_house_aabb(building.spec)
			return Rect2(Vector2(bounds.position.x, bounds.position.z),
				Vector2(bounds.size.x, bounds.size.z))
		if building.plan != null and building.plan.world_family == &"mosque":
			return building.plan.world_meta.get("hall_rect", Rect2())
		if building.plan != null and building.plan.world_family == &"cruciform_temple":
			return building.plan.world_meta.get("hall_rect", Rect2())
		if building.plan != null and building.plan.world_family == &"pagoda":
			return building.plan.world_meta.get("footprint", Rect2())
		if building.spec is StupaSpec:
			return Rect2(Vector2(-building.spec.width * 0.5, -building.spec.length * 0.5),
				Vector2(building.spec.width, building.spec.length))
		return Rect2()

	func door(building) -> Vector3:
		if building.plan != null and building.plan.world_family in \
				[&"courtyard_house", &"insula", &"caravanserai", &"hammam", &"vihara"]:
			var d: int = building.plan.entrance()
			if d >= 0:
				var p: Vector2 = building.plan.doors[d]["pos"]
				return Vector3(p.x, 1.0, p.y)
		if building.spec is CastleSpec and CastleGeometry.is_tower_house(building.spec):
			var spec: CastleSpec = building.spec
			var bounds := CastleGeometry.tower_house_aabb(spec)
			var sill := CastleGeometry.tower_door_sill(spec)
			var height := minf(CastleGeometry.tower_storey_height(spec) * 0.7, 2.6)
			return Vector3(bounds.get_center().x, sill + height * 0.5,
				bounds.position.z - CastleGeometry.OPENING_EPS)
		if building.plan != null and building.plan.world_family == &"mosque":
			var p: Vector2 = building.plan.world_meta.get("sahn_door", Vector2.ZERO)
			return Vector3(p.x, 1.0, p.y)
		if building.plan != null and building.plan.world_family == &"cruciform_temple":
			var p: Vector2 = building.plan.world_meta["entrances"][0]["pos"]
			return Vector3(p.x, 1.0, p.y)
		if building.plan != null and building.plan.world_family == &"pagoda":
			var p: Vector2 = building.plan.world_meta.get("entry", Vector2.ZERO)
			return Vector3(p.x, 1.0, p.y)
		if building.spec is StupaSpec:
			return Vector3(0, 0, -building.spec.torana_radius)
		return Vector3.ZERO


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
	func quality_report(building) -> Dictionary:
		return VillageQA.new().check(building.village)

	func generate(request: BuildingRequest, out) -> bool:
		var spec := VillageSpec.new(request.seed)
		spec.population = int(round(request.width))
		spec.wealth = clampf(request.length / 100.0, 0.0, 1.0)
		spec.culture = request.style
		spec.purpose = request.purpose
		spec.water = request.water
		spec.enclosure = request.enclosure
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

## A family's surface colours, in surface order (API-005).
##
## Every family's mesh has its surfaces in the same order -- wall/stone, trim,
## roof, floor/openings -- and every one of them had its own copy of the loop
## that turned those into materials, with its own roughness for no reason any
## of them could have stated. `ShellAssembler.surface_materials()` is the one
## loop now and this is the one place the colours are named, so a caller that
## wants to build its own materials can ask instead of reaching into a spec
## it should not know about.
##
## Takes the SPEC rather than a generated building, because the assemblers
## are handed a plan or a spec and never the facade's wrapper.
static func colours(spec: RefCounted) -> Array:
	if spec == null:
		return []
	if spec is VillageSpec:
		var ground: Array = []
		for i in range(VillageBuilder.SURFACES):
			ground.append(Color(String(VillageBuilder.COLOURS.get(i, "808080"))))
		return ground
	if spec is TempleSpec:
		# a temple's fourth surface is its own darkness, not a floor colour
		return [spec.get("stone_color"), spec.get("trim_color"),
			spec.get("roof_color"), TEMPLE_DARK]
	# house, shop and hotel name their masonry `wall_color`; church, castle
	# and the world families call the same surface `stone_color`
	var wall = spec.get("wall_color")
	if wall == null:
		wall = spec.get("stone_color")
	var floor = spec.get("floor_color")
	if floor == null:
		floor = ShellAssembler.NO_COLOUR
	return [wall, spec.get("trim_color"), spec.get("roof_color"), floor]


## The inside of a temple, which is not a floor colour and never was.
const TEMPLE_DARK := Color("07070a")


## The three fields every family names the same way. A family whose spec
## calls them something else (the temple's `form`) copies them itself.
static func _copy_size_and_style(request: BuildingRequest, spec: RefCounted) -> void:
	spec.set("style", request.style)
	spec.set("width", request.width)
	spec.set("length", request.length)
	spec.set("height", request.height)
