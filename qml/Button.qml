import QtQuick
import QtQuick.Controls as Controls
Controls.Button {
    id: root
    property bool bordered: false
    property bool selected: false
    property bool prominent: false
    property bool focusable: true
    property bool leftAlign: false
    property int fontSize: Style.font.body
    property string tooltipText: ""
    focusPolicy: focusable ? Qt.StrongFocus : Qt.NoFocus
    implicitHeight: 34
    implicitWidth: Math.ceil(contentItem.implicitWidth) + leftPadding + rightPadding
    padding: 10
    opacity: enabled ? 1 : 0.4
    contentItem: Text {
        text: root.text; textFormat: Text.PlainText
        font.family: Style.font.family; font.pixelSize: root.fontSize
        color: root.prominent ? Color.background : root.selected ? Color.accent : Color.foreground
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: root.leftAlign ? Text.AlignLeft : Text.AlignHCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Style.cornerRadius
        color: root.prominent ? (root.down ? Qt.darker(Color.accent, 1.15) : root.hovered ? Qt.lighter(Color.accent, 1.1) : Color.accent)
            : Util.alpha(Color.accent, root.down ? 0.22 : root.selected || root.hovered ? 0.12 : 0.025)
        border.width: root.bordered || root.activeFocus ? 1 : 0
        border.color: root.activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.22)
    }
    Controls.ToolTip.visible: hovered && tooltipText !== ""
    Controls.ToolTip.text: tooltipText
    Controls.ToolTip.delay: 600
}
