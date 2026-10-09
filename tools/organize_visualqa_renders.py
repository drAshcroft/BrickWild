#!/usr/bin/env python3
"""Stage provenance-preserving house render copies under visualqa/styles.

Dry-run is the default. Use --apply only after reviewing the JSON plan.
This script never changes HumanRate.md, walk_pins.jsonl, or renders.json.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import shutil
import sys
from pathlib import Path


SOURCES = (
    ("artifacts/personality/resumed/restart21_witch_joint_cluster_full_render/renders", "restart21_witch_joint_cluster_full_render"),
    ("artifacts/personality/resumed/domestic_hearth_shell_host_v1/renders_shell_host_v1", "domestic_hearth_shell_host_v1"),
)
PROTECTED = {"HumanRate.md", "walk_pins.jsonl", "renders.json"}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_entries(repo: Path, rel_source: str, run_id: str):
    source = repo / rel_source
    manifest_path = source / "manifest.json"
    raw = manifest_path.read_bytes()
    manifest = json.loads(raw)
    if isinstance(manifest.get("renders"), list):
        rows = manifest["renders"]
    elif isinstance(manifest.get("rows"), list):
        rows = manifest["rows"]
    else:
        raise ValueError(f"No recognized render rows in {manifest_path}")
    out = []
    for index, row in enumerate(rows):
        request = row.get("request") or {}
        image_ref = row.get("image")
        if not image_ref:
            raise ValueError(f"Manifest row {index} lacks image path")
        filename = Path(image_ref.replace("\\", "/")).name
        image = source / filename
        if not image.is_file():
            raise FileNotFoundError(f"Image listed in manifest is missing: {image}")
        style = request.get("style")
        if not style:
            raise ValueError(f"Manifest row {index} lacks request.style")
        family = "house"
        view = row.get("view", "view")
        room = row.get("room_kind")
        case_id = row.get("case") or row.get("id")
        if not case_id:
            case_id = "{}_{}_{}".format(style, request.get("size", "size"), request.get("seed", "seed"))
        branch = f"rooms/{room}/{view}" if room else f"views/{view}"
        target = Path("visualqa/styles") / family / style / "renders" / run_id / case_id / branch / filename
        out.append({
            "source": image.relative_to(repo).as_posix(),
            "target": target.as_posix(),
            "source_sha256": sha256(image),
            "style": style,
            "family": family,
            "run_id": run_id,
            "request_id": case_id,
            "view": view,
            "room_kind": room,
            "source_visual_review_state": row.get("visual_review_state", "not_assessed"),
            "render_state": row.get("render_state", "not_recorded"),
        })
    return raw, sha256(manifest_path), out


def safe_target(repo: Path, target: Path) -> Path:
    resolved = (repo / target).resolve()
    root = (repo / "visualqa" / "styles" / "house").resolve()
    if root not in resolved.parents:
        raise ValueError(f"Refusing target outside visualqa/styles/house: {resolved}")
    if resolved.name in PROTECTED:
        raise ValueError(f"Refusing protected file target: {resolved}")
    return resolved


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--source", nargs=2, action="append", metavar=("DIRECTORY", "RUN"),
                        help="render directory and unique run name; repeat to replace the default cohorts")
    parser.add_argument("--apply", action="store_true", help="copy files and write indexes; default only prints a plan")
    args = parser.parse_args()
    repo = args.repo.resolve()
    sources = args.source or SOURCES
    all_rows = []
    manifests = []
    styles = set()
    for source_rel, run_id in sources:
        raw, manifest_hash, rows = load_entries(repo, source_rel, run_id)
        manifests.append({"source_manifest": (Path(source_rel) / "manifest.json").as_posix(), "sha256": manifest_hash, "run_id": run_id})
        for row in rows:
            row["source_manifest_sha256"] = manifest_hash
            styles.add(row["style"])
        all_rows.extend(rows)

    conflicts = []
    for row in all_rows:
        dest = safe_target(repo, Path(row["target"]))
        if dest.exists() and sha256(dest) != row["source_sha256"]:
            conflicts.append(str(dest))
    if conflicts:
        raise FileExistsError("Refusing to overwrite non-identical targets: " + ", ".join(conflicts))

    plan = {
        "mode": "apply" if args.apply else "dry_run",
        "copy_count": len(all_rows),
        "styles": sorted(styles),
        "sources": manifests,
        "manifest_copies": [
            {
                "source_manifest": source["source_manifest"],
                "sha256": source["sha256"],
                "target": (Path("visualqa/styles/house") / style / "renders" / source["run_id"] / "source_manifest.json").as_posix(),
            }
            for source in manifests
            for style in sorted({row["style"] for row in all_rows if row["run_id"] == source["run_id"]})
        ],
        "preserved_files": sorted(PROTECTED),
        "records": all_rows,
    }
    if not args.apply:
        print(json.dumps(plan, indent=2))
        return 0

    root = repo / "visualqa" / "styles" / "house"
    for source_rel, run_id in sources:
        source = repo / source_rel
        run_manifest = source / "manifest.json"
        matching = [r for r in all_rows if r["run_id"] == run_id]
        if not matching:
            continue
        # The source manifest belongs beside EACH style's imported run. A
        # single mixed-source manifest at the run root loses style provenance.
        for style in sorted({r["style"] for r in matching}):
            style_rows = [r for r in matching if r["style"] == style]
            run_root = root / style / "renders" / run_id
            run_root.mkdir(parents=True, exist_ok=True)
            manifest_dest = run_root / "source_manifest.json"
            raw = run_manifest.read_bytes()
            if manifest_dest.exists() and manifest_dest.read_bytes() != raw:
                raise FileExistsError(f"Refusing to overwrite changed source manifest: {manifest_dest}")
            manifest_dest.write_bytes(raw)
            if sha256(manifest_dest) != sha256(run_manifest):
                raise IOError(f"Copied source manifest hash differs from input: {manifest_dest}")
        for row in matching:
            src = repo / row["source"]
            dest = safe_target(repo, Path(row["target"]))
            dest.parent.mkdir(parents=True, exist_ok=True)
            if not dest.exists():
                shutil.copy2(src, dest)
            if sha256(dest) != row["source_sha256"]:
                raise IOError(f"Copied render hash differs from source: {dest}")

    # Concept boards already live under each style's `targets/` directory.
    # Keep them distinct from the generated `renders/` evidence tree.
    for style in sorted(styles):
        style_root = root / style
        refs = style_root / "targets"
        refs.mkdir(parents=True, exist_ok=True)
        readme = refs / "README.md"
        if not readme.exists():
            readme.write_text(
                "# Concept targets\n\n"
                "Images and prompts here describe visual intent. They are not generated renders,\n"
                "not evidence of implemented behavior, and not human ratings. Keep them outside\n"
                "the `renders/` tree.\n",
                encoding="utf-8",
            )
    index_rows = []
    for row in all_rows:
        dest = safe_target(repo, Path(row["target"]))
        rel = dest.relative_to(root).as_posix()
        index_rows.append((row, rel))
    cards = []
    for row, rel in index_rows:
        label = " / ".join(x for x in (row["style"], row["request_id"], row.get("room_kind") or row["view"]) if x)
        cards.append(f'<figure><a href="{html.escape(rel)}"><img loading="lazy" src="{html.escape(rel)}" alt="{html.escape(label)}"></a><figcaption>{html.escape(label)}<br><small>render={html.escape(str(row["render_state"]))}; visual review={html.escape(str(row["source_visual_review_state"]))}</small></figcaption></figure>')
    target_cards = []
    for target_image in sorted(root.glob("*/targets/*.png")):
        rel = target_image.relative_to(root).as_posix()
        style = target_image.parents[1].name
        title = f"{style} concept target (not a render)"
        siblings = []
        for name in ("prompt.txt", "README.md"):
            sibling = target_image.parent / name
            if sibling.is_file():
                sibling_rel = sibling.relative_to(root).as_posix()
                siblings.append(f'<a href="{html.escape(sibling_rel)}">{html.escape(name)}</a>')
        links = " · ".join(siblings)
        target_cards.append(f'<figure class="target"><a href="{html.escape(rel)}"><img loading="lazy" src="{html.escape(rel)}" alt="{html.escape(title)}"></a><figcaption>{html.escape(title)}<br><small>Visual direction only; not implementation evidence or a human rating.</small><br>{links}</figcaption></figure>')
    page = "<!doctype html><meta charset='utf-8'><title>House style renders</title>\n" \
           "<style>body{font:15px system-ui;margin:2rem;background:#eee;color:#222}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:1rem}figure{margin:0;background:white;padding:.5rem}img{width:100%;height:auto}figcaption{padding:.4rem}</style>\n" \
           "<h1>House style visual QA</h1><p>Generated renders and visual targets are separate collections. Source manifest statuses are retained; no ratings are inferred. <a href='assistant_review.json'>Read the assistant's image review</a>.</p><h2>Actual generated renders</h2><main>" + "\n".join(cards) + "</main><h2>Concept targets (not renders)</h2><main>" + "\n".join(target_cards) + "</main>\n"
    (root / "index.html").write_text(page, encoding="utf-8")
    (root / "render_index.json").write_text(json.dumps({"sources": manifests, "records": all_rows}, indent=2), encoding="utf-8")
    print(json.dumps({"applied": True, "copies": len(all_rows), "styles": sorted(styles), "index": "visualqa/styles/house/index.html"}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
