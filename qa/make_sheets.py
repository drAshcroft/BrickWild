"""Build labelled contact sheets from BigGlade render output, for visual QA.

Each sheet is a fixed grid so several buildings can be judged side by side
rather than one at a time. Labels are drawn under the tile, so a sheet can be
read without cross-referencing the file list.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RENDERS = Path(__file__).resolve().parents[1] / "artifacts" / "renders"

SHEETS = {
    "church": [
        "notre_dame.jpg", "chartres.jpg", "durham.jpg", "salisbury.jpg",
        "cologne.jpg", "st_basil.jpg", "hagia_sophia.jpg", "florence_duomo.jpg",
    ],
    "church_detail": [
        "detail_crossing.jpg", "detail_flyers.jpg", "detail_dome.jpg",
        "detail_lantern.jpg", "detail_onion.jpg", "detail_chapels.jpg",
    ],
    "castle": [
        "castle_bodiam.jpg", "castle_stokesay.jpg", "castle_krak.jpg",
        "castle_chambord.jpg", "castle_himeji.jpg",
        "castle_neuschwanstein.jpg", "castle_caernarfon.jpg",
        "castle_longhouse.jpg", "castle_dark.jpg", "castle_wizard.jpg",
    ],
    "house": [
        "house_exterior.jpg", "house_inn.jpg", "house_smithy.jpg",
        "house_farmhouse.jpg", "house_family_cottage.jpg",
        "house_alchemist.jpg", "house_one_room_cottage.jpg", "house_room.jpg",
    ],
    "temple": [
        "temple_bloodpit_basilica.jpg", "temple_ossuary_basilica.jpg",
        "temple_coiled_rotunda.jpg", "temple_ashen_ziggurat.jpg",
        "temple_exterior.jpg", "temple_plan.jpg",
    ],
    "sheet": [
        "sheet_notre_dame.jpg", "sheet_chartres.jpg",
        "sheet_hagia_sophia.jpg", "sheet_st_basil.jpg",
    ],
}

COLS = 3
TILE = 620
LABEL_H = 26
PAD = 10


def font(size: int) -> ImageDraw.ImageFont.FreeTypeFont:
    for name in ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def build(name: str, names: list[str]) -> Path:
    rows = (len(names) + COLS - 1) // COLS
    w = COLS * TILE + (COLS + 1) * PAD
    h = rows * (TILE + LABEL_H) + (rows + 1) * PAD
    sheet = Image.new("RGB", (w, h), (24, 24, 26))
    draw = ImageDraw.Draw(sheet)
    f = font(17)

    for i, filename in enumerate(names):
        r, c = divmod(i, COLS)
        x = PAD + c * (TILE + PAD)
        y = PAD + r * (TILE + LABEL_H + PAD)
        src = RENDERS / filename
        if not src.exists():
            draw.text((x + 6, y + 6), f"MISSING {filename}", font=f, fill=(255, 90, 90))
            continue
        im = Image.open(src).convert("RGB")
        im.thumbnail((TILE, TILE), Image.LANCZOS)
        ox = x + (TILE - im.width) // 2
        oy = y + (TILE - im.height) // 2
        sheet.paste(im, (ox, oy))
        draw.text((x + 2, y + TILE + 4), filename, font=f, fill=(225, 225, 225))

    out = RENDERS / f"_sheet_{name}.jpg"
    sheet.save(out, quality=92)
    return out


if __name__ == "__main__":
    wanted = sys.argv[1:] or list(SHEETS)
    for key in wanted:
        print(build(key, SHEETS[key]))
