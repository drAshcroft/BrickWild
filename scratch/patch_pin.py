import io

p = 'src/house/house_furnisher.gd'
s = io.open(p, encoding='utf-8').read()

old = '''	for yaw in yaws:
		for sc in _scales(key):
			_free_at_scale(plan, room, key, yaw, sc, floor_rect, blocked, zones,
				extra, r, result, focus)
	_commit(plan, room, result["best"], blocked, zones)'''
new = '''	# A piece the plan PINS does not need the whole room searched: the pin
	# already says where it goes, and every probe a stride away from it loses
	# to the pin anyway. Searching a 12 x 30 m great hall at 12 cm for a table
	# the plan had already placed cost ten seconds a hall.
	var pin: Rect2 = _pin_box(plan, room, key)
	for yaw in yaws:
		for sc in _scales(key):
			_free_at_scale(plan, room, key, yaw, sc, floor_rect, blocked, zones,
				extra, r, result, focus, pin)
	_commit(plan, room, result["best"], blocked, zones)


## The patch of floor a pinned piece is searched in, or an empty rect when the
## plan has not pinned this one. A stride either way, so the probe can still
## slide the piece off a door swing or out of a window.
static func _pin_box(plan: HousePlan, room: int, key: String) -> Rect2:
	if plan.focus_room() != room or plan.focus.get("placed", false):
		return Rect2()
	if PropCatalog.category(key) != plan.focus_cat():
		return Rect2()
	var at: Vector2 = plan.focus_pos()
	if not at.is_finite():
		return Rect2()
	return Rect2(at - Vector2.ONE * PIN_SEARCH, Vector2.ONE * PIN_SEARCH * 2.0)'''
assert old in s
s = s.replace(old, new)

old = '''static func _free_at_scale(plan: HousePlan, room: int, key: String, yaw: float,
		sc: float, floor_rect: Rect2, blocked: Array[Rect2], zones: Array[Rect2],
		extra: Array[Rect2], r: RandomNumberGenerator, result: Dictionary,
		focus := Vector2(INF, INF)) -> void:
	var foot: Vector2 = PropCatalog.footprint_yawed(key, yaw) * sc
	var pad: float = HouseGeometry.PATH_MIN * 0.5
	var lo := Vector2(floor_rect.position.x + foot.x / 2.0 + pad,
		floor_rect.position.y + foot.y / 2.0 + pad)
	var hi := Vector2(floor_rect.end.x - foot.x / 2.0 - pad,
		floor_rect.end.y - foot.y / 2.0 - pad)
	if lo.x > hi.x or lo.y > hi.y:
		return'''
new = '''static func _free_at_scale(plan: HousePlan, room: int, key: String, yaw: float,
		sc: float, floor_rect: Rect2, blocked: Array[Rect2], zones: Array[Rect2],
		extra: Array[Rect2], r: RandomNumberGenerator, result: Dictionary,
		focus := Vector2(INF, INF), pin := Rect2()) -> void:
	var foot: Vector2 = PropCatalog.footprint_yawed(key, yaw) * sc
	var pad: float = HouseGeometry.PATH_MIN * 0.5
	var lo := Vector2(floor_rect.position.x + foot.x / 2.0 + pad,
		floor_rect.position.y + foot.y / 2.0 + pad)
	var hi := Vector2(floor_rect.end.x - foot.x / 2.0 - pad,
		floor_rect.end.y - foot.y / 2.0 - pad)
	if pin.size.x > 0.0:
		lo = lo.max(pin.position)
		hi = hi.min(pin.end)
	if lo.x > hi.x or lo.y > hi.y:
		return'''
assert old in s
s = s.replace(old, new)

old = '''const PIN_W := 4.0'''
new = '''const PIN_W := 4.0
## How far either side of the pin a pinned piece is searched for.
const PIN_SEARCH := 0.9'''
assert old in s
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
