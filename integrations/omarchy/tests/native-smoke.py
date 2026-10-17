#!/usr/bin/env python3
"""Isolated native windows and player. Does not change the installed plugin."""
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PLUGIN = Path(__file__).resolve().parents[1]
requests = []
legacy = False
failed_paths = set()
mix = dict(id=58079, title="Test mix", artist="Test DJ", description="<p>Session notes</p>",
           tracklist="Artist - Tune\nSecond - Track", genre="Jungle", plays=42,
           timestamp="2026-10-16T01:00:00Z", image="", profile=dict(slug="djfk", name="DJFK"))
now = datetime.datetime.now(datetime.timezone.utc)
event = dict(id=1, title="Reminder test", host="Test DJ", description="",
             profile=dict(slug="djfk", name="DJFK"),
             start=(now + datetime.timedelta(minutes=2)).isoformat(),
             end=(now + datetime.timedelta(hours=1)).isoformat())


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        url = urlparse(self.path)
        args = parse_qs(url.query)
        requests.append((url.path, args))
        status = 200
        if url.path in ["/art.svg", "/mix-art.svg"]:
            body = b'<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect width="100" height="100" fill="#e58a47"/></svg>'
            self.send_response(200)
            self.send_header("Content-Type", "image/svg+xml")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except BrokenPipeError:
                pass  # Navigating away cancels pending image requests.
            return
        if url.path in failed_paths:
            status, data = 503, {}
        elif url.path == "/api/podcast":
            page = int(args.get("page", [1])[0])
            records = [dict(mix, id=58079 if page == 1 else 58078)]
            records += [dict(mix, id=58100 + i, title="Grid mix " + str(i)) for i in range(4)]
            if args.get("search") == ["missing"]:
                records = []
            data = dict(data=records, pagination=dict(total_pages=2, total=2, page=page),
                        capabilities=[] if legacy else ["search", "genre", "sort", "detail", "dj"])
        elif url.path == "/api/profiles/djfk" and not legacy:
            data = dict(data=dict(slug="djfk", name="DJFK", bio="Original jungle", image=mix["profile_image"],
                                  location="London", member_since="2020-02", stats=dict(mixes=50, plays=12345),
                                  links=[dict(label="SoundCloud", url="https://soundcloud.com/djfk")]))
        elif url.path == "/nowplaying":
            song = dict(title="Current tune", artist="Test artist", art=mix["profile_image"], custom_fields=dict(bandcamp_url="https://example.bandcamp.com/track/test"))
            data = [dict(station=dict(shortcode="dnbradio"), now_playing=dict(song=song), listeners=dict(current=42),
                         song_history=[dict(sh_id=i, played_at=int(time.time()) - i * 300, song=dict(song, title="History tune " + str(i))) for i in range(1, 16)])]
        elif url.path == "/bassdrive":
            data = dict(icestats=dict(source=[dict(listenurl="https://ice.bassdrive.net/stream", title="Bassdrive test show", listeners=12)]))
        elif url.path.startswith("/api/podcast/"):
            data = dict(data=dict(mix, description="Full mix description"))
        elif url.path == "/api/schedule":
            data = [event]
        elif url.path == "/api/support" and not legacy:
            page = int(args.get("page", [1])[0])
            data = dict(data=[dict(id=page, alias="Junglist", amount="12.34", currency="EUR", date="2026-10-16", image=mix["profile_image"], profile=dict(slug="djfk", name="DJFK"))],
                        pagination=dict(total_pages=2, page=page))
        elif url.path == "/api/donations":
            data = [dict(id=1, alias="Public alias", gross="5.00", currency="GBP", status="Completed", date="2026-10-16", name="PRIVATE"),
                    dict(id=2, alias="Pending", gross="10", status="Pending")]
        else:
            status, data = 404, {}
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except BrokenPipeError:
            pass  # A page change cancels its previous request.


def run():
    global legacy
    with tempfile.TemporaryDirectory(prefix="dnbradio-native-test-") as directory:
        root = Path(directory)
        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        mix["profile_image"] = event["image"] = f"http://127.0.0.1:{server.server_port}/art.svg"
        mix["image"] = f"http://127.0.0.1:{server.server_port}/missing.svg"
        threading.Thread(target=server.serve_forever, daemon=True).start()
        shutil.copytree(PLUGIN, root / "plugin", ignore=shutil.ignore_patterns("tests"))
        for child in Path("/usr/share/omarchy/shell").iterdir():
            if child.is_dir() and not (root / child.name).exists():
                (root / child.name).symlink_to(child, target_is_directory=True)
        (root / "shell.qml").write_text('''import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "plugin"
ShellRoot {
  Component { id: inputComponent; TestCase { when: false } }
  RadioService { id: radio; muted: true }
  Artwork { id: artworkProbe; width: 80; height: 80 }
  QtObject { id: host; function serviceFor(name) { return radio } }
  FloatingWindow {
    title: "DNBRADIO · Native QA"; visible: true; implicitWidth: 300; implicitHeight: 60
    BarWidget { id: widget; shell: host }
  }
  function panel() {
    for (var child of widget.children) if (child.item) return child.item;
    return null;
  }
  function window() {
    for (var child of radio.children) if (child.item && child.item.title) return child.item;
    return null;
  }
  function nodes(item, seen) {
    seen = seen || [];
    if (!item || seen.indexOf(item) !== -1) return [];
    seen.push(item);
    var result = [item];
    if (item.contentItem) result = result.concat(nodes(item.contentItem, seen));
    if (item.children) for (var child of item.children) result = result.concat(nodes(child, seen));
    return result;
  }
  IpcHandler {
    target: "testUi"
    function artwork(primary: string, fallback: string): void { artworkProbe.source = primary; artworkProbe.fallbackSource = fallback; }
    function artworkState(): string { return JSON.stringify({status: artworkProbe.imageStatus, fallback: artworkProbe.usingFallback}); }
    function contributor(action: string): void {
      var card = nodes(window()).find(function(n) { return n.objectName === "contributor-card-0" });
      var input = inputComponent.createObject(window().contentItem);
      try {
        input.waitForRendering(card);
        // The compositor may tile test windows below the library's minimum size.
        // Use the card's top padding, which remains visible in a short viewport.
        if (action === "click") input.mouseClick(card, card.width / 2, 12);
        else {
          card.forceActiveFocus();
          input.keyClick(action === "return" ? Qt.Key_Return : Qt.Key_Space);
        }
      } finally { input.destroy(); }
    }
    function popup(tab: string): void { panel().selectTab(Number(tab)); widget.open(); }
    function closePopup(): void { widget.close(); }
    function snapshot(): string {
      var win = window();
      var all = nodes(win);
      return JSON.stringify({panelLoaded: panel() !== null, popupOpen: widget.opened,
        windowOpen: !!win && win.visible, tab: radio.library.tab, supportLoading: radio.library.supportLoading,
        texts: all.filter(function(n) { return typeof n.text === "string" }).map(function(n) { return n.text }),
        cards: all.filter(function(n) { return n.objectName.indexOf("mix-card-") === 0 }).map(function(n) { return {x:n.x,y:n.y,width:n.width} }),
        artworkSizes: all.filter(function(n) { return ["library-artwork", "schedule-artwork", "contributor-avatar"].indexOf(n.objectName) !== -1 }).map(function(n) { return {kind:n.objectName,width:n.width,height:n.height} }),
        images: all.filter(function(n) { return n.objectName === "artwork-image" }).map(function(n) { return n.status })});
    }
  }
}
''')
        state = root / "library.json"
        state.write_text(json.dumps(dict(version=1, favorites=[], recent=[], reminders=[], notified=[])))
        (root / "bin").mkdir()
        notifier = root / "bin/notify-send"
        notifier.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >> "' + str(root / "notifications") + '"\n')
        notifier.chmod(0o755)
        # Library geometry commands must never target an installed library window.
        compositor = root / "bin/hyprctl"
        compositor.write_text('#!/bin/sh\nexit 0\n')
        compositor.chmod(0o755)
        env = dict(os.environ, DNBRADIO_API_BASE=f"http://127.0.0.1:{server.server_port}",
                   DNBRADIO_NOWPLAYING_URL=f"http://127.0.0.1:{server.server_port}/nowplaying",
                   DNBRADIO_BASSDRIVE_URL=f"http://127.0.0.1:{server.server_port}/bassdrive",
                   DNBRADIO_STATE_FILE=str(state), PATH=str(root / "bin") + ":" + os.environ["PATH"],
                   QT_QPA_PLATFORM="wayland", XDG_CONFIG_HOME=str(root / "config"))
        log = (root / "runtime.log").open("w+")
        process = None

        def start():
            return subprocess.Popen(["qs", "-p", str(root), "--no-color"], env=env, stdout=log, stderr=log)

        def ipc(method, *args, target="dnbradio"):
            result = subprocess.run(["qs", "ipc", "-p", str(root), "call", target, method, *map(str, args)],
                                    env=env, capture_output=True, text=True, timeout=5)
            if result.returncode:
                raise RuntimeError(result.stderr)
            return result.stdout.strip()

        def ui():
            return json.loads(ipc("snapshot", target="testUi"))

        def assert_no_qml_errors():
            log.flush()
            errors = [line for line in (root / "runtime.log").read_text().splitlines()
                      if re.search(r"Failed to load|TypeError:|ReferenceError:|SyntaxError:|is not a type|Type .* unavailable|Cannot assign|Unable to assign|Binding loop|[Ee]rror.*\.qml", line)]
            assert not errors, "QML errors: " + "\n".join(errors)

        def status():
            return json.loads(ipc("libraryStatus"))

        def wait(predicate, label, timeout=20):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                try:
                    value = predicate()
                    if value:
                        return value
                except (RuntimeError, json.JSONDecodeError):
                    pass
                time.sleep(0.25)
            raise AssertionError("Timed out: " + label)

        def stop():
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)

        try:
            process = start()
            wait(lambda: status()["storageReady"] and len(status()["records"]) == 5, "initial archive")
            wait(lambda: ui()["panelLoaded"], "bar widget and popup load")
            art = mix["profile_image"]
            broken = mix["image"]
            ipc("artwork", art.replace("art.svg", "mix-art.svg"), art, target="testUi")
            wait(lambda: json.loads(ipc("artworkState", target="testUi"))["status"] == 1, "mix-specific artwork")
            assert not json.loads(ipc("artworkState", target="testUi"))["fallback"]
            ipc("artwork", broken, art, target="testUi")
            wait(lambda: json.loads(ipc("artworkState", target="testUi")) == dict(status=1, fallback=True), "broken mix artwork falls back to profile")
            ipc("artwork", broken, broken + "?profile", target="testUi")
            wait(lambda: json.loads(ipc("artworkState", target="testUi"))["status"] == 3, "both images fail without a retry loop")
            ipc("artwork", "", art, target="testUi")
            wait(lambda: json.loads(ipc("artworkState", target="testUi"))["status"] == 1, "missing mix image uses profile")
            ipc("artwork", art, "", target="testUi")
            wait(lambda: json.loads(ipc("artworkState", target="testUi")) == dict(status=1, fallback=False), "new image resets fallback")
            for tab in range(3):
                ipc("popup", tab, target="testUi")
                wait(lambda: ui()["popupOpen"], "compact popup tab")
            ipc("closePopup", target="testUi")
            for tab, expected in [("home", "Recently aired"), ("mixes", "Test mix"), ("schedule", "Reminder test"),
                                  ("library", "My library"), ("contributors", "Junglist"), ("history", "History tune 15")]:
                ipc("open", tab)
                wait(lambda: ui()["windowOpen"] and ui()["tab"] == tab and
                     any(expected in text for text in ui()["texts"]), "library screen " + tab)
                if tab in ["home", "mixes", "schedule"]:
                    wait(lambda: ui()["images"] and all(s == 1 for s in ui()["images"]), "loaded artwork " + tab)
                if tab == "schedule":
                    assert any(a["kind"] == "schedule-artwork" and a["width"] >= 112 for a in ui()["artworkSizes"])
                if tab == "contributors":
                    wait(lambda: ui()["images"] and all(s == 1 for s in ui()["images"]), "contributor avatar loaded")
                    assert any(a["kind"] == "contributor-avatar" and a["width"] == 48 for a in ui()["artworkSizes"])
                if tab == "mixes":
                    cards = ui()["cards"]
                    assert len(cards) == 5 and len({c["y"] for c in cards[:4]}) == 1 and cards[4]["y"] > cards[0]["y"]
            assert json.loads(ipc("status"))["purchaseLinks"][0]["label"] == "Bandcamp"
            for action in ["click", "return", "space"]:
                ipc("open", "contributors")
                wait(lambda: not ui()["supportLoading"] and any("Junglist" in text for text in ui()["texts"]), "contributor card ready")
                assert status()["selectedProfile"] is None
                ipc("contributor", action, target="testUi")
                wait(lambda: (status()["selectedProfile"] or {}).get("slug") == "djfk" and
                     any("Original jungle" in text for text in ui()["texts"]), "contributor " + action + " opens matching profile")
            wait(lambda: (status()["selectedProfile"] or {}).get("stats", {}).get("plays") == 12345, "profile stats")
            wait(lambda: any("Original jungle" in text for text in ui()["texts"]), "profile screen")
            ipc("profilePage", 2)
            wait(lambda: status()["profilePage"] == 2 and status()["profileRecords"][0]["id"] == "58078", "DJ mixes page")
            assert any(a.get("dj") == ["djfk"] for p, a in requests if p == "/api/podcast")
            ipc("details", 0)
            wait(lambda: (status()["selectedMix"] or {}).get("description") == "Full mix description", "details from DJ profile")
            prior_requests = len(requests)
            ipc("refresh")
            wait(lambda: any(p == "/api/profiles/djfk" for p, _ in requests[prior_requests:]) and
                 any(a.get("dj") == ["djfk"] and a.get("page") == ["2"] for p, a in requests[prior_requests:]), "refresh current DJ page")
            assert status()["profilePage"] == 2 and status()["selectedMix"]["id"] == "58079"
            ipc("close")
            assert_no_qml_errors()
            ipc("search", "Test DJ", "Jungle", "popular")
            wait(lambda: any(a.get("search") == ["Test DJ"] and a.get("genre") == ["Jungle"] and a.get("sort") == ["popular"] for p, a in requests), "search request")
            failed_paths.add("/api/podcast")
            ipc("page", 2)
            wait(lambda: status()["archiveError"], "archive page failure")
            assert status()["page"] == 1 and status()["records"][0]["id"] == "58079"
            failed_paths.clear()
            ipc("page", status()["page"] + 1)
            wait(lambda: status()["page"] == 2 and status()["records"][0]["id"] == "58078", "retry same archive page")
            ipc("page", 1)
            wait(lambda: status()["records"][0]["id"] == "58079", "first page")
            ipc("open", "mixes")
            ipc("details", 0)
            wait(lambda: (status()["selectedMix"] or {}).get("description") == "Full mix description", "mix details")
            wait(lambda: any("Full mix description" in text for text in ui()["texts"]), "mix details screen")
            ipc("close")
            ipc("favorite", 0)
            wait(lambda: len(status()["favorites"]) == 1, "favorite")
            ipc("open", "library")
            wait(lambda: any(a["kind"] == "library-artwork" and a["width"] >= 96 for a in ui()["artworkSizes"]), "larger saved mix artwork")
            wait(lambda: ui()["images"] and all(s == 1 for s in ui()["images"]), "saved mix image fallback")
            ipc("close")
            ipc("reminder", 0)
            wait(lambda: status()["notificationsSent"] == 1, "due reminder")
            ipc("refresh")
            ipc("support", 1)
            wait(lambda: status()["supportPage"] == 1 and status()["supporters"][0]["id"] == 1, "first supporters page")
            failed_paths.add("/api/support")
            ipc("support", 2)
            wait(lambda: status()["supportError"], "supporters page failure")
            assert status()["supportPage"] == 1 and status()["supporters"][0]["id"] == 1
            failed_paths.clear()
            ipc("support", status()["supportPage"] + 1)
            wait(lambda: status()["supporters"] and status()["supporters"][0]["id"] == 2, "support pagination")
            assert status()["supporters"][0]["currency"] == "EUR"
            assert status()["notificationsSent"] == 1
            assert (root / "notifications").read_text().count("Reminder test") == 1

            ipc("restore", json.dumps(dict(mode="archive", recording=mix, source="", position=90000, playing=True, muted=True)))
            wait(lambda: 89000 <= json.loads(ipc("status"))["position"] < 110000, "seek after media loads", 50)
            ipc("pause")

            ipc("tune", "bassdrive")
            wait(lambda: json.loads(ipc("status"))["playing"] and json.loads(ipc("status"))["station"] == "bassdrive", "Bassdrive real playback", 40)
            assert json.loads(ipc("status"))["muted"]
            assert json.loads(ipc("status"))["title"] == "Bassdrive test show"
            ipc("pause")
            ipc("saveLibrary")
            wait(lambda: len(json.loads(state.read_text())["recent"]) == 1, "saved resume")
            saved = json.loads(state.read_text())
            assert saved["recent"][0]["position"] >= 89000
            stop()
            process = start()
            wait(lambda: status()["storageReady"], "library reload")
            assert status()["favorites"][0]["id"] == "58079"
            assert status()["recent"][0]["position"] >= 89000
            assert len(status()["reminders"]) == 1
            assert status()["notificationsSent"] == 0
            ipc("playMix", 58079)
            wait(lambda: 89000 <= json.loads(ipc("status"))["position"] < 115000, "resume from saved library", 50)
            ipc("pause")

            legacy = True
            ipc("search", "Test", "", "newest")
            wait(lambda: "server update" in status()["archiveError"], "legacy capability warning")
            assert status()["records"] == []
            ipc("support", 1)
            wait(lambda: status()["supporters"] and status()["supporters"][0].get("currency") == "GBP", "legacy donations")
            assert len(status()["supporters"]) == 1
            assert "PRIVATE" not in json.dumps(status()["supporters"])
            stop()
            process = None
            state.write_text("existing damaged file")
            process = start()
            wait(lambda: status()["storageError"], "corrupt state warning")
            assert not status()["storageReady"]
            ipc("favorite", 0)
            ipc("saveLibrary")
            assert state.read_text() == "existing damaged file"
            assert_no_qml_errors()
            print("PASS: native widget/popup, home/four-column cards/artwork, DJ profiles/pages, artwork fallback/reset, larger schedule/library art, contributor avatars and click/Return/Space navigation, full song history/purchase links, Bassdrive playback, search, failed-page retries, details, contributors, favorites, real playback/resume, persistence, reminders, legacy fallback, corrupt-state protection")
        except Exception:
            log.flush()
            print((root / "runtime.log").read_text()[-6000:])
            raise
        finally:
            if process and process.poll() is None:
                stop()
            server.shutdown()
            log.close()


if __name__ == "__main__":
    run()
