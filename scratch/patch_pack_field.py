import io, re
p = "src/house/prop_catalog.gd"
s = io.open(p, encoding="utf-8").read()
s, n = re.subn(r'(\t"Dungeon_[A-Za-z0-9_]+": \{)("cat")', r'\1"pack": "dungeon", \2', s)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("tagged %d dungeon props with their pack" % n)
