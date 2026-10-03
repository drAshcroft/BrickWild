# Visual building audit status

This is a partial visual review of fresh, assembled Godot renders. It records what was inspected; it does not establish completion of the building-family audit.

Run one family without `--headless`:

```
godot --path . --script res://tools/render_building_audit.gd -- --family:shop
```

The helper saves diagnostic views even when QA fails, records its result in
`audit.json`, and exits nonzero for generation, capture, QA or manifest-write
failures. Its summary reports fixture and image counts separately. The base
render stage initializer is guarded so this command does not launch the full
reference batch. The final shop validation on 3 October 2026 exited 0 in
39.38 seconds, reporting one fixture, three captured images and passing QA.

## Verified captures

- **House:** `artifacts/renders/building_audit/house/audit.json` and its six JPGs. The cottage and rich merchant fixtures were generated and assembled. Structured BrickWild and rich-house QA passed. The cottage has a coherent, readable exterior. From the lane, its entry sightline runs across the dining table and through another opening, giving little privacy. The rich merchant has a recognizable silhouette, but repeated vertical timbers crowd the floor hierarchy and its entry looks directly onto the dining table. The three-storey cutaway reveals the upper floor well; the lower floors remain obscured and need a better interior capture before judging them.
- **Shop:** `artifacts/renders/building_audit/shop/audit.json` and three JPGs for the `blacksmith_longhall` fixture (seed 353). Native Godot exit was 0; the renderer was non-headless. BrickWild QA passed with no diagnostics; all six rooms and three use zones were reached, with 0 stranded area. The exterior is clean and legible, though the half-timber longhall reads more as a dwelling than a blacksmith shop: it lacks a visible trade sign or obvious customer-facing display, and its large chimney dominates the roof. The cutaway shows the full one-storey plan; a central chimney mass occupies a prominent interior junction, routing movement around it. The entry view places the anvil/work area directly on the threshold sightline, with little visual buffer for customers. These are presentation and comfort observations; navigation QA passes. No clear mesh holes or intersections appeared in the inspected views.

Entry comfort is assessed through practical criteria: sightlines, privacy, daylight, and clear movement.

## Pending

Fresh visual captures and review are still needed for hotel, church, temple, world courtyard/palazzo, and village. Castle review is being tracked separately. The obscured lower levels of the rich merchant also remain unresolved visually. No broad audit completion is claimed.
