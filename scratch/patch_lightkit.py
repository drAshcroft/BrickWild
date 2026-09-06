import io
p = "core/light_kit.gd"
s = io.open(p, encoding="utf-8").read()
old = '\t"brazier": {"reach": 8.0, "energy": 2.2},\n'
new = ('\t"brazier": {"reach": 8.0, "energy": 2.2},\n'
       '\t# A cauldron IS the brazier in this pack: the church and the castle stand\n'
       '\t# them on the wall walk and at the chancel step, and a fire in a bowl\n'
       '\t# throws a fire in a bowl worth of light wherever it is standing.\n'
       '\t"hearth": {"reach": 8.0, "energy": 2.2},\n')
assert s.count(old) == 1
io.open(p, "w", encoding="utf-8", newline="\n").write(s.replace(old, new))
print("patched")
