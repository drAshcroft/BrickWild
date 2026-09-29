class_name GeneratorRandom
extends RefCounted
## Sampling shared by family generators. Each call consumes one RNG draw.

static func chance(rng: RandomNumberGenerator, probability) -> bool:
	return rng.randf() < float(probability)


static func pick(rng: RandomNumberGenerator, choices: Array):
	return choices[rng.randi_range(0, choices.size() - 1)]
