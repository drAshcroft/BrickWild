# VIS-012 church opening finish

`before` frames come from VIS-007 commit `254cf66`, rendered through its
`-- vis005` mode. `after` frames use `-- vis012` with the same landmark seeds,
camera focus, radius, front/raking light and assembled church scene. See
`manifest.json` for the detail shot definitions.

| Subject | Read in the accepted pair | Remaining limit |
|---|---|---|
| Notre-Dame clerestory | The previous dark rectangle has stone pointed-head spandrels, a leaded glass pattern, mullion and transom. The pane sits behind the wall reveal. Its blue and muted red cells survive in the whole-building portrait without losing the bay rhythm. | The head is a straight two-sided point; the glass is a procedural colour pattern rather than individual leaded pieces. |
| Notre-Dame west portal | Two open throats now have jambs, lintels and pointed stone hoods at the outer tower face. Raking light still shows the tunnel depth. | The entrance is deliberately open so the route remains clear; no door leaves are fitted. |
| Durham west portal | The paired open entrances have simple stone jambs and lintels on the exterior tower face. | The masonry treatment is schematic at this scale. |

The panes use a vertex marker on the existing opening surface. The church
assembler gives that marked region its own restrained glass shader; the other
church openings remain dark, and the stone, trim, roof and opening surface
slots retain their existing order.
