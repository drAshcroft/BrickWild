# Compact villages through the public API

`BuildingRequest.compact_village()` selects the native compact-display mode for
an external close settlement display:

```gdscript
var village := BuildingRequest.compact_village(8102, 40)
var generated := BrickWild.generate(village)
```

The factory accepts seed, population, culture, purpose and wealth. Building
dimensions remain in metres. Compact display requires `water` and `enclosure`
to remain `&"none"`; `BrickWild.describe_kind(&"village")["compact_display"]`
publishes that constraint. An enabled flag is included in request JSON; the
false default is omitted, so older requests retain their original JSON shape.
Reading older request documents that omit it also yields `false`.
