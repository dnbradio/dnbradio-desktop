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
    implicitHeight: 34
}
