import QtQuick
import DnbRadio

Main {
    id: app
    property int ticks: 0
    property int quality: 0
    Component.onCompleted: { radio.muted = true; radio.tune(0, true); }
    Timer {
        interval: 250; running: true; repeat: true
        onTriggered: {
            if (++app.ticks > 180) {
                console.error("FAIL: live HTTPS playback", app.quality, app.radio.status());
                Qt.exit(1);
            }
            if (app.radio.playing && app.radio.position > 1000 && app.radio.metadataFresh) {
                if (app.ticks < 20) return;
                console.log("PASS: live HTTPS radio", app.radio.stream.label);
                if (app.quality === 0) {
                    app.quality = 1; app.ticks = 0; app.radio.setQuality(1);
                } else { Platform.quitRequested(); }
            }
        }
    }
}
