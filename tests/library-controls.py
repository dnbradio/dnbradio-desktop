#!/usr/bin/env python3
"""Click library and return-to-live controls in isolated full and mini players."""
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

server = ThreadingHTTPServer(("127.0.0.1", 0), fixture.Handler)
base = f"http://127.0.0.1:{server.server_port}"
fixture.mix["profile_image"] = fixture.event["image"] = base + "/art.svg"
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix="dnbradio-library-controls-") as state:
        env = dict(os.environ, DNBRADIO_DATA_DIR=state, DNBRADIO_API_BASE=base,
                   DNBRADIO_NOWPLAYING_URL=base + "/nowplaying", DNBRADIO_BASSDRIVE_URL=base + "/bassdrive",
                   QT_FORCE_STDERR_LOGGING="1")
        env.setdefault("QT_QPA_PLATFORM", {"darwin": "cocoa", "win32": "windows"}.get(sys.platform, "offscreen"))
        result = subprocess.run([str(Path(sys.argv[1]).resolve()), "--test-qml", str(Path(__file__).with_suffix(".qml").resolve())],
                                cwd=Path(__file__).resolve().parents[1], env=env, capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=100)
        output = result.stdout + result.stderr
        print(output, flush=True)
        assert result.returncode == 0 and "PASS: library add/remove" in output, "Library controls failed"
        assert not re.search(r"TypeError:|ReferenceError:|Binding loop|Cannot assign|Unable to assign|FAIL:", output)
        library = json.loads((Path(state) / "library.json").read_text())
        assert library["favorites"] == [] and library["recent"] == [], "Removed entries must stay removed on disk"
finally:
    server.shutdown()
