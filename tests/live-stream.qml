import QtQuick
import DnbRadio

Main {
    id: app
    property int ticks: 0
    property int quality: 0
    property int stage: 0
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function toggle(mini, label) {
        var button = find(mini ? miniPlayer.contentItem : app.contentItem, mini ? "mini-play" : "main-play");
        check(button && button.text === label, "Unexpected live playback control");
        button.clicked();
    }
    function advance(next) { stage = next; ticks = 0; }
    Timer {
        interval: 250; running: true; repeat: true
        onTriggered: {
            try {
                if (++app.ticks > 180) throw new Error("Timeout at live stage " + app.stage);
                switch (app.stage) {
                case 0:
                    if (!radio.configured) return;
                    radio.muted = true;
                    radio.qualityIndex = 0;
                    radio.tune(0, false);
                    toggle(false, "Play"); advance(1); break;
                case 1:
                    // Short runs can replay cached opening audio and hide the AVFoundation failure.
                    if (!radio.playing || radio.position <= 1000 || !radio.metadataFresh || app.ticks < 60) return;
                    console.log("PASS: live HTTPS radio", radio.stream.label);
                    toggle(app.quality === 1, "Pause"); advance(2); break;
                case 2:
                    check(!radio.wantsPlay && JSON.parse(radio.status()).playbackState === 0, "Explicit live Pause must stay paused");
                    if (app.ticks < 4) return;
                    check(radio.stationIndex === 0 && radio.qualityIndex === app.quality, "Live selection preserved");
                    toggle(app.quality === 0, "Play"); advance(3); break;
                case 3:
                    if (!radio.playing || radio.position <= 1000 || app.ticks < 20) return;
                    check(!radio.playbackError && radio.stateText === "Playing live", "Live restart status");
                    console.log("PASS: live HTTPS restart", radio.stream.label);
                    if (app.quality === 0) {
                        app.quality = 1; radio.setQuality(1); advance(1);
                    } else {
                        radio.pause(); radio.tune(1, false); advance(4);
                    }
                    break;
                case 4:
                    check(!radio.wantsPlay && JSON.parse(radio.status()).playbackState === 0, "Paused station change must stay paused");
                    if (app.ticks < 4) return;
                    console.log("PASS: live pause and source change");
                    Platform.quitRequested(); break;
                }
            } catch (error) {
                var status = JSON.parse(radio.status());
                console.error("FAIL:", error.message, app.quality, status.source, status.mediaStatus,
                              status.playbackState, status.wantsPlay, status.position, status.backendErrorString);
                Qt.exit(1);
            }
        }
    }
}
