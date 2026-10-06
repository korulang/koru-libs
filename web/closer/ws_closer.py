#!/usr/bin/env python3
"""ws-closer — websocket closer for the web gauntlet.

Replays a captured WebSocket exchange against a server under test and diffs
it against the captured topcoat golden. Shares bytes-closer's discipline:
authored spec (case.txt + send.txt) vs captured oracle (head.txt +
frames.txt), narrow normalization, pass/fail/cant-tell per case.

Case layout under goldens/<fixture>/<case>/:
  case.txt   — the HTTP upgrade request spec (request line + headers).
               If the spec carries `upgrade: websocket` the case is a WS
               case; otherwise it replays as plain HTTP (negative probes).
  send.txt   — authored client sends, one per line (WS cases only):
                 text <utf8>            masked text frame
                 text-file <name>      masked text frame, payload from file
                 binary hex:<hex>      masked binary frame
                 binary-file <name>    masked binary frame, payload from file
                 ping hex:<hex>        masked ping control frame
                 frag-text a|b|c       masked fragmented text (fin-split)
                 close <code> <reason> masked close frame (code "-" = none)
  head.txt   — captured response head (101 for WS cases, or the HTTP reply
               for no-upgrade probes).
  body.txt   — captured HTTP body for no-upgrade probes (optional).
  frames.txt — captured ordered exchange; `> ` lines echo send.txt,
               `< ` lines are the observed server frames, rendered the same
               way (`< eof` marks server-initiated TCP close). WS cases only.

Normalization policy: `date` response header value only. Frame payloads,
opcodes, masking rules, and ordering compare raw. Client frames are always
sent masked (protocol requirement); server frames must arrive unmasked —
a masked server frame fails the case loudly.

Usage:
  ws_closer.py capture --base 127.0.0.1:PORT [--goldens DIR] [--only CASE]
  ws_closer.py close   --base 127.0.0.1:PORT [--goldens DIR] [--only CASE] [--verbose]
"""

import argparse
import base64
import os
import re
import socket
import sys

DATE_RE = re.compile(r"^date:\s*.*$", re.IGNORECASE | re.MULTILINE)
TIMEOUT = 5.0
MASK_KEY = b"\x37\xfa\x21\x3d"  # fixed client mask — capture determinism

OP_TEXT, OP_BIN, OP_CLOSE, OP_PING, OP_PONG, OP_CONT = 0x1, 0x2, 0x8, 0x9, 0xA, 0x0

OP_NAMES = {OP_TEXT: "text", OP_BIN: "binary", OP_CLOSE: "close",
            OP_PING: "ping", OP_PONG: "pong"}


def norm_head(raw):
    return DATE_RE.sub("date: <DATE>", raw)


# ---------- frame codec ----------

def build_frame(opcode, payload, fin=True, mask=MASK_KEY):
    b0 = (0x80 if fin else 0) | opcode
    n = len(payload)
    if n < 126:
        hdr = bytes([b0, 0x80 | n])
    elif n < 65536:
        hdr = bytes([b0, 0x80 | 126]) + n.to_bytes(2, "big")
    else:
        hdr = bytes([b0, 0x80 | 127]) + n.to_bytes(8, "big")
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    return hdr + mask + masked


def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def recv_frame(sock):
    """Return (fin, opcode, payload, masked) or None on clean EOF."""
    hdr = recv_exact(sock, 2)
    if hdr is None:
        return None
    b0, b1 = hdr
    fin = bool(b0 & 0x80)
    opcode = b0 & 0x0F
    masked = bool(b1 & 0x80)
    n = b1 & 0x7F
    if n == 126:
        n = int.from_bytes(recv_exact(sock, 2), "big")
    elif n == 127:
        n = int.from_bytes(recv_exact(sock, 8), "big")
    key = recv_exact(sock, 4) if masked else b""
    payload = recv_exact(sock, n) or b""
    if masked:
        payload = bytes(b ^ key[i % 4] for i, b in enumerate(payload))
    return fin, opcode, payload, masked


def render_frame(frame, case_dir):
    """Render a received frame as a frames.txt line payload (no < prefix)."""
    if frame is None:
        return "eof"
    fin, opcode, payload, masked = frame
    if masked:
        return "MASKED-SERVER-FRAME " + _render_payload(opcode, payload)
    return _render_payload(opcode, payload)


def _render_payload(opcode, payload):
    name = OP_NAMES.get(opcode, f"op{opcode}")
    if opcode == OP_CLOSE:
        if not payload:
            return "close - -"
        code = int.from_bytes(payload[:2], "big")
        reason = payload[2:].decode("utf-8", "replace")
        return f"close {code} {reason}"
    if opcode == OP_TEXT:
        try:
            return "text " + payload.decode("utf-8")
        except UnicodeDecodeError:
            return "text hex:" + payload.hex()
    return f"{name} hex:{payload.hex()}"


# ---------- send spec ----------

def load_payload(line, case_dir):
    """Parse a send/frames line, returning a list of (fin, opcode, payload)."""
    kind, _, rest = line.partition(" ")
    if kind in ("text-file", "binary-file"):
        data = open(os.path.join(case_dir, rest.strip()), "rb").read()
        if kind == "text-file":
            return [(True, OP_TEXT, data)]
        return [(True, OP_BIN, data)]
    if kind == "text":
        return [(True, OP_TEXT, rest.encode())]
    if kind == "binary":
        hexpart = rest.split(":", 1)[1] if ":" in rest else rest
        return [(True, OP_BIN, bytes.fromhex(hexpart.strip()))]
    if kind == "ping":
        hexpart = rest.split(":", 1)[1] if ":" in rest else rest
        return [(True, OP_PING, bytes.fromhex(hexpart.strip()))]
    if kind == "frag-text":
        frags = rest.split("|")
        out = []
        for i, frag in enumerate(frags):
            op = OP_CONT if i else OP_TEXT
            out.append((i == len(frags) - 1, op, frag.encode()))
        return out
    if kind == "close":
        parts = rest.split(" ", 1)
        code_s = parts[0]
        reason = parts[1] if len(parts) > 1 else ""
        if code_s == "-":
            return [(True, OP_CLOSE, b"")]
        return [(True, OP_CLOSE, int(code_s).to_bytes(2, "big") + reason.encode())]
    raise ValueError(f"unknown send spec: {line!r}")


def send_line(sock, line, case_dir):
    for fin, op, payload in load_payload(line, case_dir):
        sock.sendall(build_frame(op, payload, fin))


def render_send(line, case_dir):
    """Canonical `>` rendering for frames.txt."""
    kind = line.split(" ", 1)[0]
    if kind == "frag-text":
        return line  # keep the authored split visible
    if kind in ("text-file", "binary-file"):
        return line
    return line


# ---------- case machinery ----------

def read_spec(case_dir):
    with open(os.path.join(case_dir, "case.txt")) as f:
        lines = [l.rstrip("\n") for l in f if l.strip()]
    method, path = lines[0].split(" ", 1)
    headers = {}
    for line in lines[1:]:
        k, _, v = line.partition(":")
        headers[k.strip()] = v.strip()
    return method, path, headers


def is_ws(headers):
    return headers.get("upgrade", "").lower() == "websocket"


def read_head(sock):
    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            break
        buf += chunk
    head, _, rest = buf.partition(b"\r\n\r\n")
    return head.decode("utf-8", "replace") + "\r\n\r\n", rest


def read_body(sock, head, rest):
    """Read a plain-HTTP body per content-length / conn close."""
    m = re.search(r"^content-length:\s*(\d+)", head, re.IGNORECASE | re.MULTILINE)
    if m:
        need = int(m.group(1)) - len(rest)
        extra = recv_exact(sock, max(need, 0)) or b""
        return rest + extra
    return rest


def connect(host, port):
    s = socket.create_connection((host, port), TIMEOUT)
    s.settimeout(TIMEOUT)
    return s


# ---------- capture ----------

def capture_case(base, case_dir):
    host, port = base
    method, path, headers = read_spec(case_dir)
    req = f"{method} {path} HTTP/1.1\r\n" + "".join(
        f"{k}: {v}\r\n" for k, v in headers.items()) + "\r\n"
    sock = connect(host, port)
    sock.sendall(req.encode())
    head, rest = read_head(sock)
    with open(os.path.join(case_dir, "head.txt"), "w") as f:
        f.write(head)
    if not is_ws(headers):
        body = read_body(sock, head, rest)
        sock.close()
        if body:
            with open(os.path.join(case_dir, "body.txt"), "wb") as f:
                f.write(body)
        return 0
    send_path = os.path.join(case_dir, "send.txt")
    sends = [l.strip() for l in open(send_path) if l.strip()] \
        if os.path.isfile(send_path) else []
    out = []
    for line in sends:
        send_line(sock, line, case_dir)
        out.append("> " + render_send(line, case_dir))
        frame = recv_frame(sock)
        kind = line.split(" ", 1)[0]
        want_op = OP_TEXT if kind == "text-file" else OP_BIN
        if kind in ("text-file", "binary-file") and frame is not None \
                and not frame[3] and frame[1] == want_op:
            name = line.split(" ", 1)[1].strip()
            if frame[2] == open(os.path.join(case_dir, name), "rb").read():
                out.append("< " + line)
                continue
        out.append("< " + render_frame(frame, case_dir))
        if frame is None:
            break
        if frame[1] == OP_CLOSE:
            # server may still hang up; probe for eof
            try:
                nxt = recv_frame(sock)
                out.append("< " + render_frame(nxt, case_dir))
            except socket.timeout:
                pass
            break
    else:
        # no close expected — confirm the conn stays open briefly
        sock.settimeout(0.5)
        try:
            nxt = recv_frame(sock)
            if nxt is not None:
                out.append("< " + render_frame(nxt, case_dir))
        except socket.timeout:
            pass
        sock.settimeout(TIMEOUT)
    sock.close()
    with open(os.path.join(case_dir, "frames.txt"), "w") as f:
        f.write("\n".join(out) + "\n")
    return 0


# ---------- close ----------

def close_case(base, case_dir, verbose):
    host, port = base
    method, path, headers = read_spec(case_dir)
    req = f"{method} {path} HTTP/1.1\r\n" + "".join(
        f"{k}: {v}\r\n" for k, v in headers.items()) + "\r\n"
    sock = connect(host, port)
    sock.sendall(req.encode())
    try:
        head, rest = read_head(sock)
    except socket.timeout:
        sock.close()
        return "cant-tell", "no response head"
    exp_head_path = os.path.join(case_dir, "head.txt")
    if not os.path.isfile(exp_head_path):
        sock.close()
        return "cant-tell", "missing head.txt"
    exp_head = open(exp_head_path, "rb").read().decode("utf-8", "replace")
    if norm_head(head) != norm_head(exp_head):
        sock.close()
        return "fail", f"head mismatch\n  got: {head!r}\n  exp: {exp_head!r}"
    if not is_ws(headers):
        body = read_body(sock, head, rest)
        sock.close()
        exp_body_path = os.path.join(case_dir, "body.txt")
        exp_body = open(exp_body_path, "rb").read() if os.path.isfile(exp_body_path) else b""
        if body != exp_body:
            return "fail", f"body mismatch\n  got: {body[:200]!r}\n  exp: {exp_body[:200]!r}"
        return "pass", ""
    frames_path = os.path.join(case_dir, "frames.txt")
    if not os.path.isfile(frames_path):
        sock.close()
        return "cant-tell", "missing frames.txt"
    spec = [l.rstrip("\n") for l in open(frames_path) if l.strip()]
    ok, detail = True, ""
    for line in spec:
        direction, _, content = line.partition(" ")
        if direction == ">":
            try:
                send_line(sock, content, case_dir)
            except (BrokenPipeError, ConnectionResetError, socket.timeout) as e:
                ok, detail = False, f"send {content!r} failed: {e}"
                break
            continue
        # `<` line — expected server frame
        try:
            frame = recv_frame(sock)
        except socket.timeout:
            ok, detail = False, f"timeout awaiting {content!r}"
            break
        got = render_frame(frame, case_dir)
        # large-payload comparison by file or literal
        if content.startswith(("text-file ", "binary-file ")):
            exp_payload = open(os.path.join(case_dir, content.split(" ", 1)[1]), "rb").read()
            want_text = content.startswith("text-file")
            op_ok = frame is not None and frame[1] == (OP_TEXT if want_text else OP_BIN)
            if frame is None or not op_ok or frame[2] != exp_payload or frame[3]:
                ok, detail = False, f"got {got[:120]!r}, expected {content!r}"
                break
        elif got != content:
            ok, detail = False, f"got {got!r}, expected {content!r}"
            break
    sock.close()
    return ("pass" if ok else "fail"), detail


def iter_cases(goldens, only):
    for name in sorted(os.listdir(goldens)):
        if only and name != only:
            continue
        d = os.path.join(goldens, name)
        if os.path.isdir(d) and os.path.isfile(os.path.join(d, "case.txt")):
            yield name, d


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["capture", "close"])
    ap.add_argument("--base", required=True, help="host:port")
    ap.add_argument("--goldens", required=True)
    ap.add_argument("--only")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    host, _, port = args.base.partition(":")
    base = (host or "127.0.0.1", int(port))
    results = {"pass": 0, "fail": 0, "cant-tell": 0}
    for name, case_dir in iter_cases(args.goldens, args.only):
        try:
            if args.mode == "capture":
                capture_case(base, case_dir)
                verdict, detail = "capture", ""
            else:
                verdict, detail = close_case(base, case_dir, args.verbose)
        except Exception as e:
            verdict, detail = "cant-tell", f"{type(e).__name__}: {e}"
        print(f"{verdict:>9} {name}" + (f" — {detail}" if detail and args.verbose else ""))
        if verdict in results:
            results[verdict] += 1
    if args.mode == "close":
        total = sum(results.values())
        ct_pct = (100 * results["cant-tell"] // total) if total else 0
        print(f"\n{results['pass']}/{total} pass, {results['fail']} fail, "
              f"{results['cant-tell']} cant-tell ({ct_pct}%)")
        sys.exit(1 if results["fail"] or results["cant-tell"] else 0)


if __name__ == "__main__":
    main()
