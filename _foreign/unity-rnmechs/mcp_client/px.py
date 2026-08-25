"""Playtest helper: send C# code (from a file or stdin) to Unity MCP execute_code.
Usage: python px.py <code_file>   OR   echo code | python px.py -
"""
import json, sys, urllib.request

BASE = "http://localhost:8088/mcp"


def post(payload, session=None):
    req = urllib.request.Request(
        BASE, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json",
                 "Accept": "application/json, text/event-stream"})
    if session:
        req.add_header("mcp-session-id", session)
    resp = urllib.request.urlopen(req, timeout=120)
    return resp.headers.get("mcp-session-id"), resp.read().decode()


def call_tool(tool, args):
    sid, _ = post({"jsonrpc": "2.0", "id": 0, "method": "initialize",
                   "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                              "clientInfo": {"name": "cli", "version": "0"}}})
    post({"jsonrpc": "2.0", "method": "notifications/initialized"}, sid)
    _, body = post({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                    "params": {"name": tool, "arguments": args}}, sid)
    out = []
    for line in body.splitlines():
        if line.startswith("data:"):
            line = line[5:].strip()
        try:
            msg = json.loads(line)
        except Exception:
            continue
        r = msg.get("result") or msg.get("error")
        if isinstance(r, dict) and "content" in r:
            for c in r["content"]:
                out.append(c.get("text", ""))
        else:
            out.append(json.dumps(r)[:2000])
    return "\n".join(out)


if __name__ == "__main__":
    tool = sys.argv[1]
    if len(sys.argv) > 2 and sys.argv[2] != "-":
        with open(sys.argv[2]) as f:
            code = f.read()
    else:
        code = sys.stdin.read()
    args = {"code": code} if tool == "execute_code" else dict(code=code)
    args["action"] = "execute"
    print(call_tool(tool, args))
