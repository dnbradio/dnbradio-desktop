import QtQuick
import qs.Commons
import "Data.js" as Data

Rectangle {
  id: root
  property string source: ""
  property string fallbackSource: ""
  property string label: ""
  property string placeholder: "󰎆"
  property alias imageStatus: picture.status
  property bool usingFallback: false
  onSourceChanged: usingFallback = false
  onFallbackSourceChanged: usingFallback = false
  color: Util.alpha(Color.accent, 0.08)
  clip: true
  implicitWidth: 64
  implicitHeight: width
  Text {
    anchors.centerIn: parent
    text: root.placeholder
    color: Color.accent
    font.family: Style.font.family
    font.pixelSize: Math.min(48, root.width / 3)
  }
  Image {
    id: picture
    objectName: "artwork-image"
    anchors.fill: parent
    source: root.usingFallback || !Data.imageUrl(root.source) ? Data.imageUrl(root.fallbackSource) : Data.imageUrl(root.source)
    onStatusChanged: if (status === Image.Error && !root.usingFallback) root.usingFallback = true
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    sourceSize: Qt.size(Math.min(900, root.width * 2), Math.min(900, root.height * 2))
    Accessible.name: root.label
  }
}
