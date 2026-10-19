#!/usr/bin/env python3
"""Stores one InputMate settings document. GET /settings, PUT /settings (If-Match: revision).

No credentials: the only way in is the tailnet (`tailscale serve` in front, no public port).
Env: INPUTMATE_SYNC_DIR (default /var/lib/inputmate-sync), INPUTMATE_SYNC_HOST (default
127.0.0.1) and INPUTMATE_SYNC_PORT (default 8787).
"""
import json
import os
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DIR = os.environ.get("INPUTMATE_SYNC_DIR", "/var/lib/inputmate-sync")
HOST = os.environ.get("INPUTMATE_SYNC_HOST", "127.0.0.1")
PORT = int(os.environ.get("INPUTMATE_SYNC_PORT", "8787"))
MAX_BYTES = 256 * 1024
PATH = os.path.join(DIR, "settings.json")


def load():
    try:
        with open(PATH) as f:
            return json.load(f)
    except FileNotFoundError:
        return {"rev": 0, "data": None}


def save(doc):
    fd, tmp = tempfile.mkstemp(dir=DIR)
    with os.fdopen(fd, "w") as f:
        json.dump(doc, f)
    os.replace(tmp, PATH)


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, body=None):
        raw = json.dumps(body).encode() if body is not None else b""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def known_path(self):
        return self.path == "/settings"

    def do_GET(self):
        if not self.known_path():
            return self.reply(404, {"error": "not found"})
        self.reply(200, load())

    def do_PUT(self):
        if not self.known_path():
            return self.reply(404, {"error": "not found"})
        length = int(self.headers.get("Content-Length", "0"))
        if not 0 < length <= MAX_BYTES:
            return self.reply(413, {"error": "bad size"})
        try:
            data = json.loads(self.rfile.read(length))
        except ValueError:
            return self.reply(400, {"error": "bad json"})
        doc = load()
        if self.headers.get("If-Match") != str(doc["rev"]):
            return self.reply(409, doc)
        doc = {"rev": doc["rev"] + 1, "data": data}
        save(doc)
        self.reply(200, doc)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    os.makedirs(DIR, exist_ok=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
