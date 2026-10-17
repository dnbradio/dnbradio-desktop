import QtQuick
import QtQuick.Controls as Controls
Controls.TextField {
    implicitHeight: 34
    color: Color.foreground
    placeholderTextColor: Util.alpha(Color.foreground, 0.55)
    selectByMouse: true
    background: Rectangle {
        color: "#20222c"; radius: Style.cornerRadius
        border.width: 1; border.color: parent.activeFocus ? Color.accent : "#353844"
    }
}
