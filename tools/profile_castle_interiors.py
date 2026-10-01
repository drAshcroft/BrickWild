"""Prepare an isolated Godot project with reversible phase instrumentation.

No source files are changed. Run `prepare` once per before/after revision, then
`run` in a coordinated quiet window. Detailed instrumentation is diagnostic:
timing every candidate distorts absolute timings, so use phase mode for medians.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
PHASES = {
    "src/castle/castle_generator.gd": ["generate"],
    "src/castle/castle_interiors.gd": ["primary", "yard", "emit"],
    "src/castle/castle_builder.gd": ["build"],
    "src/house/house_builder.gd": ["build"],
    "src/house/house_furnisher.gd": ["furnish", "_furnish_room",
        "_keep_the_room_passable"],
    "src/house/house_furnish_repair.gd": ["relax"],
    "src/house/house_furnish_placement.gd": ["could_place", "place_one",
        "place_free", "place_around"],
    "qa/house_qa.gd": ["check"],
    "qa/castle_qa.gd": ["check", "_check_interiors", "lords_walk"],
    "qa/voxel_grid.gd": ["rasterize"],
}
CLOCK = '''extends RefCounted
static var rows: Dictionary = {}
static var stack: Array[Dictionary] = []
static func clear() -> void:
\trows.clear()
\tstack.clear()
static func start(label: String) -> void:
\tstack.append({"label": label, "start": Time.get_ticks_usec(), "children": 0})
static func stop() -> void:
\tvar span: Dictionary = stack.pop_back()
\tvar elapsed: int = Time.get_ticks_usec() - int(span.start)
\tif not stack.is_empty():
\t\tstack[-1].children += elapsed
\tvar key: String = span.label
\tif not rows.has(key):
\t\trows[key] = {"calls": 0, "inclusive_us": 0, "self_us": 0}
\trows[key].calls += 1
\trows[key].inclusive_us += elapsed
\trows[key].self_us += elapsed - int(span.children)
'''


def split_params(value: str) -> list[str]:
    """Split GDScript parameters without splitting array/vector defaults."""
    parts, start, depth = [], 0, 0
    for i, char in enumerate(value):
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == "," and depth == 0:
            parts.append(value[start:i])
            start = i + 1
    parts.append(value[start:])
    return [re.match(r"\s*(\w+)", p).group(1) for p in parts if p.strip()]


def instrument(source: str, relative: str, methods: list[str]) -> str:
    wrappers = []
    for name in methods:
        pattern = re.compile(r"^(static )?func " + re.escape(name)
            + r"\((.*?)\)(\s*->\s*[^:\n]+)?:", re.MULTILINE | re.DOTALL)
        matches = list(pattern.finditer(source))
        if len(matches) != 1:
            raise ValueError(f"Expected one {relative}:{name}, found {len(matches)}")
        match = matches[0]
        signature = match.group(0)
        call = f"_profile_impl_{name}({', '.join(split_params(match.group(2)))})"
        is_void = bool(match.group(3) and match.group(3).strip() == "-> void")
        label = f"{Path(relative).stem}.{name}"
        body = [signature, f'\t_CastleProfileClock.start("{label}")']
        body.append(f"\t{call}" if is_void else f"\tvar _profile_value = {call}")
        body.append("\t_CastleProfileClock.stop()")
        if not is_void:
            body.append("\treturn _profile_value")
        wrappers.append("\n".join(body))
        replacement = signature.replace(f"func {name}(", f"func _profile_impl_{name}(", 1)
        source = source[:match.start()] + replacement + source[match.end():]
    return source + '\n\nconst _CastleProfileClock = preload("res://tools/castle_phase_clock.gd")\n\n' + "\n\n".join(wrappers) + "\n"


def prepare(args: argparse.Namespace) -> None:
    target = args.snapshot.resolve()
    if target.exists():
        raise SystemExit(f"Snapshot already exists; choose a fresh directory: {target}")
    target.mkdir(parents=True)
    # Parent .gdignore prevents the original editor registering duplicate classes.
    if target.is_relative_to(ROOT / "artifacts"):
        (target.parent / ".gdignore").touch()
    hashes = {}
    paths = [p for base in ("src", "core", "qa") for p in (ROOT / base).rglob("*.gd")]
    paths += [ROOT / "tests/suites/castle_sweep.gd", ROOT / "assets/props/catalog.json",
        ROOT / "tools/profile_castle_interiors.gd"]
    for path in paths:
        relative = path.relative_to(ROOT)
        out = target / relative
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, out)
        hashes[relative.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    (target / "project.godot").write_text('config_version=5\n[application]\nconfig/name="BigGlade castle profile"\nconfig/features=PackedStringArray("4.5")\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
    (target / "tools/castle_phase_clock.gd").write_text(CLOCK, encoding="utf-8")
    methods = {} if args.plain else {key: value[:] for key, value in PHASES.items()}
    if args.detail:
        methods["src/house/house_furnish_geometry.gd"] = ["fits", "inside_outline", "candidate"]
        methods["src/house/house_furnish_score.gd"] = ["_affinity"]
    for relative, names in methods.items():
        path = target / relative
        path.write_text(instrument(path.read_text(encoding="utf-8"), relative, names), encoding="utf-8")
    (target / "profile_source.json").write_text(json.dumps({"source": str(ROOT),
        "instrumentation": "none" if args.plain else ("detail" if args.detail else "phases"), "sha256": hashes}, indent=2), encoding="utf-8")
    print(json.dumps({"snapshot": str(target), "scripts": len(paths), "instrumented": methods}))


def run(args: argparse.Namespace) -> None:
    target = args.snapshot.resolve()
    if not (target / "profile_source.json").exists():
        raise SystemExit("Prepare the snapshot before running it")
    # Stop only this owned Godot process on timeout. Never orphan the console shim.
    godot = args.godot.resolve()
    if godot.stem.endswith("_console"):
        candidate = godot.with_name(godot.stem.removesuffix("_console") + godot.suffix)
        if candidate.exists():
            godot = candidate
    log_dir = target / "results"
    log_dir.mkdir(exist_ok=True)
    # Isolated snapshots must not depend on, or attempt to update, the host
    # editor settings. Managed runners commonly expose the real AppData as
    # read-only, which makes Godot's editor import crash before profiling.
    user_root = target / ".profile_user"
    roaming = user_root / "AppData" / "Roaming"
    local = user_root / "AppData" / "Local"
    roaming.mkdir(parents=True, exist_ok=True)
    local.mkdir(parents=True, exist_ok=True)
    profile_env = os.environ.copy()
    profile_env["APPDATA"] = str(roaming)
    profile_env["LOCALAPPDATA"] = str(local)
    commands = [([str(godot), "--headless", "--path", str(target), "--editor", "--quit"], "import")]
    run_args = [str(godot), "--headless", "--path", str(target), "--script", "res://tools/profile_castle_interiors.gd", "--", "--repeat", str(args.repeat)]
    for case in args.case or []:
        run_args += ["--case", case]
    if args.no_qa:
        run_args += ["--no-qa"]
    if args.concurrent:
        run_args += ["--concurrent"]
    commands.append((run_args, "profile"))
    for command, name in commands:
        started = time.monotonic()
        with (log_dir / f"{name}.log").open("w", encoding="utf-8") as log:
            try:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                    timeout=args.timeout, check=False, env=profile_env)
            except subprocess.TimeoutExpired:
                print(json.dumps({"phase": name, "ok": False, "reason": "timeout", "log": str(log.name)}))
                raise SystemExit(1)
        contents = (log_dir / f"{name}.log").read_text(encoding="utf-8")
        failed = result.returncode != 0 or "SCRIPT ERROR" in contents or "Parse Error" in contents
        print(json.dumps({"phase": name, "ok": not failed, "exit": result.returncode,
            "elapsed_s": round(time.monotonic() - started, 3), "log": str(log_dir / f"{name}.log")}))
        if failed:
            raise SystemExit(1)
    report = json.loads((log_dir / "profile.json").read_text(encoding="utf-8"))
    if not report.get("complete"):
        raise SystemExit("Missing final completion marker; partial profile is not a pass")


def compare(args: argparse.Namespace) -> None:
    before = json.loads(args.before.read_text(encoding="utf-8"))
    after = json.loads(args.after.read_text(encoding="utf-8"))
    failures, rows = [], []
    for name, data in (("before", before), ("after", after)):
        if not data.get("complete"):
            failures.append(f"Incomplete {name} profile")
        if not data.get("ok"):
            failures.append(f"{name.capitalize()} profile reports QA or repeatability failures")
    if set(before["cases"]) != set(after["cases"]):
        failures.append("Before/after fixture sets differ")
    for label, b in before["cases"].items():
        a = after["cases"].get(label)
        if a is None:
            failures.append(f"Missing case {label}")
            continue
        exact = b["fingerprint"] == a["fingerprint"]
        if not exact:
            failures.append(f"Plan/placements/RNG/mesh/log parity failed: {label}")
        rows.append({"case": label, "exact_equal": exact, "before_median_ms": b["median_ms"],
            "after_median_ms": a["median_ms"]})
    report = {"ok": not failures, "failures": failures, "cases": rows,
        "quiet_before": before["quiet_requested"], "quiet_after": after["quiet_requested"],
        "qa_before": before.get("qa_enabled", False),
        "qa_after": after.get("qa_enabled", False)}
    print(json.dumps(report, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    p = commands.add_parser("prepare")
    p.add_argument("snapshot", type=Path)
    mode = p.add_mutually_exclusive_group()
    mode.add_argument("--detail", action="store_true")
    mode.add_argument("--plain", action="store_true", help="Uninstrumented parity/control timing")
    p.set_defaults(action=prepare)
    p = commands.add_parser("run")
    p.add_argument("snapshot", type=Path)
    p.add_argument("--godot", type=Path, required=True)
    p.add_argument("--repeat", type=int, default=3)
    p.add_argument("--case", action="append", help="style:tier:index; repeatable")
    p.add_argument("--timeout", type=int, default=3600)
    p.add_argument("--concurrent", action="store_true", help="Explicitly label a non-idle diagnostic run")
    p.add_argument("--no-qa", action="store_true", help="Generation-only diagnostics; never full acceptance")
    p.set_defaults(action=run)
    p = commands.add_parser("compare")
    p.add_argument("before", type=Path)
    p.add_argument("after", type=Path)
    p.set_defaults(action=compare)
    args = parser.parse_args()
    args.action(args)
