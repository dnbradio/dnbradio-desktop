import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import "Stations.js" as Catalog

Window {
    id: root
    required property var radio
    property string tab: "live"
    signal navigate(string tab)
    objectName: "miniPlayer"
    title: "DNBRADIO · Mini player"
    width: 440
    height: Math.min(Math.max(380, miniContent.implicitHeight + 36), Screen.height - 80)
    onHeightChanged: if (visible) Platform.positionMiniPlayer(root)
    visible: false
    transientParent: null
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: Color.background
    onActiveChanged: {
        if (active) dismissTimer.stop();
        else if (visible) dismissTimer.restart();
    }
    onVisibleChanged: {
        if (visible) { dismissTimer.stop(); focusScope.forceActiveFocus(); }
        else { quality.popup.close(); dismissTimer.stop(); }
    }
    Timer { id: dismissTimer; interval: 150; onTriggered: if (root.visible && !root.active) root.hide() }

    component Label: Text {
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }
    component Action: Button { fontSize: Style.font.caption }
    component Rule: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#3b3e49" }

    Rectangle { anchors.fill: parent; color: Color.background; border.color: "#65616a"; radius: 10 }
    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.hide()
        Keys.onSpacePressed: root.radio.toggle()
        Keys.onPressed: function(event) {
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
                root.radio.tune(event.key - Qt.Key_1, true); event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                root.radio.muted = !root.radio.muted; event.accepted = true;
            }
        }
        Controls.ScrollView {
            anchors { fill: parent; margins: 18 }
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                id: miniContent
                width: parent.width
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "DNBRADIO"; font.pixelSize: 19; font.bold: true; font.letterSpacing: 1.5; Layout.fillWidth: true }
                    Action { objectName: "mini-open"; text: "Open player ↗"; onClicked: Platform.showRequested() }
                    Action { text: "×"; tooltipText: "Close mini player"; onClicked: root.hide() }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Artwork {
                        Layout.preferredWidth: 64; Layout.preferredHeight: 64
                        source: root.radio.artwork
                        fallbackSource: root.radio.mode === "archive" ? root.radio.recording.profile_image || "" : ""
                        label: root.radio.title
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 5
                        Label { Layout.fillWidth: true; text: root.radio.mode === "archive" ? "RECORDED MIX" : root.radio.station.name + (root.radio.isLiveDj ? " · LIVE DJ" : ""); color: Color.accent; font.pixelSize: 11 }
                        Label { objectName: "mini-title"; Layout.fillWidth: true; text: root.radio.title; font.bold: true; wrapMode: Text.Wrap; maximumLineCount: 2 }
                        Label { Layout.fillWidth: true; text: root.radio.artist; color: "#b2b3bd"; font.pixelSize: 12 }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Action { objectName: "mini-play"; text: root.radio.wantsPlay ? "Pause" : "Play"; bordered: true; selected: root.radio.wantsPlay; onClicked: root.radio.toggle() }
                    Label { Layout.fillWidth: true; text: root.radio.stateText; color: root.radio.playbackError ? Color.urgent : "#b2b3bd"; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: 2 }
                    Dropdown {
                        id: quality
                        objectName: "mini-quality"
                        Layout.preferredWidth: 126
                        visible: root.radio.mode === "live"
                        options: root.radio.station.streams.map(function(s, i) { return {value: String(i), label: s.label}; })
                        value: String(Math.min(root.radio.qualityIndex, root.radio.station.streams.length - 1))
                        onChanged: function(value) { root.radio.setQuality(Number(value)); }
                    }
                    Action { visible: root.radio.mode === "archive"; text: "Live radio"; onClicked: root.radio.tune(root.radio.stationIndex, true) }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Action { objectName: "mini-mute"; text: root.radio.muted ? "Unmute" : "Mute"; selected: root.radio.muted; onClicked: root.radio.muted = !root.radio.muted }
                    PanelSlider { objectName: "mini-volume"; Layout.fillWidth: true; value: root.radio.volume; onMoved: function(value) { root.radio.volume = value; } }
                    Label { Layout.preferredWidth: 35; text: Math.round(root.radio.volume * 100) + "%"; font.pixelSize: 12; horizontalAlignment: Text.AlignRight }
                }
                RowLayout {
                    visible: root.radio.seekable
                    Layout.fillWidth: true
                    Label { text: Catalog.time(root.radio.position); font.pixelSize: 11 }
                    PanelSlider { Layout.fillWidth: true; maximum: Math.max(1, root.radio.duration); value: root.radio.position; onReleased: function(value) { root.radio.seek(value); } }
                    Label { text: Catalog.time(root.radio.duration); font.pixelSize: 11 }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: root.radio.purchaseLinks.length > 0
                    Repeater {
                        model: root.radio.purchaseLinks
                        Action { required property var modelData; text: modelData.label + " ↗"; onClicked: Qt.openUrlExternally(modelData.url) }
                    }
                }
                Rule {}
                RowLayout {
                    Layout.fillWidth: true; spacing: 5
                    Repeater {
                        model: [{id: "live", label: "Live radio"}, {id: "mixes", label: "Recent mixes"}, {id: "explore", label: "Explore"}]
                        Action { required property var modelData; objectName: "mini-tab-" + modelData.id; Layout.fillWidth: true; text: modelData.label; selected: root.tab === modelData.id; onClicked: root.tab = modelData.id }
                    }
                }
                ColumnLayout {
                    visible: root.tab === "live"
                    Layout.fillWidth: true; spacing: 4
                    Repeater {
                        model: root.radio.stations
                        Action {
                            required property var modelData
                            required property int index
                            objectName: "mini-station-" + index
                            Layout.fillWidth: true; implicitHeight: 34; leftAlign: true
                            text: (index + 1) + "   " + modelData.name
                            selected: root.radio.mode === "live" && root.radio.stationIndex === index
                            fontSize: 14
                            onClicked: root.radio.tune(index, true)
                        }
                    }
                }
                ColumnLayout {
                    visible: root.tab === "mixes"
                    Layout.fillWidth: true; spacing: 8
                    Repeater {
                        model: root.radio.recordings.slice(0, 3)
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Artwork { Layout.preferredWidth: 48; Layout.preferredHeight: 48; source: parent.modelData.image || ""; fallbackSource: parent.modelData.profile_image || ""; label: parent.modelData.title }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label { Layout.fillWidth: true; text: parent.parent.modelData.title; font.pixelSize: 12; font.bold: true }
                                Label { Layout.fillWidth: true; text: parent.parent.modelData.artist; font.pixelSize: 11; color: "#b2b3bd" }
                            }
                            Action { text: "Play"; onClicked: root.radio.playMix(parent.modelData, true) }
                        }
                    }
                    Label { visible: root.radio.recordings.length === 0; text: root.radio.archiveLoading ? "Loading mixes…" : "Open recorded mixes to browse the archive."; Layout.fillWidth: true; wrapMode: Text.Wrap }
                    Action { text: "Browse all recorded mixes →"; onClicked: root.navigate("mixes") }
                }
                GridLayout {
                    visible: root.tab === "explore"
                    Layout.fillWidth: true; columns: 2
                    Repeater {
                        model: [{id: "home", label: "Home"}, {id: "schedule", label: "Show schedule"}, {id: "library", label: "My library"}, {id: "contributors", label: "Contributors"}]
                        Action { required property var modelData; objectName: "mini-nav-" + modelData.id; text: modelData.label; Layout.fillWidth: true; bordered: true; onClicked: root.navigate(modelData.id) }
                    }
                    Action { text: "dnbradio.com ↗"; onClicked: Qt.openUrlExternally("https://dnbradio.com") }
                    Action { text: "Donate ↗"; onClicked: Qt.openUrlExternally("https://dnbradio.com/donate") }
                }
                Rule {}
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: root.radio.listeners >= 0 ? root.radio.listeners + " listening" : "Independent drum & bass"; font.pixelSize: 11; color: "#b2b3bd" }
                    Action { objectName: "mini-history"; text: "Song history"; onClicked: root.navigate("history") }
                    Action { objectName: "mini-quit"; text: "Quit"; onClicked: Platform.quitRequested() }
                }
            }
        }
    }
}
