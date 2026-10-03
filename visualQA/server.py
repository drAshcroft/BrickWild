"""Local human render review. Python standard library only."""
import argparse
import hashlib
import json
import mimetypes
import re
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FIELDS = ["pretty", "collisions", "window problems", "door problems", "roof problems"]
MARKER = re.compile(r"<!-- human-review ([A-Za-z0-9_-]+) ([a-z]+) -->")


def make_server(port=8765, output=None):
    output = Path(output) if output else HERE / "HumanRate.md"
    lock = threading.Lock()
    classes = json.loads((HERE / "renders.json").read_text(encoding="utf-8"))
    images = {}
    for row in classes:
        for i, render in enumerate(row["renders"]):
            path = (ROOT / render["path"]).resolve()
            if not path.is_relative_to(ROOT) or not path.is_file():
                raise ValueError(f"Missing render: {render['path']}")
            render["id"] = f"{row['id']}-{i}"
            render["url"] = f"/image/{render['id']}"
            render["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            render["captured"] = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()
            images[render["id"]] = path
    by_id = {row["id"]: row for row in classes}
    if not output.exists():
        output.write_text(
            "# Human visual QA\n\n"
            "Saved by the local review page. Pretty means approval; the other checked boxes mean a visible problem.\n"
            "Unchecked problem boxes mean no problem was flagged in this image, not proof that the mesh is correct.\n\n",
            encoding="utf-8",
        )

    class Handler(BaseHTTPRequestHandler):
        def send(self, status, body, content_type="application/json; charset=utf-8"):
            if not isinstance(body, bytes):
                body = json.dumps(body).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            path = urlsplit(self.path).path
            if path == "/":
                self.send(200, (HERE / "index.html").read_bytes(), "text/html; charset=utf-8")
            elif path == "/api/classes":
                with lock:
                    reviewed = {kind for _, kind in MARKER.findall(output.read_text(encoding="utf-8"))}
                self.send(200, {"classes": classes, "reviewed": sorted(reviewed)})
            elif path.startswith("/image/") and path[7:] in images:
                image = images[path[7:]]
                self.send(200, image.read_bytes(), mimetypes.guess_type(image.name)[0])
            else:
                self.send(404, {"error": "Not found"})

        def do_POST(self):
            expected_origin = f"http://127.0.0.1:{self.server.server_port}"
            if self.headers.get("Origin") != expected_origin:
                self.send(403, {"error": "Open this page using " + expected_origin})
                return
            if self.path != "/api/rate":
                self.send(404, {"error": "Not found"})
                return
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= 16384:
                    raise ValueError("Invalid request size")
                data = json.loads(self.rfile.read(size))
                review_id = data.get("review_id", "")
                if not isinstance(review_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]{8,80}", review_id):
                    raise ValueError("Invalid review ID")
                row = by_id.get(data.get("class"))
                if row is None or not isinstance(data.get("ratings"), list) or len(data["ratings"]) != 2:
                    raise ValueError("Rate both images in a known class")
                timestamp = datetime.now(timezone.utc).isoformat()
                parts = [f"<!-- human-review {review_id} {row['id']} -->\n", f"## {row['label']} — {timestamp}\n\n"]
                for render, rating in zip(row["renders"], data["ratings"]):
                    if rating.get("id") != render["id"]:
                        raise ValueError("Image ID does not match class")
                    flags = rating.get("flags")
                    if not isinstance(flags, dict) or set(flags) != set(FIELDS) or any(type(v) is not bool for v in flags.values()):
                        raise ValueError("All five checkbox values are required")
                    note = rating.get("note", "")
                    if not isinstance(note, str) or len(note) > 2000:
                        raise ValueError("Notes must be at most 2000 characters")
                    # Prevent multiline notes from impersonating a saved-review marker.
                    note = note.replace("<!--", "&lt;!--")
                    parts.extend([
                        f"### {render['label']}\n\n",
                        f"Render: [{render['path']}](../{render['path']})\n\n",
                        f"Capture time (UTC): {render['captured']}\n\n",
                        f"SHA-256: `{render['sha256']}`\n\n",
                    ])
                    parts.extend(f"- [{'x' if flags[key] else ' '}] {key}\n" for key in FIELDS)
                    if note.strip():
                        parts.append("\nNotes:\n" + "\n".join("> " + line for line in note.strip().splitlines()) + "\n")
                    parts.append("\n")
                with lock:
                    saved = MARKER.findall(output.read_text(encoding="utf-8"))
                    if not any(saved_id == review_id for saved_id, _ in saved):
                        import os
                        with output.open("a", encoding="utf-8", newline="\n") as file:
                            file.write("".join(parts))
                            file.flush()
                            os.fsync(file.fileno())
                self.send(200, {"saved": True, "file": "visualQA/HumanRate.md"})
            except (ValueError, TypeError, AttributeError, KeyError) as error:
                self.send(400, {"error": str(error)})
            except OSError as error:
                self.send(500, {"error": f"Could not save rating: {error}"})

    return ThreadingHTTPServer(("127.0.0.1", port), Handler)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    server = make_server(args.port)
    print(f"Human visual QA: http://127.0.0.1:{server.server_port}", flush=True)
    print(f"Ratings: {HERE / 'HumanRate.md'}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
