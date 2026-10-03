extends RefCounted
## The five mills, every one of them, against `WindmillCheck` -- plus the two
## things a generator harness is allowed to assume and this one proves anyway:
## that a seed gives the same mill twice, and that a mill the PUBLIC API built
## is the mill the family built.

const SEEDS := 5
## The three numbers a caller moves: a rotor span, a body, a height. The ends
## matter more than the middle -- the clamp in `WindmillGeometry.legal()` is
## where an impossible mill is refused, and that is exactly where a sweep that
## only tried the defaults would find nothing.
const SPANS := [2.5, 8.0, 20.0]
const BODIES := [2.0, 6.0, 10.0]
const HEIGHTS := [3.0, 12.0, 24.0]


static func run() -> SuiteResult:
	var res := SuiteResult.new("windmills")
	_sweep(res)
	_variety(res)
	_purity(res)
	_public_api(res)
	return res


## Every mill, at every corner of its own envelope, from several seeds.
static func _sweep(res: SuiteResult) -> void:
	var checked := 0
	var bad := 0
	for mill_type in WindmillSpec.TYPES:
		for span in SPANS:
			for body in BODIES:
				for height in HEIGHTS:
					var spec := _spec(mill_type, span, body, height, SEEDS)
					var builder := WindmillBuilder.new()
					var mesh: ArrayMesh = builder.build(spec)
					var rep: Dictionary = WindmillCheck.new().check(spec, mesh, builder)
					checked += 1
					if not rep["ok"]:
						bad += 1
						if bad <= 6:
							for f in rep["failures"]:
								res.fail("%s s%d span=%.1f body=%.1f h=%.1f: %s" % [
									mill_type, spec.seed, span, body, height, f])
	res.checked += checked
	res.note("%d mills checked, %d with defects" % [checked, bad])


## The point of the family is that these are five DIFFERENT buildings. Two mills
## of the same kind from different seeds must differ; two kinds from the same
## seed must differ more, or the `style` a caller picks is a decoration.
static func _variety(res: SuiteResult) -> void:
	var per_type := {}
	var shared_seed := 9118
	for mill_type in WindmillSpec.TYPES:
		var marks := {}
		for s in [3, 29, 101, 9118]:
			var spec := _spec(mill_type, 12.0, 6.0, 12.0, s)
			var mesh: ArrayMesh = WindmillBuilder.new().build(spec)
			marks[s] = int(WindmillCheck.measure(mesh, spec)["checksum"])
		per_type[mill_type] = marks
		var distinct := {}
		for key in marks:
			distinct[marks[key]] = true
		_expect(res, distinct.size() == marks.size(),
			"%s: %d seeds gave only %d different mills." % [mill_type, marks.size(),
				distinct.size()])
	_expect(res, int(per_type.values()[0][shared_seed]) != 0, "no mill was built")
	# the five kinds must not be one building in five costumes
	var kinds := {}
	for mill_type in per_type:
		kinds[int(per_type[mill_type][shared_seed])] = true
	_expect(res, kinds.size() == WindmillSpec.TYPES.size(),
		"the five mill types produced only %d distinct buildings at seed %d."
			% [kinds.size(), shared_seed])


## A mill is a pure function of its spec. Two builds, one spec, one mesh.
static func _purity(res: SuiteResult) -> void:
	for mill_type in WindmillSpec.TYPES:
		var spec := _spec(mill_type, 11.0, 5.5, 13.0, 4242)
		var first: int = int(WindmillCheck.measure(
			WindmillBuilder.new().build(spec), spec)["checksum"])
		var second: int = int(WindmillCheck.measure(
			WindmillBuilder.new().build(spec), spec)["checksum"])
		_expect(res, first == second,
			"%s: two builds of one spec differ (%d vs %d)." % [mill_type, first, second])


## The public API builds the same mill the family does, for every kind it
## publishes, and a document round trip is lossless.
static func _public_api(res: SuiteResult) -> void:
	var described: Dictionary = BrickWild.describe_kind(&"windmill")
	_expect(res, not described.is_empty(), "the library publishes no windmill kind.")
	var styles: Array = described.get("styles", [])
	_expect(res, styles.size() == WindmillSpec.TYPES.size(),
		"the library offers %d mill types; the family has %d."
			% [styles.size(), WindmillSpec.TYPES.size()])
	for row in styles:
		var mill_type := StringName(row["id"])
		var request := BuildingRequest.windmill(9118, mill_type)
		var building := BrickWild.generate(request)
		var problems := _errors_of(building)
		_expect(res, problems.is_empty(), "%s: the API refused a default request: %s"
			% [mill_type, " / ".join(problems)])
		if not problems.is_empty():
			continue
		var mesh: ArrayMesh = BrickWild.build_mesh(building)
		_expect(res, mesh != null, "%s: the API built no mesh." % mill_type)
		if mesh == null:
			continue
		var direct: ArrayMesh = WindmillBuilder.new().build(building.spec as WindmillSpec)
		_expect(res, WindmillCheck.measure(mesh)["checksum"]
				== WindmillCheck.measure(direct)["checksum"],
			"%s: the API's mesh is not the family builder's mesh." % mill_type)
		var place: Dictionary = BrickWild.placement(building)
		_expect(res, place.has("bounds") and place.has("door"),
			"%s: the API reported no placement." % mill_type)
		var fp: Rect2 = place.get("footprint", Rect2())
		var door: Vector3 = place.get("door", Vector3.ZERO)
		_expect(res, absf(door.z - fp.position.y) <= 0.6,
			"%s: the door is %.2f m off the footprint's -Z edge."
				% [mill_type, door.z - fp.position.y])
		# A polder mill's race is ground it needs and does not own, so it is
		# published beside the placement -- and every other mill has none.
		var race: Rect2 = place.get("race", Rect2())
		if mill_type == &"paddle":
			_expect(res, race.size != Vector2.ZERO and race.position.y < fp.position.y,
				"%s: no race was published in front of the door." % mill_type)
		else:
			_expect(res, race.size == Vector2.ZERO,
				"%s: published a race it does not have." % mill_type)
		# Dispatch follows the SPEC, so a caller scribbling on the request
		# snapshot it was handed cannot turn a mill into a temple.
		var kind_now: StringName = building.request.kind
		building.request.kind = &"temple"
		_expect(res, WindmillCheck.measure(BrickWild.build_mesh(building))["checksum"]
				== WindmillCheck.measure(mesh)["checksum"],
			"%s: mutating the request snapshot broke mesh dispatch." % mill_type)
		building.request.kind = kind_now
		var scene := BrickWild.instantiate(building)
		_expect(res, scene != null and scene.get_child_count() > 0,
			"%s: the assembler returned nothing." % mill_type)
		# and the document crossing the boundary is lossless
		var doc := BrickWild.generate_document(request)
		var again: ArrayMesh = BrickWild.build_mesh(doc)
		_expect(res, again != null and WindmillCheck.measure(again)["checksum"]
				== WindmillCheck.measure(mesh)["checksum"],
			"%s: a mill changed crossing the document boundary." % mill_type)
	# an unknown mill type is refused before anything is built
	var bad: Array[Dictionary] = BrickWild.generate(
		BuildingRequest.windmill(1, &"sawmill")).errors
	_expect(res, not bad.is_empty(), "an unknown mill type was accepted.")


static func _spec(mill_type: StringName, span: float, body: float, height: float,
		seed_value: int) -> WindmillSpec:
	var spec := WindmillSpec.new(seed_value)
	spec.mill_type = mill_type
	spec.sail_span = span
	spec.body = body
	spec.height = height
	WindmillGenerator.generate(spec, seed_value)
	return spec


## Why the API refused a request, in words. Empty when it did not refuse it.
static func _errors_of(building) -> Array[String]:
	if building == null:
		return ["no building at all"]
	var out: Array[String] = []
	for e in building.errors:
		out.append("%s: %s" % [e.get("code", ""), e.get("message", "")])
	return out


static func _expect(res: SuiteResult, ok: bool, why: String) -> void:
	res.checked += 1
	if not ok:
		res.fail(why)