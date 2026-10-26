"""LIVE-HOUSE-STYLES: write a frozen, alias-shuffled render case list.

    python tools/house_style_blind_cases.py <cases.json> <key.json>

Every HouseSpec.STYLES row at three fixed fixtures (default size seeds 8102
and 1; large two-storey seed 8102), each under a shuffled alias so the image
file names say nothing about the style. The alias->style key goes to a
separate file that the reviewer opens only after writing down verdicts.
Render the cases (NOT headless) with

    godot --path . --script res://tools/render_personality_baseline.gd -- \
        cases=<cases.json> out=res://artifacts/hstyles/blind
"""
import json
import random
import sys

STYLES = ["cottage", "farmhouse", "townhouse", "longhall", "witch_hut", "rich",
          "mediterranean", "asian", "african", "thatch_cottage", "mud_hut", "pueblo"]
FIXTURES = [
    ("d", 8102, {}),
    ("d", 1, {}),
    ("l", 8102, {"width": 14.5, "length": 19.0, "height": 3.1, "storeys": 2}),
]


def main(cases_path: str, key_path: str, shuffle_seed: int = 20261021) -> None:
    rng = random.Random(shuffle_seed)
    aliases = ["H%02d" % n for n in rng.sample(range(10, 99), len(STYLES))]
    key = dict(zip(aliases, STYLES))
    cases = []
    for size, seed, override in FIXTURES:
        for alias, style in key.items():
            request = {"schema": "brickwild.request", "schema_version": 1, "kind": "house",
                       "seed": str(seed), "style": style, "purpose": "none"}
            request.update(override)
            cases.append({"key": "%s%d_%s" % (size, seed, alias), "request": request})
    cases.sort(key=lambda c: c["key"])
    with open(cases_path, "w") as f:
        json.dump({"cases": cases}, f, indent=1)
    with open(key_path, "w") as f:
        json.dump(key, f, indent=1)
    print(len(cases), "cases")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 20261021)
