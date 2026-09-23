"""Pair the tracked Godot renderer's --matrix and --matrix --before-art outputs."""
from pathlib import Path
import html
import json


def main() -> None:
    root = Path(__file__).resolve().parents[1] / "artifacts" / "p1p2_house"
    before = {r["key"]: r for r in json.loads((root / "art_before/evidence.json").read_text())}
    after = json.loads((root / "art_after/evidence.json").read_text())
    rows = []
    for row in after:
        key = row["key"]
        old = before[key]
        assert all(old[k] == row[k] for k in ("seed", "width", "length", "height", "storeys"))
        rows.append(
            f"<section><h2>{html.escape(row['style'])}: {row['width']:g} × {row['length']:g} m, "
            f"{row['storeys']} storeys, seed {row['seed']}</h2><div>"
            f"<figure><img src='art_before/{key}.jpg'><figcaption>Original pitch: "
            f"rise {old['rise']:.2f} m; roof/wall {old['roof_to_wall']:.2f}</figcaption></figure>"
            f"<figure><img src='art_after/{key}.jpg'><figcaption>Tuned pitch: "
            f"rise {row['rise']:.2f} m; roof/wall {row['roof_to_wall']:.2f}; "
            f"{row['material']}</figcaption></figure></div></section>"
        )
    document = """<!doctype html><meta charset="utf-8"><title>House style comparison</title>
<style>body{max-width:1400px;margin:24px auto;background:#222822;color:#ece8d8;font:16px sans-serif}
h2{font-size:20px}section{margin:32px 0}section>div{display:grid;grid-template-columns:1fr 1fr;gap:16px}
figure{margin:0}img{width:100%}figcaption{padding:8px}</style><h1>House style comparison</h1>
<p>Five styles × four canonical sizes × one/two storeys. Each pair shares seed, dimensions,
camera policy and lighting. These compare original and tuned roof proportions; both use the
current opening-aware facade rhythm and material treatment. Ratios are visual guidance,
not structural limits.</p>""" + "".join(rows)
    (root / "comparison.html").write_text(document, encoding="utf-8")
    print(f"Wrote {len(rows)} comparisons to {root / 'comparison.html'}")


if __name__ == "__main__":
    main()
