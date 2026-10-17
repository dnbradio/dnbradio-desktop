import QtQuick
import DnbRadio

Main {
    id: app
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (app.active && app.library.storageReady && app.radio.metadataFresh) {
                console.log("READY: native tray");
                stop();
            }
        }
    }
}
