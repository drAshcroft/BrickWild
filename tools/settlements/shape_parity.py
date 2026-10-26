"""Second half of tools/shape_parity.gd: measure each SitePlan it wrote with
survey.py's own `measure()` and compare every shared numeric metric with
VillageShape's. Agreement is 2 % relative or 0.02 absolute, whichever is
looser. Exit 1 on any disagreement or a key one side lacks.

  C:/projects/.local/Scripts/python.exe -I -X utf8 tools/settlements/shape_parity.py artifacts/shape
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

SURVEY = Path(__file__).with_name("survey.py")


def main(shape_dir: Path) -> int:
    cases = json.loads((shape_dir / "cases.json").read_text(encoding="utf-8"))
    bad = 0
    for c in cases:
        out = shape_dir / f"{c['name']}.py.json"
        cmd = [sys.executable, "-I", "-X", "utf8", str(SURVEY), "measure-plan", "--plan", c["plan"], "--out", str(out)]
        if c["terrain"]:
            cmd += ["--terrain", c["terrain"]]
        subprocess.run(cmd, check=True)
        py = json.loads(out.read_text(encoding="utf-8"))
        gd = json.loads(Path(c["gd"]).read_text(encoding="utf-8"))
        print(f"\n## {c['name']}{' on ' + Path(c['terrain']).stem if c['terrain'] else ' (flat)'}")
        print(f"| metric | GDScript | Python | delta |\n|---|---|---|---|")
        for k in sorted(set(py) | set(gd)):
            a, b = gd.get(k), py.get(k)
            if isinstance(a, bool) or isinstance(b, bool) or isinstance(a, list) or isinstance(b, list):
                ok = a == b
                d = "" if ok else "DIFFERS"
            elif a is None or b is None:
                ok = a is None and b is None
                d = "" if ok else "MISSING"
            else:
                d_abs = abs(float(a) - float(b))
                ok = d_abs <= max(0.02, 0.02 * max(abs(float(a)), abs(float(b))))
                d = f"{d_abs:.4g}" + ("" if ok else " FAIL")
            bad += 0 if ok else 1
            print(f"| {k} | {a} | {b} | {d} |")
    print(f"\n{bad} disagreement(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1] if len(sys.argv) > 1 else "artifacts/shape")))
