import QtQuick
import QtMultimedia
import "Stations.js" as Catalog
import "Data.js" as Data

Item {
  id: root
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
  readonly property bool prebuffering: livePrebuffer.running
  property int livePrebufferMs: Qt.platform.os === "osx" ? (stream.macPrebufferMs || 0) : 0
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
  readonly property bool playing: wantsPlay && player.playbackState === MediaPlayer.PlayingState
    && player.mediaStatus !== MediaPlayer.LoadingMedia && player.mediaStatus !== MediaPlayer.StalledMedia
  readonly property bool connecting: wantsPlay && !playing
  readonly property real position: pendingSeek > 0 ? pendingSeek : player.position
  readonly property real duration: player.duration
  readonly property bool seekable: mode === "archive" && player.seekable && duration > 0
  readonly property string stateText: playbackError ? playbackError : prebuffering ? "Buffering live audio…" : connecting ? "Connecting…" : playing ? (mode === "live" ? "Playing live" : "Playing recording") : "Ready to play"

  function configure() {
    var settings = Platform.loadPlayer();
    for (var i = 0; i < stations.length; i++) if (stations[i].id === settings.station) stationIndex = i;
    if (typeof settings.volume === "number") volume = Math.max(0, Math.min(1, settings.volume));
    muted = settings.muted === true;
    qualityIndex = settings.quality === 1 ? 1 : 0;
    configured = true;
  }
  function save() { if (configured) saveTimer.restart(); }
  function persist() {
    if (configured) Platform.savePlayer({station: station.id, quality: qualityIndex, volume: volume, muted: muted});
  }
  function shutdown() {
    pause(); libraryManager.saveNow(); persist();
    pendingSeek = 0;
    player.stop(); player.source = "";
  }
  Component.onCompleted: configure()
  onVolumeChanged: save()
  onMutedChanged: save()

  function play() {
    if (livePrebuffer.running) return;
    var retry = playbackError !== "" || player.error !== MediaPlayer.NoError || player.mediaStatus === MediaPlayer.InvalidMedia;
    if (retry && mode === "archive") pendingSeek = position;
    playbackError = "";
    wantsPlay = true;
    var url = mode === "archive" ? recording.audio : stream.url;
    var reopen = retry || player.source.toString() !== url;
    if (reopen) {
      player.stop();
      // Setting the same URL is a no-op in QMediaPlayer, including after an error.
      // Unload it first so one explicit Play creates a fresh backend request.
      player.source = "";
      player.source = url;
    }
    if (!wantsPlay) return;
    connectionTimeout.restart();
    // Give this live MP3 mount time to accumulate audio before starting on
    // AVFoundation. Pause/source changes cancel the pending start.
    if (reopen && mode === "live" && livePrebufferMs > 0) {
      livePrebuffer.interval = livePrebufferMs;
      livePrebuffer.restart();
      return;
    }
    beginPlayback();
  }
  function beginPlayback() {
    if (!wantsPlay) return;
    player.play();
    applyResume();
    if (playing && player.mediaStatus === MediaPlayer.BufferedMedia) connectionTimeout.stop();
  }
  function pause() {
    libraryManager.rememberPosition();
    wantsPlay = false;
    livePrebuffer.stop();
    connectionTimeout.stop();
    if (mode === "archive") player.pause();
    else {
      player.stop();
      // Live playback must reopen at the live edge. AVFoundation can wait forever
      // after stop() seeks an existing non-seekable stream back to zero.
      player.source = "";
    }
  }
  function toggle() { if (wantsPlay) pause(); else play(); }
  function failPlayback(message) {
    libraryManager.rememberPosition();
    if (mode === "archive") pendingSeek = position;
    wantsPlay = false;
    livePrebuffer.stop();
    connectionTimeout.stop();
    playbackError = message;
    player.stop();
  }
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
    if (pendingSeek > 0 && wantsPlay && playing && player.mediaStatus === MediaPlayer.BufferedMedia && player.seekable && player.duration > 0) {
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
    if (!seekable || !isFinite(milliseconds)) return;
    var target = Math.max(0, Math.min(duration, milliseconds));
    if (pendingSeek > 0 || playbackError) pendingSeek = target;
    else player.position = target;
  }
  function refreshMetadata() {
    if (metadataBusy) return;
    metadataBusy = true;
    var request = new XMLHttpRequest();
    metadataRequest = request;
    request.open("GET", Platform.environment("DNBRADIO_NOWPLAYING_URL") || "https://azura.drmnbss.org/api/nowplaying");
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
    xhr.open("GET", Platform.environment("DNBRADIO_BASSDRIVE_URL") || "https://ice.bassdrive.net/status-json.xsl");
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
      playing: playing, connecting: connecting, prebuffering: prebuffering, wantsPlay: wantsPlay, error: playbackError, mediaStatus: player.mediaStatus,
      playbackState: player.playbackState, backendError: player.error, backendErrorString: player.errorString, pendingSeek: pendingSeek,
      position: position, duration: duration, seekable: seekable, volume: volume, muted: muted, quality: qualityIndex,
      source: player.source.toString(), metadataFresh: stationMetadataFresh, listeners: listeners,
      history: history, purchaseLinks: purchaseLinks,
      recordings: recordings.length, recording: recording, archiveFailed: archiveFailed});
  }

  AudioOutput { id: output; volume: root.volume; muted: root.muted }
  MediaPlayer {
    id: player
    audioOutput: output
    onSeekableChanged: root.applyResume()
    onDurationChanged: root.applyResume()
    onMediaStatusChanged: {
      root.applyResume();
      if (mediaStatus === MediaPlayer.EndOfMedia && !root.playbackError) { libraryManager.rememberPosition(); root.wantsPlay = false; livePrebuffer.stop(); connectionTimeout.stop(); }
      if (mediaStatus === MediaPlayer.BufferedMedia && root.playing) connectionTimeout.stop();
    }
    onErrorOccurred: function(error, errorString) {
      root.failPlayback("Playback failed · press Play to retry");
      console.warn("DNBRADIO playback:", errorString);
    }
  }
  LibraryState { id: libraryManager; radio: root }
  Timer { id: livePrebuffer; onTriggered: root.beginPlayback() }
  Timer { id: bassdriveTimeout; interval: 10000; onTriggered: { if (root.bassdriveRequest) root.bassdriveRequest.abort(); root.bassdriveRequest = null; root.bassdriveFresh = false; } }
  Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshBassdrive() }
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
      root.failPlayback("Connection timed out · press Play to retry");
    }
  }
  Component.onDestruction: { player.stop(); if (metadataRequest) metadataRequest.abort(); if (bassdriveRequest) bassdriveRequest.abort(); }
}
