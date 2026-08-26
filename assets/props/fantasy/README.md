# Fantasy Props MegaKit

Quaternius "Fantasy Props MegaKit" (Standard licence, see `License_Standard.txt`),
copied from `C:/Projects/itch_assets/quaternius/Fantasy Props MegaKit[Standard]/Exports/glTF`.

94 props, three shared trim textures (furniture / metal / cloth). Every model is
in metres with its origin on the floor at its own centre, which is what
`PropCatalog` assumes -- `tools/build_prop_catalog.gd` measures each one and
writes `catalog.json`, and the house suite checks the measurements still match
the meshes.
