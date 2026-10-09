#!/usr/bin/env python3
"""Stage provenance-preserving house render indexes and copies.

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
from collections import Counter
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


def _within(parent: Path, child: Path) -> bool:
    try:
        child.relative_to(parent)
        return True
    except ValueError:
        return False


def _case_table(manifest: dict) -> dict[str, dict]:
    table: dict[str, dict] = {}
    for field in ("cases", "case_states"):
        rows = manifest.get(field)
        if isinstance(rows, list):
            for row in rows:
                if isinstance(row, dict) and row.get("id") is not None:
                    table[str(row["id"])] = row
        elif isinstance(rows, dict):
            for key, row in rows.items():
                if isinstance(row, dict):
                    table[str(key)] = row
    return table


def _resolve_image(repo: Path, source: Path, image_ref: str) -> Path:
    normalized = image_ref.replace("\\", "/")
    if normalized.startswith("res://"):
        image = (repo / normalized[len("res://"):].lstrip("/")).resolve()
    else:
        image_path = Path(normalized)
        image = (image_path if image_path.is_absolute() else source / image_path).resolve()
    if not _within(source, image):
        raise ValueError(f"Image path escapes its source directory: {image_ref}")
    if not image.is_file():
        raise FileNotFoundError(f"Image listed in manifest is missing: {image}")
    return image


def load_entries(repo: Path, rel_source: str, run_id: str):
    repo = repo.resolve()
    source = (repo / rel_source).resolve()
    if not _within(repo, source):
        raise ValueError(f"Render source escapes repository: {rel_source}")
    manifest_path = source / "manifest.json"
    raw = manifest_path.read_bytes()
    manifest = json.loads(raw)
    if isinstance(manifest.get("renders"), list):
        rows = manifest["renders"]
    elif isinstance(manifest.get("rows"), list):
        rows = manifest["rows"]
    else:
        raise ValueError(f"No recognized render rows in {manifest_path}")
    manifest_hash = hashlib.sha256(raw).hexdigest()
    manifest_rel = manifest_path.relative_to(repo).as_posix()
    source_identity = f"{manifest_rel}#sha256:{manifest_hash}"
    gallery_root = (repo / "visualqa" / "styles" / "house").resolve()
    source_in_gallery = _within(gallery_root, source)
    case_table = _case_table(manifest)
    out = []
    styles: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"Manifest row {index} is not an object")
        request = row.get("request") or {}
        if not isinstance(request, dict):
            raise ValueError(f"Manifest row {index} request is not an object")
        image_ref = row.get("image")
        if not isinstance(image_ref, str) or not image_ref:
            raise ValueError(f"Manifest row {index} lacks image path")
        image = _resolve_image(repo, source, image_ref)
        style = request.get("style") or row.get("style") or manifest.get("style")
        if not style:
            raise ValueError(f"Manifest row {index} lacks request.style")
        style = str(style)
        styles.add(style)
        family = "house"
        view = str(row.get("view", "view"))
        actual_room = row.get("actual_room")
        room = actual_room.get("kind") if isinstance(actual_room, dict) else None
        room = room or row.get("room_kind")
        if room is not None:
            room = str(room)
        raw_case = row.get("case") or row.get("id")
        case_id = str(raw_case) if raw_case else "{}_{}_{}".format(
            style, request.get("size", "size"), request.get("seed", "seed"))
        case_state = case_table.get(case_id, {})
        row_state = row.get("render_state")
        case_render_state = case_state.get("render_state")
        save_error = row.get("save_error")
        if row_state is not None:
            render_state = row_state
            render_state_source = "row"
        elif case_render_state is not None:
            render_state = case_render_state
            render_state_source = "case_join"
        elif save_error is not None:
            render_state = "saved" if int(save_error) == 0 else "failed"
            render_state_source = "save_error"
        else:
            render_state = "not_recorded"
            render_state_source = "missing"
        case_review_state = case_state.get("visual_review_state")
        review_state = row.get("visual_review_state") or case_review_state \
            or manifest.get("visual_review_state") or "not_assessed"
        target = image.relative_to(repo).as_posix() if source_in_gallery else ""
        out.append({
            "source": image.relative_to(repo).as_posix(),
            "target": target,
            "source_is_in_place": source_in_gallery,
            "source_sha256": sha256(image),
            "source_identity": source_identity,
            "source_manifest": manifest_rel,
            "source_manifest_sha256": manifest_hash,
            "source_row_index": index,
            "style": style,
            "family": family,
            "run_id": run_id,
            "request_id": case_id,
            "request": request,
            "view": view,
            "room_kind": room,
            "save_error": save_error,
            "render_state": render_state,
            "render_state_source": render_state_source,
            "case_generation_state": case_state.get("generation_state"),
            "case_navigation_qa_state": case_state.get("navigation_qa_state"),
            "case_assembly_state": case_state.get("assembly_state")
                or case_state.get("mesh_assembly_state"),
            "source_visual_review_state": review_state,
        })
    info = {
        "source_manifest": manifest_rel,
        "sha256": manifest_hash,
        "run_id": run_id,
        "source_identity": source_identity,
        "source_root": source.relative_to(repo).as_posix(),
        "source_in_place": source_in_gallery,
        "styles": sorted(styles),
        "manifest_bytes": raw,
    }
    return info, out


def assign_targets(repo: Path, sources: list[dict], rows: list[dict]) -> list[dict]:
    pair_sources: Counter[tuple[str, str]] = Counter()
    for source in sources:
        identity = source["source_identity"]
        styles = set(source["styles"])
        for style in styles:
            pair_sources[(style, source["run_id"])] += 1
    run_ids: dict[tuple[str, str], str] = {}
    for source in sources:
        identity = source["source_identity"]
        for style in source["styles"]:
            key = (identity, style)
            if source["source_in_place"] or pair_sources[(style, source["run_id"])] == 1:
                target_run = source["run_id"]
            else:
                suffix = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:10]
                target_run = f"{source['run_id']}_{suffix}"
            run_ids[key] = target_run
    root = Path("visualqa/styles/house")
    for row in rows:
        identity = row["source_identity"]
        row["target_run_id"] = run_ids[(identity, row["style"])]
        if row["source_is_in_place"]:
            row["target"] = row["source"]
        else:
            branch = f"rooms/{row['room_kind']}/{row['view']}" if row["room_kind"] \
                else f"views/{row['view']}"
            row["target"] = (root / row["style"] / "renders" / row["target_run_id"]
                / row["request_id"] / branch / Path(row["source"]).name).as_posix()
    manifest_copies = []
    for source in sources:
        identity = source["source_identity"]
        for style in source["styles"]:
            target_run = run_ids[(identity, style)]
            target_manifest = (Path(source["source_manifest"]) if source["source_in_place"]
                else root / style / "renders" / target_run / "source_manifest.json")
            manifest_copies.append({
                "source_manifest": source["source_manifest"],
                "source_identity": identity,
                "style": style,
                "run_id": source["run_id"],
                "target_run_id": target_run,
                "sha256": source["sha256"],
                "target": Path(target_manifest).as_posix(),
                "in_place": source["source_in_place"],
            })
    return manifest_copies


def safe_target(repo: Path, target: Path) -> Path:
    resolved = (repo / target).resolve()
    root = (repo / "visualqa" / "styles" / "house").resolve()
    if not _within(root, resolved) or resolved == root:
        raise ValueError(f"Refusing target outside visualqa/styles/house: {resolved}")
    if resolved.name in PROTECTED:
        raise ValueError(f"Refusing protected file target: {resolved}")
    return resolved


def build_plan(repo: Path, sources_arg: list[tuple[str, str]]):
    source_infos: list[dict] = []
    all_rows: list[dict] = []
    identities: set[str] = set()
    for source_rel, run_id in sources_arg:
        info, rows = load_entries(repo, source_rel, run_id)
        if info["source_identity"] in identities:
            raise ValueError(f"Duplicate source manifest selected twice: {info['source_manifest']}")
        identities.add(info["source_identity"])
        source_infos.append(info)
        all_rows.extend(rows)
    manifest_copies = assign_targets(repo, source_infos, all_rows)
    conflicts = []
    for row in all_rows:
        dest = safe_target(repo, Path(row["target"]))
        if dest.exists() and sha256(dest) != row["source_sha256"]:
            conflicts.append(str(dest))
    for record in manifest_copies:
        dest = safe_target(repo, Path(record["target"]))
        source = repo / record["source_manifest"]
        if dest.exists() and dest.read_bytes() != source.read_bytes():
            conflicts.append(str(dest))
    if conflicts:
        raise FileExistsError("Refusing to overwrite non-identical targets: " + ", ".join(sorted(set(conflicts))))
    manifest_rows = [{k: v for k, v in source.items() if k != "manifest_bytes"}
        for source in source_infos]
    styles = sorted({row["style"] for row in all_rows})
    plan = {
        "mode": "dry_run",
        "record_count": len(all_rows),
        "copy_count": sum(not row["source_is_in_place"] for row in all_rows),
        "in_place_count": sum(row["source_is_in_place"] for row in all_rows),
        "styles": styles,
        "sources": manifest_rows,
        "manifest_copies": manifest_copies,
        "preserved_files": sorted(PROTECTED),
        "records": all_rows,
    }
    return source_infos, all_rows, plan


def _write_manifest_copy(repo: Path, source: dict, record: dict) -> None:
    source_path = repo / source["source_manifest"]
    dest = safe_target(repo, Path(record["target"]))
    if dest.resolve() == source_path.resolve():
        if dest.read_bytes() != source["manifest_bytes"]:
            raise IOError(f"In-place source manifest changed during import: {dest}")
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.read_bytes() != source["manifest_bytes"]:
        raise FileExistsError(f"Refusing to overwrite changed source manifest: {dest}")
    if not dest.exists():
        dest.write_bytes(source["manifest_bytes"])
    if sha256(dest) != source["sha256"]:
        raise IOError(f"Copied source manifest hash differs from input: {dest}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--source", nargs=2, action="append", metavar=("DIRECTORY", "RUN"),
        help="render directory and run name; repeat to select a cohort")
    parser.add_argument("--apply", action="store_true", help="copy files and write indexes; default only prints a plan")
    args = parser.parse_args()
    repo = args.repo.resolve()
    sources_arg = args.source or list(SOURCES)
    source_infos, all_rows, plan = build_plan(repo, sources_arg)
    plan["mode"] = "apply" if args.apply else "dry_run"
    if not args.apply:
        print(json.dumps(plan, indent=2))
        return 0

    source_by_identity = {source["source_identity"]: source for source in source_infos}
    for record in plan["manifest_copies"]:
        _write_manifest_copy(repo, source_by_identity[record["source_identity"]], record)
    for row in all_rows:
        src = repo / row["source"]
        dest = safe_target(repo, Path(row["target"]))
        if src.resolve() == dest.resolve():
            if sha256(src) != row["source_sha256"]:
                raise IOError(f"In-place render changed during import: {src}")
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        if not dest.exists():
            shutil.copy2(src, dest)
        if sha256(dest) != row["source_sha256"]:
            raise IOError(f"Copied render hash differs from source: {dest}")

    root = repo / "visualqa" / "styles" / "house"
    styles = plan["styles"]
    for style in styles:
        refs = root / style / "targets"
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
    cards = []
    for row in all_rows:
        dest = safe_target(repo, Path(row["target"]))
        rel = dest.relative_to(root).as_posix()
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
    (root / "render_index.json").write_text(json.dumps({"sources": plan["sources"], "records": all_rows}, indent=2), encoding="utf-8")
    print(json.dumps({"applied": True, "records": len(all_rows), "copies": plan["copy_count"],
        "in_place": plan["in_place_count"], "styles": styles,
        "index": "visualqa/styles/house/index.html"}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
