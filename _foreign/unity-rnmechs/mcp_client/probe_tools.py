"""List MCP tools and their schemas (filtered by argv[1] substring if given)."""
import json, sys, urllib.request
sys.path.insert(0, r"C:/Projects/BigGlade")
from px import post

sid, _ = post({"jsonrpc": "2.0", "id": 0, "method": "initialize",
               "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                          "clientInfo": {"name": "cli", "version": "0"}}})
post({"jsonrpc": "2.0", "method": "notifications/initialized"}, sid)
_, body = post({"jsonrpc": "2.0", "id": 1, "method": "tools/list"}, sid)
filt = sys.argv[1] if len(sys.argv) > 1 else ""
for line in body.splitlines():
    if line.startswith("data:"):
        line = line[5:].strip()
    try:
        msg = json.loads(line)
    except Exception:
        continue
    tools = (msg.get("result") or {}).get("tools") or []
    for t in tools:
        if filt in t["name"]:
            print(t["name"], "::", json.dumps(t.get("inputSchema", {}))[:600])
