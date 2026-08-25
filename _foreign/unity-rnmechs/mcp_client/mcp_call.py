"""Minimal MCP-over-HTTP client for the local unity-mcp server (port 8088).
Usage: python mcp_call.py <tool_name> [json_arguments]
Prints the tool's text result."""
import json
import sys
import urllib.request

BASE = "http://localhost:8088/mcp"


def post(payload, session=None):
    req = urllib.request.Request(BASE, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json",
                                          "Accept": "application/json, text/event-stream"})
    if session:
        req.add_header("mcp-session-id", session)
    resp = urllib.request.urlopen(req, timeout=120)
    sid = resp.headers.get("mcp-session-id")
    body = resp.read().decode()
    return sid, body


def parse_body(body):
    out = []
    for line in body.splitlines():
        if line.startswith("data:"):
            out.append(line[5:].strip())
    if not out:
        out.append(body)
    return out


def main():
    tool = sys.argv[1]
    args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    sid, _ = post({"jsonrpc": "2.0", "id": 0, "method": "initialize",
                   "params": {"protocolVersion": "2024-11-05", "capabilities": {},
                              "clientInfo": {"name": "cli", "version": "0"}}})
    post({"jsonrpc": "2.0", "method": "notifications/initialized"}, sid)
    _, body = post({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                    "params": {"name": tool, "arguments": args}}, sid)
    for chunk in parse_body(body):
        try:
            msg = json.loads(chunk)
        except json.JSONDecodeError:
            continue
        result = msg.get("result") or msg.get("error")
        if isinstance(result, dict) and "content" in result:
            for c in result["content"]:
                print(c.get("text", ""))
        else:
            print(json.dumps(result)[:2000])


if __name__ == "__main__":
    main()
