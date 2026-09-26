"""Move existing procedural knowledge into the book taxonomy, preserving IDs.

Dry run: python tools/reindex_procedural_knowledge.py
Apply:   python tools/reindex_procedural_knowledge.py --apply

Reads the global WaterFree SQLite database for inventory only. All writes use
`waterfree knowledge update`, so revisions and indexes stay consistent.
"""

import json
from pathlib import Path
import sqlite3
import subprocess
import sys


# Exact titles make this list reviewable. Unrelated packaging, asset inventory,
# UI mechanics, and villager simulation entries retain their current taxonomy.
TARGETS = {
    "Plan-first occupational buildings reuse residential spatial QA": "Procedural/buildings/shops",
    "BigGlade lossless building documents, headless CLI, and site-coordinate interior export": "Procedural/buildings/transport",
    "Castle facade QA checks occupied height bands rather than total window count": "Procedural/buildings/castles",
    "Castle chapel reserves a procession aisle and reuses temple axis and sightline QA": "Procedural/buildings/ritual",
    "Gothic clerestory windows share aisle-roof geometry and flyer bay rhythm": "Procedural/buildings/churches",
    "Polygon furnishing affinities use real wall normals and oriented prop projections": "Procedural/buildings/decoration",
    "BigGlade building generation pipeline: Spec -> Geometry -> Plan -> Builder -> Assembler": "Procedural/buildings/pipeline",
    "BigGlade QA logs: measure the emitted mesh, never re-derive from the spec": "Procedural/Meshes/validation",
    "Temple column grids as authored plan data": "Procedural/buildings/ritual",
    "BigGlade: usable dining pairs and real polygon wall affinity": "Procedural/buildings/decoration",
    "BigGlade classify roof seams before removing dome caps": "Procedural/Meshes/roofs",
    "BigGlade walkable rugs and structural hearth surrounds": "Procedural/buildings/decoration",
    "BigGlade castle profiling separates furnishing search, navigation repair and mesh QA": "Procedural/buildings/performance",
    "Ridge castle roofs terminate under tower decks": "Procedural/Meshes/roofs",
    "MeshKit and RoofShape gotchas: clockwise faces, no generate_normals, dropped empty surfaces": "Procedural/Meshes/surfaces",
    "Keep procedural roof descriptors pure and verify component logs against emitted triangles": "Procedural/Meshes/roofs",
    "Seat a dormer on the roof plane it stands on: RoofShape.dormer_seat": "Procedural/Meshes/roofs",
    "Joined polygon hipped roofs need shared mid-plane endpoints and vertical depth": "Procedural/Meshes/roofs",
    "Roof openings require ridge-cap cuts and vertical ray evidence": "Procedural/Meshes/roofs",
    "BigGlade roof-region contracts separate occupied space, material and support": "Procedural/Meshes/validation",
    "BigGlade house roof reproduction fixtures and validation ladder": "Procedural/Meshes/validation",
    "Prove a refactor moved no geometry: vertex fingerprint against a git worktree": "Procedural/Meshes/validation",
    "BigGlade test lanes: pick the lane that matches the edit, never the full sweep per task": "Procedural/buildings/validation",
    "Roof coverage cannot prove topology: test the envelope, seams, closure, multiplicity, and winding": "Procedural/Meshes/validation",
    "A check that selects what it measures can pass by measuring nothing: compare check counts, not just failures": "Procedural/buildings/validation",
    "BigGlade persistent curved village crossings and stable material slots": "Procedural/villages/infrastructure",
    "BigGlade: persistent village boundaries, open gateways and real circulation": "Procedural/villages/infrastructure",
    "VIL-018 pre-lot water ribbons and deduplicated crossings": "Procedural/villages/infrastructure",
    "Plan-first procedural landmark family": "Procedural/buildings/families",
    "BigGlade exact-output furnishing optimization with measured polygon rejection cost": "Procedural/buildings/performance",
    "BigGlade occupied motte keeps preserve eight real storeys, usable oval floors and a wall flue": "Procedural/buildings/castles",
    "BigGlade real jetty, glazing marker, and geometry-backed exterior QA": "Procedural/buildings/houses",
    "BigGlade settlement form semantics: round fans and paired services": "Procedural/villages/forms",
    "Measured mining entrances: rock berms, working aprons and true mouth reachability": "Procedural/villages/landmarks",
    "BigGlade native courtyard arrivals and short manor lanes": "Procedural/villages/lots",
    "BigGlade ziggurat placement retains twin stairs and the native chamber approach": "Procedural/villages/lots",
    "BigGlade planted village square frontage, market aisles and measured terrace clearance": "Procedural/villages/forms",
    "BigGlade shoreline enclosure: water gaps and measured dam controls": "Procedural/villages/infrastructure",
    "Courtyard-house rings: bounded scales, supported court roofs, and water gates": "Procedural/buildings/courtyards",
    "Timber hall pond placement and HallCheck QA": "Procedural/buildings/timber-halls",
    # Transferable patterns from other projects; retain their source_repo and scope.
    "Procedural settlement layout: fit each plot as its seed is placed, never in a second pass": "Procedural/villages/lots",
    "Coarse world cells cannot certify a village footprint": "Procedural/villages/sites",
    "Polygon village capacity: add connected perimeter lanes, do not overextend radial roads": "Procedural/villages/infrastructure",
    "VoxelGames inhabited Italian villages separate structure, finish, attached facade detail, and public-realm dressing": "Procedural/villages/decoration",
    "CGA-style split needs CUMULATIVE rounding -- and a 1:2 test provably cannot detect that it is missing": "Procedural/buildings/grammars",
    "Backtracking packer: a budget hit is not a proof; restart with a new shuffle, then most-constrained-first, and report exhausted": "Procedural/buildings/plans",
    "Give identity its own RNG stream: adding one generated field renames everything and orphans every save": "Procedural/buildings/pipeline",
    "Procedural generator coin correlated across dungeons: hash the seed WITH the element id": "Procedural/buildings/pipeline",
    "Measure meshes and paint both sides: why generated rooms looked ignored": "Procedural/Meshes/surfaces",
    "Motte shell stairs must start at the drum toe and sample the full tread footprint": "Procedural/buildings/castles",
    "VoxelGames editable houses use local sparse documents with disposable block and smooth views": "Procedural/buildings/authoring",
    "Editable house faces use Godot clockwise winding; fixtures mount from socket masks": "Procedural/Meshes/surfaces",
    "Editable house authoring: rectangular sockets, guarded smooth corners, and modal bulk stamps": "Procedural/buildings/authoring",
    "Editable voxel houses: micro-chunk rendering and asynchronous support remove click stalls": "Procedural/Meshes/performance",
    "Editable house edits: delta-journal undo + flag-routed incremental views remove all full-rebuild fallbacks": "Procedural/buildings/authoring",
    "Entry stairs on a slope must choose their descent direction, not cap their step count": "Procedural/buildings/site-adaptation",
    "Small props sink: terrain sampler is not what a 0.2 m object stands on": "Procedural/villages/decoration",
    "Baked house direction: quarter_turns and door_edge are one fact stored twice": "Procedural/buildings/plans",
    "Apply prop placement offsets before the bounds check, not after": "Procedural/buildings/decoration",
    "A graded path across procedural ridge noise needs cut/fill equal to the ridge amplitude - suppress the noise, do not reroute": "Procedural/villages/sites",
    "BigGlade Village Studio uses public descriptors and actual settlement plans": "Procedural/villages/visualization",
    "BigGlade addon must include the complete runtime and measured prop closure": "Procedural/buildings/distribution",
    # Entries filed under legacy roots the book never described. Audit
    # 2026-09-26: `procedural/building/*` (singular) held five entries and
    # `procedural-buildings/distribution/validation` (hyphenated) held one,
    # so the branch the book indexes was six entries short of reality.
    "BigGlade exact placement measurement retains furnishing-derived shell details": "Procedural/villages/lots",
    "BigGlade narrow arrival clearance needs a local fine grid": "Procedural/buildings/validation",
    "Fishing shore props need measured footprints and reached working ground": "Procedural/villages/decoration",
    "BigGlade immutable addon source snapshots in a shared workspace": "Procedural/buildings/distribution",
}


def main():
    db = Path.home() / ".waterfree" / "global" / "knowledge.db"
    with sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True) as conn:
        rows = conn.execute("SELECT id, title, hierarchy_path, source_repo FROM knowledge_entries").fetchall()
    by_title = {title: (id_, path, repo) for id_, title, path, repo in rows}
    missing = set(TARGETS) - set(by_title)
    if missing:
        raise SystemExit(f"Missing titles: {sorted(missing)}")
    changed = 0
    for title, target in TARGETS.items():
        id_, old, repo = by_title[title]
        if old.lower() == target.lower():
            continue
        print(json.dumps({"id": id_, "title": title, "source_repo": repo,
                          "from": old, "to": target}), flush=True)
        if "--apply" in sys.argv:
            result = subprocess.run(
                ["waterfree", "knowledge", "update", id_, "--hierarchy-path", target],
                capture_output=True, text=True, check=True,
            )
            response = json.loads(result.stdout)
            if not response.get("updated"):
                raise RuntimeError(f"Update did not report a change: {title}: {response}")
        changed += 1
    print(json.dumps({"candidates": len(TARGETS), "changed": changed,
                      "mode": "apply" if "--apply" in sys.argv else "dry-run"}))


if __name__ == "__main__":
    main()
