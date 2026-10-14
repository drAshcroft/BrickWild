"""One 2x2 contact sheet per sacred matrix id: front, side, entry, rear.
Usage: python -I tools/sacred_contact_sheets.py <renders_dir> <sheets_dir>
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

renders, sheets = sys.argv[1], sys.argv[2]
os.makedirs(sheets, exist_ok=True)
slugs = sorted({os.path.basename(f).split("__")[0]
                for f in glob.glob(os.path.join(renders, "*__front.jpg"))})
for s in slugs:
    im = Image.new("RGB", (1280, 880), "white")
    for i, v in enumerate(["front", "side", "entry", "rear"]):
        a = Image.open(os.path.join(renders, "%s__%s.jpg" % (s, v))).convert("RGB").resize((640, 430))
        ImageDraw.Draw(a).text((6, 4), v, fill=(255, 255, 0))
        im.paste(a, ((i % 2) * 640, (i // 2) * 440))
    ImageDraw.Draw(im).text((6, 864), s, fill="black")
    im.save(os.path.join(sheets, s + ".jpg"), quality=88)
print(len(slugs))
