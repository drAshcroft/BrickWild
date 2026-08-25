class_name TestSweep
extends RefCounted
## The canonical variant sweep: 4 styles x 15 sizes, fixed seeds.
## Every church suite iterates the same set, so a seed named in one suite's
## output means the same building in every other suite's output.

const COUNT := 15

static func styles() -> Array:
	return ChurchSpec.STYLES.keys()


## Build spec number `i` for `style`, generated and ready to build.
static func spec_at(style: StringName, i: int) -> ChurchSpec:
	var spec := ChurchSpec.new(0)
	spec.style = style
	spec.width = 10.0 + i * 0.5
	spec.length = 18.0 + i * 2.0
	spec.height = 10.0 + (i % 5) * 1.5
	ChurchGenerator.generate(spec, seed_at(i))
	return spec


static func seed_at(i: int) -> int:
	return 5000 + i


## Every (style, index) pair in the sweep, in a stable order.
static func each() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for style in styles():
		for i in range(COUNT):
			out.append({"style": style, "index": i})
	return out
