import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import qs.Ui as ShellUi
import "Stations.js" as Catalog
import "Data.js" as Data

ShellUi.Panel {
  id: root
  moduleName: "com.dnbradio.radio"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property var radio: null
  property int tabIndex: 0
  readonly property color ink: bar ? bar.foreground : Color.foreground
  readonly property string family: bar ? bar.fontFamily : Style.font.family
  readonly property var matches: {
    if (!radio) return [];
    var query = search.text.toLowerCase();
    return radio.recordings.map(function(r, i) { return {record: r, index: i}; })
      .filter(function(r) { return r.record.title.toLowerCase().indexOf(query) !== -1; });
  }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(hostWidget || root, direction);
    return false;
  }
  function openLink(url) { Qt.openUrlExternally(url); root.close(); }
  function selectTab(index) { tabIndex = index; }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: popup.fittedContentWidth(Style.space(500))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      blocked: search.activeFocus || quality.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.tabIndex = (root.tabIndex + direction + 3) % 3; }
      onActivateRequested: if (root.radio) root.radio.toggle()
      onMoveRequested: function(dx, dy) {
        if (!root.radio) return;
        if (dx) root.radio.volume = Math.max(0, Math.min(1, root.radio.volume + dx * 0.05));
        if (dy) root.radio.tune((root.radio.stationIndex + dy + Catalog.stations.length) % Catalog.stations.length, root.radio.wantsPlay);
      }
      onTextKey: function(text) {
        if (!root.radio) return;
        if (/^[1-9]$/.test(text) && Number(text) <= Catalog.stations.length) root.radio.tune(Number(text) - 1, true);
        if (text === "m") root.radio.muted = !root.radio.muted;
        if (text === "r") root.radio.refresh();
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        RowLayout {
          width: parent.width
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(3)
            Text { text: "DNBRADIO"; color: root.ink; font.family: root.family; font.pixelSize: Style.font.subtitle; font.bold: true }
            Text { text: "DRUM & BASS · 24/7"; color: Color.accent; font.family: root.family; font.pixelSize: Style.font.caption }
          }
          RowLayout {
            Layout.alignment: Qt.AlignRight | Qt.AlignTop; spacing: Style.space(4)
            Button { text: "↗"; tooltipText: "Open dnbradio.com"; onClicked: root.openLink("https://dnbradio.com") }
            Button { text: "×"; tooltipText: "Close panel · Esc"; onClicked: root.close() }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(4)
          Repeater {
            model: ["Live radio", "Recorded mixes", "Explore"]
            Button {
              required property int index
              required property string modelData
              width: (content.width - Style.space(8)) / 3
              text: modelData
              fontSize: Style.font.caption
              selected: root.tabIndex === index
              onClicked: root.selectTab(index)
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(10)
          RowLayout {
            width: parent.width
            Rectangle {
              width: Style.space(62); height: width
              color: Style.normalFillFor(root.ink, Color.accent)
              Image {
                id: cover
                anchors.fill: parent
                source: root.radio ? root.radio.artwork : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }
              Text { anchors.centerIn: parent; visible: cover.status !== Image.Ready; text: "󰎆"; color: Color.accent; font.family: root.family; font.pixelSize: Style.font.displayLarge }
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(4)
              Text {
                Layout.fillWidth: true; textFormat: Text.PlainText
                text: root.radio ? (root.radio.mode === "archive" ? "RECORDED MIX" : root.radio.station.name.toUpperCase() + (root.radio.isLiveDj ? " · LIVE DJ" : " · RADIO")) : "CONNECTING"
                color: Color.accent; font.family: root.family; font.pixelSize: Style.font.caption
              }
              Text {
                Layout.fillWidth: true; textFormat: Text.PlainText
                text: root.radio ? root.radio.title : "DNBRADIO"
                color: root.ink; font.family: root.family; font.pixelSize: Style.font.body; font.bold: true
                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
              }
              Text {
                Layout.fillWidth: true; textFormat: Text.PlainText
                text: root.radio ? root.radio.artist : "Loading…"
                color: root.ink; opacity: 0.65; font.family: root.family; font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
            Button { text: "History"; fontSize: Style.font.caption; tooltipText: "Song history"; visible: !!root.radio && root.radio.mode === "live"; onClicked: { root.radio.library.open("history"); root.close(); } }
          }

          Flow {
            width: parent.width; spacing: Style.space(6)
            visible: !!root.radio && root.radio.purchaseLinks.length > 0
            Repeater {
              model: root.radio ? root.radio.purchaseLinks : []
              Button { required property var modelData; text: modelData.label + " ↗"; fontSize: Style.font.caption; onClicked: root.openLink(modelData.url) }
            }
          }

          RowLayout {
            width: parent.width
            Button {
              text: root.radio && root.radio.wantsPlay ? (root.radio.connecting ? "Cancel" : "󰏤 Pause") : "󰐊 Play"
              selected: root.radio ? root.radio.playing : false
              bordered: true
              enabled: !!root.radio
              onClicked: root.radio.toggle()
            }
            Text {
              Layout.fillWidth: true
              text: root.radio ? root.radio.stateText : "Loading player…"
              color: root.radio && root.radio.playbackError ? Color.urgent : root.ink
              opacity: 0.75; font.family: root.family; font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Dropdown {
              id: quality
              visible: !!root.radio && root.radio.mode === "live"
              enabled: !!root.radio && root.radio.station.streams.length > 1
              Layout.preferredWidth: Style.space(120)
              showLabel: false
              value: root.radio ? String(Math.min(root.radio.qualityIndex, root.radio.station.streams.length - 1)) : "0"
              options: root.radio ? root.radio.station.streams.map(function(s, i) { return {value: String(i), label: s.label}; }) : []
              onChanged: function(value) { root.radio.setQuality(Number(value)); }
            }
          }

          RowLayout {
            width: parent.width
            Button { text: root.radio && root.radio.muted ? "󰝟" : "󰕾"; tooltipText: "Mute · M"; onClicked: if (root.radio) root.radio.muted = !root.radio.muted }
            PanelSlider {
              Layout.fillWidth: true; bar: root.bar
              value: root.radio ? root.radio.volume : 0.45
              onMoved: function(value) { if (root.radio) root.radio.volume = value; }
            }
            Text { text: root.radio ? Math.round(root.radio.volume * 100) + "%" : "45%"; color: root.ink; font.family: root.family; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: Style.space(38) }
          }

          Column {
            width: parent.width
            visible: !!root.radio && root.radio.mode === "archive"
            PanelSlider {
              width: parent.width; bar: root.bar
              enabled: !!root.radio && root.radio.seekable
              maximum: root.radio ? Math.max(1, root.radio.duration) : 1
              value: root.radio ? root.radio.position : 0
              onReleased: function(value) { if (root.radio) root.radio.seek(value); }
            }
            RowLayout {
              width: parent.width
              Text { text: root.radio ? Catalog.time(root.radio.position) + " / " + Catalog.time(root.radio.duration) : ""; color: root.ink; font.family: root.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true }
              Button { text: "Return to live"; fontSize: Style.font.caption; onClicked: if (root.radio) root.radio.tune(root.radio.stationIndex, true) }
            }
          }
        }

        Rectangle { width: parent.width; height: 1; color: root.ink; opacity: 0.15 }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.tabIndex === 0
          Repeater {
            model: Catalog.stations
            Button {
              required property var modelData
              required property int index
              width: content.width
              leftAlign: true
              text: (index + 1) + "  " + modelData.name
              tooltipText: modelData.description
              selected: !!root.radio && root.radio.mode === "live" && root.radio.stationIndex === index
              onClicked: if (root.radio) root.radio.tune(index, true)
            }
          }
          Text {
            width: parent.width
            topPadding: Style.space(8)
            text: root.radio && root.radio.stationMetadataFresh ? (root.radio.listeners >= 0 ? root.radio.listeners + " listeners · live station information" : "Live station information") : "Station info unavailable · audio still works"
            color: root.ink; opacity: 0.55; font.family: root.family; font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.tabIndex === 1
          TextField {
            id: search
            width: parent.width
            placeholderText: "Search recent mixes…"
            Keys.onEscapePressed: { focus = false; keys.forceActiveFocus(); }
          }
          SmoothScrollView {
            width: parent.width
            height: Style.space(220)
            Column {
              id: mixRows
              width: parent.width
              spacing: Style.space(4)
              Repeater {
                model: root.matches
                Button {
                  id: mixButton
                  required property var modelData
                  width: mixRows.width
                  text: mixLabel.elidedText
                  tooltipText: modelData.record.title + "\n" + modelData.record.date
                  fontSize: Style.font.caption
                  leftAlign: true
                  selected: !!root.radio && root.radio.mode === "archive" && root.radio.recording.audio === modelData.record.audio
                  onClicked: if (root.radio) { root.radio.library.showDetails(modelData.record); root.close(); }
                  TextMetrics {
                    id: mixLabel
                    text: mixButton.modelData.record.title
                    font.family: root.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    elideWidth: mixRows.width - Style.space(36)
                  }
                }
              }
              Text {
                width: parent.width
                visible: root.matches.length === 0
                text: root.radio && root.radio.archiveLoading ? "Loading latest mixes…" : root.radio && root.radio.archiveFailed ? "Mix feed unavailable. Refresh to retry." : "No matching mixes."
                color: root.ink; font.family: root.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap
              }
            }
          }
          RowLayout {
            width: parent.width
            Button { text: "Open mix library"; fontSize: Style.font.caption; Layout.fillWidth: true; onClicked: { root.radio.library.open("mixes"); root.close(); } }
            Button { text: "Refresh"; fontSize: Style.font.caption; onClicked: if (root.radio) root.radio.refresh() }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.tabIndex === 2
          Repeater {
            model: [
              {title: "DJ schedule", url: "https://dnbradio.com/shows"},
              {title: "Live chat", url: "https://chat.dnbradio.com"},
              {title: "Discord community", url: "https://discord.gg/DYb3fay"},
              {title: "Podcasts & featured feeds", url: "https://dnbradio.com/featured-feeds"},
              {title: "Donate to DNBRADIO", url: "https://dnbradio.com/donate"},
              {title: "Merchandise", url: "https://dnbradio.com/merch"},
              {title: "About & help", url: "https://dnbradio.com/faq"}
            ]
            Button {
              required property var modelData
              width: content.width; leftAlign: true
              text: modelData.title + "  ↗"
              fontSize: Style.font.caption
              onClicked: root.openLink(modelData.url)
            }
          }
        }
        RowLayout {
          width: parent.width
          Button { text: "Home"; fontSize: Style.font.caption; Layout.fillWidth: true; onClicked: { root.radio.library.open("home"); root.close(); } }
          Button { text: "Schedule"; fontSize: Style.font.caption; Layout.fillWidth: true; onClicked: { root.radio.library.open("schedule"); root.close(); } }
          Button { text: "My library"; fontSize: Style.font.caption; Layout.fillWidth: true; onClicked: { root.radio.library.open("library"); root.close(); } }
          Button { text: "Contributors"; fontSize: Style.font.caption; Layout.fillWidth: true; onClicked: { root.radio.library.open("contributors"); root.close(); } }
        }
        Text {
          width: parent.width
          text: "Space play/pause · 1–" + Catalog.stations.length + " stations · M mute · Esc close"
          color: root.ink; opacity: 0.45; font.family: root.family; font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
