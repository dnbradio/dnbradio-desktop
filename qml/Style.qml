pragma Singleton
import QtQuick
QtObject {
    readonly property QtObject font: QtObject {
        readonly property string family: Qt.application.font.family
        readonly property int body: 14
        readonly property int caption: 12
    }
    readonly property int cornerRadius: 8
    function selectedFillFor(foreground, accent) { return Qt.rgba(accent.r, accent.g, accent.b, 0.14); }
}
