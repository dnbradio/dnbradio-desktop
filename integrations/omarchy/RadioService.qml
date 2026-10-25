import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import "Stations.js" as Catalog
import "Data.js" as Data

Item {
  id: root
  property var shell: null
  readonly property string pluginId: "com.dnbradio.radio"
  readonly property var stations: Catalog.stations
  property int stationIndex: 0
  property int qualityIndex: 0
  property real volume: 0.45
  property bool muted: false
  property bool configured: false
  property bool wantsPlay: false
  property string playbackError: ""
  property string mode: "live"
  property var recording: ({})
  property var metadata: ({})
  property bool metadataFresh: false
  property bool metadataBusy: false
  property var metadataRequest: null
  property var bassdriveRequest: null
  property bool bassdriveFresh: false
  property alias library: libraryManager
  property real pendingSeek: 0
  readonly property var recordings: libraryManager.latest
  readonly property bool archiveLoading: libraryManager.loading
  readonly property bool archiveFailed: libraryManager.archiveError !== ""
  readonly property var station: stations[stationIndex]
  readonly property var stream: station.streams[Math.min(qualityIndex, station.streams.length - 1)]
  readonly property var current: metadata[station.id] || ({})
  readonly property var song: current.now_playing ? current.now_playing.song : ({})
  readonly property string title: mode === "archive" ? (recording.title || "Recorded mix") : (song.title || song.text || station.name)
  readonly property string artist: mode === "archive" ? (recording.artist || "DNBRADIO archive") : (song.artist || station.description)
  readonly property string artwork: mode === "live" ? (song.art || "") : (recording.image || "")
  readonly property bool stationMetadataFresh: station.id === "bassdrive" ? bassdriveFresh : metadataFresh
  readonly property int listeners: stationMetadataFresh && current.listeners ? current.listeners.current : -1
  readonly property bool isLiveDj: mode === "live" && stationMetadataFresh && !!(current.live && current.live.is_live)
  readonly property var history: stationMetadataFresh ? (current.song_history || []) : []
  readonly property var purchaseLinks: mode === "live" && stationMetadataFresh ? Data.songLinks(song) : []
  readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
  readonly property bool connecting: wantsPlay && !playing
  readonly property real position: player.position
  readonly property real duration: player.duration
  readonly property bool seekable: mode === "archive" && player.seekable && duration > 0
  readonly property string stateText: playbackError ? playbackError : connecting ? "Connecting…" : playing ? (mode === "live" ? "Playing live" : "Playing recording") : "Ready to play"

  function configure() {
    if (configured || !shell) return;
    var layout = shell.barConfig.layout || {};
    for (var section in layout) {
      var entries = layout[section];
      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        if (entry.id !== pluginId) continue;
        for (var n = 0; n < stations.length; n++) if (stations[n].id === entry.station) stationIndex = n;
        qualityIndex = entry.quality === 1 ? 1 : 0;
        if (typeof entry.volume === "number") volume = Math.max(0, Math.min(1, entry.volume));
        muted = entry.muted === true;
      }
    }
    configured = true;
  }
  onShellChanged: configure()
  function save() {
    if (configured) saveTimer.restart();
  }
  function persist() {
    if (!shell || !configured) return;
    var entry = {id: pluginId, station: station.id, quality: qualityIndex, volume: volume, muted: muted};
    shell.updateEntryInline(pluginId, entry);
  }
  onVolumeChanged: save()
  onMutedChanged: save()

  function play() {
    playbackError = "";
    wantsPlay = true;
    var url = mode === "archive" ? recording.audio : stream.url;
    if (player.source.toString() !== url || player.mediaStatus === MediaPlayer.InvalidMedia) {
      player.stop();
      player.source = url;
    }
    connectionTimeout.restart();
    player.play();
  }
  function pause() {
    libraryManager.rememberPosition();
    wantsPlay = false;
    connectionTimeout.stop();
    if (mode === "archive") player.pause();
    else player.stop();
  }
  function toggle() { if (wantsPlay || playing) pause(); else play(); }
  function tune(index, start) {
    if (index < 0 || index >= stations.length) return;
    pause();
    player.source = "";
    stationIndex = index;
    pendingSeek = 0;
    mode = "live";
    recording = ({});
    playbackError = "";
    save();
    if (start) play();
  }
  function setQuality(index) {
    if (index < 0 || index >= station.streams.length) return;
    var resume = wantsPlay;
    pause();
    qualityIndex = index;
    save();
    if (resume) play();
  }
  function playRecording(index) {
    if (index >= 0 && index < recordings.length) playMix(recordings[index], true);
  }
  function playMix(value, resume) {
    var next = Data.recording(value);
    if (!next) return;
    pause();
    player.source = "";
    mode = "archive";
    recording = next;
    pendingSeek = resume ? libraryManager.resumePosition(next) : 0;
    play();
  }
  function applyResume() {
    if (pendingSeek > 0 && playing && player.mediaStatus === MediaPlayer.BufferedMedia && player.seekable && player.duration > 0) {
      player.position = Math.min(pendingSeek, Math.max(0, player.duration - 1000));
      pendingSeek = 0;
    }
  }
  function restore(value) {
    var state = JSON.parse(value);
    if (typeof state.volume === "number") volume = Math.max(0, Math.min(1, state.volume));
    if (state.quality === 0 || state.quality === 1) qualityIndex = state.quality;
    muted = state.muted === true;
    if (state.mode === "archive") {
      var match = String(state.source || "").match(/\/recordings\/(\d+)\//);
      var mix = Data.recording(state.recording || {id: match ? match[1] : "", title: state.title, artist: state.artist});
      if (!mix) return;
      pause();
      player.source = "";
      recording = mix;
      mode = "archive";
      pendingSeek = Math.max(0, Number(state.position) || 0);
      player.source = mix.audio;
      if (state.playing || state.connecting) play();
    } else {
      for (var i = 0; i < stations.length; i++) if (stations[i].id === state.station) tune(i, false);
      if (state.playing || state.connecting) play();
    }
  }
  function seek(milliseconds) {
    if (seekable && isFinite(milliseconds)) player.position = Math.max(0, Math.min(duration, milliseconds));
  }
  function refreshMetadata() {
    if (metadataBusy) return;
    metadataBusy = true;
    var request = new XMLHttpRequest();
    metadataRequest = request;
    request.open("GET", Quickshell.env("DNBRADIO_NOWPLAYING_URL") || "https://dnbradio.com/api/nowplaying");
    request.onreadystatechange = function() {
      if (request.readyState !== XMLHttpRequest.DONE) return;
      metadataTimeout.stop();
      metadataBusy = false;
      metadataFresh = false;
      if (request.status !== 200) return;
      try {
        var rows = JSON.parse(request.responseText);
        if (!Array.isArray(rows)) return;
        var result = {};
        for (var i = 0; i < rows.length; i++) if (rows[i].station) result[rows[i].station.shortcode] = rows[i];
        if (metadata.bassdrive) result.bassdrive = metadata.bassdrive;
        metadata = result;
        metadataFresh = true;
      } catch (e) { metadataFresh = false; }
    };
    metadataTimeout.restart();
    request.send();
  }
  function refreshBassdrive() {
    if (bassdriveRequest) return;
    var xhr = new XMLHttpRequest();
    bassdriveRequest = xhr;
    xhr.open("GET", Quickshell.env("DNBRADIO_BASSDRIVE_URL") || "https://ice.bassdrive.net/status-json.xsl");
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return;
      bassdriveTimeout.stop(); bassdriveRequest = null; bassdriveFresh = false;
      if (xhr.status !== 200) return;
      try {
        var sources = JSON.parse(xhr.responseText).icestats.source;
        if (!Array.isArray(sources)) sources = [sources];
        var source = sources.find(function(s) { return /\/stream$/.test(s.listenurl || ""); });
        if (!source) return;
        var next = Object.assign({}, metadata);
        next.bassdrive = {now_playing: {song: {title: source.title || source["display-title"] || "Bassdrive", artist: source.artist || "Worldwide drum & bass"}},
          listeners: {current: Number(source.listeners || 0)}, song_history: []};
        metadata = next; bassdriveFresh = true;
      } catch (e) { bassdriveFresh = false; }
    };
    bassdriveTimeout.restart(); xhr.send();
  }
  function refresh() { refreshMetadata(); refreshBassdrive(); libraryManager.refresh(); }
  function libraryStatus() {
    return JSON.stringify({page: library.page, pages: library.pages, total: library.total,
      records: library.records, supportsSearch: library.supportsSearch, archiveError: library.archiveError,
      selectedMix: library.selectedMix, selectedProfile: library.selectedProfile, profileRecords: library.profileRecords,
      profilePage: library.profilePage, profilePages: library.profilePages, profileError: library.profileError, profileMixError: library.profileMixError,
      favorites: library.favorites, recent: library.recent,
      events: library.upcoming, scheduleError: library.scheduleError,
      supporters: library.supporters, supportPage: library.supportPage, supportPages: library.supportPages,
      supportError: library.supportError, storageReady: library.storageReady, storageError: library.storageError,
      reminders: library.reminders, notified: library.notified, notificationsSent: library.notificationsSent});
  }
  function status() {
    return JSON.stringify({station: station.id, mode: mode, title: title, artist: artist,
      playing: playing, connecting: connecting, error: playbackError, mediaStatus: player.mediaStatus,
      position: position, duration: duration, seekable: seekable, volume: volume, muted: muted, quality: qualityIndex,
      source: player.source.toString(), metadataFresh: stationMetadataFresh, listeners: listeners,
      history: history, purchaseLinks: purchaseLinks,
      recordings: recordings.length, recording: recording, archiveFailed: archiveFailed});
  }

  AudioOutput { id: output; volume: root.volume; muted: root.muted }
  MediaPlayer {
    id: player
    audioOutput: output
    onPlaybackStateChanged: if (playbackState === MediaPlayer.PlayingState) connectionTimeout.stop()
    onSeekableChanged: root.applyResume()
    onDurationChanged: root.applyResume()
    onMediaStatusChanged: {
      root.applyResume();
      if (mediaStatus === MediaPlayer.EndOfMedia) { libraryManager.rememberPosition(); root.wantsPlay = false; connectionTimeout.stop(); }
      if (mediaStatus === MediaPlayer.BufferedMedia) connectionTimeout.stop();
    }
    onErrorOccurred: function(error, errorString) {
      root.wantsPlay = false;
      connectionTimeout.stop();
      root.playbackError = "Connection failed · press Play to retry";
      console.warn("DNBRADIO playback:", errorString);
    }
  }
  LibraryState { id: libraryManager; radio: root }
  Timer { id: bassdriveTimeout; interval: 10000; onTriggered: { if (root.bassdriveRequest) root.bassdriveRequest.abort(); root.bassdriveRequest = null; root.bassdriveFresh = false; } }
  Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshBassdrive() }
  Loader {
    active: libraryManager.windowOpen
    sourceComponent: LibraryWindow { radio: root }
  }
  Timer { id: saveTimer; interval: 350; onTriggered: root.persist() }
  Timer { interval: 250; running: root.pendingSeek > 0 && root.wantsPlay; repeat: true; onTriggered: root.applyResume() }
  Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshMetadata() }
  Timer { interval: 900000; running: true; repeat: true; onTriggered: if (!libraryManager.query && !libraryManager.genre) libraryManager.fetchArchive(libraryManager.page) }
  Timer {
    id: metadataTimeout
    interval: 12000
    onTriggered: {
      root.metadataFresh = false;
      root.metadataBusy = false;
      if (root.metadataRequest) root.metadataRequest.abort();
    }
  }
  Timer {
    id: connectionTimeout
    interval: 25000
    onTriggered: {
      root.pause();
      root.playbackError = "Connection timed out · press Play to retry";
    }
  }
  IpcHandler {
    target: "dnbradio"
    function status(): string { return root.status(); }
    function libraryStatus(): string { return root.libraryStatus(); }
    function open(section: string): void { libraryManager.open(section); }
    function close(): void { libraryManager.windowOpen = false; }
    function search(query: string, genre: string, sort: string): void {
      libraryManager.query = query; libraryManager.genre = genre; libraryManager.sort = sort;
      libraryManager.fetchArchive(1);
    }
    function page(number: string): void { libraryManager.fetchArchive(Number(number)); }
    function details(index: string): void { var mix = libraryManager.records[Number(index)]; if (mix) libraryManager.showDetails(mix); }
    function profile(slug: string): void { libraryManager.showProfile({slug: slug}); }
    function profilePage(page: string): void { libraryManager.fetchProfileMixes(Number(page)); }
    function favorite(index: string): void { var mix = libraryManager.records[Number(index)]; if (mix) libraryManager.toggleFavorite(mix); }
    function reminder(index: string): void { var event = libraryManager.upcoming[Number(index)]; if (event) libraryManager.toggleReminder(event); }
    function support(page: string): void { libraryManager.refreshSupport(Number(page)); }
    function playMix(id: string): void { if (/^\d+$/.test(id)) root.playMix({id: id, title: "Mix " + id}, true); }
    function restore(state: string): void { root.restore(state); }
    function saveLibrary(): void { libraryManager.rememberPosition(); libraryManager.saveNow(); }
    function play(): void { root.play(); }
    function pause(): void { root.pause(); }
    function toggle(): void { root.toggle(); }
    function tune(station: string): string {
      for (var i = 0; i < root.stations.length; i++) {
        if (root.stations[i].id === station) { root.tune(i, true); return "ok"; }
      }
      return "Unknown station";
    }
    function volume(percent: string): void { var n = Number(percent); if (isFinite(n)) root.volume = Math.max(0, Math.min(100, n)) / 100; }
    function mute(value: string): void { root.muted = value === "true"; }
    function quality(index: string): void { var n = Number(index); if (Number.isInteger(n)) root.setQuality(n); }
    function recording(index: string): void { var n = Number(index); if (Number.isInteger(n)) root.playRecording(n); }
    function seek(seconds: string): void { root.seek(Number(seconds) * 1000); }
    function refresh(): void { root.refresh(); }
  }
  Component.onDestruction: { libraryManager.rememberPosition(); libraryManager.saveNow(); player.stop(); if (metadataRequest) metadataRequest.abort(); if (bassdriveRequest) bassdriveRequest.abort(); }
}
