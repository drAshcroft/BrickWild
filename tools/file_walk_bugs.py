"""File human walk-QA pins as waterfree todos, one todo per pin.

    python -I tools/file_walk_bugs.py --dry-run
    python -I tools/file_walk_bugs.py --review 1a113f97860b8a160d1
    python -I tools/file_walk_bugs.py --since 2026-10-26T00:00:00Z

Reads visualqa/walk_pins.jsonl (one review per line, written by the walk rig,
visualqa/walk/walk_qa.gd). Every pin becomes a todo with key
WALK-<first 8 of review_id>-<n>, phase `bug-walk`, priority from the pin's
severity (blocker P1, bug P2, polish P3; a pin from before severities existed
is P2). A key that already exists is skipped, so running it twice files
nothing twice. Standard library only; the rig launches it on Save.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_PINS = os.path.join(ROOT, "visualqa", "walk_pins.jsonl")
PRIORITY = {"blocker": "P1", "bug": "P2", "polish": "P3"}
PHASE = "bug-walk"

# Family source directory by request kind. A target file is only given when
# the pin kind makes it obvious; otherwise it is omitted.
FAMILY_DIR = {
    "house": "src/house", "shop": "src/shop", "hotel": "src/hotel",
    "church": "src/church", "castle": "src/castle", "temple": "src/temple",
    "windmill": "src/windmill", "village": "src/village", "world": "src/world",
}


def target_file(request, pin_kind):
    kind = str(request.get("kind", ""))
    guess = ""
    plan_backed = kind in ("house", "shop")
    if pin_kind.startswith("furniture") and plan_backed:
        guess = "src/house/house_furnisher.gd"
    elif pin_kind in ("door", "window") and plan_backed:
        guess = "src/house/house_plan_openings.gd"
    elif pin_kind.startswith("ground") and plan_backed:
        if request.get("foundation") == "piles":
            guess = "src/house/house_piles.gd"
        elif float(request.get("ground_fall_m", 0) or 0) > 0:
            guess = "src/house/house_slope.gd"
    elif pin_kind.startswith("ground") and kind == "village":
        guess = "src/village/village_ground_surface.gd"
    if guess and os.path.exists(os.path.join(ROOT, guess)):
        return guess
    return ""


def _num(v):
    f = float(v)
    return str(int(f)) if f == int(f) else ("%g" % f)


def reopen_command(review):
    """The rig's own reopen line when it wrote one, else rebuilt from the request."""
    if review.get("reopen"):
        return review["reopen"]
    req = review.get("request", {})
    parts = [".\\visualqa\\walk.ps1", "--kind=%s" % req.get("kind", "house"),
             "--seed=%s" % req.get("seed", "1")]
    if req.get("style"):
        parts.append("--style=%s" % req["style"])
    if req.get("purpose"):
        parts.append("--purpose=%s" % req["purpose"])
    if float(req.get("jank", 0) or 0) > 0:
        parts.append("--jank=%s" % _num(req["jank"]))
    if float(req.get("ground_fall_m", 0) or 0) > 0:
        parts.append("--fall=%s" % _num(req["ground_fall_m"]))
        parts.append("--downhill=%s" % _num(req.get("ground_downhill_deg", 0) or 0))
    if req.get("foundation") == "piles":
        parts.append("--foundation=piles")
        if float(req.get("pile_water_m", 0) or 0) > 0:
            parts.append("--water=%s" % _num(req["pile_water_m"]))
    if review.get("cutaway"):
        parts.append("--cutaway")
    return " ".join(parts)


def describe(review, pin, shots_dir):
    note = str(pin.get("note", "")).strip() or "(no note)"
    lines = [
        "Human bug-walk pin %s on %s (review %s, %s)." % (
            pin.get("n"), review.get("name", "?"), review.get("review_id"), review.get("time", "")),
        "",
        "Note: " + note,
        "Kind: %s; severity: %s" % (pin.get("kind", "?"), pin.get("severity", "unset (old pin)")),
    ]
    if review.get("why"):
        lines.append("Tour stop: %s (%s)" % (review.get("stop", "?"), review["why"]))
    if pin.get("room"):
        lines.append("Room: " + str(pin["room"]))
    if pin.get("part"):
        lines.append("Part hit: " + str(pin["part"]))
    if pin.get("plan"):
        lines.append("Plan records: " + str(pin["plan"]))
    lines.append("Building-local position: %s, normal %s" % (pin.get("pos"), pin.get("normal")))
    lines.append("Camera %s looking %s" % (pin.get("camera"), pin.get("look")))
    if pin.get("screenshot"):
        lines.append("Screenshot: " + os.path.relpath(
            os.path.join(shots_dir, pin["screenshot"]), ROOT).replace("\\", "/"))
    if review.get("note"):
        lines.append("Review notes: " + str(review["note"]).replace("\n", " / "))
    lines.append("Request: " + json.dumps(review.get("request", {}), sort_keys=True))
    lines.append("Reopen: " + reopen_command(review))
    return "\n".join(lines)


def title(review, pin):
    note = " ".join(str(pin.get("note", "")).split()) or "(no note)"
    if len(note) > 60:
        note = note[:59].rstrip() + "…"
    return "%s: %s — %s" % (review.get("name", "?"), pin.get("kind", "?"), note)


class Todos:
    def __init__(self, workspace):
        self.workspace = workspace
        self.exe = shutil.which("waterfree")

    def run(self, *args):
        cmd = [self.exe] + list(args) + ["--workspace", self.workspace]
        p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        return p.returncode, (p.stdout or "") + (p.stderr or "")

    def get(self, key):
        """The existing todo's text, or None."""
        rc, out = self.run("todos", "get", key)
        if rc != 0 or "not found" in out.lower() or not out.strip().startswith("{"):
            return None
        return out


def pick_key(todos, review_id, n, dry_run):
    """WALK-<8>-<n>; skip when that todo is this pin, widen the id when it is another review's."""
    for width in (8, 12, len(review_id)):
        key = "WALK-%s-%d" % (review_id[:width], n)
        if todos is None:
            return key, False
        existing = todos.get(key)
        if existing is None:
            return key, False
        if review_id in existing:
            return key, True
    return key, True


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pins", default=DEFAULT_PINS, help="the walk_pins.jsonl to read")
    ap.add_argument("--since", default="", help="only reviews at or after this ISO time")
    ap.add_argument("--review", default="", help="only this review id (a prefix is enough)")
    ap.add_argument("--dry-run", action="store_true", help="print what would be filed; file nothing")
    ap.add_argument("--no-lookup", action="store_true", help="with --dry-run: do not ask waterfree which keys exist")
    ap.add_argument("--workspace", default=ROOT)
    ap.add_argument("--log", default="", help="append one summary line here")
    a = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass

    todos = Todos(a.workspace)
    if todos.exe is None:
        if not a.dry_run:
            print("waterfree is not on PATH; nothing filed.")
            _log(a.log, "error: waterfree not on PATH")
            return 2
        todos = None
    if a.dry_run and a.no_lookup:
        todos = None

    shots_dir = os.path.dirname(os.path.abspath(a.pins))
    added = skipped = failed = 0
    with open(a.pins, encoding="utf-8") as fh:
        for line_no, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                review = json.loads(line)
            except ValueError:
                print("line %d: not JSON, skipped" % line_no)
                continue
            rid = str(review.get("review_id", ""))
            if a.review and not rid.startswith(a.review):
                continue
            if a.since and str(review.get("time", "")) < a.since:
                continue
            for pin in review.get("pins", []):
                n = int(pin.get("n", 0))
                key, exists = pick_key(todos, rid, n, a.dry_run)
                if exists:
                    skipped += 1
                    print("skip %s (already filed)" % key)
                    continue
                args = ["todos", "add", "--key", key, "--title", title(review, pin),
                        "--description", describe(review, pin, shots_dir),
                        "--priority", PRIORITY.get(str(pin.get("severity", "")), "P2"),
                        "--phase", PHASE]
                target = target_file(review.get("request", {}), str(pin.get("kind", "")))
                if target:
                    args += ["--target-file", target]
                if a.dry_run:
                    print("would add %s %s [%s]%s\n    %s" % (key, args[args.index("--priority") + 1],
                          PHASE, " -> " + target if target else "", title(review, pin)))
                    added += 1
                    continue
                rc, out = todos.run(*args)
                if rc == 0:
                    added += 1
                    print("added %s  %s" % (key, title(review, pin)))
                else:
                    failed += 1
                    print("FAILED %s: %s" % (key, out.strip()[:300]))
    verb = "would file" if a.dry_run else "filed"
    summary = "%s %d, skipped %d already filed, %d failed" % (verb, added, skipped, failed)
    print(summary)
    _log(a.log, summary + (" (review %s)" % a.review if a.review else ""))
    return 1 if failed else 0


def _log(path, text):
    if not path:
        return
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write("%s %s\n" % (time.strftime("%Y-%m-%dT%H:%M:%S"), text))


if __name__ == "__main__":
    sys.exit(main())
