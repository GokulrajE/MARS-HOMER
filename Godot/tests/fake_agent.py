"""A stand-in for agent.py's local API (/start /stop /trial-ended /check /status).
Usage: python fake_agent.py <port> <log file>. Every request line is appended to the log file."""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

PORT = int(sys.argv[1])
LOG = sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        with open(LOG, "a", encoding="utf-8") as handle:
            handle.write(self.path + "\n")
        patient = (parse_qs(parsed.query).get("patient") or [""])[0]
        if parsed.path == "/status":
            self.reply(200, {"client": "fake", "device": "NOARK", "patient": None, "lost": None, "server_reachable": True})
        elif parsed.path == "/start":
            if patient == "busy-patient":
                self.reply(409, {"message": "User is using another device"})
            else:
                self.reply(200, {"ok": True})
        elif parsed.path == "/trial-ended":
            self.reply(200, {"ok": True, "lost": None})
        elif parsed.path == "/stop":
            self.reply(200, {"ok": True})
        else:
            self.reply(404, {})


HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
