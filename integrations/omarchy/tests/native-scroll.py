#!/usr/bin/env python3
"""Native Qt input regression. Requires g++, pkg-config, Qt6Quick and Qt6Test headers."""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

source = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix="dnbradio-scroll-test-") as directory:
    binary = str(Path(directory) / "scroll-input")
    flags = shlex.split(subprocess.check_output(
        ["pkg-config", "--cflags", "--libs", "Qt6Quick", "Qt6Test"], text=True))
    subprocess.run(["g++", "-std=c++17", "-fPIC", str(source / "scroll-input.cpp"), "-o", binary, *flags], check=True)
    subprocess.run([binary, str(source / "scroll-input.qml")], check=True,
                   env=dict(os.environ, QT_QPA_PLATFORM=os.environ.get("QT_QPA_PLATFORM", "offscreen")))
