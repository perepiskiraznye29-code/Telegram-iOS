"""Mechagram preview ledger. No Telegram credentials, payments or NFT ownership.

Installations may publish their own visual records for arbitrary recipient IDs.
Bearer tokens authorize an installation, never a Telegram identity. Public reads
are intentional; payloads must contain only gift metadata, no peer objects.
"""
import base64
import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import ssl
import threading
import time
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DB = os.environ.get("MECHAGRAM_DB", "/var/lib/mechagram/ledger.sqlite3")
MAX_BODY = 262144
LOCK = threading.Lock()
LIMITS = {}


@contextmanager
def connect():
    db = sqlite3.connect(DB, timeout=10)
    try:
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA max_page_count=51200")
        with db:
            yield db
    finally:
        db.close()


def initialize():
    with connect() as db:
        db.executescript("""
        CREATE TABLE IF NOT EXISTS installations(id TEXT PRIMARY KEY, digest TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS gifts(installation TEXT NOT NULL, id TEXT NOT NULL,
          owner TEXT NOT NULL, payload TEXT NOT NULL, worn INTEGER NOT NULL DEFAULT 0,
          updated INTEGER NOT NULL, PRIMARY KEY(installation,id));
        CREATE INDEX IF NOT EXISTS gift_owner ON gifts(owner);
        CREATE INDEX IF NOT EXISTS gift_versions ON gifts(id,updated);
        CREATE TABLE IF NOT EXISTS gift_history(id TEXT NOT NULL,owner TEXT NOT NULL,PRIMARY KEY(id,owner));
        """)


class Handler(BaseHTTPRequestHandler):
    server_version = "Mechagram"

    def log_message(self, *_):
        pass  # Never log tokens, recipient IDs or payloads.

    def setup(self):
        super().setup()
        self.connection.settimeout(10)

    def reply(self, code, value):
        data = json.dumps(value, separators=(",", ":")).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(data)

    def limited(self, registration=False):
        window = int(time.time()) // (3600 if registration else 60)
        key = (self.client_address[0], registration, window)
        with LOCK:
            if len(LIMITS) > 10000:
                LIMITS.clear()
            LIMITS[key] = LIMITS.get(key, 0) + 1
            return LIMITS[key] > (20 if registration else 180)

    def do_GET(self):
        if self.path == "/health":
            self.reply(200, {"ok": True, "protocol": 1})
            return
        if self.limited():
            self.reply(429, {"error": "rate_limit"})
            return
        match = re.fullmatch(r"/v1/profile/([0-9]{1,20})", self.path)
        if not match:
            self.reply(404, {"error": "not_found"})
            return
        with connect() as db:
            rows = db.execute("SELECT payload,worn,id FROM gifts g WHERE owner=? AND updated=(SELECT MAX(updated) FROM gifts newer WHERE newer.id=g.id) ORDER BY updated DESC LIMIT 300", (match[1],)).fetchall()
            moved = [r[0] for r in db.execute("SELECT id FROM gift_history g WHERE owner=? AND EXISTS(SELECT 1 FROM gifts n WHERE n.id=g.id AND n.owner<>g.owner AND n.updated=(SELECT MAX(updated) FROM gifts v WHERE v.id=g.id)) LIMIT 2000", (match[1],))]
        # Copies of the same public NFT may exist in separate installations.
        seen, gifts = set(), []
        total = 0
        for payload, worn, gift_id in rows:
            if gift_id in seen:
                continue
            seen.add(gift_id)
            total += len(payload)
            if total > 7_000_000:
                break
            gifts.append({"payload": payload, "worn": bool(worn), "id": gift_id})
        self.reply(200, {"gifts": gifts, "moved": moved})

    def do_POST(self):
        registration = self.path == "/v1/register"
        if self.path not in ("/v1/register", "/v1/gift"):
            self.reply(404, {"error": "not_found"})
            return
        if self.limited(registration):
            self.reply(429, {"error": "rate_limit"})
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= MAX_BODY:
                raise ValueError("size")
            value = json.loads(self.rfile.read(size))
            if not isinstance(value, dict):
                raise ValueError("object")
        except (ValueError, OSError):
            self.reply(400, {"error": "invalid_body"})
            return
        if registration:
            token, installation = secrets.token_urlsafe(32), secrets.token_hex(16)
            with connect() as db:
                count = db.execute("SELECT COUNT(*) FROM installations").fetchone()[0]
                if count >= 10000:
                    self.reply(503, {"error": "capacity"})
                    return
                db.execute("INSERT INTO installations VALUES(?,?)", (installation, hashlib.sha256(token.encode()).hexdigest()))
            self.reply(201, {"installation": installation, "token": token})
            return
        installation = self.headers.get("X-Mechagram-Installation", "")
        token = self.headers.get("Authorization", "").removeprefix("Bearer ")
        with connect() as db:
            auth = db.execute("SELECT digest FROM installations WHERE id=?", (installation,)).fetchone()
            if not auth or not hmac.compare_digest(auth[0], hashlib.sha256(token.encode()).hexdigest()):
                self.reply(401, {"error": "unauthorized"})
                return
            try:
                gift_id, owner, payload = value["id"], value["owner"], value["payload"]
                if not all(isinstance(x, str) for x in (gift_id, owner, payload)) or not re.fullmatch(r"[0-9]{1,20}", gift_id) or not re.fullmatch(r"[0-9]{1,20}", owner):
                    raise ValueError("id")
                decoded = json.loads(base64.b64decode(payload, validate=True))
                # The native Codable wrapper has fields g/r/fp/d/...; no sender,
                # message text or entity objects may be published.
                allowed = {"gift", "date", "nameHidden", "savedToProfile", "pinnedToTop", "canUpgrade", "upgradeSeparate", "isRefunded"}
                if not isinstance(decoded, dict) or len(payload) > 240000 or not set(decoded).issubset(allowed) or "gift" not in decoded:
                    raise ValueError("payload")
                if db.execute("SELECT COUNT(*) FROM gifts WHERE installation=?", (installation,)).fetchone()[0] >= 2000 and not db.execute("SELECT 1 FROM gifts WHERE installation=? AND id=?", (installation, gift_id)).fetchone():
                    self.reply(409, {"error": "capacity"})
                    return
            except (KeyError, ValueError, TypeError):
                self.reply(400, {"error": "invalid_gift"})
                return
            db.execute("INSERT OR IGNORE INTO gift_history VALUES(?,?)", (gift_id, owner))
            db.execute("INSERT INTO gifts VALUES(?,?,?,?,?,?) ON CONFLICT(installation,id) DO UPDATE SET owner=excluded.owner,payload=excluded.payload,worn=excluded.worn,updated=excluded.updated", (installation, gift_id, owner, payload, int(value.get("worn") is True), time.time_ns()))
        self.reply(200, {"ok": True})


if __name__ == "__main__":
    initialize()
    server = ThreadingHTTPServer(("0.0.0.0", 8443), Handler)
    server.daemon_threads = True
    tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    tls.minimum_version = ssl.TLSVersion.TLSv1_2
    tls.load_cert_chain(os.environ["MECHAGRAM_CERT"], os.environ["MECHAGRAM_KEY"])
    server.socket = tls.wrap_socket(server.socket, server_side=True)
    server.serve_forever()
