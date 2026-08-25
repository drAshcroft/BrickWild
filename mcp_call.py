#!/usr/bin/env python3
"""One-shot MCP-over-HTTP client for the unity-mcp bridge (http://127.0.0.1:8088/mcp).

Usage:
  python mcp_call.py <tool_name> '<json-args>'
  python mcp_call.py list                      # list tools
  echo '<json-args>' | python mcp_call.py <tool_name> -

Each invocation does its own handshake (initialize -> initialized -> tools/call).
Results are printed as plain text extracted from the MCP response content.
"""
import json
import sys
import urllib.request

MCP_URL = "http://127.0.0.1:8088/mcp"
TIMEOUT = 300


def _post(session_id, payload):
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    if session_id:
        headers["mcp-session-id"] = session_id
    req = urllib.request.Request(MCP_URL, data=json.dumps(payload).encode("utf-8"),
                                 headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        sid = resp.headers.get("mcp-session-id")
        raw = resp.read().decode("utf-8", errors="replace")
    return sid, raw


def _parse_sse(raw):
    """Extract JSON payloads from SSE 'data:' lines."""
    out = []
    for line in raw.splitlines():
        if line.startswith("data:"):
            body = line[5:].strip()
            if body:
                try:
                    out.append(json.loads(body))
                except json.JSONDecodeError:
                    pass
    if not out and raw.strip():
        try:
            out.append(json.loads(raw))
        except json.JSONDecodeError:
            pass
    return out


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)

    # Handshake
    sid, raw = _post(None, {"jsonrpc": "2.0", "id": 0, "method": "initialize",
                            "params": {"protocolVersion": "2024-11-05",
                                       "capabilities": {},
                                       "clientInfo": {"name": "hermes-cli", "version": "1"}}})
    msgs = _parse_sse(raw)
    init_result = None
    for m in msgs:
        if isinstance(m, dict) and m.get("id") == 0 and "result" in m:
            init_result = m["result"]
            break
    if sid is None:
        print(json.dumps({"error": "no mcp-session-id header", "raw": raw[:500]}))
        sys.exit(1)
    _post(sid, {"jsonrpc": "2.0", "method": "notifications/initialized"})

    def call(req_id, name, tool_args):
        _, raw = _post(sid, {"jsonrpc": "2.0", "id": req_id,
                             "method": method_name, "params": {"name": name, "arguments": tool_args}})
        return raw

    if args[0] == "list":
        _, raw = _post(sid, {"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}})
        names = []
        for m in _parse_sse(raw):
            if isinstance(m, dict) and "result" in m and "tools" in m["result"]:
                names = [t.get("name") for t in m["result"]["tools"]]
        print("\n".join(names))
        return

    tool_name = args[0]
    if len(args) > 1:
        arg_text = args[1]
        if arg_text == "-":
            arg_text = sys.stdin.read()
        try:
            tool_args = json.loads(arg_text) if arg_text.strip() else {}
        except json.JSONDecodeError as e:
            print(json.dumps({"error": "bad json args", "detail": str(e)}))
            sys.exit(2)
    else:
        tool_args = {}

    method_name = "tools/call"
    raw = call(2, tool_name, tool_args)
    results = _parse_sse(raw)
    payload = None
    is_error = False
    for m in results:
        if isinstance(m, dict) and m.get("id") == 2:
            payload = m.get("result")
            is_error = bool(m.get("error"))
            if m.get("error"):
                payload = m["error"]
            break
    if payload is None:
        print(json.dumps({"error": "no response for id=2", "sse": results[:2]}))
        sys.exit(1)

    if is_error:
        print(json.dumps(payload, indent=2))
        sys.exit(1)

    # Unwrap content blocks
    text_parts = []
    structured = payload.get("structuredContent") if isinstance(payload, dict) else None
    if isinstance(payload, dict):
        for block in payload.get("content", []):
            if block.get("type") == "text":
                text_parts.append(block.get("text", ""))
            else:
                text_parts.append(json.dumps(block))
    out = "\n".join(text_parts) if text_parts else json.dumps(payload, indent=2)
    if structured and not text_parts:
        out = json.dumps(structured, indent=2)
    try:
        parsed = json.loads(out)
        print(json.dumps(parsed, indent=2))
    except (json.JSONDecodeError, TypeError):
        print(out)


if __name__ == "__main__":
    main()
