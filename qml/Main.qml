import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import "Data.js" as Data
import "Stations.js" as Catalog

Controls.ApplicationWindow {
  id: root
  RadioService { id: radioService }
  readonly property var radio: radioService
  readonly property var library: radio.library
  readonly property var miniPlayer: miniPanel
  objectName: "mainWindow"
  title: "DNBRADIO"
  color: Color.background
  width: 1100; height: 850
  minimumWidth: 800; minimumHeight: 650
  visible: true
  palette.window: Color.background
  palette.windowText: Color.foreground
  palette.base: "#20222c"
  palette.text: Color.foreground
  palette.button: "#252834"
  palette.buttonText: Color.foreground
  palette.highlight: Color.accent
  palette.highlightedText: Color.background
  font.family: Style.font.family
  font.pixelSize: Style.font.body
  onClosing: function(close) {
    if (Platform.trayAvailable) {
      close.accepted = false;
      root.hide();
    } else { radio.shutdown(); Qt.quit(); }
  }
  Component.onCompleted: radio.library.open("home")
  Connections {
    target: Platform
    function onShowRequested() { miniPanel.hide(); root.showNormal(); root.raise(); root.requestActivate(); }
    function onMiniPlayerRequested() { Platform.presentMiniPlayer(miniPanel); }
    function onQuitRequested() { root.radio.shutdown(); Qt.quit(); }
    function onShutdownRequested() { root.radio.shutdown(); }
    function onTrayAvailableChanged() {
      if (!Platform.trayAvailable && !root.visible) Platform.showRequested();
    }
  }
  Shortcut { sequences: [StandardKey.Quit]; onActivated: Platform.quitRequested() }
  MiniPlayer {
    id: miniPanel
    radio: root.radio
    onNavigate: function(tab) { root.library.open(tab); Platform.showRequested(); }
  }

  function date(value) {
    var d = new Date(value);
    return isNaN(d.getTime()) ? "" : Qt.formatDateTime(d, "ddd, MMM d · h:mm AP");
  }
  function day(value) {
    var d = new Date(value);
    return isNaN(d.getTime()) ? "" : Qt.formatDate(d, "MMM d, yyyy");
  }
  function contributionDate(value) {
    var parts = String(value || "").slice(0, 10).split("-");
    return parts.length === 3 ? day(new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))) : "";
  }

  component Label: Text {
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
  }
  component Action: Button { focusable: true; fontSize: Style.font.caption }
  component Rule: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Color.foreground; opacity: 0.12 }
  component MixGrid: Grid {
    required property var records
    columns: 4; spacing: 14
    Repeater {
      model: parent.records
      MixCard { required property var modelData; width: (parent.width - 42) / 4; mix: modelData; radio: root.radio }
    }
  }
  component ShowTile: Column {
    id: tile
    required property var event
    readonly property var profile: Data.profileRef(event.profile)
    spacing: 6
    Artwork {
      width: parent.width; height: width; source: tile.event.image || ""; label: Data.plain(tile.event.title)
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !!tile.profile; onClicked: root.library.showProfile(tile.profile) }
    }
    Label {
      width: parent.width; height: 34; text: Data.plain(tile.event.title); font.bold: true; font.pixelSize: Style.font.caption; maximumLineCount: 2; elide: Text.ElideRight
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !!tile.profile; onClicked: root.library.showProfile(tile.profile) }
    }
    Label { width: parent.width; text: tile.profile ? "@" + tile.profile.slug : Data.plain(tile.event.host); maximumLineCount: 1; elide: Text.ElideRight; opacity: 0.65; font.pixelSize: Style.font.caption }
    Label { width: parent.width; text: Data.startsIn(tile.event, root.library.now); color: Color.accent; font.pixelSize: Style.font.caption }
  }
  component MixRow: Rectangle {
    id: row
    required property var mix
    property real resumeAt: 0
    implicitHeight: Math.max(84, rowContent.implicitHeight + 24)
    color: root.radio.mode === "archive" && root.radio.recording.id === mix.id ? Style.selectedFillFor(Color.foreground, Color.accent) : "transparent"
    border.width: 1
    border.color: Util.alpha(Color.foreground, 0.10)
    radius: Style.cornerRadius
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.library.showDetails(row.mix) }
    RowLayout {
      id: rowContent
      anchors { fill: parent; margins: 12 }
      spacing: 12
      Artwork {
        objectName: "library-artwork"
        Layout.preferredWidth: root.width < 850 ? 96 : 120; Layout.preferredHeight: Layout.preferredWidth
        source: row.mix.image || ""; fallbackSource: row.mix.profile_image || ""; label: row.mix.title
      }
      ColumnLayout {
        Layout.fillWidth: true; spacing: 4
        Label { Layout.fillWidth: true; text: row.mix.title; font.bold: true; maximumLineCount: 2; elide: Text.ElideRight }
        Label { Layout.fillWidth: true; text: row.mix.artist + (row.mix.genre ? " · " + row.mix.genre : ""); font.pixelSize: Style.font.caption; opacity: 0.7; maximumLineCount: 1; elide: Text.ElideRight }
        Label { Layout.fillWidth: true; text: root.day(row.mix.date) + (row.resumeAt > 0 ? " · Resume at " + Catalog.time(row.resumeAt) : " · " + row.mix.plays + " plays"); font.pixelSize: Style.font.caption; opacity: 0.55 }
      }
      Action { text: row.resumeAt > 0 ? "Resume" : "Play"; bordered: true; onClicked: root.radio.playMix(row.mix, true) }
      Action { text: "Details"; onClicked: root.library.showDetails(row.mix) }
      Action { text: root.library.favorite(row.mix) ? "♥" : "♡"; tooltipText: "Save favorite"; selected: root.library.favorite(row.mix); enabled: root.library.storageReady; onClicked: root.library.toggleFavorite(row.mix) }
    }
  }

  FocusScope {
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: {
      if (root.library.selectedMix) root.library.selectedMix = null;
      else if (root.library.selectedProfile) root.library.selectedProfile = null;
      else root.showMinimized();
    }
    ColumnLayout {
      anchors { fill: parent; margins: 24 }
      spacing: 14
      RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
          spacing: 3
          Label { text: "DNBRADIO"; font.pixelSize: 25; font.bold: true; font.letterSpacing: 2 }
          Label { text: "INDEPENDENT DRUM & BASS · SINCE 2003"; color: Color.accent; font.pixelSize: Style.font.caption }
        }
        Item { Layout.fillWidth: true }
        Action { text: "Donate ↗"; bordered: true; onClicked: Qt.openUrlExternally("https://dnbradio.com/donate") }
        Action { text: "dnbradio.com ↗"; onClicked: Qt.openUrlExternally("https://dnbradio.com") }
      }
      RowLayout {
        Layout.fillWidth: true; spacing: 6
        Repeater {
          model: [{id: "home", label: "Home"}, {id: "mixes", label: "Recorded mixes"}, {id: "schedule", label: "Show schedule"}, {id: "library", label: "My library"}, {id: "contributors", label: "Contributors"}]
          Action {
            required property var modelData
            text: modelData.label; selected: root.library.tab === modelData.id
            onClicked: root.library.open(modelData.id)
          }
        }
        Item { Layout.fillWidth: true }
        Action { text: "Refresh"; onClicked: root.radio.refresh() }
      }
      RowLayout {
        Layout.fillWidth: true
        Dropdown {
          objectName: "stationSelector"
          Layout.preferredWidth: 190
          options: root.radio.stations.map(function(s, i) { return {value: String(i), label: s.name}; })
          value: String(root.radio.stationIndex)
          onChanged: function(value) { root.radio.tune(Number(value), true); }
        }
        Dropdown {
          Layout.preferredWidth: 150
          options: root.radio.station.streams.map(function(s, i) { return {value: String(i), label: s.label}; })
          value: String(Math.min(root.radio.qualityIndex, root.radio.station.streams.length - 1))
          onChanged: function(value) { root.radio.setQuality(Number(value)); }
        }
        Label { Layout.fillWidth: true; text: root.radio.station.description; opacity: 0.6; elide: Text.ElideRight; maximumLineCount: 1 }
        Label { visible: root.radio.listeners >= 0; text: root.radio.listeners + " listening"; color: Color.accent; font.pixelSize: Style.font.caption }
      }
      Rule {}
      Label { visible: Platform.lastNotification !== ""; text: Platform.lastNotification; Layout.fillWidth: true; color: Color.accent }
      Label { visible: text !== ""; text: root.library.storageError; color: Color.urgent; Layout.fillWidth: true; font.pixelSize: Style.font.caption }
      Loader {
        Layout.fillWidth: true; Layout.fillHeight: true
        sourceComponent: root.library.selectedMix ? detailPage : root.library.selectedProfile ? profilePage : root.library.tab === "home" ? homePage : root.library.tab === "mixes" ? mixesPage : root.library.tab === "schedule" ? schedulePage : root.library.tab === "library" ? savedPage : root.library.tab === "history" ? historyPage : supportPage
      }
      Rule {}
      Flow {
        Layout.fillWidth: true; spacing: 8
        visible: root.radio.purchaseLinks.length > 0
        Repeater {
          model: root.radio.purchaseLinks
          Action { required property var modelData; text: modelData.label + " ↗"; onClicked: Qt.openUrlExternally(modelData.url) }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        Action { text: root.radio.wantsPlay ? "Pause" : "Play"; bordered: true; selected: root.radio.playing; onClicked: root.radio.toggle() }
        ColumnLayout {
          Layout.fillWidth: true; spacing: 3
          Label { Layout.fillWidth: true; text: root.radio.title; font.bold: true; maximumLineCount: 1; elide: Text.ElideRight }
          Label { Layout.fillWidth: true; text: root.radio.playbackError || (root.radio.artist + " · " + root.radio.stateText); color: root.radio.playbackError ? Color.urgent : Color.foreground; opacity: 0.65; font.pixelSize: Style.font.caption; maximumLineCount: 1; elide: Text.ElideRight }
        }
        Action { visible: root.radio.mode === "live"; text: "Song history"; onClicked: root.library.open("history") }
        Action { text: root.radio.muted ? "Unmute" : "Mute"; onClicked: root.radio.muted = !root.radio.muted }
        PanelSlider { Layout.preferredWidth: root.width < 950 ? 65 : 100; minimum: 0; maximum: 1; value: root.radio.volume; onMoved: function(value) { root.radio.volume = value; } }
        Action { text: "Live radio"; onClicked: root.radio.tune(root.radio.stationIndex, true) }
      }
      RowLayout {
        visible: root.radio.mode === "archive"
        Layout.fillWidth: true
        Label { text: Catalog.time(root.radio.position); font.pixelSize: Style.font.caption }
        PanelSlider { Layout.fillWidth: true; minimum: 0; maximum: Math.max(1, root.radio.duration); value: root.radio.position; enabled: root.radio.seekable; onReleased: function(value) { root.radio.seek(value); } }
        Label { text: Catalog.time(root.radio.duration); font.pixelSize: Style.font.caption }
      }
    }
  }

  Component {
    id: homePage
    SmoothScrollView {
      clip: true; contentWidth: availableWidth
      Column {
        width: parent.width; spacing: 16
        Label { text: "Upcoming shows"; font.pixelSize: 22; font.bold: true }
        Label { visible: text !== ""; width: parent.width; text: root.library.scheduleError; color: Color.urgent }
        Grid {
          width: parent.width; columns: 8; spacing: 12
          Repeater { model: root.library.upcoming.slice(0, 8); ShowTile { required property var modelData; width: (parent.width - 84) / 8; event: modelData } }
        }
        Label { visible: !root.library.upcoming.length; text: root.library.scheduleLoading ? "Loading upcoming shows…" : "Live radio continues around the clock."; opacity: 0.6 }
        RowLayout {
          width: parent.width
          Label { text: "Recently aired"; font.pixelSize: 22; font.bold: true; Layout.fillWidth: true }
          Action { text: "Browse all mixes →"; onClicked: root.library.open("mixes") }
        }
        Label { width: parent.width; visible: text !== ""; text: root.library.homeError; color: Color.urgent }
        MixGrid { width: parent.width; records: root.library.latest }
      }
    }
  }

  Component {
    id: mixesPage
    ColumnLayout {
      spacing: 10
      RowLayout {
        Layout.fillWidth: true
        TextField { id: search; Layout.fillWidth: true; text: root.library.query; placeholderText: "Search titles, DJs, or descriptions…"; maximumLength: 150; onAccepted: { root.library.query = text; root.library.genre = genre.text; root.library.fetchArchive(1); } }
        TextField { id: genre; Layout.preferredWidth: 155; text: root.library.genre; placeholderText: "Genre (exact)"; maximumLength: 100; onAccepted: { root.library.query = search.text; root.library.genre = text; root.library.fetchArchive(1); } }
        Dropdown { Layout.preferredWidth: 130; showLabel: false; value: root.library.sort; options: [{value: "newest", label: "Newest"}, {value: "oldest", label: "Oldest"}, {value: "popular", label: "Most played"}]; onChanged: function(value) { root.library.sort = value; root.library.query = search.text; root.library.genre = genre.text; root.library.fetchArchive(1); } }
        Action { text: "Search"; bordered: true; onClicked: { root.library.query = search.text; root.library.genre = genre.text; root.library.fetchArchive(1); } }
      }
      Label { Layout.fillWidth: true; text: root.library.loading ? "Loading mixes…" : root.library.archiveError || (root.library.total ? root.library.total.toLocaleString() + " recorded mixes" : "The DNBRADIO mix archive"); font.pixelSize: Style.font.caption; opacity: 0.7 }
      SmoothScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
        contentWidth: availableWidth
        Column {
          width: parent.width; spacing: 8
          MixGrid { width: parent.width; records: root.library.records }
          Label { width: parent.width; visible: !root.library.loading && !root.library.archiveError && !root.library.records.length; text: "No mixes match this search. Try a DJ name or clear the genre filter." }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        Action { text: "Clear filters"; onClicked: { root.library.query = ""; root.library.genre = ""; root.library.sort = "newest"; search.text = ""; genre.text = ""; root.library.fetchArchive(1); } }
        Item { Layout.fillWidth: true }
        Action { text: "← Previous"; enabled: !root.library.loading && root.library.page > 1; onClicked: root.library.fetchArchive(root.library.page - 1) }
        Label { text: "Page " + root.library.page + " / " + root.library.pages; font.pixelSize: Style.font.caption }
        Action { text: "Next →"; enabled: !root.library.loading && root.library.page < root.library.pages; onClicked: root.library.fetchArchive(root.library.page + 1) }
      }
    }
  }

  Component {
    id: detailPage
    ColumnLayout {
      readonly property var mix: root.library.selectedMix || ({})
      id: details
      spacing: 12
      RowLayout {
        Action { text: "← Back"; onClicked: root.library.selectedMix = null }
        Item { Layout.fillWidth: true }
        Action { text: "Download ↗"; onClicked: Qt.openUrlExternally(details.mix.audio + "?download=1") }
        Action { text: "Copy link"; onClicked: { clipboard.text = details.mix.link; clipboard.selectAll(); clipboard.copy(); text = "Copied"; } }
        Action { text: "Website ↗"; onClicked: Qt.openUrlExternally(details.mix.link) }
      }
      TextEdit { id: clipboard; visible: false }
      SmoothScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentWidth: availableWidth
        ColumnLayout {
          width: parent.width; spacing: 16
          RowLayout {
            Layout.fillWidth: true; spacing: 18
            Artwork {
              Layout.preferredWidth: 140; Layout.preferredHeight: 140
              source: details.mix.image || ""; fallbackSource: details.mix.profile_image || ""; label: details.mix.title || ""
            }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 8
              Action { text: details.mix.profile ? "@" + details.mix.profile.slug + " · View DJ profile" : details.mix.artist || ""; enabled: !!details.mix.profile; onClicked: root.library.showProfile(details.mix.profile) }
              Label { text: details.mix.title || ""; font.bold: true; font.pixelSize: 23; Layout.fillWidth: true }
              Label { text: (details.mix.genre || "Drum & bass") + " · " + root.day(details.mix.date) + " · " + details.mix.plays + " plays"; opacity: 0.6; Layout.fillWidth: true; font.pixelSize: Style.font.caption }
              RowLayout {
                Action { text: root.library.resumePosition(details.mix) > 0 ? "Resume · " + Catalog.time(root.library.resumePosition(details.mix)) : "Play mix"; bordered: true; selected: true; onClicked: root.radio.playMix(details.mix, true) }
                Action { visible: root.library.resumePosition(details.mix) > 0; text: "From start"; onClicked: root.radio.playMix(details.mix, false) }
                Action { text: root.library.favorite(details.mix) ? "♥ Saved" : "♡ Save"; enabled: root.library.storageReady; onClicked: root.library.toggleFavorite(details.mix) }
              }
            }
          }
          Label { Layout.fillWidth: true; visible: text !== ""; text: root.library.detailError; color: Color.urgent }
          Label { Layout.fillWidth: true; text: details.mix.description || "No description has been added to this mix."; opacity: 0.8 }
          Label { text: "TRACKLIST"; color: Color.accent; font.pixelSize: Style.font.caption; font.bold: true }
          Label { Layout.fillWidth: true; text: details.mix.tracklist || "The DJ has not supplied a tracklist."; opacity: 0.8 }
        }
      }
    }
  }

  Component {
    id: schedulePage
    ColumnLayout {
      spacing: 12
      Label { Layout.fillWidth: true; text: "Your next sessions"; font.pixelSize: 22; font.bold: true }
      Label { Layout.fillWidth: true; text: "Times shown in your local timezone (" + Qt.formatDateTime(new Date(), "t") + "). Reminders appear 5 minutes before a show while DNBRADIO is running."; opacity: 0.6; font.pixelSize: Style.font.caption }
      Label { Layout.fillWidth: true; visible: root.library.scheduleError !== ""; text: root.library.scheduleError; color: Color.urgent }
      SmoothScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentWidth: availableWidth
        Column {
          width: parent.width; spacing: 8
          Repeater {
            model: root.library.upcoming
            Rectangle {
              id: eventRow
              required property var modelData
              width: parent.width; height: eventContent.implicitHeight + 28
              color: Util.alpha(Color.accent, 0.04); radius: Style.cornerRadius
              MouseArea { anchors.fill: parent; enabled: !!Data.profileRef(eventRow.modelData.profile); cursorShape: Qt.PointingHandCursor; onClicked: root.library.showProfile(eventRow.modelData.profile) }
              RowLayout {
                id: eventContent
                anchors { fill: parent; margins: 14 } spacing: 18
                Artwork { objectName: "schedule-artwork"; Layout.preferredWidth: root.width < 850 ? 112 : 144; Layout.preferredHeight: Layout.preferredWidth; source: eventRow.modelData.image || ""; label: Data.plain(eventRow.modelData.title) }
                ColumnLayout {
                  Layout.fillWidth: true; spacing: 5
                  Label { Layout.fillWidth: true; text: (Date.parse(eventRow.modelData.start) <= root.library.now ? "ON AIR · " : "") + root.date(eventRow.modelData.start) + " – " + Qt.formatTime(new Date(eventRow.modelData.end), "h:mm AP"); color: Color.accent; font.pixelSize: Style.font.caption }
                  Label { Layout.fillWidth: true; text: Data.plain(eventRow.modelData.title); font.bold: true }
                  Label { Layout.fillWidth: true; text: Data.plain(eventRow.modelData.host); opacity: 0.65; font.pixelSize: Style.font.caption }
                  Label { Layout.fillWidth: true; visible: text !== ""; text: Data.plain(eventRow.modelData.description); opacity: 0.65; maximumLineCount: 3; elide: Text.ElideRight; font.pixelSize: Style.font.caption }
                }
                Action { text: root.library.reminded(eventRow.modelData) ? "✓ Reminder set" : "Remind me"; selected: root.library.reminded(eventRow.modelData); enabled: root.library.storageReady && Date.parse(eventRow.modelData.start) > root.library.now; onClicked: root.library.toggleReminder(eventRow.modelData) }
              }
            }
          }
          Label { width: parent.width; visible: !root.library.upcoming.length; text: root.library.scheduleLoading ? "Loading schedule…" : "No upcoming shows are listed. Live radio continues around the clock." }
        }
      }
    }
  }

  Component {
    id: savedPage
    SmoothScrollView {
      clip: true; contentWidth: availableWidth
      Column {
        width: parent.width; spacing: 10
        Label { text: "Pick up where you left off"; font.pixelSize: 22; font.bold: true }
        Label { text: "Saved on this desktop. Favorites and listening positions stay between sessions."; opacity: 0.6; width: parent.width; font.pixelSize: Style.font.caption }
        Label { text: "RECENTLY PLAYED"; color: Color.accent; topPadding: 14; font.pixelSize: Style.font.caption }
        Label { visible: !root.library.recent.length; text: "Play a recorded mix to start your listening history."; opacity: 0.65; width: parent.width }
        Repeater { model: root.library.recent; MixRow { required property var modelData; width: parent.width; mix: modelData.record; resumeAt: modelData.position } }
        Label { text: "FAVORITES · " + root.library.favorites.length; color: Color.accent; topPadding: 14; font.pixelSize: Style.font.caption }
        Label { visible: !root.library.favorites.length; text: "Use the heart beside a mix to save it here."; opacity: 0.65; width: parent.width }
        Repeater { model: root.library.favorites; MixRow { required property var modelData; width: parent.width; mix: modelData; resumeAt: root.library.resumePosition(modelData) } }
      }
    }
  }

  Component {
    id: profilePage
    ColumnLayout {
      id: profileView
      readonly property var dj: root.library.selectedProfile || ({})
      spacing: 12
      RowLayout {
        Layout.fillWidth: true
        Action { text: "← Back"; onClicked: root.library.selectedProfile = null }
        Item { Layout.fillWidth: true }
        Action { text: "DJ website ↗"; onClicked: Qt.openUrlExternally("https://dnbradio.com/profiles/" + profileView.dj.slug) }
      }
      SmoothScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentWidth: availableWidth
        Column {
          width: parent.width; spacing: 16
          RowLayout {
            width: parent.width; spacing: 20
            Artwork { Layout.preferredWidth: 132; Layout.preferredHeight: 132; source: profileView.dj.image || ""; label: profileView.dj.name || "" }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 6
              Label { Layout.fillWidth: true; text: profileView.dj.name || profileView.dj.slug || "DJ profile"; font.pixelSize: 26; font.bold: true }
              Label { text: "@" + (profileView.dj.slug || ""); color: Color.accent }
              Label { Layout.fillWidth: true; text: [profileView.dj.location, profileView.dj.member_since ? "Member since " + profileView.dj.member_since : ""].filter(Boolean).join(" · "); opacity: 0.6; font.pixelSize: Style.font.caption }
              Label { visible: !!profileView.dj.stats; text: profileView.dj.stats ? Number(profileView.dj.stats.mixes).toLocaleString() + " mixes · " + Number(profileView.dj.stats.plays).toLocaleString() + " plays" : ""; font.bold: true }
              Label { Layout.fillWidth: true; visible: !!profileView.dj.next_show; text: profileView.dj.next_show ? "Next show · " + root.date(profileView.dj.next_show.start) : ""; color: Color.accent; font.pixelSize: Style.font.caption }
            }
          }
          Label { width: parent.width; visible: root.library.profileLoading; text: "Loading DJ profile…"; opacity: 0.6 }
          Label { width: parent.width; visible: text !== ""; text: root.library.profileError; color: Color.urgent }
          Label { width: parent.width; visible: text !== ""; text: Data.plain(profileView.dj.bio); opacity: 0.8 }
          Flow {
            width: parent.width; spacing: 8
            Repeater {
              model: profileView.dj.links || []
              Action { required property var modelData; text: Data.plain(modelData.label) + " ↗"; visible: Data.webUrl(modelData.url) !== ""; onClicked: Qt.openUrlExternally(Data.webUrl(modelData.url)) }
            }
          }
          Label { text: "Recorded mixes"; font.pixelSize: 22; font.bold: true }
          Label { width: parent.width; visible: root.library.profileMixLoading || root.library.profileMixError !== ""; text: root.library.profileMixLoading ? "Loading this DJ's mixes…" : root.library.profileMixError; color: root.library.profileMixError ? Color.urgent : Color.foreground }
          MixGrid { width: parent.width; records: root.library.profileRecords }
          Label { width: parent.width; visible: !root.library.profileMixLoading && !root.library.profileMixError && !root.library.profileRecords.length; text: "This DJ has no published recordings yet."; opacity: 0.6 }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        Action { text: "← Previous"; enabled: !root.library.profileMixLoading && root.library.profilePage > 1; onClicked: root.library.fetchProfileMixes(root.library.profilePage - 1) }
        Label { text: "Page " + root.library.profilePage + " / " + root.library.profilePages; font.pixelSize: Style.font.caption }
        Action { text: "Next →"; enabled: !root.library.profileMixLoading && root.library.profilePage < root.library.profilePages; onClicked: root.library.fetchProfileMixes(root.library.profilePage + 1) }
      }
    }
  }

  Component {
    id: historyPage
    ColumnLayout {
      spacing: 14
      Label { text: "Song history · " + root.radio.station.name; font.pixelSize: 22; font.bold: true }
      Label { text: "Recently played on this station"; opacity: 0.6; font.pixelSize: Style.font.caption }
      SmoothScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentWidth: availableWidth
        Column {
          width: parent.width; spacing: 10
          Repeater {
            model: root.radio.history
            Rectangle {
              id: historyRow
              required property var modelData
              readonly property var song: modelData.song || ({})
              width: parent.width; height: historyContent.implicitHeight + 24
              color: Util.alpha(Color.accent, 0.04)
              RowLayout {
                id: historyContent
                anchors { fill: parent; margins: 12 } spacing: 14
                Artwork { Layout.preferredWidth: 58; Layout.preferredHeight: 58; source: historyRow.song.art || ""; label: historyRow.song.title || "" }
                ColumnLayout {
                  Layout.fillWidth: true; spacing: 5
                  Label { Layout.fillWidth: true; text: Data.plain(historyRow.song.title || historyRow.song.text); font.bold: true }
                  Label { Layout.fillWidth: true; text: Data.plain(historyRow.song.artist) + (historyRow.song.album ? " · " + Data.plain(historyRow.song.album) : ""); opacity: 0.65; font.pixelSize: Style.font.caption }
                  Flow {
                    Layout.fillWidth: true; spacing: 8
                    Repeater { model: Data.songLinks(historyRow.song); Action { required property var modelData; text: modelData.label + " ↗"; onClicked: Qt.openUrlExternally(modelData.url) } }
                  }
                }
                Label { text: Data.relativeTime(historyRow.modelData.played_at, root.library.now); opacity: 0.55; font.pixelSize: Style.font.caption }
              }
            }
          }
          Label { width: parent.width; visible: !root.radio.history.length; text: root.radio.stationMetadataFresh ? "This station is not publishing recent song history." : "Station history is unavailable. Refresh to retry."; opacity: 0.6 }
        }
      }
    }
  }

  Component {
    id: supportPage
    ColumnLayout {
      spacing: 14
      RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
          Layout.fillWidth: true; spacing: 7
          Label { text: "Kept on air by you."; font.pixelSize: 25; font.bold: true }
          Label { text: "Thank you to everyone supporting independent drum & bass radio."; opacity: 0.7; Layout.fillWidth: true }
        }
        Action { text: "Donate to DNBRADIO ↗"; bordered: true; selected: true; onClicked: Qt.openUrlExternally("https://dnbradio.com/donate") }
      }
      Label { text: "RECENT CONTRIBUTIONS"; color: Color.accent; font.pixelSize: Style.font.caption; font.bold: true }
      Label { Layout.fillWidth: true; visible: root.library.supportError !== ""; text: root.library.supportError; color: Color.urgent }
      SmoothScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentWidth: availableWidth
        Grid {
          width: parent.width; columns: root.width < 850 ? 2 : 4; spacing: 12
          Repeater {
            model: root.library.supporters
            Rectangle {
              id: donor
              required property var modelData
              required property int index
              readonly property var profile: Data.profileRef(modelData.profile)
              objectName: "contributor-card-" + index
              width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns; height: 158
              activeFocusOnTab: !!profile
              Accessible.role: profile ? Accessible.Button : Accessible.StaticText
              Accessible.name: Data.plain(modelData.alias) + (profile ? " · View profile" : "")
              Keys.onReturnPressed: if (profile) root.library.showProfile(profile)
              Keys.onSpacePressed: if (profile) root.library.showProfile(profile)
              MouseArea { anchors.fill: parent; enabled: !!donor.profile; cursorShape: Qt.PointingHandCursor; onClicked: root.library.showProfile(donor.profile) }
              color: Util.alpha(Color.accent, 0.045); border.color: activeFocus ? Color.accent : Util.alpha(Color.foreground, 0.12); radius: Style.cornerRadius
              ColumnLayout {
                anchors { fill: parent; margins: 14 } spacing: 8
                Label { text: "♥  " + Data.money(donor.modelData.amount, donor.modelData.currency); color: Color.accent; font.pixelSize: 19; font.bold: true; Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight }
                RowLayout {
                  Layout.fillWidth: true; spacing: 10
                  Artwork {
                    objectName: "contributor-avatar"
                    Layout.preferredWidth: 48; Layout.preferredHeight: 48
                    source: donor.modelData.image || ""; label: Data.plain(donor.modelData.alias)
                    placeholder: Data.plain(donor.modelData.alias || "?").charAt(0).toUpperCase()
                  }
                  Label { text: Data.plain(donor.modelData.alias || "Anonymous supporter"); Layout.fillWidth: true; font.bold: true; maximumLineCount: 2; elide: Text.ElideRight }
                }
                Label { text: root.contributionDate(donor.modelData.date); opacity: 0.5; font.pixelSize: Style.font.caption }
              }
            }
          }
          Label { width: parent.width; visible: !root.library.supporters.length; text: root.library.supportLoading ? "Loading supporters…" : root.library.supportError ? "" : "Be the next person to keep the music playing." }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        Label { Layout.fillWidth: true; text: "Public supporter names · amounts shown in their original currency"; font.pixelSize: Style.font.caption; opacity: 0.5 }
        Action { text: "←"; enabled: !root.library.supportLoading && root.library.supportPage > 1; onClicked: root.library.refreshSupport(root.library.supportPage - 1) }
        Label { text: root.library.supportPage + " / " + root.library.supportPages; font.pixelSize: Style.font.caption }
        Action { text: "→"; enabled: !root.library.supportLoading && root.library.supportPage < root.library.supportPages; onClicked: root.library.refreshSupport(root.library.supportPage + 1) }
      }
    }
  }
}
