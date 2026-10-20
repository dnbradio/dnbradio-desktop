#!/usr/bin/env python3
"""Check delayed live starts and cancellation with local media fixtures."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import threading
from http.server import ThreadingHTTPServer
import fixture_server as fixture


class Handler(fixture.Handler):
    def do_GET(self):
        if self.path in ("/live.mp3", "/live.aac"):
            self.path = "/audio.wav"
        super().do_GET()


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
base = f"http://127.0.0.1:{server.server_port}"
fixture.mix["profile_image"] = fixture.event["image"] = base + "/art.svg"
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix="dnbradio-prebuffer-") as state:
        env = dict(os.environ, DNBRADIO_DATA_DIR=state, DNBRADIO_API_BASE=base,
                   DNBRADIO_NOWPLAYING_URL=base + "/nowplaying", DNBRADIO_BASSDRIVE_URL=base + "/bassdrive",
                   QT_FORCE_STDERR_LOGGING="1")
        result = subprocess.run([sys.argv[1], "--test-qml", str(Path(__file__).with_suffix(".qml").resolve())],
                                env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=45)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "PASS: live prebuffer" in output, "Live prebuffer controls failed"
        assert not re.search(r"TypeError:|ReferenceError:|Binding loop|Cannot assign|Unable to assign|FAIL:", output)
finally:
    server.shutdown()
