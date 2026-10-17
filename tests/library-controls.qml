import QtQuick
import QtTest
import QtMultimedia
import DnbRadio

Main {
    id: app
    TestCase { id: input; name: "LibraryControls"; when: false }
    TestCase { id: miniInput; parent: app.miniPlayer.contentItem; name: "MiniLiveControl"; when: false }
    property int stage: 0
    property int ticks: 0
    property bool captured: false
    property var backend: null
    function check(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name && item.visible) return item;
        for (var child of item.children || []) { var result = find(child, name); if (result) return result; }
        return null;
    }
    function button(name, mini) {
        var item = find(mini ? miniPlayer.contentItem : contentItem, name);
        check(item && item.enabled, "Missing enabled control: " + name);
        check(!item.contentItem.truncated, "Clipped label: " + name);
        return item;
    }
    function click(name, mini) {
        var item = button(name, mini);
        for (var parent = item.parent; parent; parent = parent.parent) {
            if (typeof parent.contentY === "number" && parent.contentItem) {
                var y = item.mapToItem(parent.contentItem, 0, 0).y;
                parent.contentY = Math.max(0, Math.min(parent.contentHeight - parent.height, y - (parent.height - item.height) / 2));
            }
        }
        (mini ? miniInput : input).mouseClick(item, item.width / 2, item.height / 2);
    }
    function archive() {
        radio.pause(); radio.mode = "archive";
        radio.recording = {id: "58079", title: "Random Renegade 2026-10-16", artist: "Drastic", audio: Platform.environment("DNBRADIO_API_BASE") + "/audio.wav"};
        radio.play();
    }
    function checkLivePlacement(mini) {
        var live = button(mini ? "mini-live" : "main-live", mini);
        var play = button(mini ? "mini-play" : "main-play", mini);
        check(live.text === "Back to live" && live.prominent, "Live action is explicit and prominent");
        check(live.parent === play.parent && live.x + live.width <= play.x && play.x - live.x - live.width < 20,
              "Back to live immediately left of Play/Pause");
    }
    function capture(item, name) {
        captured = false;
        var backdrop = Qt.createQmlObject('import QtQuick; Rectangle { anchors.fill: parent; z: -1; color: "#171920" }', item);
        item.grabToImage(function(result) { captured = result.saveToFile("build/" + name + ".png"); backdrop.destroy(); });
    }
    function advance() { stage++; ticks = 0; }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            try {
                if (++app.ticks > 180) throw new Error("Timeout at stage " + app.stage);
                switch (app.stage) {
                case 0:
                    if (!library.storageReady || library.latest.length !== 5) return;
                    app.width = 800; app.height = 650;
                    radio.muted = true;
                    backend = radio.resources.find(function(x) { return x.playbackState !== undefined; });
                    for (var station of radio.stations)
                        for (var stream of station.streams) stream.url = Platform.environment("DNBRADIO_API_BASE") + "/audio.wav";
                    radio.tune(2, false);
                    library.open("library"); advance(); break;
                case 1:
                    click("library-add");
                    check(library.tab === "mixes", "Add mixes opens the archive");
                    advance(); break;
                case 2:
                    if (!find(contentItem, "mix-save-58079")) return;
                    check(button("mix-save-58079").text === "Save", "Visible Save label");
                    click("mix-save-58079");
                    check(library.favorites.length === 1, "Save adds mix");
                    library.open("library"); advance(); break;
                case 3:
                    if (!find(contentItem, "favorite-remove-58079")) return;
                    check(button("favorite-remove-58079").text === "Remove", "Visible Remove label");
                    capture(find(contentItem, "main-content"), "library-favorites"); advance(); break;
                case 4:
                    if (!captured) return;
                    click("favorite-remove-58079");
                    check(library.favorites.length === 0 && !library.selectedMix, "Remove only changes saved mix, not navigation");
                    library.saveNow(); library.loadLibrary();
                    check(library.favorites.length === 0, "Favorite removal persisted");
                    archive(); advance(); break;
                case 5:
                    if (!radio.seekable || radio.position < 1000) return;
                    radio.seek(5000); advance(); break;
                case 6:
                    if (radio.position < 5100) return;
                    library.rememberPosition();
                    check(library.recent.length === 1, "Listening position saved");
                    checkLivePlacement(false);
                    capture(find(contentItem, "main-content"), "library-live-controls"); advance(); break;
                case 7:
                    if (!captured) return;
                    click("recent-remove-58079");
                    check(library.recent.length === 0, "Remove from history clears mix");
                    library.rememberPosition(); radio.pause(); library.saveNow(); library.loadLibrary();
                    check(library.recent.length === 0, "Periodic save and Pause do not re-add removed mix");
                    click("main-live");
                    check(radio.mode === "live" && radio.stationIndex === 2 && radio.wantsPlay, "Full Back to live tunes the selected station");
                    advance(); break;
                case 8:
                    if (!radio.playing || radio.position < 300) return;
                    check(!find(contentItem, "main-live"), "Return action disappears in live mode");
                    archive(); advance(); break;
                case 9:
                    if (!radio.seekable || radio.position < 1000) return;
                    radio.seek(7000); advance(); break;
                case 10:
                    if (radio.position < 7100) return;
                    radio.pause(); library.rememberPosition();
                    check(library.recent.length === 1, "Choosing a recording again restores normal history saving");
                    Platform.miniPlayerRequested(); advance(); break;
                case 11:
                    if (!miniPlayer.visible || (Qt.platform.os !== "osx" && !miniPlayer.active)) return;
                    checkLivePlacement(true);
                    capture(find(miniPlayer.contentItem, "mini-content"), "mini-live-controls"); advance(); break;
                case 12:
                    if (!captured) return;
                    click("mini-live", true);
                    check(radio.mode === "live" && radio.stationIndex === 2 && radio.wantsPlay, "Mini Back to live tunes the selected station");
                    check(library.resumePosition({id: "58079"}) >= 7000, "Returning live preserves archive resume");
                    advance(); break;
                case 13:
                    if (!radio.playing || radio.position < 300) return;
                    library.removeRecent({id: "58079"});
                    radio.shutdown(); library.loadLibrary();
                    check(!library.recent.length && !library.favorites.length, "Removed entries stay removed after Quit saves");
                    check(backend.playbackState !== MediaPlayer.PlayingState, "Shutdown stops playback");
                    console.log("PASS: library add/remove persistence, history removal during playback, full/mini Back to live, resume, narrow layout");
                    Platform.quitRequested(); break;
                }
            } catch (error) { console.error("FAIL:", error.message, radio.status()); Qt.exit(1); }
        }
    }
}
