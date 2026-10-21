"""A small stand-in for the NeuroDash server, speaking the protocol sender.py speaks.
Usage: python fake_neurodash_server.py <port> <output folder>
Everything it receives is written under the output folder so a test can inspect it."""
import json
import os
import socket
import sys
import threading

PORT = int(sys.argv[1])
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
PATIENTS = [
    {"user_id": "AG1", "status": "active", "side": "left", "devices": ["MARS", "PLUTO"]},
    {"user_id": "AG2", "status": "paused", "side": "right", "devices": ["MARS"]},
    {"user_id": "AG3", "status": "active", "side": "right", "devices": ["PLUTO"]},
    {"user_id": "AG4", "status": "active", "side": "right", "devices": ["MARS"]},
]
VERSION = 3
held = {"busy-patient": {"device": "PLUTO", "client": "OTHER-LAPTOP", "seconds_ago": 5}}
known_prints = set()
lock = threading.Lock()


def read_exact(conn, size):
    data = bytearray()
    while len(data) < size:
        chunk = conn.recv(size - len(data))
        if not chunk:
            raise ConnectionError("closed")
        data.extend(chunk)
    return bytes(data)


def reply(conn, payload):
    body = json.dumps(payload).encode("utf-8")
    conn.sendall(len(body).to_bytes(4, "big") + body)


def log(name, content):
    with lock:
        with open(os.path.join(OUT, name), "a", encoding="utf-8") as handle:
            handle.write(content + "\n")


def handle(conn):
    try:
        header = json.loads(read_exact(conn, int.from_bytes(read_exact(conn, 4), "big")).decode("utf-8"))
        action = header.get("action")
        log("requests.log", json.dumps(header, sort_keys=True))
        if action == "sync":
            if int(header.get("patients_version", 0)) >= VERSION:
                reply(conn, {"success": True, "up_to_date": True, "version": VERSION})
            else:
                reply(conn, {"success": True, "up_to_date": False, "version": VERSION, "updated_at": "2026-10-19T10:00:00", "view": "abc123", "patients": PATIENTS})
        elif action == "claim_user":
            user = header["user_id"]
            holder = held.get(user)
            if holder and holder["client"] != header.get("client_id"):
                reply(conn, {"success": True, "claimed": False, "in_use_by": holder})
            else:
                held[user] = {"device": header["device_id"], "client": header["client_id"], "seconds_ago": 0}
                reply(conn, {"success": True, "claimed": True})
        elif action == "release":
            held.pop(header["user_id"], None)
            reply(conn, {"success": True, "released": True})
        elif action == "assessment":
            fingerprint = header["fingerprint"]
            if fingerprint in known_prints:
                reply(conn, {"success": True, "send": False})
            else:
                reply(conn, {"success": True, "send": True})
                payload = read_exact(conn, int(header["file_size"]))
                known_prints.add(fingerprint)
                with open(os.path.join(OUT, "assessment-%s-%s-%s.zip" % (header["patient_id"], header["limb"], header["timepoint"])), "wb") as handle_file:
                    handle_file.write(payload)
                reply(conn, {"success": True})
        else:
            payload = read_exact(conn, int(header["file_size"]))
            with open(os.path.join(OUT, "csv-" + header["filename"]), "wb") as handle_file:
                handle_file.write(payload)
            # A plain CSV upload is answered with raw JSON, not a length-prefixed frame.
            conn.sendall(json.dumps({"success": True}).encode("utf-8"))
    except Exception as error:  # noqa: BLE001
        log("errors.log", repr(error))
    finally:
        conn.close()


server = socket.socket()
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("127.0.0.1", PORT))
server.listen(8)
open(os.path.join(OUT, "ready"), "w").write("ok")
while True:
    connection, _ = server.accept()
    threading.Thread(target=handle, args=(connection,), daemon=True).start()
