class_name TempleSweep
extends RefCounted
## The canonical temple sweep: every form x every cult x three sizes, on fixed
## seeds. Every temple suite iterates the same set, so a seed named in one
## suite's output means the same temple in another's.
##
## The smallest size is deliberately mean. A temple that cannot be built at
## 16 x 26 m should say so by failing a rule, not by quietly producing a
## sanctum with no room to swing a censer.

const SIZES := [
	{"w": 16.0, "l": 26.0, "h": 8.0},
	{"w": 26.0, "l": 44.0, "h": 12.0},
	{"w": 40.0, "l": 68.0, "h": 18.0},
]

const COUNT := 3


static func forms() -> Array:
	return TempleSpec.FORMS.keys()


static func cults() -> Array:
	return TempleSpec.CULTS.keys()


## Build temple number `i` for (form, cult), generated and ready to build.
static func spec_at(form: StringName, cult: StringName, i: int) -> TempleSpec:
	var row: Dictionary = SIZES[i]
	var spec := TempleSpec.new()
	spec.form = form
	spec.cult = cult
	spec.width = float(row["w"])
	spec.length = float(row["l"])
	spec.height = float(row["h"])
	TempleGenerator.generate(spec, seed_at(form, cult, i))
	return spec


static func seed_at(form: StringName, cult: StringName, i: int) -> int:
	return 31000 + absi(String(form).hash()) % 300 + absi(String(cult).hash()) % 70 + i
