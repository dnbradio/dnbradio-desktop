import QtQuick
import ".."

Rectangle {
  width: 400; height: 300; color: "#222222"
  SmoothScrollView {
    anchors.fill: parent
    Column {
      width: parent.width
      Repeater {
        model: 100
        Rectangle {
          required property int index
          width: parent.width; height: 80
          color: index % 2 ? "#333333" : "#444444"
          // Input must still scroll over the clickable cards used in the library.
          MouseArea { anchors.fill: parent; onClicked: {} }
        }
      }
    }
  }
}
