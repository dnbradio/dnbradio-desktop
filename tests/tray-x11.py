#!/usr/bin/env python3
"""Click the actual X11 tray, check positioning/dismissal and recover from panel loss.

Run under Xvfb with openbox; requires trayer, xdotool, and xprop. Uses isolated app state.
"""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import threading
import time
from http.server import ThreadingHTTPServer
import fixture_server as fixture


def command(*args):
    return subprocess.run(args, capture_output=True, text=True, check=True).stdout.strip()


def wait_for(predicate, message, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.1)
    raise AssertionError(message)


def windows(name):
    result = subprocess.run(["xdotool", "search", "--onlyvisible", "--name", name], capture_output=True, text=True)
    found = result.stdout.split()
    if name == "^DNBRADIO$":
        # The XEmbed tray child has the same title as the application window.
        found = [window for window in found if int(dict(line.split("=", 1) for line in
                 command("xdotool", "getwindowgeometry", "--shell", window).splitlines())["WIDTH"]) > 400]
    return found


server = ThreadingHTTPServer(("127.0.0.1", 0), fixture.Handler)
base = f"http://127.0.0.1:{server.server_port}"
fixture.mix["profile_image"] = fixture.event["image"] = base + "/art.svg"
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix="dnbradio-tray-") as state:
        env = dict(os.environ, DNBRADIO_DATA_DIR=state, DNBRADIO_API_BASE=base,
                   DNBRADIO_NOWPLAYING_URL=base + "/nowplaying", DNBRADIO_BASSDRIVE_URL=base + "/bassdrive",
                   QT_QPA_PLATFORM="xcb", QT_QUICK_BACKEND="software")
        with open(Path(state) / "player.log", "w+") as log:
            tray = subprocess.Popen(["trayer", "--edge", "bottom", "--align", "right", "--widthtype", "pixel",
                                     "--width", "40", "--height", "32", "--transparent", "false", "--tint", "0x20222c"])
            app = None
            try:
                wait_for(lambda: windows("^panel$"), "Tray host did not start")
                app = subprocess.Popen([sys.argv[1], "--test-qml", str(Path(__file__).with_suffix(".qml").resolve())], env=env, stdout=log, stderr=log)
                wait_for(lambda: "READY: native tray" in (Path(state) / "player.log").read_text(), "App did not become ready", timeout=30)
                wait_for(lambda: windows("^DNBRADIO$"), "Main window did not open")
                full = windows("^DNBRADIO$")[0]
                command("xdotool", "windowactivate", "--sync", full, "key", "--clearmodifiers", "alt+F4")
                wait_for(lambda: not windows("^DNBRADIO$"), "Main close did not hide")
                assert app.poll() is None, "Main close quit despite tray"
                width, height = map(int, command("xdotool", "getdisplaygeometry").split())

                def click_tray(button=1):
                    command("xdotool", "mousemove", "--sync", str(width - 20), str(height - 16), "click", str(button))

                click_tray()
                wait_for(lambda: windows("Mini player"), "Tray click did not open mini")
                mini = windows("Mini player")[0]
                geometry = dict(line.split("=", 1) for line in command("xdotool", "getwindowgeometry", "--shell", mini).splitlines())
                assert int(geometry["Y"]) + int(geometry["HEIGHT"]) <= height - 32, "Mini covers bottom panel"
                assert 0 <= int(geometry["X"]) <= width - int(geometry["WIDTH"]), "Mini extends beyond screen"
                # Optional evidence screenshot in the caller's output directory.
                if os.environ.get("DNBRADIO_SCREENSHOT"):
                    command("import", "-window", "root", os.environ["DNBRADIO_SCREENSHOT"])
                command("xdotool", "mousemove", "--sync", "150", "80", "click", "1")
                wait_for(lambda: not windows("Mini player"), "Click-away did not dismiss mini")
                click_tray()
                wait_for(lambda: windows("Mini player"), "Tray did not reopen mini")
                click_tray()
                wait_for(lambda: not windows("Mini player"), "Repeat tray click did not dismiss mini")
                click_tray(3)
                def menu_window():
                    ids = subprocess.run(["xdotool", "search", "--onlyvisible", "--pid", str(app.pid)], capture_output=True, text=True).stdout.split()
                    return next((window for window in ids if "_NET_WM_WINDOW_TYPE_POPUP_MENU" in command("xprop", "-id", window, "_NET_WM_WINDOW_TYPE")), None)
                wait_for(menu_window, "Tray context menu did not appear")
                menu = dict(line.split("=", 1) for line in command("xdotool", "getwindowgeometry", "--shell", menu_window()).splitlines())
                command("xdotool", "mousemove", "--sync", str(int(menu["X"]) + int(menu["WIDTH"]) // 2),
                        str(int(menu["Y"]) + int(menu["HEIGHT"]) // 6), "click", "1")
                wait_for(lambda: windows("Mini player"), "Context menu Mini player did not open mini")
                command("xdotool", "key", "Escape")
                wait_for(lambda: not windows("Mini player"), "Escape did not dismiss mini")
                # A panel crash must recover the hidden player instead of stranding audio.
                tray.terminate()
                tray.wait(timeout=5)
                wait_for(lambda: windows("^DNBRADIO$"), "Panel loss did not restore full player")
                command("xdotool", "windowactivate", "--sync", full, "key", "--clearmodifiers", "alt+F4")
                app.wait(timeout=10)
                assert app.returncode == 0, "Closing without a tray must quit cleanly"
                assert (Path(state) / "player.ini").exists(), "Close did not persist settings"
                print("PASS: native X11 tray click, bottom placement, click-away, toggle, menu, Escape, panel-loss recovery, no-tray quit")
            except Exception:
                log.flush()
                print((Path(state) / "player.log").read_text())
                if os.environ.get("DNBRADIO_SCREENSHOT"):
                    command("import", "-window", "root", os.environ["DNBRADIO_SCREENSHOT"].replace(".png", "-failure.png"))
                raise
            finally:
                for process in (app, tray):
                    if process and process.poll() is None:
                        process.terminate()
                        process.wait(timeout=5)
                log.seek(0)
                output = log.read()
                if any(error in output for error in ("TypeError:", "ReferenceError:", "Binding loop", "Cannot assign", "Unable to assign")):
                    raise AssertionError(output)
finally:
    server.shutdown()
