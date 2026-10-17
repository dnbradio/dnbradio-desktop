#!/usr/bin/env python3
"""Real Qt playback and UI controls, with a recoverable HTTP failure and error signal."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import threading
from http.server import ThreadingHTTPServer
import fixture_server as fixture


audio_requests = []


class Handler(fixture.Handler):
    def do_GET(self):
        if self.path == "/retry.wav":
            audio_requests.append(self.headers.get("Range", ""))
            print("HTTP retry.wav", len(audio_requests), audio_requests[-1], flush=True)
            if len(audio_requests) == 1:
                self.send_response(503)
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            self.path = "/audio.wav"
        super().do_GET()


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
base = f"http://127.0.0.1:{server.server_port}"
fixture.mix["profile_image"] = fixture.event["image"] = base + "/art.svg"
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix="dnbradio-retry-") as state:
        env = dict(os.environ, DNBRADIO_DATA_DIR=state, DNBRADIO_API_BASE=base,
                   DNBRADIO_NOWPLAYING_URL=base + "/nowplaying", DNBRADIO_BASSDRIVE_URL=base + "/bassdrive",
                   QT_FORCE_STDERR_LOGGING="1")
        env.setdefault("QT_QPA_PLATFORM", {"darwin": "cocoa", "win32": "windows"}.get(sys.platform, "offscreen"))
        result = subprocess.run([sys.argv[1], "--test-qml", str(Path(__file__).with_suffix(".qml").resolve())],
                                env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=100)
        output = result.stdout + result.stderr
        print(output, flush=True)
        assert result.returncode == 0 and "PASS: playback retry" in output, "Playback retry failed"
        assert not re.search(r"TypeError:|ReferenceError:|Binding loop|Cannot assign|Unable to assign|FAIL:", output)
        assert len(audio_requests) >= 3, "Retries must reopen HTTP, even for the same URL"
        library = json.loads((Path(state) / "library.json").read_text())
        assert library["recent"][0]["position"] >= 10000, "Retry must preserve saved resume position"
finally:
    server.shutdown()
