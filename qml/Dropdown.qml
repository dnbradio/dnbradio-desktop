import QtQuick
import QtQuick.Controls as Controls
Controls.ComboBox {
    id: root
    property var options: []
    property string value: ""
    property bool showLabel: false
    signal changed(string value)
    model: options
    textRole: "label"
    valueRole: "value"
    currentIndex: options.findIndex(function(option) { return option.value === root.value; })
    onActivated: changed(String(currentValue))
    implicitHeight: 38
    implicitWidth: 180
    leftPadding: 12
    rightPadding: 34
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    contentItem: Text {
        text: root.displayText
        font: root.font
        color: root.enabled ? Color.foreground : "#9395a0"
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: root.width - width - 12
        anchors.verticalCenter: parent.verticalCenter
        text: "▾"
        color: Color.foreground
        font.pixelSize: 16
    }
    background: Rectangle {
        radius: Style.cornerRadius
        color: "#252834"
        border.color: root.activeFocus || root.popup.visible ? Color.accent : root.hovered ? "#757887" : "#484b59"
    }
    delegate: Controls.ItemDelegate {
        id: option
        required property int index
        required property var modelData
        objectName: "dropdown-option-" + index
        width: root.width - 8
        height: 38
        leftPadding: 10
        rightPadding: 30
        text: modelData.label
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: option.text
            font: root.font
            color: Color.foreground
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 5
            color: option.highlighted || option.hovered ? "#514234" : root.currentIndex === option.index ? "#333744" : "#20222c"
        }
        Text {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            visible: root.currentIndex === option.index
            text: "✓"
            color: Color.accent
            font.pixelSize: 14
        }
    }
    popup: Controls.Popup {
        y: root.height + 4
        width: root.width
        padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 340)
        // Keep the list inside its owning window, including the menu-bar player.
        popupType: Controls.Popup.Item
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollIndicator.vertical: Controls.ScrollIndicator {}
        }
        background: Rectangle {
            color: "#20222c"
            radius: Style.cornerRadius
            border.color: "#757887"
        }
    }
}
