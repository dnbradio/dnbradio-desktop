#!/usr/bin/env python3
"""Run the actual Qt application against an isolated local API and audio fixture."""
import json
import configparser
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
fixture.mix["image"] = base + "/missing.svg"
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix="dnbradio-smoke-") as state:
        env = dict(os.environ, DNBRADIO_DATA_DIR=state, DNBRADIO_API_BASE=base,
                   DNBRADIO_NOWPLAYING_URL=base + "/nowplaying", DNBRADIO_BASSDRIVE_URL=base + "/bassdrive")
        env.setdefault("QT_QPA_PLATFORM", "cocoa" if sys.platform == "darwin" else "offscreen")
        result = subprocess.run([sys.argv[1], "--test-qml", str(Path(__file__).with_name("smoke.qml"))],
                                env=env, capture_output=True, text=True, timeout=80)
        output = result.stdout + result.stderr
        print(output)
        assert result.returncode == 0 and "PASS: standalone" in output, "Native smoke failed"
        assert not re.search(r"TypeError:|ReferenceError:|Binding loop|Cannot assign|Unable to assign|FAIL:", output), "QML runtime error"
        library = json.loads((Path(state) / "library.json").read_text())
        assert library["favorites"][0]["id"] == "58079"
        assert library["recent"][0]["position"] >= 2900
        assert len(library["notified"]) == 1
        settings = configparser.ConfigParser()
        settings.read(Path(state) / "player.ini")
        assert settings.getfloat("General", "volume") == 0.37, "Tray Quit must save before exiting"
        assert any(q.get("dj") == ["djfk"] and q.get("page") == ["2"] for p, q in fixture.requests if p == "/api/podcast")
finally:
    server.shutdown()
