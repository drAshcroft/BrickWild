# Human visual QA

Run from the project root:

```powershell
python visualQA/server.py
```

Open http://127.0.0.1:8765. No packages or build step.

Eight public building classes, two existing renders each. Each image has its own
five checkboxes and optional notes. Pretty means approval; the other boxes mean
a problem was seen. Save & Next appends both ratings directly to
`visualQA/HumanRate.md` and advances only after the server confirms the write.
Reload resumes at the first unsaved class. The class dropdown lets you revisit
a class and append another review. Switching classes before saving discards
that page's unsaved selections.

These are existing captures, not a fresh render sweep. Capture dates are shown.
Edit `renders.json` to choose different fixtures. Recorded source paths and
SHA-256 hashes identify which images were reviewed. Do not replace captures
while this server is running; restart it after changing the render selection.

The server listens only on loopback and serves only the selected images and
the review page. Ctrl+C stops it. Change the port with `--port 8766`.
