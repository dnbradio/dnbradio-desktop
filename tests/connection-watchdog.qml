import QtQuick
import QtMultimedia
import DnbRadio

Main {
    id: app
    property var backend: null
    property int stage: 0
    property int ticks: 0
    function check(value, message) { if (!value) throw new Error(message); }
    function trace(label) {
        if (!backend) return;
        console.log("TRACE", label, JSON.stringify({mediaStatus: backend.mediaStatus, playbackState: backend.playbackState,
            awaitingAudio: radio.awaitingAudio, playing: radio.playing, position: radio.position,
            pendingSeek: radio.pendingSeek, stateText: radio.stateText}));
    }
    function advance() { trace("stage " + stage); stage++; ticks = 0; }
    Connections {
        target: app.backend
        function onMediaStatusChanged() { app.trace("media"); }
        function onPlaybackStateChanged() { app.trace("state"); }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if (++app.ticks > 200) throw new Error("Timeout at stage " + app.stage);
                var base = Platform.environment("DNBRADIO_API_BASE");
                switch (app.stage) {
                case 0:
                    if (!radio.library.storageReady) return;
                    backend = radio.resources.find(function(x) { return x.playbackState !== undefined; });
                    check(backend, "MediaPlayer found");
                    radio.muted = true;
                    radio.mode = "archive";
                    radio.recording = {id: "58079", title: "Watchdog fixture", artist: "Fixture", audio: base + "/audio.wav"};
                    radio.pendingSeek = 10000;
                    radio.play();
                    check(radio.awaitingAudio, "Play arms the connection watchdog");
                    advance(); break;
                case 1:
                    if (!radio.playing || radio.pendingSeek > 0 || radio.position < 12000) return;
                    check(!radio.awaitingAudio, "Audio advancing after a resume seek clears the watchdog");
                    console.log("PASS: resumed recording clears the watchdog");
                    radio.pause(); advance(); break;
                case 2:
                    for (var station of radio.stations)
                        for (var stream of station.streams) stream.url = base + "/live.wav";
                    radio.tune(0, true);
                    check(radio.awaitingAudio, "Live Play arms the connection watchdog");
                    advance(); break;
                case 3:
                    if (!radio.playing || radio.position < 2500) return;
                    check(!radio.awaitingAudio, "Live audio advancing clears the watchdog");
                    console.log("PASS: live-paced stream clears the watchdog");
                    advance(); break;
                case 4:
                    check(!radio.playbackError, "Live playback keeps running: " + radio.playbackError);
                    if (app.ticks < 30) return;
                    radio.shutdown();
                    console.log("PASS: connection watchdog");
                    Qt.exit(0);
                }
            } catch (error) {
                app.trace("failure");
                console.error("FAIL:", error.message);
                Qt.exit(1);
            }
        }
    }
}
