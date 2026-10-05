#!/usr/bin/env python3
"""bytes-closer — rung-1 closer for the web gauntlet.

Replays each fixture case against a server under test and diffs the wire
response against the captured topcoat golden. Verdicts per case:
  pass      — status line, headers (post-normalization), and body all match
  fail      — at least one differs
  cant-tell — the case spec or golden is unreadable/unsupported

Normalization policy (deliberately narrow — every entry here is a
fixture-authoring concession, none are conformance gaps):
  - `date` response header value: volatile by spec (1s granularity), replaced
    with <DATE> on both sides before comparison. Everything else compares raw.
  - multipart request bodies are re-encoded with a fixed boundary; the golden
    body/response must be boundary-insensitive for the case to pass.

Usage:
  bytes_closer.py --base http://127.0.0.1:PORT [--goldens DIR] [--verbose]
"""

import argparse
import http.client
import os
import re
import sys
import urllib.parse

DATE_RE = re.compile(r"^date:\s*.*$", re.IGNORECASE | re.MULTILINE)
MP_BOUNDARY = "bytes-closer-fixed-boundary-00"

# LEDGER P3 (ratified 2026-10-05, Lars's delegation): informational extras the
# claimant may emit without failing. ENUMERATED, not wildcarded — any other
# extra header still fails loudly. Missing headers are never tolerated.
TOLERATED_EXTRAS = {"connection", "x-powered-by", "x-orisha"}


def load_case(case_dir):
    """Return (request, expected) or raise for cant-tell."""
    case_path = os.path.join(case_dir, "case.txt")
    head_path = os.path.join(case_dir, "head.txt")
    if not (os.path.isfile(case_path) and os.path.isfile(head_path)):
        raise ValueError("missing case.txt or head.txt")
    with open(case_path) as f:
        spec = [l.rstrip("\n") for l in f if l.strip()]
    method, path = spec[0].split(" ", 1)
    headers = {}
    multipart_field = None
    for line in spec[1:]:
        if line.startswith("multipart-field:"):
            multipart_field = line.split(":", 1)[1].strip()
            continue
        k, _, v = line.partition(":")
        headers[k.strip()] = v.strip()
    body_path = os.path.join(case_dir, "req-body.bin")
    body = open(body_path, "rb").read() if os.path.isfile(body_path) else None
    if multipart_field is not None:
        name, _, filename = multipart_field.partition("=")
        with open(os.path.join(case_dir, filename), "rb") as f:
            payload = f.read()
        body = (
            f"--{MP_BOUNDARY}\r\n"
            f'Content-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'
            f"Content-Type: application/octet-stream\r\n\r\n"
        ).encode() + payload + f"\r\n--{MP_BOUNDARY}--\r\n".encode()
        headers["content-type"] = f"multipart/form-data; boundary={MP_BOUNDARY}"
    for cand in ("body.html", "body.txt"):
        p = os.path.join(case_dir, cand)
        if os.path.isfile(p):
            expected_body = open(p, "rb").read()
            break
    else:
        raise ValueError("no golden body file")
    with open(head_path, "rb") as f:
        expected_head = f.read()
    return (method, path, headers, body), expected_head, expected_body


def normalize_head(raw):
    """Split status line + headers; blank Date; lowercase header NAMES
    (case-insensitive by RFC 9110 §5.1 — values compare verbatim)."""
    text = raw.decode("latin-1").replace("\r\n", "\n")
    status, _, rest = text.partition("\n")
    rest = DATE_RE.sub("date: <DATE>", rest)
    headers = []
    for line in rest.strip().split("\n"):
        if not line.strip():
            continue
        name, _, value = line.partition(":")
        headers.append(f"{name.strip().lower()}: {value.strip()}")
    return status.strip(), sorted(headers)


def verdicts(goldens, base, only=None):
    host, _, port = urllib.parse.urlsplit(base).netloc.partition(":")
    results = {}
    for fixture in sorted(os.listdir(goldens)):
        if only and fixture != only:
            continue
        fdir = os.path.join(goldens, fixture)
        if not os.path.isdir(fdir):
            continue
        # A fixture dir may be a single case (hello-world) or a dir of cases.
        cases = [fdir] if os.path.isfile(os.path.join(fdir, "case.txt")) else [
            os.path.join(fdir, c) for c in sorted(os.listdir(fdir))
        ]
        for cdir in cases:
            case = os.path.basename(cdir)
            key = fixture if cdir == fdir else f"{fixture}/{case}"
            if not os.path.isdir(cdir):
                continue
            try:
                (method, path, headers, body), exp_head, exp_body = load_case(cdir)
            except Exception as e:
                results[key] = ("cant-tell", f"spec: {e}")
                continue
            try:
                conn = http.client.HTTPConnection(host, int(port or 80), timeout=10)
                conn.request(method, path, body=body, headers=headers)
                resp = conn.getresponse()
                got_head = (
                    f"HTTP/{resp.version // 10}.{resp.version % 10} "
                    f"{resp.status} {resp.reason}\n"
                    + "\n".join(f"{k}: {v}" for k, v in resp.getheaders())
                ).encode("latin-1")
                got_body = resp.read()
                conn.close()
            except Exception as e:
                results[key] = ("cant-tell", f"replay: {e}")
                continue
            e_status, e_headers = normalize_head(exp_head)
            g_status, g_headers = normalize_head(got_head)
            diffs = []
            notes = []
            if e_status != g_status:
                diffs.append(f"status: want {e_status!r} got {g_status!r}")
            if e_headers != g_headers:
                e_names = {h.split(":")[0] for h in e_headers}
                g_names = {h.split(":")[0] for h in g_headers}
                parts = []
                missing = e_names - g_names
                extra = g_names - e_names
                tolerated = sorted(extra & TOLERATED_EXTRAS)
                extra -= TOLERATED_EXTRAS
                changed = [
                    n for n in e_names & g_names
                    if [h for h in e_headers if h.startswith(n)] != [h for h in g_headers if h.startswith(n)]
                ]
                if missing:
                    parts.append("missing " + ",".join(sorted(missing)))
                if extra:
                    parts.append("extra " + ",".join(sorted(extra)))
                if changed:
                    parts.append("value-differs " + ",".join(sorted(changed)))
                if parts:
                    diffs.append("headers: " + "; ".join(parts))
                if tolerated:
                    notes.append("tolerated-extra " + ",".join(tolerated))
            if exp_body != got_body:
                diffs.append(
                    f"body: want {len(exp_body)}B got {len(got_body)}B"
                    + ("" if len(exp_body) != len(got_body) else " (same length)")
                )
            detail = "; ".join(diffs + notes)
            results[key] = ("pass" if not diffs else "fail", detail)
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True, help="server under test, e.g. http://127.0.0.1:3000")
    ap.add_argument("--goldens", default=os.path.join(os.path.dirname(__file__), "..", "goldens"))
    ap.add_argument("--fixture", help="run one fixture dir only (self-certification needs per-server bases)")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    results = verdicts(os.path.abspath(args.goldens), args.base, args.fixture)
    counts = {"pass": 0, "fail": 0, "cant-tell": 0}
    for key in sorted(results):
        v, detail = results[key]
        counts[v] += 1
        mark = {"pass": "PASS", "fail": "FAIL", "cant-tell": "CANT-TELL"}[v]
        if args.verbose or v != "pass":
            print(f"{mark:9s} {key}" + (f"  — {detail}" if detail else ""))
    total = sum(counts.values())
    ct_frac = counts["cant-tell"] / total if total else 0.0
    print(
        f"\n{counts['pass']}/{total} pass, {counts['fail']} fail, "
        f"{counts['cant-tell']} cant-tell ({ct_frac:.0%})"
    )
    sys.exit(1 if counts["fail"] or counts["cant-tell"] else 0)


if __name__ == "__main__":
    main()
