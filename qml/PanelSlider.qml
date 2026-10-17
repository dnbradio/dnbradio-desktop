import QtQuick
import QtQuick.Controls as Controls
Item {
    id: root
    property real minimum: 0
    property real maximum: 1
    property real value: 0
    signal moved(real value)
    signal released(real value)
    implicitHeight: 32
    implicitWidth: 120
    Controls.Slider {
        anchors.fill: parent
        from: root.minimum; to: root.maximum
        value: root.value
        onMoved: root.moved(value)
        onPressedChanged: if (!pressed) root.released(value)
        palette.highlight: Color.accent
    }
}
