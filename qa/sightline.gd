class_name Sightline
extends RefCounted
## Can you see B from A? (INT-020)
##
## One segment-against-boxes test, kept here so every family asks it the same
## way: TempleRiteCheck casts it from the gate to the idol and wants it CLEAR;
## a courtyard house's blind entry casts it from the street door to the court
## and wants it BLOCKED; the house `focus` rule casts it from the door to the
## hearth. The slab method, which is the shortest honest way to answer it.


## Does the segment from `from` to `to` pass through `box`?
static func hits(from: Vector3, to: Vector3, box: AABB) -> bool:
	var d: Vector3 = to - from
	var t0 := 0.0
	var t1 := 1.0
	for axis in range(3):
		var lo: float = box.position[axis]
		var hi: float = lo + box.size[axis]
		if absf(d[axis]) < 0.00001:
			if from[axis] < lo or from[axis] > hi:
				return false
			continue
		var ta: float = (lo - from[axis]) / d[axis]
		var tb: float = (hi - from[axis]) / d[axis]
		if ta > tb:
			var swap: float = ta
			ta = tb
			tb = swap
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true


## The indices of the boxes the segment passes through, in the order given.
static func blockers(from: Vector3, to: Vector3, boxes: Array) -> Array[int]:
	var out: Array[int] = []
	for i in range(boxes.size()):
		if hits(from, to, boxes[i]):
			out.append(i)
	return out


## Nothing in `boxes` stands between the two points.
static func clear(from: Vector3, to: Vector3, boxes: Array) -> bool:
	return blockers(from, to, boxes).is_empty()


## Something in `boxes` does.
static func blocked(from: Vector3, to: Vector3, boxes: Array) -> bool:
	return not clear(from, to, boxes)
