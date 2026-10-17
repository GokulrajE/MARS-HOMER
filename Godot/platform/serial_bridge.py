#!/usr/bin/env python3
"""Serial bridge for Linux, macOS and Raspberry Pi (Python 3 standard library only).

Godot cannot open serial devices itself, so MARS HOMER starts this helper. It talks to the
application over a local, token-authenticated TCP socket with newline-delimited JSON (the
same protocol as serial_bridge.ps1 on Windows):

    bridge -> app   {"token": "..."}            first line, proves who started the bridge
    bridge -> app   {"connected": true}         the device is open
    bridge -> app   {"bytes": "<base64>"}       bytes read from the device
    bridge -> app   {"error": "..."}            the device could not be opened or was lost
    app -> bridge   {"bytes": "<base64>"}       bytes to write to the device
    app -> bridge   {"close": true}             shut down

Port forms:
    /dev/rfcomm0, /dev/ttyUSB0, /dev/ttyACM0, /dev/serial0   a serial device (115200 8N1)
    bt:AA:BB:CC:DD:EE[:channel]                              Bluetooth RFCOMM straight to the
                                                             robot, no `rfcomm bind` or root
    tcp:host:port                                            a serial-over-network server
"""
import argparse
import base64
import json
import os
import select
import socket
import sys
import time


def send(sock, message):
    sock.sendall((json.dumps(message, separators=(",", ":")) + "\n").encode("utf-8"))


class Device:
    """A byte stream to the robot, whatever it is physically."""

    def __init__(self, port):
        self.fd = None
        self.sock = None
        if port.startswith("bt:"):
            parts = port[3:].split(":")
            if len(parts) not in (6, 7):
                raise ValueError("Use bt:AA:BB:CC:DD:EE or bt:AA:BB:CC:DD:EE:channel")
            address = ":".join(parts[:6])
            channel = int(parts[6]) if len(parts) == 7 else 1
            if not hasattr(socket, "AF_BLUETOOTH") or not hasattr(socket, "BTPROTO_RFCOMM"):
                raise RuntimeError("This Python has no Bluetooth RFCOMM support")
            self.sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
            self.sock.settimeout(10)
            self.sock.connect((address, channel))
            self.sock.setblocking(False)
        elif port.startswith("tcp:"):
            host, _, number = port[4:].rpartition(":")
            self.sock = socket.create_connection((host, int(number)), timeout=10)
            self.sock.setblocking(False)
        elif port.startswith("/dev/"):
            self._open_serial(port)
        else:
            raise ValueError("Unsupported port: " + port)

    def _open_serial(self, path):
        import termios
        self.fd = os.open(path, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        try:
            attributes = termios.tcgetattr(self.fd)
        except termios.error:
            # Some Bluetooth/pty nodes cannot be configured; they are already raw byte pipes.
            return
        # Raw 115200 8N1, no flow control, receiver on.
        attributes[0] = 0
        attributes[1] = 0
        attributes[2] = (attributes[2] & ~(termios.CSIZE | termios.PARENB | termios.CSTOPB | getattr(termios, "CRTSCTS", 0))) | termios.CS8 | termios.CREAD | termios.CLOCAL
        attributes[3] = 0
        attributes[4] = attributes[5] = termios.B115200
        attributes[6][termios.VMIN] = 0
        attributes[6][termios.VTIME] = 0
        termios.tcsetattr(self.fd, termios.TCSANOW, attributes)
        try:
            import fcntl
            import struct
            fcntl.ioctl(self.fd, termios.TIOCMBIS, struct.pack("I", termios.TIOCM_DTR))
        except (OSError, ImportError, AttributeError):
            pass
        termios.tcflush(self.fd, termios.TCIOFLUSH)

    def readable(self):
        return self.sock if self.sock is not None else self.fd

    def read(self):
        if self.sock is not None:
            data = self.sock.recv(4096)
            if not data:
                raise ConnectionError("The robot closed the connection")
            return data
        return os.read(self.fd, 4096)

    def write(self, data):
        deadline = time.monotonic() + 1.0
        view = memoryview(data)
        while len(view):
            if time.monotonic() > deadline:
                raise TimeoutError("Serial write timed out; connection closed")
            try:
                written = self.sock.send(view) if self.sock is not None else os.write(self.fd, view)
            except BlockingIOError:
                select.select([], [self.readable()], [], 0.1)
                continue
            if written == 0:
                raise ConnectionError("Device stopped accepting data")
            view = view[written:]

    def close(self):
        try:
            if self.sock is not None:
                self.sock.close()
            if self.fd is not None:
                os.close(self.fd)
        except OSError:
            pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True)
    parser.add_argument("--socket", type=int, required=True)
    parser.add_argument("--token", required=True)
    args = parser.parse_args()
    app = socket.create_connection(("127.0.0.1", args.socket), timeout=10)
    app.setblocking(True)
    device = None
    try:
        send(app, {"token": args.token})
        device = Device(args.port)
        send(app, {"connected": True})
        pending = b""
        while True:
            ready, _, _ = select.select([app, device.readable()], [], [], 0.05)
            if device.readable() in ready:
                try:
                    data = device.read()
                except BlockingIOError:
                    data = b""
                if data:
                    send(app, {"bytes": base64.b64encode(data).decode("ascii")})
            if app in ready:
                chunk = app.recv(4096)
                if not chunk:
                    break
                pending += chunk
                if len(pending) > 65536:
                    raise ValueError("Invalid bridge message")
                while b"\n" in pending:
                    line, pending = pending.split(b"\n", 1)
                    if not line.strip():
                        continue
                    message = json.loads(line.decode("utf-8"))
                    if message.get("close"):
                        return
                    if message.get("bytes"):
                        device.write(base64.b64decode(message["bytes"]))
    except Exception as error:  # noqa: BLE001 - reported to the app, then the bridge ends
        try:
            send(app, {"error": str(error)})
        except OSError:
            pass
        print(str(error), file=sys.stderr)
    finally:
        if device is not None:
            device.close()
        app.close()


if __name__ == "__main__":
    main()

