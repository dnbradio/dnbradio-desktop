#!/usr/bin/env python3
"""Exercise the desktop tray lifecycle and both windows with native Qt input."""
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
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix="dnbradio-menu-bar-") as state:
        env = dict(os.environ, DNBRADIO_DATA_DIR=state, DNBRADIO_API_BASE=base,
                   DNBRADIO_NOWPLAYING_URL=base + "/nowplaying", DNBRADIO_BASSDRIVE_URL=base + "/bassdrive")
        env.setdefault("QT_QPA_PLATFORM", {"darwin": "cocoa", "win32": "windows"}.get(sys.platform, "xcb"))
        harness = str(Path(__file__).with_suffix(".qml").resolve())
        if sys.platform == "darwin":
            log = Path(state) / "output.log"
            command = ["/usr/bin/open", "-n", "-W", "-a", str(Path(sys.argv[1]).resolve().parents[2]),
                       "--stdout", str(log), "--stderr", str(log)]
            for key in ("DNBRADIO_DATA_DIR", "DNBRADIO_API_BASE", "DNBRADIO_NOWPLAYING_URL", "DNBRADIO_BASSDRIVE_URL", "QT_QPA_PLATFORM"):
                command.extend(["--env", key + "=" + env[key]])
            command.extend(["--args", "--test-qml", harness])
        else:
            command = [sys.argv[1], "--test-qml", harness]
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=100)
        output = result.stdout + result.stderr
        if sys.platform == "darwin" and log.exists():
            output = log.read_text() + output
        print(output)
        assert result.returncode == 0 and "PASS: menu-bar" in output, "Menu-bar smoke failed"
        assert not re.search(r"TypeError:|ReferenceError:|Binding loop|Cannot assign|Unable to assign|FAIL:", output), "QML runtime error"
        settings = configparser.ConfigParser()
        settings.read(Path(state) / "player.ini")
        assert settings.getfloat("General", "volume") > 0.6, "Mini Quit must save volume"
        assert settings.get("General", "station") == "jungletrain.net", "Mini Quit must save station"
finally:
    server.shutdown()
