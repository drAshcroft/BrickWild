import io
p = "README.md"
s = io.open(p, encoding="utf-8").read()

pairs = [
("""    church_builder.gd     spec -> ArrayMesh (stone / trim / roof / openings)
""",
 """    church_builder.gd     spec -> ArrayMesh (stone / trim / roof / openings)
    church_furnisher.gd   spec -> prop placements: pews, altar, banners, fire
    church_assembler.gd   the only file that loads a model
"""),
("""  mesh_kit.gd           mesh primitives shared by every builder: boxes, slabs,
                        gable/hip roofs, tapers, surfaces of revolution, arches
""",
 """  mesh_kit.gd           mesh primitives shared by every builder: boxes, slabs,
                        gable/hip roofs, tapers, surfaces of revolution, arches
  mass_builder.gd       the three logs every check reads: parts, masses, props
  shell_assembler.gd    a built shell + its dressing -> a scene, with lights
"""),
("""  massing_check.gd        no gaps, no overlap, size match
""",
 """  massing_check.gd        no gaps, no overlap, size match
  dressing_check.gd       the props are known, inside, clear of each other,
                          and not blocking the aisle or the gate
"""),
("| `assets` | measured prop catalogue still matches imported models |",
 "| `assets` | measured prop catalogue still matches imported models |\n"
 "| `dressing` | churches and castles are furnished, and you can still walk through them |"),
("""| Narthex, pendentives, transept crossing, apse, rose windows | throughout |
""",
 """| Narthex, pendentives, transept crossing, apse, rose windows | throughout |

A built church is also **furnished**. `ChurchFurnisher` puts an altar at the
east end with a chalice, candles and standing candelabra; pews in two blocks
either side of a processional aisle, pitched down the nave and dropped where
they would stand in the crossing; a lectern and a brazier at the chancel step;
torches and banners along the nave walls at the same bay as the windows;
lamps hung over the aisle; a font inside the west door and a coil of bell rope
in the tower. Aisles get their own light and the parish chest.

None of it is placed by a coordinate. The pews are pitched, the sconces are
spaced by the bay, and every piece is sized against the nave it is going in --
so a chapel and a cathedral are furnished by the same rules and neither has a
number written down for it.
"""),
]
for old, new in pairs:
    assert s.count(old) == 1, old[:60]
    s = s.replace(old, new)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("patched")
