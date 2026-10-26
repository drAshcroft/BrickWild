"""LIVE-HOUSE-STYLES: tile alias-named renders into unlabelled contact sheets.

    python tools/house_style_blind_sheets.py <render_dir>

Groups <fixture>_<alias>_<view>.jpg by (fixture, view) and writes
<render_dir>/sheets/<fixture>_<view>.jpg, each tile captioned with its alias
only. The sheets carry no style names: the key lives in a separate file.
"""
import collections
import pathlib
import re
import sys

from PIL import Image, ImageDraw

TILE = (440, 304)
COLS = 4


def main(render_dir: str) -> None:
    root = pathlib.Path(render_dir)
    groups = collections.defaultdict(list)
    for path in sorted(root.glob("*.jpg")):
        m = re.match(r"([a-z]\d+)_(h\d+)_(\w+)\.jpg$", path.name, re.I)
        if m:
            groups[(m.group(1), m.group(3))].append((m.group(2).upper(), path))
    out = root / "sheets"
    out.mkdir(exist_ok=True)
    for (fixture, view), tiles in sorted(groups.items()):
        rows = (len(tiles) + COLS - 1) // COLS
        sheet = Image.new("RGB", (TILE[0] * COLS, (TILE[1] + 22) * rows), "white")
        draw = ImageDraw.Draw(sheet)
        for i, (alias, path) in enumerate(tiles):
            x, y = (i % COLS) * TILE[0], (i // COLS) * (TILE[1] + 22)
            sheet.paste(Image.open(path).convert("RGB").resize(TILE), (x, y + 22))
            draw.text((x + 6, y + 4), alias, fill="black")
        target = out / ("%s_%s.jpg" % (fixture, view))
        sheet.save(target, quality=88)
        print(target)


if __name__ == "__main__":
    main(sys.argv[1])
