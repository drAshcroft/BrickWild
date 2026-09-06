# Nature Kit

Quaternius "Nature Kit" (see `License.txt`), copied from
`C:/Projects/itch_assets/quaternius/Nature Kit/glTF`.

36 plants — birches, maples, ten dead trees, the bushes and their flowering
variants, the flower clumps and three grasses. Every `.gltf` is prefixed
`Nature_` on disk because the Stylized Nature MegaKit next door ships a
`DeadTree_1` too and a catalogue key has to be globally unique; the `.bin`
buffers keep their own names, which is what the glTF files refer to.

Measured by `tools/build_prop_catalog.gd` like every other pack, and — because
this is a plant pack (`PropCatalog.PACKS`) — with a `canopy` and a `trunk`
radius as well as a bounding box. A tree's box is mostly air: the village
plants by the trunk and keeps roofs clear by the canopy (VILLAGES §8).
