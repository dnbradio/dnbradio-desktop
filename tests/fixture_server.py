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
        if url.path == "/audio.wav":
            import io, wave
            stream = io.BytesIO()
            with wave.open(stream, "wb") as wav:
                wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(8000)
                wav.writeframes(b"\x00\x00" * 8000 * 60)
            body = stream.getvalue()
            match = re.match(r"bytes=(\d+)-(\d*)", self.headers.get("Range", ""))
            start = int(match[1]) if match else 0
            end = int(match[2]) if match and match[2] else len(body) - 1
            end = min(end, len(body) - 1)
            self.send_response(206 if match else 200)
            self.send_header("Content-Type", "audio/wav")
            self.send_header("Accept-Ranges", "bytes")
            if match: self.send_header("Content-Range", f"bytes {start}-{end}/{len(body)}")
            self.send_header("Content-Length", str(end - start + 1))
            self.end_headers()
            try: self.wfile.write(body[start:end + 1])
            except BrokenPipeError: pass
            return
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

