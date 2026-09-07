import io

p = 'qa/house_furnish_check.gd'
s = io.open(p, encoding='utf-8').read()

old = '''		if int(p["host"]) >= 0 or String(p.get("row", "")) != "":
			continue
		var off: float = (Rect2(p["rect"]).get_center() - mid).dot(dir)'''
new = '''		if int(p["host"]) >= 0 or String(p.get("row", "")) != "":
			continue
		# A table the PLAN pinned is where the plan put it. A great hall high
		# table stands on the dais at the upper end and the fire is on a side
		# wall behind the trestles: measuring that table against the fire is
		# measuring the plan against a rule the plan already answered (INT-002).
		if plan.focus_cat() == "table" and plan.focus_room() == room \\
				and Rect2(p["rect"]).get_center().distance_to(plan.focus_pos()) \\
					< FOCUS_TOL:
			continue
		var off: float = (Rect2(p["rect"]).get_center() - mid).dot(dir)'''
assert old in s
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
