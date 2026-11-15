"""Generated villages (tools/probe_village_layout.gd JSON) against the real
layout statistics (layout_stats.py JSON): building size distribution, wall
to wall gaps, touching share, stragglers and the town wall's distance from
the houses. One line per plan per measure, with the real culture band.

    python -I tools/settlements/layout_compare.py artifacts/vreal_layout/base.json \
        [--real tests/fixtures/settlements/layout_stats.json]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from emit_layout_table import build_table  # noqa: E402


def pct(a, q):
    a = np.asarray(a, float)
    return float(np.percentile(a, q)) if a.size else float("nan")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("probe")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--real", default="", help="ignored; the historic table is built from --repo")
    a = ap.parse_args()
    stats, _historic, pool, table = build_table(Path(a.repo))
    real = {"pooled": stats["pooled"]}
    plans = json.loads(Path(a.probe).read_text(encoding="utf-8"))["plans"]
    for p in plans:
        bs = p["buildings"]
        homes = [b for b in bs if b["kind"] in ("house", "shop")]
        area = [b["fp_area"] for b in homes]
        gaps = [b["gap_m"] for b in bs]
        floor = [b["fp_area"] * max(1, b["storeys"]) for b in homes if b["kind"] == "house"]
        c = p["culture"]
        t = table.get(c, pool)
        rb = {"p10": t["area_p10"], "p50": t["area_p50"], "p90": t["area_p90"]}
        rg = {"p25": float("nan"), "p50": t["gap_p50"], "p90": t["gap_p90"]}
        touch = round(t["touching"], 2)
        var = f" [{p['variant']}]" if p.get("variant") else ""
        print(f"== stop {p['stop']} seed {p['seed']}{var} {c}/{p['purpose']} pop {p['population']} "
              f"hh {p['households']} wealth {p['wealth']} form {p['form']} site {p['site'][2]:.0f}x{p['site'][3]:.0f} m")
        print(f"   footprint m2   gen p10/50/90 {pct(area,10):6.0f} {pct(area,50):6.0f} {pct(area,90):6.0f}"
              f"   real {rb.get('p10',0):6.0f} {rb.get('p50',0):6.0f} {rb.get('p90',0):6.0f}"
              f"   log-sd gen {np.std(np.log(area)):.2f} real {t['log_sd']:.2f}")
        print(f"   floor area m2  gen p50/max {pct(floor,50):6.0f} {max(floor) if floor else 0:6.0f}"
              f"   storeys {sorted(set(b['storeys'] for b in homes))}  heights p50/max "
              f"{pct([b['height'] for b in homes],50):.1f} {max(b['height'] for b in homes):.1f} m")
        print(f"   gap wall-wall  gen p25/50/90 {pct(gaps,25):6.1f} {pct(gaps,50):6.1f} {pct(gaps,90):6.1f}"
              f"   real {rg.get('p25',0):6.1f} {rg.get('p50',0):6.1f} {rg.get('p90',0):6.1f}"
              f"   touching gen {np.mean(np.array(gaps) < 0.5):.2f} real {touch}")
        far = sorted(bs, key=lambda b: -b["gap_m"])[:3]
        # real: the loneliest building of a historic body, median 23.5 m, p90 33 m
        print(f"   loneliest gap gen {far[0]['gap_m']:.1f} m   real max median 23.5, p90 33.0")
        print("   loneliest     " + "; ".join(f"{b['kind']}/{b['style']}/{b['purpose'] or b['class']} "
                                             f"gap {b['gap_m']:.0f} m, {b['to_common']:.0f} m from common" for b in far))
        hs = [b for b in bs if b["kind"] == "house" and b["class"] != "farm"]
        if len(hs) >= 5:
            ra = np.argsort(np.argsort([b["fp_area"] for b in hs]))
            rd = np.argsort(np.argsort([b["to_common"] for b in hs]))
            rho = float(np.corrcoef(ra, rd)[0, 1])
            print(f"   gradient       spearman size~distance {rho:+.2f} over {len(hs)} houses (VillagePlaceCheck wants <= -0.3 at 8+)")
        import shapely
        hull = shapely.MultiPoint([tuple(b["c"]) for b in bs]).convex_hull.area
        # real: historic bodies of <= 80 buildings, hull of the centroids per main building
        print(f"   body hull      {hull / 1e4:.2f} ha, {hull / max(len(bs), 1):.0f} m2 per building"
              f"   real p25/50/75 419 459 639 m2 per main building")
        print(f"   to common      p50/max {pct([b['to_common'] for b in bs],50):.0f} {max(b['to_common'] for b in bs):.0f} m")
        if p.get("wall"):
            w = p["wall"]["to_building_m"]
            rw = real["pooled"].get("wall_to_building_m", {})
            print(f"   wall->building gen p25/50/90 {pct(w,25):6.1f} {pct(w,50):6.1f} {pct(w,90):6.1f}"
                  f"   real {rw.get('p25',0):6.1f} {rw.get('p50',0):6.1f} {rw.get('p90',0):6.1f}"
                  f"   wall {p['wall']['perimeter_m']:.0f} m round {p['wall']['area_m2']/1e4:.2f} ha")
        mix = {}
        for b in bs:
            k = f"{b['kind']}:{b['style']}" + (f"({b['purpose']})" if b["purpose"] and b["purpose"] != "none" else "")
            mix[k] = mix.get(k, 0) + 1
        print("   mix            " + ", ".join(f"{k} x{v}" for k, v in sorted(mix.items(), key=lambda kv: -kv[1])))
        sh = p.get("shape", {})
        print(f"   shape          clark_evans {sh.get('clark_evans')}  nn_median {sh.get('nn_median_m')}  "
              f"coverage {sh.get('coverage')}  setback {sh.get('setback_median_m')}")
        if "qa_failures" in p:
            fails = p["qa_failures"]
            print(f"   VillageQA      {len(fails)} failure(s)" + "".join(f"\n      - {f}" for f in fails[:8]))


if __name__ == "__main__":
    main()
