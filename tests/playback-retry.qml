import QtQuick
import QtTest
import QtMultimedia
import DnbRadio

Main {
    id: app
    TestCase { id: input; name: "RetryFullPlayer"; when: false }
    TestCase { id: miniInput; parent: app.miniPlayer.contentItem; name: "RetryMiniPlayer"; when: false }
    property var backend: null
    property int stage: 0
    property int ticks: 0
    property real savedPosition: 0
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function click(mini) {
        var button = find(mini ? miniPlayer.contentItem : app.contentItem, mini ? "mini-play" : "main-play");
        check(button && button.text === "Play", "Retry control must say Play");
        (mini ? miniInput : input).mouseClick(button, button.width / 2, button.height / 2);
        check(radio.wantsPlay, "Play control must request playback after error");
    }
    function trace(label) {
        if (!backend) return;
        console.log("TRACE", label, JSON.stringify({mediaStatus: backend.mediaStatus, playbackState: backend.playbackState,
            wantsPlay: radio.wantsPlay, error: backend.error, errorString: backend.errorString,
            source: backend.source.toString(), position: radio.position, backendPosition: backend.position,
            pendingSeek: radio.pendingSeek, stateText: radio.stateText}));
    }
    function failPlaying() {
        check(backend.playbackState === MediaPlayer.PlayingState, "Inject error into a playing backend");
        savedPosition = radio.position;
        // Backend errors need not change playbackState. Exercise the real service's signal handler
        // without depending on platform-specific buffering or network timeout lengths.
        backend.errorOccurred(MediaPlayer.NetworkError, "Injected mid-playback read failure");
        trace("injected error");
    }
    function advance() { trace("stage " + stage); stage++; ticks = 0; }
    Connections {
        target: app.backend
        function onErrorOccurred() { app.trace("error"); }
        function onMediaStatusChanged() { app.trace("media"); }
        function onPlaybackStateChanged() { app.trace("state"); }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if (++app.ticks > 200) throw new Error("Timeout at stage " + app.stage);
                switch (app.stage) {
                case 0:
                    if (!radio.library.storageReady) return;
                    backend = radio.resources.find(function(x) { return x.playbackState !== undefined; });
                    check(backend, "MediaPlayer found");
                    radio.muted = true;
                    radio.mode = "archive";
                    radio.recording = {id: "58079", title: "Retry fixture", audio: Platform.environment("DNBRADIO_API_BASE") + "/retry.wav"};
                    radio.pendingSeek = 10000;
                    radio.play(); advance(); break;
                case 1:
                    if (!radio.playbackError) return;
                    trace("HTTP failure before full Play");
                    click(false); advance(); break;
                case 2:
                    if (!radio.playing || radio.position < 10300 || radio.pendingSeek) return;
                    check(!radio.playbackError && radio.stateText === "Playing recording", "Recovered state text");
                    failPlaying();
                    Platform.miniPlayerRequested(); advance(); break;
                case 3:
                    if (!miniPlayer.visible) return;
                    click(true); advance(); break;
                case 4:
                    if (!radio.playing || radio.position < savedPosition + 300 || radio.pendingSeek) return;
                    check(radio.recording.id === "58079" && !radio.playbackError, "Mini retry preserves mix");
                    failPlaying(); radio.play(); radio.pause(); advance(); break;
                case 5:
                    if (app.ticks < 10) return;
                    check(!radio.wantsPlay && backend.playbackState !== MediaPlayer.PlayingState, "Pause cancels loading retry");
                    check(radio.position >= savedPosition - 500, "Pause keeps retry position");
                    radio.play(); advance(); break;
                case 6:
                    if (!radio.playing || radio.position < savedPosition + 300 || radio.pendingSeek) return;
                    radio.seek(25000); advance(); break;
                case 7:
                    if (radio.position < 25000) return;
                    radio.pause(); radio.library.saveNow();
                    check(radio.library.resumePosition(radio.recording) >= 25000, "Seek/resume persists after retry");
                    radio.play(); advance(); break;
                case 8:
                    if (!radio.playing) return;
                    failPlaying(); radio.play(); radio.tune(1, false); advance(); break;
                case 9:
                    if (app.ticks < 10) return;
                    check(!radio.wantsPlay && !radio.playing && !radio.pendingSeek, "Source change cancels retry and pending seek");
                    check(radio.mode === "live" && backend.source.toString() === "", "Previous recording remains unloaded");
                    radio.stream.url = Platform.environment("DNBRADIO_API_BASE") + "/audio.wav";
                    radio.play(); advance(); break;
                case 10:
                    if (!radio.playing || radio.position < 300) return;
                    failPlaying(); radio.play(); radio.shutdown(); advance(); break;
                case 11:
                    if (app.ticks < 5) return;
                    check(!radio.wantsPlay && backend.playbackState !== MediaPlayer.PlayingState && backend.source.toString() === "", "Quit cancels loading retry");
                    console.log("PASS: playback retry, full/mini controls, resume, seek, pause, source change, live, shutdown");
                    Platform.quitRequested(); break;
                }
            } catch (error) { console.error("FAIL:", error.message); app.trace("failure"); Qt.exit(1); }
        }
    }
}
