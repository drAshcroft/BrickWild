"""Measure the owned townhouse writing pair from GLTF triangles and catalogue data.

Read-only inputs: Chair_1.gltf/bin, Workbench.gltf/bin, catalog.json, and the
active townhouse office recipe. Only the JSON receipt is written.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
from pathlib import Path
from typing import Any

SEAT_LOCAL_Y_BAND_M = (0.48, 0.51)
UPWARD_NORMAL_Y_MIN = 0.98
CATALOGUE_BOUNDS_TOLERANCE_M = 0.003


def fail(message: str) -> None:
    raise SystemExit(f"measure_townhouse_writing_pair: {message}")


def finite_number(value: Any, label: str) -> float:
    try:
        result = float(value)
    except (TypeError, ValueError):
        fail(f"{label} is not numeric")
    if not math.isfinite(result):
        fail(f"{label} is not finite")
    return result


def matrix_identity() -> list[list[float]]:
    return [[1.0 if row == col else 0.0 for col in range(4)] for row in range(4)]


def matrix_multiply(a: list[list[float]], b: list[list[float]]) -> list[list[float]]:
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def node_local_matrix(node: dict[str, Any], node_index: int) -> list[list[float]]:
    if "matrix" in node and any(k in node for k in ("translation", "rotation", "scale")):
        fail(f"node {node_index} defines both matrix and TRS transforms")
    if "matrix" in node:
        values = [finite_number(v, f"node {node_index} matrix") for v in node["matrix"]]
        if len(values) != 16:
            fail(f"node {node_index} matrix must have 16 values")
        return [[values[col * 4 + row] for col in range(4)] for row in range(4)]

    translation = node.get("translation", [0.0, 0.0, 0.0])
    rotation = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    scale = node.get("scale", [1.0, 1.0, 1.0])
    if len(translation) != 3 or len(rotation) != 4 or len(scale) != 3:
        fail(f"node {node_index} has malformed TRS transform")
    tx, ty, tz = [finite_number(v, f"node {node_index} translation") for v in translation]
    qx, qy, qz, qw = [finite_number(v, f"node {node_index} rotation") for v in rotation]
    sx, sy, sz = [finite_number(v, f"node {node_index} scale") for v in scale]
    qlen = math.sqrt(qx*qx + qy*qy + qz*qz + qw*qw)
    if qlen <= 1e-12:
        fail(f"node {node_index} has a zero quaternion")
    qx, qy, qz, qw = qx/qlen, qy/qlen, qz/qlen, qw/qlen
    rot = [
        [1-2*(qy*qy+qz*qz), 2*(qx*qy-qz*qw), 2*(qx*qz+qy*qw)],
        [2*(qx*qy+qz*qw), 1-2*(qx*qx+qz*qz), 2*(qy*qz-qx*qw)],
        [2*(qx*qz-qy*qw), 2*(qy*qz+qx*qw), 1-2*(qx*qx+qy*qy)],
    ]
    out = matrix_identity()
    for r in range(3):
        out[r][0] = rot[r][0] * sx
        out[r][1] = rot[r][1] * sy
        out[r][2] = rot[r][2] * sz
    out[0][3], out[1][3], out[2][3] = tx, ty, tz
    return out


def transform_point(matrix: list[list[float]], point: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = point
    result = tuple(matrix[r][0]*x + matrix[r][1]*y + matrix[r][2]*z + matrix[r][3] for r in range(3))
    return result  # type: ignore[return-value]


def resolve_mesh_world_matrices(document: dict[str, Any]) -> list[tuple[int, list[list[float]]]]:
    nodes = document.get("nodes")
    scenes = document.get("scenes")
    if not isinstance(nodes, list) or not nodes or not isinstance(scenes, list) or not scenes:
        fail("GLTF must contain nodes and scenes")
    scene_index = int(document.get("scene", 0))
    if scene_index < 0 or scene_index >= len(scenes):
        fail("default scene index is outside scenes")
    roots = scenes[scene_index].get("nodes")
    if not isinstance(roots, list) or not roots:
        fail("default scene has no root nodes")
    visited: set[int] = set()
    stack: set[int] = set()
    mesh_instances: list[tuple[int, list[list[float]]]] = []

    def visit(index_value: Any, parent: list[list[float]]) -> None:
        if not isinstance(index_value, int) or index_value < 0 or index_value >= len(nodes):
            fail(f"scene references invalid node index {index_value!r}")
        index = index_value
        if index in stack:
            fail(f"node graph cycle at node {index}")
        if index in visited:
            fail(f"node {index} is referenced more than once in the active scene")
        stack.add(index)
        node = nodes[index]
        if not isinstance(node, dict):
            fail(f"node {index} is not an object")
        world = matrix_multiply(parent, node_local_matrix(node, index))
        if "mesh" in node:
            mesh_index = int(node["mesh"])
            mesh_instances.append((mesh_index, world))
        for child in node.get("children", []):
            visit(child, world)
        stack.remove(index)
        visited.add(index)

    for root_index in roots:
        visit(root_index, matrix_identity())
    if len(mesh_instances) != 1:
        fail(f"expected one active-scene mesh instance, found {len(mesh_instances)}")
    return mesh_instances


def external_binary(asset_path: Path, document: dict[str, Any]) -> tuple[bytes, Path]:
    buffers = document.get("buffers")
    if not isinstance(buffers, list) or len(buffers) != 1:
        fail(f"{asset_path.name} must use exactly one external buffer")
    uri = buffers[0].get("uri")
    if not isinstance(uri, str) or uri.startswith("data:"):
        fail(f"{asset_path.name} must name its external binary buffer")
    if Path(uri).is_absolute() or ".." in Path(uri).parts:
        fail(f"{asset_path.name} buffer URI must stay beside the GLTF")
    binary_path = (asset_path.parent / uri).resolve()
    if binary_path.parent != asset_path.parent.resolve():
        fail(f"{asset_path.name} buffer URI escapes the asset directory")
    binary = binary_path.read_bytes()
    declared = int(buffers[0].get("byteLength", -1))
    if declared < 0 or len(binary) < declared:
        fail(f"{binary_path.name} is shorter than the declared GLTF buffer")
    return binary, binary_path


def decode_accessor(document: dict[str, Any], binary: bytes, accessor_index: int,
                    expected_type: str, allowed_components: dict[int, tuple[str, int]]) -> list[tuple[float, ...]]:
    accessors = document.get("accessors", [])
    views = document.get("bufferViews", [])
    if accessor_index < 0 or accessor_index >= len(accessors):
        fail(f"accessor {accessor_index} is outside the table")
    accessor = accessors[accessor_index]
    if accessor.get("type") != expected_type:
        fail(f"accessor {accessor_index} type must be {expected_type}")
    if "sparse" in accessor:
        fail(f"sparse accessor {accessor_index} is unsupported; refusing partial decode")
    component_type = int(accessor.get("componentType", -1))
    if component_type not in allowed_components:
        fail(f"accessor {accessor_index} componentType {component_type} is unsupported")
    fmt, component_size = allowed_components[component_type]
    components = 3 if expected_type == "VEC3" else 1
    count = int(accessor.get("count", -1))
    if count <= 0:
        fail(f"accessor {accessor_index} has no elements")
    view_index = int(accessor.get("bufferView", -1))
    if view_index < 0 or view_index >= len(views):
        fail(f"accessor {accessor_index} has no valid bufferView")
    view = views[view_index]
    if int(view.get("buffer", 0)) != 0:
        fail(f"accessor {accessor_index} references a nonzero buffer")
    view_offset = int(view.get("byteOffset", 0))
    view_length = int(view.get("byteLength", -1))
    accessor_offset = int(accessor.get("byteOffset", 0))
    stride = int(view.get("byteStride", component_size * components))
    packed_size = component_size * components
    if stride < packed_size or accessor_offset < 0 or view_length < 0:
        fail(f"accessor {accessor_index} has invalid offset, length, or stride")
    if expected_type == "SCALAR" and "byteStride" in view and stride != component_size:
        fail(f"index accessor {accessor_index} must be tightly packed")
    local_end = accessor_offset + (count - 1) * stride + packed_size
    if local_end > view_length or view_offset + local_end > len(binary):
        fail(f"accessor {accessor_index} reads beyond its bufferView or binary")
    values = []
    base = view_offset + accessor_offset
    for i in range(count):
        unpacked = struct.unpack_from("<" + fmt * components, binary, base + i * stride)
        row = tuple(float(v) for v in unpacked)
        if not all(math.isfinite(v) for v in row):
            fail(f"accessor {accessor_index} contains non-finite data")
        values.append(row)
    return values


def load_asset(root: Path, key: str, catalogue: dict[str, Any]) -> dict[str, Any]:
    rel = Path("assets/props/fantasy") / f"{key}.gltf"
    path = root / rel
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("asset", {}).get("version") != "2.0":
        fail(f"{rel.as_posix()} is not glTF 2.0")
    binary, binary_path = external_binary(path, document)
    instances = resolve_mesh_world_matrices(document)
    mesh_index, world_matrix = instances[0]
    meshes = document.get("meshes", [])
    if mesh_index != 0 or len(meshes) != 1:
        fail(f"{key} must have one active mesh at mesh index 0")
    primitives = meshes[0].get("primitives", [])
    if not primitives:
        fail(f"{key} mesh has no primitives")
    transformed_by_primitive: list[list[tuple[float, float, float]]] = []
    index_rows: list[list[tuple[float, ...]]] = []
    for primitive_index, primitive in enumerate(primitives):
        if int(primitive.get("mode", 4)) != 4:
            fail(f"{key} primitive {primitive_index} is not triangles")
        attributes = primitive.get("attributes", {})
        if "POSITION" not in attributes:
            fail(f"{key} primitive {primitive_index} has no POSITION accessor")
        raw_positions = decode_accessor(document, binary, int(attributes["POSITION"]),
                                        "VEC3", {5126: ("f", 4)})
        transformed = [transform_point(world_matrix, (v[0], v[1], v[2])) for v in raw_positions]
        transformed_by_primitive.append(transformed)
        if "indices" not in primitive:
            fail(f"{key} primitive {primitive_index} has no index accessor")
        index_rows.append(decode_accessor(document, binary, int(primitive["indices"]),
                                          "SCALAR", {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}))
        indices = [int(row[0]) for row in index_rows[-1]]
        if len(indices) % 3:
            fail(f"{key} primitive {primitive_index} index count is not divisible by three")
        if any(index < 0 or index >= len(transformed) for index in indices):
            fail(f"{key} primitive {primitive_index} contains an out-of-range index")
    points = [point for primitive in transformed_by_primitive for point in primitive]
    bounds = [[min(p[axis] for p in points), max(p[axis] for p in points)] for axis in range(3)]
    expected = catalogue.get(key)
    if not isinstance(expected, dict) or len(expected.get("size", [])) != 3:
        fail(f"catalog.json has no three-axis measurement for {key}")
    expected_size = [finite_number(v, f"catalogue {key} size") for v in expected["size"]]
    actual_size = [bounds[axis][1] - bounds[axis][0] for axis in range(3)]
    deltas = [abs(actual_size[i] - expected_size[i]) for i in range(3)]
    if any(delta > CATALOGUE_BOUNDS_TOLERANCE_M for delta in deltas):
        fail(f"{key} GLTF bounds {actual_size} disagree with catalogue {expected_size} by {deltas}")
    return {
        "key": key, "gltf_path": rel.as_posix(), "binary_path": binary_path.relative_to(root).as_posix(),
        "gltf_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "binary_sha256": hashlib.sha256(binary).hexdigest(),
        "mesh_index": mesh_index, "primitive_count": len(primitives),
        "world_matrix_row_major": world_matrix,
        "actual_bounds_m": {"x": bounds[0], "y": bounds[1], "z": bounds[2]},
        "actual_size_m": actual_size, "catalogue_size_m": expected_size,
        "catalogue_size_abs_delta_m": deltas,
        "transformed_positions_by_primitive": transformed_by_primitive,
        "indices_by_primitive": index_rows,
        "document": document,
    }


def triangle_measurements(asset: dict[str, Any]) -> tuple[list[dict[str, Any]], int]:
    document = asset["document"]
    primitive = document["meshes"][0]["primitives"][0]
    attributes = primitive["attributes"]
    # The seat band is defined in Chair_1's authored local frame.
    transformed = asset["transformed_positions_by_primitive"][0]
    indices = [int(row[0]) for row in asset["indices_by_primitive"][0]]
    triangles = []
    degenerate = 0
    for i in range(0, len(indices), 3):
        tri = [transformed[indices[i + j]] for j in range(3)]
        a, b, c = tri
        ab = tuple(b[k] - a[k] for k in range(3))
        ac = tuple(c[k] - a[k] for k in range(3))
        normal = (ab[1]*ac[2]-ab[2]*ac[1], ab[2]*ac[0]-ab[0]*ac[2], ab[0]*ac[1]-ab[1]*ac[0])
        norm = math.sqrt(sum(v*v for v in normal))
        if norm <= 1e-12:
            degenerate += 1
            continue
        if normal[1] / norm <= UPWARD_NORMAL_Y_MIN:
            continue
        if min(point[1] for point in tri) < SEAT_LOCAL_Y_BAND_M[0] \
                or max(point[1] for point in tri) > SEAT_LOCAL_Y_BAND_M[1]:
            continue
        triangles.append({"vertices": tri, "area_m2": norm * 0.5, "normal_y": normal[1] / norm})
    return triangles, degenerate


def recipe_scale(recipe_path: Path) -> tuple[float, float, str, str]:
    source = recipe_path.read_text(encoding="utf-8")
    match = re.search(r"(?m)^const\s+TOWNHOUSE_WRITING_SURFACE_HEIGHT_SCALE\s*:=\s*([0-9]+(?:\.[0-9]+)?)\s*$", source)
    if not match:
        fail(f"{recipe_path} lacks the explicit townhouse writing-surface scale constant")
    scale = finite_number(match.group(1), "townhouse recipe scale")
    if scale <= 0.0 or scale > 1.0:
        fail("townhouse recipe scale must be in (0, 1]")
    start = source.find("const TOWNHOUSE_OFFICE_ACTIVITY")
    end = source.find("\n]", start)
    if start < 0 or end < 0:
        fail("townhouse office activity array was not found")
    activity = source[start:end]
    bench_row = re.search(r'"key"\s*:\s*"Workbench"[\s\S]{0,200}?"height_scale"\s*:\s*TOWNHOUSE_WRITING_SURFACE_HEIGHT_SCALE', activity)
    if not bench_row:
        fail("townhouse office Workbench row does not use the measured scale constant")
    chair_key = activity.find('"key": "Chair_1"')
    if chair_key < 0:
        fail("townhouse office activity has no Chair_1 row")
    chair_row_start = activity.rfind("{", 0, chair_key)
    chair_row_end = activity.find("}", chair_key)
    if chair_row_start < 0 or chair_row_end < 0:
        fail("townhouse Chair_1 activity row is malformed")
    chair_row = activity[chair_row_start:chair_row_end]
    if re.search(r'"(?:height_scale|scale)"\s*:', chair_row):
        fail("Chair_1 recipe now has an explicit vertical scale; include and measure that scale")
    catalog_source = (recipe_path.parent / "prop_catalog.gd").read_text(encoding="utf-8")
    default_match = re.search(r'placement\.get\("height_scale",\s*placement\.get\("scale",\s*([0-9]+(?:\.[0-9]+)?)\)\)', catalog_source)
    if not default_match:
        fail("PropCatalog placement-height default changed; cannot derive Chair_1 scale")
    chair_scale = finite_number(default_match.group(1), "PropCatalog placement-height default")
    compact_catalog_source = re.sub(r"\s+", "", catalog_source)
    surface_contract = "returnminf(float(PROPS[key].get(\"top\",height(key))),height(key))"
    if surface_contract not in compact_catalog_source:
        fail("PropCatalog surface-height formula changed; review catalogue derivation")
    return (scale, chair_scale,
            hashlib.sha256(recipe_path.read_bytes()).hexdigest(),
            hashlib.sha256((recipe_path.parent / "prop_catalog.gd").read_bytes()).hexdigest())


def main() -> None:
    default_repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=default_repo,
                        help="BrickWild project root (default: tools/../)")
    parser.add_argument("--out", type=Path,
                        help="receipt JSON path (default: <repo>/artifacts/townhouse_writing_pair_measurement.json)")
    args = parser.parse_args()
    repo = args.repo.expanduser().resolve()
    if not (repo / "project.godot").is_file():
        fail(f"--repo is not a BrickWild project root: {repo}")
    catalog_path = repo / "assets/props/catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    chair = load_asset(repo, "Chair_1", catalog)
    bench = load_asset(repo, "Workbench", catalog)
    identity = matrix_identity()
    if any(abs(chair["world_matrix_row_major"][r][c] - identity[r][c]) > 1e-9
           for r in range(4) for c in range(4)):
        fail("Chair_1 has a non-identity scene-node transform; update the local seat-band mapping before reporting")
    triangles, degenerate_count = triangle_measurements(chair)
    if not triangles:
        fail("no upward-facing Chair_1 seat-plane triangles in local y band "
             f"{SEAT_LOCAL_Y_BAND_M[0]}..{SEAT_LOCAL_Y_BAND_M[1]} m")
    seat_points = [p for row in triangles for p in row["vertices"]]
    seat_y = [p[1] for p in seat_points]
    if max(seat_y) - min(seat_y) > 0.001:
        fail(f"selected chair seat triangles are not one plane: y range {min(seat_y)}..{max(seat_y)}")
    chair_entry = catalog["Chair_1"]
    bench_entry = catalog["Workbench"]
    chair_floor = finite_number(chair_entry.get("floor", 0.0), "Chair_1 catalogue floor offset")
    bench_floor = finite_number(bench_entry.get("floor", 0.0), "Workbench catalogue floor offset")
    scale, chair_scale, recipe_hash, prop_catalog_hash = recipe_scale(
        repo / "src/house/house_furnishing_recipes.gd")
    workbench_height = finite_number(bench_entry["size"][1], "Workbench catalogue height")
    workbench_surface_local = min(finite_number(bench_entry.get("top", workbench_height),
                                                 "Workbench catalogue top"), workbench_height)
    prop_source = (repo / "src/house/prop_catalog.gd").read_text(encoding="utf-8")
    if not re.search(r'"Workbench"\s*:\s*\{[^\n]*\[WALL,\s*SURFACE\]', prop_source):
        fail("PropCatalog no longer identifies Workbench as a surface host")
    chair_seat_world = (min(seat_y) - chair_floor) * chair_scale
    workbench_surface_world = -bench_floor * scale + workbench_surface_local * scale
    seat_to_surface = workbench_surface_world - chair_seat_world
    if not math.isfinite(seat_to_surface):
        fail("derived seat-to-worktop difference is not finite")
    output = {
        "tool": "tools/measure_townhouse_writing_pair.py",
        "repo_root": str(repo),
        "read_only_inputs": [
            "assets/props/fantasy/Chair_1.gltf", "assets/props/fantasy/Chair_1.bin",
            "assets/props/fantasy/Workbench.gltf", "assets/props/fantasy/Workbench.bin",
            "assets/props/catalog.json", "src/house/house_furnishing_recipes.gd",
            "src/house/prop_catalog.gd",
        ],
        "recipe_source_sha256": recipe_hash,
        "selection": {
            "chair_mesh_index": chair["mesh_index"], "primitive_index": 0,
            "position_accessor": chair["document"]["meshes"][0]["primitives"][0]["attributes"]["POSITION"],
            "index_accessor": chair["document"]["meshes"][0]["primitives"][0]["indices"],
            "seat_local_y_band_m": list(SEAT_LOCAL_Y_BAND_M),
            "minimum_world_up_normal_y": UPWARD_NORMAL_Y_MIN,
            "degenerate_triangles_skipped": degenerate_count,
            "node_world_matrix_applied": chair["world_matrix_row_major"],
        },
        "chair_seat": {
            "triangle_count": len(triangles),
            "area_m2": sum(t["area_m2"] for t in triangles),
            "normal_y_min": min(t["normal_y"] for t in triangles),
            "bounds_m": {axis: [min(p[i] for p in seat_points), max(p[i] for p in seat_points)]
                         for i, axis in enumerate(("x", "y", "z"))},
            "catalogue_floor_offset_m": chair_floor,
            "placement_height_scale": chair_scale,
            "assembled_world_y_at_floor_m": chair_seat_world,
            "catalogue_bounds_validation": {"actual_m": chair["actual_size_m"],
                                             "catalogue_m": chair["catalogue_size_m"],
                                             "abs_delta_m": chair["catalogue_size_abs_delta_m"]},
        },
        "workbench": {
            "catalogue_bounds_validation": {"actual_m": bench["actual_size_m"],
                                             "catalogue_m": bench["catalogue_size_m"],
                                             "abs_delta_m": bench["catalogue_size_abs_delta_m"]},
            "catalogue_floor_offset_m": bench_floor,
            "catalogue_surface_height_m": workbench_surface_local,
            "recipe_vertical_scale": scale,
            "assembled_surface_world_y_at_floor_m": workbench_surface_world,
        },
        "derived_relation": {
            "seat_to_worktop_difference_m": seat_to_surface,
            "difference_formula": "(-Workbench.floor + Workbench.surface_height) * recipe_scale - (Chair_1.seat_plane_y - Chair_1.floor_offset) * chair_scale",
        },
        "asset_hashes": {
            "chair_gltf_sha256": chair["gltf_sha256"], "chair_binary_sha256": chair["binary_sha256"],
            "workbench_gltf_sha256": bench["gltf_sha256"], "workbench_binary_sha256": bench["binary_sha256"],
            "catalog_sha256": hashlib.sha256(catalog_path.read_bytes()).hexdigest(),
            "prop_catalog_source_sha256": prop_catalog_hash,
        },
    }
    output_path = args.out.expanduser().resolve() if args.out else repo / "artifacts/townhouse_writing_pair_measurement.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"receipt": str(output_path), "seat_triangles": len(triangles),
                      "seat_world_y_m": chair_seat_world,
                      "worktop_world_y_m": workbench_surface_world,
                      "seat_to_worktop_m": seat_to_surface}, indent=2))


if __name__ == "__main__":
    main()
