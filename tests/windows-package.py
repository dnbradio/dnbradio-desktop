#!/usr/bin/env python3
"""Verify an extracted Windows ZIP and its QA twin without the build environment."""
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import threading
import time
import zipfile
from http.server import ThreadingHTTPServer
import fixture_server as fixture

root = Path(__file__).resolve().parents[1]
evidence = root / "build-windows-package/evidence"
evidence.mkdir(parents=True, exist_ok=True)
errors = r"TypeError:|ReferenceError:|Binding loop|Cannot assign|Unable to assign|FAIL:|module .* is not installed"


def loaded_modules(pid):
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    psapi = ctypes.WinDLL("psapi", use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    psapi.EnumProcessModulesEx.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.HMODULE),
                                          wintypes.DWORD, ctypes.POINTER(wintypes.DWORD), wintypes.DWORD]
    psapi.GetModuleFileNameExW.argtypes = [wintypes.HANDLE, wintypes.HMODULE, wintypes.LPWSTR, wintypes.DWORD]
    process = kernel.OpenProcess(0x0410, False, pid)
    if not process:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        modules = (wintypes.HMODULE * 2048)()
        needed = wintypes.DWORD()
        if not psapi.EnumProcessModulesEx(process, modules, ctypes.sizeof(modules), ctypes.byref(needed), 3):
            raise ctypes.WinError(ctypes.get_last_error())
        assert needed.value <= ctypes.sizeof(modules), "Module list truncated"
        result = []
        for module in modules[:needed.value // ctypes.sizeof(wintypes.HMODULE)]:
            path = ctypes.create_unicode_buffer(32768)
            if not psapi.GetModuleFileNameExW(process, module, path, len(path)):
                raise ctypes.WinError(ctypes.get_last_error())
            result.append(Path(path.value).resolve())
        return result
    finally:
        kernel.CloseHandle(process)


def main():
    archive, qa = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith(("QT", "QML", "DNBRADIO"))}
    env.update(PATH=os.environ["SystemRoot"] + r"\System32;" + os.environ["SystemRoot"],
               QT_QPA_PLATFORM="windows", QT_FORCE_STDERR_LOGGING="1",
               QT_COMMAND_LINE_PARSER_NO_GUI_MESSAGE_BOXES="1")
    server = ThreadingHTTPServer(("127.0.0.1", 0), fixture.Handler)
    base = f"http://127.0.0.1:{server.server_port}"
    fixture.mix["profile_image"] = fixture.event["image"] = base + "/art.svg"
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with tempfile.TemporaryDirectory(prefix="DNBRADIO Windows ZIP ") as temp:
            # TEMP can use RUNNER~1 while Windows reports DLLs under runneradmin.
            work = Path(temp).resolve()
            with zipfile.ZipFile(archive) as package:
                assert package.testzip() is None, "Corrupt ZIP"
                package.extractall(work)
            app_dir = work / "DNBRADIO"
            executable = app_dir / "dnbradio.exe"
            info = json.loads((app_dir / "BUILD-INFO.json").read_text())
            assert not info["build_testing"]
            # Every shipped DLL is also exercised in the test-enabled bundle.
            for dll in app_dir.rglob("*.dll"):
                twin = qa / dll.relative_to(app_dir)
                assert twin.is_file(), f"QA is missing {dll.name}"
                assert hashlib.sha256(dll.read_bytes()).digest() == hashlib.sha256(twin.read_bytes()).digest(), dll
            production_env = dict(env, DNBRADIO_DATA_DIR=str(work / "state"), DNBRADIO_API_BASE=base,
                                  DNBRADIO_NOWPLAYING_URL=base + "/nowplaying", DNBRADIO_BASSDRIVE_URL=base + "/bassdrive")
            result = subprocess.run([str(executable), "--test-qml", "does-not-exist.qml"], env=production_env,
                                    capture_output=True, text=True, timeout=15)
            assert result.returncode != 0 and "Unknown option" in result.stdout + result.stderr, "Test loader enabled"
            log = evidence / "production.log"
            with log.open("w") as output:
                process = subprocess.Popen([str(executable)], cwd=work, env=production_env,
                                           stdout=output, stderr=subprocess.STDOUT)
                try:
                    deadline = time.monotonic() + 20
                    while time.monotonic() < deadline:
                        assert process.poll() is None, f"Production app exited: {log.read_text()}"
                        if {"/api/podcast", "/api/schedule", "/nowplaying"}.issubset({p for p, _ in fixture.requests}):
                            break
                        time.sleep(0.25)
                    else:
                        raise AssertionError("Production UI did not load fixture data")
                    modules = loaded_modules(process.pid)
                    (evidence / "production-modules.txt").write_text("\n".join(map(str, modules)), encoding="utf-8")
                    qt_modules = [p for p in modules if p.name.lower().startswith("qt6")]
                    assert len(qt_modules) >= 10, "Qt modules were not loaded"
                    assert all(p.is_relative_to(app_dir) for p in qt_modules), "Loaded Qt from outside ZIP"
                    for name in ("vcruntime140.dll", "msvcp140.dll", "qwindows.dll", "qsvgicon.dll"):
                        assert any(p.name.lower() == name and p.is_relative_to(app_dir) for p in modules), f"Unbundled {name}"
                    screenshot = str(evidence / "windows-desktop.png").replace("'", "''")
                    subprocess.run(["powershell.exe", "-NoProfile", "-Command",
                        "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; "
                        "$r=[System.Windows.Forms.SystemInformation]::VirtualScreen; "
                        "$b=New-Object System.Drawing.Bitmap($r.Width,$r.Height); $g=[System.Drawing.Graphics]::FromImage($b); "
                        "$g.CopyFromScreen($r.Left,$r.Top,0,0,$b.Size); "
                        f"$b.Save('{screenshot}'); $g.Dispose(); $b.Dispose()"], check=True, timeout=15)
                    print(f"PASS: extracted production ZIP loads UI, icon, bundled Qt and MSVC runtimes ({len(qt_modules)} Qt DLLs)", flush=True)
                finally:
                    process.terminate()
                    process.wait(timeout=10)
            assert not re.search(errors, log.read_text(encoding="utf-8", errors="replace")), "Production QML error"
            for test in ("smoke", "menu-bar"):
                result = subprocess.run([sys.executable, str(root / "tests" / f"{test}.py"), str(qa / "dnbradio.exe")],
                                        env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
                output = result.stdout + result.stderr
                (evidence / f"{test}.log").write_text(output, encoding="utf-8")
                print(output, flush=True)
                assert result.returncode == 0, f"Packaged {test} failed"
            if "--live" in sys.argv[3:]:
                result = subprocess.run([str(qa / "dnbradio.exe"), "--test-qml", str(root / "tests/live-stream.qml")],
                    env=dict(env, DNBRADIO_DATA_DIR=str(work / "live-state")), capture_output=True,
                    text=True, encoding="utf-8", errors="replace", timeout=100)
                output = result.stdout + result.stderr
                (evidence / "live-stream.log").write_text(output, encoding="utf-8")
                print(output, flush=True)
                assert result.returncode == 0 and output.count("PASS: live HTTPS radio") == 2, "Live MP3/AAC failed"
                assert not re.search(errors, output), "Live QML error"
    finally:
        server.shutdown()
    print("PASS: Windows ZIP, production test-loader exclusion, UI, audio and tray checks", flush=True)


if __name__ == "__main__":
    main()
