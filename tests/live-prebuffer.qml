import QtQuick
import QtMultimedia
import DnbRadio

Main {
    id: app
    visible: false
    property var backend: null
    property int stage: 0
    property int ticks: 0
    function check(value, message) { if (!value) throw new Error(message); }
    function advance() { stage++; ticks = 0; }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var found = find(child, name); if (found) return found; }
        return null;
    }
    function toggle(mini) {
        find(mini ? miniPlayer.contentItem : app.contentItem, mini ? "mini-play" : "main-play").clicked();
    }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: {
            try {
                if (++app.ticks > 200) throw new Error("Prebuffer timeout at stage " + app.stage);
                switch (app.stage) {
                case 0:
                    if (!radio.configured || !radio.library.storageReady) return;
                    radio.muted = true;
                    backend = radio.resources.find(function(x) { return x.playbackState !== undefined; });
                    radio.tune(0, false);
                    check(radio.livePrebufferMs === (Qt.platform.os === "osx" ? 2500 : 0), "Production platform default");
                    radio.station.streams[0].url = Platform.environment("DNBRADIO_API_BASE") + "/live.mp3";
                    radio.station.streams[1].url = Platform.environment("DNBRADIO_API_BASE") + "/live.aac";
                    radio.station.streams[0].macPrebufferMs = 400;
                    // Exercise cancellation on every backend without delaying other platforms in production.
                    radio.livePrebufferMs = Qt.binding(function() { return radio.stream.macPrebufferMs || 0; });
                    toggle(false);
                    check(radio.prebuffering && radio.wantsPlay && !radio.playing, "MP3 waits before playback");
                    check(radio.stateText === "Buffering live audio…", "Explain pending playback");
                    radio.play();
                    advance(); break;
                case 1:
                    if (app.ticks < 2) return;
                    check(backend.playbackState !== MediaPlayer.PlayingState, "No early start");
                    toggle(true); advance(); break;
                case 2:
                    if (app.ticks < 12) return;
                    check(!radio.wantsPlay && !radio.prebuffering && backend.source.toString() === "", "Mini Pause cancels pending start");
                    toggle(true); advance(); break;
                case 3:
                    if (!radio.playing || radio.position < 300) return;
                    check(!radio.prebuffering, "MP3 starts after prebuffer");
                    radio.pause(); radio.play();
                    check(radio.prebuffering, "Live restart prebuffers a fresh source");
                    radio.setQuality(1);
                    check(!radio.prebuffering && radio.wantsPlay, "AAC starts without MP3 delay");
                    advance(); break;
                case 4:
                    if (app.ticks < 12 || !radio.playing) return;
                    check(backend.source.toString().endsWith("/live.aac"), "Old MP3 timer cannot replace AAC");
                    radio.setQuality(0);
                    check(radio.prebuffering, "Switching back to MP3 prebuffers");
                    radio.tune(1, false); advance(); break;
                case 5:
                    if (app.ticks < 12) return;
                    check(!radio.wantsPlay && !radio.prebuffering && backend.source.toString() === "", "Paused station change cancels pending start");
                    radio.tune(0, true);
                    radio.failPlayback("Injected load failure"); advance(); break;
                case 6:
                    if (app.ticks < 12) return;
                    check(!radio.wantsPlay && !radio.prebuffering && !radio.playing, "Failure cancels pending start");
                    radio.play();
                    check(radio.prebuffering, "Retry prebuffers the replacement source");
                    radio.pause();
                    radio.mode = "archive";
                    radio.recording = {id: "58079", title: "Archive fixture", audio: Platform.environment("DNBRADIO_API_BASE") + "/audio.wav"};
                    radio.play();
                    check(!radio.prebuffering, "Recordings have no live prebuffer delay");
                    advance(); break;
                case 7:
                    if (!radio.playing || radio.position < 300) return;
                    radio.tune(0, true);
                    check(radio.prebuffering, "Return to live starts prebuffer");
                    radio.shutdown(); advance(); break;
                case 8:
                    if (app.ticks < 12) return;
                    check(!radio.wantsPlay && !radio.prebuffering && backend.source.toString() === "", "Shutdown cancels pending start");
                    console.log("PASS: live prebuffer, full/mini cancellation, retry, quality, station, archive, shutdown");
                    Qt.exit(0); break;
                }
            } catch (error) {
                console.error("FAIL:", error.message, radio.status()); Qt.exit(1);
            }
        }
    }
}
