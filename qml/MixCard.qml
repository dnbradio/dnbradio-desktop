import QtQuick
import QtQuick.Layouts
import "Stations.js" as Catalog

Rectangle {
  id: root
  required property var mix
  required property var radio
  readonly property var library: radio.library
  readonly property real resumeAt: library.resumePosition(mix)
  objectName: "mix-card-" + mix.id
  implicitHeight: width + info.implicitHeight + 22
  color: Util.alpha(Color.accent, 0.045)
  border.width: 1
  border.color: activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.12)
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: mix.title + " · " + mix.artist + " · View mix details"
  Keys.onReturnPressed: library.showDetails(mix)
  Keys.onSpacePressed: library.showDetails(mix)
  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.forceActiveFocus(); root.library.showDetails(root.mix); } }
  Artwork { width: parent.width; height: width; source: root.mix.image; fallbackSource: root.mix.profile_image || ""; label: root.mix.title }
  ColumnLayout {
    id: info
    anchors { top: parent.top; topMargin: root.width + 10; left: parent.left; right: parent.right; margins: 10 }
    spacing: 5
    Text {
      Layout.fillWidth: true; Layout.preferredHeight: 38
      text: root.mix.title; textFormat: Text.PlainText; color: Color.foreground
      font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true
      wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
    }
    Button {
      Layout.fillWidth: true; leftAlign: true; fontSize: Style.font.caption
      text: root.mix.profile ? "@" + root.mix.profile.slug : root.mix.artist
      enabled: !!root.mix.profile
      tooltipText: "View DJ profile"
      onClicked: root.library.showProfile(root.mix.profile)
    }
    Text {
      Layout.fillWidth: true; textFormat: Text.PlainText; color: Color.foreground; opacity: 0.6
      font.family: Style.font.family; font.pixelSize: Style.font.caption
      text: root.mix.plays.toLocaleString() + " plays · " + Qt.formatDateTime(new Date(root.mix.date), "MMM d, yyyy")
      elide: Text.ElideRight
    }
    RowLayout {
      Layout.fillWidth: true
      Button { text: root.resumeAt > 0 ? "Resume" : "Play"; bordered: true; fontSize: Style.font.caption; onClicked: root.radio.playMix(root.mix, true) }
      Item { Layout.fillWidth: true }
      Button { text: root.library.favorite(root.mix) ? "♥" : "♡"; fontSize: Style.font.caption; tooltipText: "Save favorite"; enabled: root.library.storageReady; onClicked: root.library.toggleFavorite(root.mix) }
    }
  }
}
