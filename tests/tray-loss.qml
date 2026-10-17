import QtQuick
import DnbRadio

Main {
    id: app
    property bool armed: false
    property bool lossNotified: false
    Connections {
        target: Platform
        function onTrayAvailableChanged() {
            if (app.armed && !Platform.trayAvailable) app.lossNotified = true;
        }
    }
    Timer {
        interval: 10; running: true; repeat: true
        onTriggered: {
            if (!app.armed) {
                if (app.active && app.library.storageReady && app.radio.metadataFresh && Platform.trayAvailable) {
                    app.armed = true;
                    console.log("READY: immediate tray loss");
                }
                return;
            }
            if (!Platform.trayAvailable) {
                stop();
                if (app.lossNotified) {
                    console.error("FAIL: availability poll ran before the regression trigger");
                    Qt.exit(1);
                    return;
                }
                console.log("PASS: immediate no-tray close");
                app.close();
            }
        }
    }
}
