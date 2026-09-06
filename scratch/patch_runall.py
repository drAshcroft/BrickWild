import io
p = "tests/run_all.gd"
s = io.open(p, encoding="utf-8").read()

pairs = [
("##  12 cvoxelqa   - the same, for the castles (slow)\n",
 "##  12 cvoxelqa   - the same, for the castles (slow)\n"
 "## 12a dressing   - what is in the churches and castles, and can you walk past it\n"),
('"castle", "cnormals", "cmassing", "clandmark", "voxelqa", "cvoxelqa",',
 '"castle", "cnormals", "cmassing", "clandmark", "voxelqa", "cvoxelqa", "dressing",'),
('\t\t"cvoxelqa":\n\t\t\treturn CastleQASuite.run()\n',
 '\t\t"cvoxelqa":\n\t\t\treturn CastleQASuite.run()\n\t\t"dressing":\n\t\t\treturn DressingSuite.run()\n'),
]
for old, new in pairs:
    assert s.count(old) == 1, old[:60]
    s = s.replace(old, new)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
