"""Index saved imagegen references without assigning procedural QA ratings."""
from pathlib import Path
import hashlib
import html
import json


def main():
    root = Path(__file__).resolve().parents[1] / "visualqa" / "styles"
    records = []
    cards = []
    for board in sorted(root.glob("**/targets/design_board_v*.png")):
        subject = board.parent.relative_to(root).parts[:-1]
        title = " / ".join(subject)
        paths = {"image": board, "prompt": board.parent / "prompt.txt", "notes": board.parent / "README.md"}
        if not all(path.is_file() for path in paths.values()):
            raise FileNotFoundError(f"Incomplete reference: {board}")
        record = {"subject": list(subject), "classification": "imagegen_reference_not_actual_render"}
        for key, path in paths.items():
            record[key] = path.relative_to(root).as_posix()
            record[key + "_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        records.append(record)
        esc = html.escape
        cards.append(f'<figure><a href="{esc(record["image"])}"><img loading="lazy" src="{esc(record["image"])}" alt="{esc(title)}"></a><figcaption>{esc(title)} — concept only<br><a href="{esc(record["prompt"])}">Exact prompt</a> · <a href="{esc(record["notes"])}">Interpretation and limitations</a></figcaption></figure>')
    page = "<!doctype html><meta charset='utf-8'><title>Building design targets</title><style>body{font:16px system-ui;margin:2rem;background:#eee;color:#222}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:1rem}figure{margin:0;padding:.6rem;background:white}img{width:100%;height:auto}</style><h1>Building design targets</h1><p>Imagegen references guide architecture, useful room composition and restrained props. They are not actual procedural renders or proof of completion. Read each board's limitations.</p><p><a href='house/index.html'>Actual house render comparisons and assistant findings</a> · <a href='church/gothic/index.html'>Actual Gothic chapel comparisons</a></p><main>" + "\n".join(cards) + "</main>\n"
    (root / "index.html").write_text(page, encoding="utf-8")
    (root / "target_index.json").write_text(json.dumps({"targets": records}, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"targets": len(records), "index": "visualqa/styles/index.html"}))


if __name__ == "__main__":
    main()
