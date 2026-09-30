"""Draw the fixed Crusader keep door lines and stair feet from probe logs.

Run after tools/probe_cas_reg_005.gd wrote plan_before.log and plan_after.log.
No scene or mesh data is fabricated here; every rectangle is parsed from the
planner's own printed records. The floor outline shown is its bounding rect.
"""

from __future__ import annotations

import re
from pathlib import Path
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artifacts" / "cas_reg_005"
NUMBER = r"-?\d+(?:\.\d+)?"
RECT = re.compile(
    rf"\[P: \(({NUMBER}), ({NUMBER})\), S: \(({NUMBER}), ({NUMBER})\)\]"
)


def rects(line: str):
    return [tuple(float(x) for x in m.groups()) for m in RECT.finditer(line)]


def parse(path: Path):
    out = {}
    current = None
    raw = path.read_bytes()
    contents = raw.decode("utf-16") if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else raw.decode("utf-8")
    for line in contents.splitlines():
        if line.startswith("CASE "):
            seed = int(re.search(r"seed=(\d+)", line).group(1))
            current = out[seed] = {"stairs": []}
        elif line.startswith("DOOR "):
            current["line"], current["room"] = rects(line)
            pos = re.search(r"pos=\(([^,]+), ([^)]+)\)", line)
            current["door"] = (float(pos.group(1)), float(pos.group(2)))
            current["entry"] = int(re.search(r"room=(\d+)", line).group(1))
        elif line.startswith("STAIR "):
            current["stairs"].append(
                {
                    "index": int(re.search(r"index=(\d+)", line).group(1)),
                    "a": int(re.search(r" a=(\d+)", line).group(1)),
                    "rect": rects(line)[0],
                }
            )
    return out


def overlap(a, b):
    return max(0.0, min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])), max(
        0.0, min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    )


def panel(case, x0, y0, title, repaired):
    room = case["room"]
    w, h = 730, 390
    pad = 2.0
    extent = max(room[2], room[3]) + 2 * pad
    scale = min((w - 85) / extent, (h - 90) / extent)
    cx, cy = room[0] + room[2] / 2, room[1] + room[3] / 2

    def point(x, y):
        return x0 + w / 2 + (x - cx) * scale, y0 + h / 2 - (y - cy) * scale

    def box(rect, fill, stroke, opacity=1, dash=""):
        x, y, rw, rh = rect
        px, py = point(x, y + rh)
        return (
            f'<rect x="{px:.1f}" y="{py:.1f}" width="{rw * scale:.1f}" '
            f'height="{rh * scale:.1f}" fill="{fill}" fill-opacity="{opacity}" '
            f'stroke="{stroke}" stroke-width="2" {dash}/>'
        )

    pieces = [f'<g><rect x="{x0}" y="{y0}" width="{w}" height="{h}" '
              'rx="12" fill="#fcfbf6" stroke="#c6c2b5"/>']
    pieces.append(f'<text x="{x0 + 24}" y="{y0 + 35}" class="panel">{escape(title)}</text>')
    pieces.append(box(room, "none", "#555b66", dash='stroke-dasharray="7 5"'))
    pieces.append(box(case["line"], "#5598cf", "#3a73a6", 0.24))
    for stair in case["stairs"]:
        if stair["a"] == case["entry"]:
            continue
        pieces.append(box(stair["rect"], "#b9b5a9", "#797568", 0.38))
    foot = next(s["rect"] for s in case["stairs"] if s["a"] == case["entry"])
    pieces.append(box(foot, "#63a86b" if repaired else "#cc6d5a",
                      "#316e3a" if repaired else "#a34230", 0.85))
    dx, dy = point(*case["door"])
    pieces.append(f'<circle cx="{dx:.1f}" cy="{dy:.1f}" r="6" fill="#1a2631"/>')
    hit = overlap(case["line"], foot)
    pieces.append(
        f'<text x="{x0 + 24}" y="{y0 + h - 23}" class="note">'
        f'Front-door line / stair overlap: {hit[0]:.3f} × {hit[1]:.3f} m</text>'
    )
    pieces.append('</g>')
    return "\n".join(pieces)


def main():
    before = parse(ART / "plan_before.log")
    after = parse(ART / "plan_after.log")
    chunks = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1550" height="905" '
        'viewBox="0 0 1550 905">',
        '<style>text{font-family:Arial,sans-serif;fill:#20252a}.title{font-size:23px;'
        'font-weight:700}.panel{font-size:19px;font-weight:700}.note{font-size:16px}</style>',
        '<rect width="1550" height="905" fill="#eeeae1"/>',
        '<text x="25" y="36" class="title">Crusader keep entrance route: fixed plan comparison</text>',
        '<text x="25" y="60" class="note">Blue: front-door line. Red/green: '
        'stair from entrance storey. Dashed: room floor bounds. Dot: raised door.</text>',
    ]
    for row, seed in enumerate((9250, 9118)):
        y = 76 + row * 410
        chunks.append(panel(before[seed], 25, y, f"Seed {seed} before", False))
        chunks.append(panel(after[seed], 795, y, f"Seed {seed} after", True))
    chunks.append('</svg>')
    target = ART / "plan_comparison.svg"
    target.write_text("\n".join(chunks), encoding="utf-8")
    print(target)


if __name__ == "__main__":
    main()
