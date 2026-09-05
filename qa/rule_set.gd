class_name RuleSet
extends RefCounted
## Runs a check's rules in order, letting a family REPLACE one (INT-020).
##
## A hammam is a correct building that breaks the daylight rule, and a stupa
## is a correct building that breaks the walking rule. The wrong answer is to
## switch the rule off, because a check with a rule switched off is a check
## that has stopped measuring something. The right one is to replace it with
## the rule the family actually obeys -- `daylight` becomes `hammam.blind`,
## and the report says so. Every check exposes its `RULES` and takes an
## `overrides` dictionary mapping a rule name to its replacement; a rule
## named with no replacement is an error, not a silence.
##
## A replacement is a Callable taking the same arguments the check's own
## rules would be measured against (the plan; or the spec and the builder)
## and returning either an Array of failure strings or a Dictionary with
## "failures" and "warnings". It may also be a Dictionary {"name": String,
## "call": Callable} so the report can name it.


## Run every rule of `check`. `methods` maps a rule name to the method on
## `check` that measures it (missing entries fall back to "_check_" + rule);
## `method_args` are handed to those methods and `override_args` to a
## replacement. Returns {rule: replacement_name} for the rules replaced.
static func run(check: Object, rules: Array, methods: Dictionary, overrides: Dictionary,
		method_args: Array, override_args: Array, failures: Array,
		warnings: Array) -> Dictionary:
	var replaced := {}
	for rule in rules:
		var key := String(rule)
		if overrides.has(StringName(key)) or overrides.has(key):
			var repl = overrides.get(StringName(key), overrides.get(key))
			var name := ""
			var fn := Callable()
			if repl is Callable:
				fn = repl
				name = String(fn.get_method())
			elif repl is Dictionary and repl.get("call") is Callable:
				fn = repl["call"]
				name = String(repl.get("name", fn.get_method()))
			if not fn.is_valid():
				var msg := "rules: %s was switched off with no replacement" % key
				push_error(msg)
				failures.append(msg)
				continue
			if name == "" or name.begins_with("<"):
				name = "replacement"
			replaced[key] = name
			var result = fn.callv(override_args)
			var prefix := "%s -> %s: " % [key, name]
			if result is Dictionary:
				for f in result.get("failures", []):
					failures.append(prefix + _strip(str(f), name))
				for w in result.get("warnings", []):
					warnings.append(prefix + _strip(str(w), name))
			elif result is Array:
				for f2 in result:
					failures.append(prefix + _strip(str(f2), name))
			continue
		var method: String = String(methods.get(StringName(key), "_check_" + key))
		check.callv(method, method_args)
	return replaced


## A replacement that already prefixes its messages with its own name is not
## prefixed with it twice.
static func _strip(msg: String, name: String) -> String:
	if msg.begins_with(name + ": "):
		return msg.substr(name.length() + 2)
	return msg


## The override keys that belong to none of the rule lists given: a family
## that names a rule no check has is a family with a typo.
static func unknown(overrides: Dictionary, rule_lists: Array) -> Array[String]:
	var out: Array[String] = []
	for key in overrides:
		var found := false
		for rules in rule_lists:
			for r in rules:
				if String(r) == String(key):
					found = true
		if not found:
			out.append(String(key))
	return out
