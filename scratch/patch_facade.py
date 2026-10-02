import io
p = 'src/api/brick_wild.gd'
s = io.open(p, encoding='utf-8').read()

head_start = s.index('const API_VERSION := 1')
head_end = s.index('static func kinds()')
new_head = '''## The public API version. BuildingLibrary owns the tables this facade
## publishes and validates against; the version is re-exported here because
## it is part of what every descriptor and placement carries.
const API_VERSION := BuildingLibrary.API_VERSION


'''
s = s[:head_start] + new_head + s[head_end:]

old = '''static func kinds() -> Array[StringName]:
	return _KINDS.duplicate()
'''
new = '''static func kinds() -> Array[StringName]:
	return BuildingLibrary.kinds()
'''
assert s.count(old) == 1
s = s.replace(old, new)

# describe_kind delegates
start = s.index("## Public controls and supported envelopes for one family.")
end = s.index("## Generate the family-specific representation without emitting an ArrayMesh.")
new_describe = '''## Public controls and supported envelopes for one family: its label, its
## size envelope, and -- the option-discovery contract -- `styles` and
## `purposes`, each an ordered array of {"id", "label"}, plus the words this
## family calls them (`style_label`, `purpose_label`). A caller can fill a
## menu and build a valid request from this alone, without importing a single
## family header.
##
## The returned data is detached from the library's tables, so consumers
## cannot mutate global state by editing what they were handed.
static func describe_kind(kind: StringName) -> Dictionary:
	return BuildingLibrary.describe(kind)


## A valid request for a kind, filled from that kind's own default envelope.
static func default_request(kind: StringName, p_seed: int = 0) -> BuildingRequest:
	return BuildingLibrary.defaults(kind, p_seed)


## The word for one option id, for a caller that has to print it.
static func option_label(kind: StringName, field: StringName,
		id: StringName) -> String:
	return BuildingLibrary.option_label(kind, field, id)


'''
s = s[:start] + new_describe + s[end:]

# _validate delegates
start = s.index("static func _validate(out: GeneratedBuilding) -> void:")
end = s.index("static func _add_error(out: GeneratedBuilding, code: StringName,")
new_validate = '''## Every request is refused on its own terms before a family generator sees
## it, against the same rows describe_kind() publishes (API-002).
static func _validate(out: GeneratedBuilding) -> void:
	out.errors.append_array(BuildingLibrary.validate(out.request))


'''
s = s[:start] + new_validate + s[end:]
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
