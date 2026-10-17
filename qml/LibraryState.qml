import QtQuick
import "Data.js" as Data

Item {
  id: root
  required property var radio
  readonly property string apiBase: Platform.environment("DNBRADIO_API_BASE") || "https://dnbradio.com"

  property bool windowOpen: false
  property string tab: "home"
  property var records: []
  property var latest: []
  property int page: 1
  property int pages: 1
  property int total: 0
  property string query: ""
  property string genre: ""
  property string sort: "newest"
  property bool loading: false
  property bool supportsSearch: false
  property string archiveError: ""
  property var selectedMix: null
  property string detailError: ""
  property var selectedProfile: null
  property var profileRecords: []
  property int profilePage: 1
  property int profilePages: 1
  property bool profileLoading: false
  property bool profileMixLoading: false
  property string profileError: ""
  property string profileMixError: ""
  property string homeError: ""
  property var events: []
  property double now: Date.now()
  readonly property var upcoming: Data.upcoming(events, now)
  readonly property var nextShow: upcoming.length ? upcoming[0] : null
  property string scheduleError: ""
  property bool scheduleLoading: false
  property var supporters: []
  property int supportPage: 1
  property int supportPages: 1
  property bool supportLoading: false
  property string supportError: ""
  property var favorites: []
  property var recent: []
  property string removedCurrentMix: ""
  property var reminders: []
  property var notified: []
  property bool storageReady: false
  property string storageError: ""
  property var pending: ({})
  property int notificationsSent: 0

  function request(key, path, success, failure) {
    if (pending[key]) {
      var old = pending[key];
      delete pending[key];
      old.xhr.abort();
    }
    var xhr = new XMLHttpRequest();
    var entry = {xhr: xhr, started: Date.now(), failure: failure};
    pending[key] = entry;
    xhr.open("GET", apiBase + path);
    xhr.setRequestHeader("Accept", "application/json");
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE || pending[key] !== entry) return;
      delete pending[key];
      if (xhr.status !== 200) { failure(xhr.status); return; }
      try { success(JSON.parse(xhr.responseText)); } catch (e) { failure(0); }
    };
    xhr.send();
  }
  function open(section) {
    tab = section === "support" ? "contributors" : (section || "home");
    selectedMix = null;
    selectedProfile = null;
    windowOpen = true;
    if (tab === "schedule" || tab === "home") refreshSchedule();
    if (tab === "home") refreshLatest();
    if (tab === "contributors") refreshSupport(1);
  }
  function refreshLatest() {
    request("home", "/api/podcast?items_per_page=20", function(data) {
      if (!Array.isArray(data.data)) throw new Error("Invalid recordings");
      latest = data.data.map(Data.recording).filter(function(r) { return r !== null; });
      homeError = "";
    }, function() { homeError = "Could not refresh recently aired mixes. Please retry."; });
  }
  function fetchArchive(targetPage) {
    var requestedPage = Math.max(1, targetPage || 1);
    loading = true;
    archiveError = "";
    var path = "/api/podcast?items_per_page=20&page=" + requestedPage + "&sort=" + sort;
    if (query.trim()) path += "&search=" + encodeURIComponent(query.trim());
    if (genre.trim()) path += "&genre=" + encodeURIComponent(genre.trim());
    request("archive", path, function(data) {
      if (!Array.isArray(data.data) || !data.pagination) throw new Error("Invalid recordings");
      loading = false;
      supportsSearch = (data.capabilities || []).indexOf("search") !== -1;
      if (!supportsSearch && (query.trim() || genre.trim() || sort !== "newest")) {
        records = [];
        archiveError = "Archive search is waiting for the DNBRADIO server update. Browse recent mixes below.";
        return;
      }
      records = data.data.map(Data.recording).filter(function(r) { return r !== null; });
      page = requestedPage;
      pages = Math.max(1, Number(data.pagination.total_pages || 1));
      total = Number(data.pagination.total || 0);
      if (page === 1 && !query && !genre && sort === "newest") latest = records;
    }, function() { loading = false; archiveError = "Could not load mixes. Check your connection and retry."; });
  }
  function showDetails(record) {
    windowOpen = true;
    selectedMix = record;
    detailError = "";
    request("detail", "/api/podcast/" + record.id, function(data) {
      var next = Data.recording(data.data || {});
      if (next && selectedMix && selectedMix.id === next.id) selectedMix = next;
    }, function(status) {
      if (status !== 404) detailError = "Showing saved mix details. Refresh when you are back online.";
    });
  }
  function showProfile(value) {
    var profile = Data.profileRef(value);
    if (!profile) return;
    selectedMix = null;
    selectedProfile = profile;
    profileError = ""; profileMixError = ""; profileRecords = []; profilePage = 1; profilePages = 1;
    windowOpen = true;
    refreshProfile();
    fetchProfileMixes(1);
  }
  function refreshProfile() {
    var profile = selectedProfile;
    if (!profile) return;
    profileLoading = true; profileError = "";
    request("profile", "/api/profiles/" + encodeURIComponent(profile.slug), function(data) {
      if (!data.data || data.data.slug !== profile.slug) throw new Error("Invalid profile");
      if (!selectedProfile || selectedProfile.slug !== profile.slug) return;
      selectedProfile = data.data; profileLoading = false;
    }, function(status) {
      if (!selectedProfile || selectedProfile.slug !== profile.slug) return;
      profileLoading = false;
      profileError = status === 404 ? "This DJ profile is not available in the app yet. You can open it on the website." : "Could not load this DJ profile. Please retry.";
    });
  }
  function fetchProfileMixes(targetPage) {
    if (!selectedProfile) return;
    var slug = selectedProfile.slug, requestedPage = Math.max(1, targetPage || 1);
    profileMixLoading = true; profileMixError = "";
    request("profileMixes", "/api/podcast?items_per_page=12&dj=" + encodeURIComponent(slug) + "&page=" + requestedPage, function(data) {
      if (!selectedProfile || selectedProfile.slug !== slug) return;
      if (!Array.isArray(data.data) || !data.pagination) throw new Error("Invalid mixes");
      profileMixLoading = false;
      if ((data.capabilities || []).indexOf("dj") === -1) { profileMixError = "DJ mix browsing is waiting for the server update."; return; }
      profileRecords = data.data.map(Data.recording).filter(function(r) { return r !== null; });
      profilePage = requestedPage; profilePages = Math.max(1, Number(data.pagination.total_pages || 1));
    }, function() { profileMixLoading = false; profileMixError = "Could not load this DJ's mixes. Please retry."; });
  }
  function refreshSchedule() {
    scheduleLoading = true;
    request("schedule", "/api/schedule", function(data) {
      if (!Array.isArray(data)) throw new Error("Invalid schedule");
      events = data;
      now = Date.now();
      scheduleError = "";
      scheduleLoading = false;
      checkReminders();
    }, function() { scheduleLoading = false; scheduleError = "Schedule unavailable. Previously loaded times may have changed."; });
  }
  function refreshSupport(targetPage) {
    supportLoading = true;
    supportError = "";
    var requestedPage = Math.max(1, targetPage || 1);
    request("support", "/api/support?items_per_page=30&page=" + requestedPage, function(data) {
      if (!Array.isArray(data.data) || !data.pagination) throw new Error("Invalid supporters");
      supporters = data.data;
      supportPage = requestedPage;
      supportPages = Number(data.pagination.total_pages || 1);
      supportLoading = false;
    }, function(status) {
      if (status !== 404) { supportLoading = false; supportError = "Supporters could not be loaded. Please retry."; return; }
      // Older deployments already publish this list. Keep only public display fields.
      request("support", "/api/donations", function(data) {
        if (!Array.isArray(data)) throw new Error("Invalid supporters");
        supporters = data.filter(function(d) { return d.status === "Completed" && Number(d.gross) > 0; }).map(function(d) {
          return {id: d.id, alias: d.alias || "Anonymous supporter", amount: String(d.gross), currency: d.currency || "USD", date: d.date};
        });
        supportPage = 1; supportPages = 1; supportLoading = false;
      }, function() { supportLoading = false; supportError = "Supporters could not be loaded. Please retry."; });
    });
  }
  function refresh() {
    fetchArchive(page); refreshSchedule();
    if (tab === "home") refreshLatest();
    if (tab === "contributors") refreshSupport(supportPage);
    if (selectedProfile) { refreshProfile(); fetchProfileMixes(profilePage); }
    if (selectedMix) showDetails(selectedMix);
  }
  function favorite(record) { return favorites.some(function(r) { return r.id === record.id; }); }
  function toggleFavorite(record) {
    if (!storageReady) return;
    favorites = favorite(record) ? favorites.filter(function(r) { return r.id !== record.id; }) : [record].concat(favorites);
    save();
  }
  function rememberPosition() {
    if (!storageReady || radio.mode !== "archive" || radio.position < 1000) return;
    var rec = Data.recording(radio.recording);
    if (!rec || rec.id === removedCurrentMix) return;
    var position = radio.duration > 0 && radio.duration - radio.position < 15000 ? 0 : radio.position;
    recent = [{record: rec, position: position, updatedAt: Date.now()}].concat(recent.filter(function(r) { return r.record.id !== rec.id; })).slice(0, 100);
    save();
  }
  function resumePosition(record) {
    var found = recent.find(function(r) { return r.record.id === record.id; });
    return found ? Number(found.position || 0) : 0;
  }
  function removeRecent(record) {
    if (!storageReady) return;
    // Periodic saves, Pause and Quit must not immediately re-add a removed row.
    if (radio.mode === "archive" && radio.recording.id === record.id) removedCurrentMix = record.id;
    recent = recent.filter(function(r) { return r.record.id !== record.id; });
    save();
  }
  function reminded(event) { return reminders.indexOf(Data.eventKey(event)) !== -1; }
  function toggleReminder(event) {
    if (!storageReady) return;
    var key = Data.eventKey(event);
    reminders = reminded(event) ? reminders.filter(function(r) { return r !== key; }) : reminders.concat([key]);
    save();
    checkReminders();
  }
  function checkReminders() {
    if (!storageReady || scheduleError) return;
    var sent = notified.slice();
    events.forEach(function(event) {
      var key = Data.eventKey(event);
      if (!reminded(event) || sent.indexOf(key) !== -1 || !Data.due(event, Date.now())) return;
      sent.push(key);
      Platform.notify(
        Date.parse(event.start) > Date.now() ? "Your show starts within 5 minutes" : "Your show is starting",
        Data.plain(event.title) + " · " + Data.plain(event.host));
      notificationsSent += 1;
    });
    if (sent.length !== notified.length) { notified = sent.slice(-200); save(); }
  }
  function save() { if (storageReady) saveTimer.restart(); }
  function saveNow() {
    if (!storageReady) return;
    var error = Platform.saveLibrary(JSON.stringify({version: 1, favorites: favorites, recent: recent, reminders: reminders, notified: notified}));
    storageError = error;
  }
  function loadLibrary() {
    var result = Platform.loadLibrary();
    if (result.error) { storageError = result.error; return; }
    try {
      var data = JSON.parse(result.text);
      if (data.version !== 1 || !Array.isArray(data.favorites) || !Array.isArray(data.recent) || !Array.isArray(data.reminders)) throw new Error("Invalid library");
      favorites = data.favorites.map(Data.recording).filter(function(r) { return r !== null; });
      recent = data.recent.filter(function(r) { return r.record && /^\d+$/.test(String(r.record.id)) && isFinite(r.position); }).slice(0, 100);
      reminders = data.reminders;
      notified = Array.isArray(data.notified) ? data.notified : [];
      storageReady = true;
      storageError = "";
    } catch (e) { storageError = "Saved library could not be read. Your existing file has been kept."; }
  }
  Timer { id: saveTimer; interval: 400; onTriggered: root.saveNow() }
  Connections { target: root.radio; function onRecordingChanged() { root.removedCurrentMix = ""; } }
  Timer {
    interval: 1000; running: true; repeat: true
    onTriggered: {
      for (var key in root.pending) {
        var entry = root.pending[key];
        if (Date.now() - entry.started <= 15000) continue;
        delete root.pending[key];
        entry.xhr.abort();
        entry.failure(0);
      }
    }
  }
  Timer { interval: 15000; running: true; repeat: true; onTriggered: if (root.radio.playing) root.rememberPosition() }
  Timer { interval: 30000; running: true; repeat: true; onTriggered: { root.now = Date.now(); root.checkReminders(); } }
  Timer { interval: 300000; running: true; repeat: true; onTriggered: root.refreshSchedule() }
  Component.onCompleted: { loadLibrary(); fetchArchive(1); refreshSchedule(); }
  Component.onDestruction: {
    for (var key in pending) { var xhr = pending[key].xhr; delete pending[key]; xhr.abort(); }
  }
}
