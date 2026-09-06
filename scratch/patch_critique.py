import io
p = "docs/CRITIQUE_LAYOUTS_AND_CASTLES.md"
s = io.open(p, encoding="utf-8").read()

old = """- The bailey is empty apart from keep, hall and chapel. A castle was a
  village: stables, kitchen, smithy, well, granary. These are *houses*, and
  section 3 says how to put them there."""
new = """- The bailey is empty apart from keep, hall and chapel. A castle was a
  village: stables, kitchen, smithy, well, granary. These are *houses*, and
  section 3 says how to put them there.

  *Partly done.* `CastleFurnisher` now deals a working yard round the inside
  of the curtain -- a cart, an anvil and its fire, a training dummy, a weapon
  stand, barrels, crates, sacks and rope -- and dresses the hall, chapel and
  keep with props. That is the smithy as a **prop group**, not as a building
  with an inside; the ask above, bailey buildings as `HousePlan`s, still
  stands."""
assert s.count(old) == 1
s = s.replace(old, new)

old2 = """4. **Lights that light.** `KNOWN_ISSUES` 0d: props tagged `LIGHT` place no
   `OmniLight3D`. `TempleAssembler` already does it; lift it into the shared
   assembler. Until then every interior render with the roof on is black,
   which hides most of the feng shui work from the person judging it."""
new2 = """4. **Lights that light.** `KNOWN_ISSUES` 0d: props tagged `LIGHT` place no
   `OmniLight3D`. `TempleAssembler` already does it; lift it into the shared
   assembler. Until then every interior render with the roof on is black,
   which hides most of the feng shui work from the person judging it.

   *Done.* `LightKit` does it for the houses, shops and hotel, and
   `ShellAssembler` does it for the churches and castles: a light per flame,
   at the prop's measured `light_offset`, from the one per-category table."""
assert s.count(old2) == 1
io.open(p, "w", encoding="utf-8", newline="\n").write(s.replace(old2, new2))
print("patched")
