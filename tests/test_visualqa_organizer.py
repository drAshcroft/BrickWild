from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "organize_visualqa_renders.py"
spec = importlib.util.spec_from_file_location("organize_visualqa_renders_proposed", MODULE_PATH)
organizer = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(organizer)


class OrganizerSourceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name).resolve()

    def tearDown(self):
        self.tmp.cleanup()

    def _nested_public_source(self, style: str, run: str, case_id: str, room: str):
        root = self.repo / "visualqa" / "styles" / "house" / style / "renders" / run
        case_root = root / case_id
        image = case_root / "rooms" / "room_kitchen.jpg"
        image.parent.mkdir(parents=True, exist_ok=True)
        image.write_bytes((style + ":pixel-bytes").encode("ascii"))
        request = {"kind": "house", "style": style, "seed": 8102, "width": 10.0,
            "length": 22.0, "height": 8.0, "storeys": 2, "trade": "none"}
        manifest = {
            "style": style,
            "visual_review_state": "not_assessed",
            "cases": [{"id": case_id, "generation_state": "passed",
                "navigation_qa_state": "failed", "assembly_state": "passed",
                "render_state": "failed"}],
            "renders": [{"case": case_id, "view": "room_cooking_kitchen_1",
                "image": "res://" + image.relative_to(self.repo).as_posix(),
                "actual_room": {"index": 1, "kind": room, "storey": 0},
                "save_error": 0, "request": request}],
        }
        (root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        return root, image

    def test_in_place_nested_paths_case_join_and_style_identity(self):
        run = "target_comparison_restart23"
        longhall_root, longhall_image = self._nested_public_source(
            "longhall", run, "longhall_default_8102", "kitchen")
        townhouse_root, townhouse_image = self._nested_public_source(
            "townhouse", run, "townhouse_default_8102", "kitchen")
        infos, rows = [], []
        for style, root in [("longhall", longhall_root), ("townhouse", townhouse_root)]:
            info, found = organizer.load_entries(self.repo,
                root.relative_to(self.repo).as_posix(), run)
            infos.append(info)
            rows.extend(found)
        copies = organizer.assign_targets(self.repo, infos, rows)
        self.assertEqual(len(copies), 2)
        self.assertNotEqual(copies[0]["source_identity"], copies[1]["source_identity"])
        self.assertEqual({r["style"] for r in rows}, {"longhall", "townhouse"})
        for row, source_image in zip(rows, [longhall_image, townhouse_image]):
            self.assertEqual(row["target"], source_image.relative_to(self.repo).as_posix())
            self.assertEqual(row["room_kind"], "kitchen")
            self.assertEqual(row["request"]["seed"], 8102)
            self.assertEqual(row["render_state"], "failed")
            self.assertEqual(row["render_state_source"], "case_join")
            self.assertEqual(row["case_navigation_qa_state"], "failed")
            self.assertEqual(row["source_sha256"], hashlib.sha256(source_image.read_bytes()).hexdigest())

    def test_legacy_rows_keep_import_layout_and_explicit_row_status(self):
        source = self.repo / "artifacts" / "legacy_run"
        source.mkdir(parents=True)
        image = source / "view.jpg"
        image.write_bytes(b"old-image")
        manifest = {"rows": [{"image": "res://artifacts/legacy_run/view.jpg",
            "view": "bedroom_eye", "room_kind": "bedroom", "render_state": "passed",
            "request": {"kind": "house", "style": "cottage", "seed": 7441}}]}
        (source / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        info, rows = organizer.load_entries(self.repo, "artifacts/legacy_run", "legacy")
        organizer.assign_targets(self.repo, [info], rows)
        row = rows[0]
        self.assertEqual(row["render_state"], "passed")
        self.assertEqual(row["render_state_source"], "row")
        self.assertEqual(row["target"], "visualqa/styles/house/cottage/renders/legacy/cottage_size_7441/rooms/bedroom/bedroom_eye/view.jpg")

    def test_res_project_image_cannot_escape_source_directory(self):
        source = self.repo / "visualqa" / "styles" / "house" / "rich" / "renders" / "run"
        source.mkdir(parents=True)
        outside = self.repo / "visualqa" / "styles" / "house" / "rich" / "outside.jpg"
        outside.write_bytes(b"outside")
        manifest = {"renders": [{"image": "res://" + outside.relative_to(self.repo).as_posix(),
            "request": {"style": "rich", "seed": 1}}]}
        (source / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "escapes its source directory"):
            organizer.load_entries(self.repo,
                source.relative_to(self.repo).as_posix(), "run")


if __name__ == "__main__":
    unittest.main(verbosity=2)
