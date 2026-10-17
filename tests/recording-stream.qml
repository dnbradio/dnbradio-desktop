import QtQuick
import DnbRadio

Main {
    id: app
    property int stage: 0
    property int ticks: 0
    Component.onCompleted: {
        radio.muted = true;
        radio.playMix({id: "58084", title: "Random Renegade 2026-10-16", artist: "Drastic"}, false);
    }
    Timer {
        interval: 250; running: true; repeat: true
        onTriggered: {
            if (++app.ticks > 180 || app.radio.playbackError) {
                console.error("FAIL: archive HTTPS playback", app.stage, app.radio.status());
                Qt.exit(1); return;
            }
            if (!app.radio.playing || !app.radio.seekable) return;
            if (app.stage === 0 && app.radio.position > 1500) {
                app.radio.seek(60000); app.stage = 1;
            } else if (app.stage === 1 && app.radio.position > 61000) {
                app.radio.pause();
                app.radio.library.saveNow();
                console.log("PASS: archive HTTPS playback/seek/resume", app.radio.status());
                Platform.quitRequested();
            }
        }
    }
}
