#!/usr/bin/env python3
"""The connection watchdog clears once audio plays: after a resume seek and on a live-paced stream."""
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import threading
import time
from http.server import ThreadingHTTPServer
import fixture_server as fixture

RATE = 8000
CHUNK = b"\x00\x00" * (RATE // 10)
live_requests = []


class Handler(fixture.Handler):
    def do_GET(self):
        if self.path != "/live.wav":
            return super().do_GET()
        live_requests.append(self.path)
        # Like an Icecast mount: no length or ranges, a short burst, then audio in real time,
        # so the media backend can never queue four seconds ahead.
        self.send_response(200)
        self.send_header("Content-Type", "audio/wav")
        self.end_headers()
        try:
            self.wfile.write(struct.pack("<4sI4s4sIHHIIHH4sI", b"RIFF", 0xFFFFFFFF, b"WAVE", b"fmt ", 16, 1, 1,
                                         RATE, RATE * 2, 2, 16, b"data", 0xFFFFFFFF))
            start = time.monotonic()
            for index in range(450):
                if index >= 15:
                    time.sleep(max(0, start + (index - 15) / 10 - time.monotonic()))
                self.wfile.write(CHUNK)
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
base = f"http://127.0.0.1:{server.server_port}"
fixture.mix["profile_image"] = fixture.event["image"] = base + "/art.svg"
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix="dnbradio-watchdog-") as state:
        env = dict(os.environ, DNBRADIO_DATA_DIR=state, DNBRADIO_API_BASE=base,
                   DNBRADIO_NOWPLAYING_URL=base + "/nowplaying", DNBRADIO_BASSDRIVE_URL=base + "/bassdrive",
                   QT_FORCE_STDERR_LOGGING="1")
        env.setdefault("QT_QPA_PLATFORM", {"darwin": "cocoa", "win32": "windows"}.get(sys.platform, "offscreen"))
        result = subprocess.run([sys.argv[1], "--test-qml", str(Path(__file__).with_suffix(".qml").resolve())],
                                env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=100)
        output = result.stdout + result.stderr
        print(output, flush=True)
        assert result.returncode == 0 and "PASS: connection watchdog" in output, "Connection watchdog failed"
        assert not re.search(r"TypeError:|ReferenceError:|Binding loop|Cannot assign|Unable to assign|FAIL:", output)
        assert live_requests, "The live stage must play the live-paced fixture"
finally:
    server.shutdown()
