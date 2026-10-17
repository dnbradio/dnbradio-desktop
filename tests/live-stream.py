#!/usr/bin/env python3
"""Check real HTTPS live startup and restart with isolated player state."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory(prefix="dnbradio-live-") as state:
    env = dict(os.environ, DNBRADIO_DATA_DIR=state, QT_FORCE_STDERR_LOGGING="1")
    result = subprocess.run([sys.argv[1], "--test-qml", str(Path(__file__).with_suffix(".qml").resolve())],
                            env=env, capture_output=True, text=True, timeout=100)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and output.count("PASS: live HTTPS radio") == 2, "Live MP3/AAC failed"
    assert output.count("PASS: live HTTPS restart") == 2 and "PASS: live pause and source change" in output, "Live restart failed"
    assert not re.search(r"TypeError:|ReferenceError:|Binding loop|Cannot assign|Unable to assign|FAIL:", output), "Live QML error"
