import QtQuick
import QtTest
import DnbRadio

Main {
    id: app
    TestCase { id: input; name: "Dropdown"; when: false }
    TestCase { id: miniInput; parent: app.miniPlayer.contentItem; name: "MiniPlayer"; when: false }
    property int stage: 0
    property int ticks: 0
    property bool nativeFocusObserved: false
    Component.onCompleted: {
        radio.muted = true;
        for (var station of radio.stations)
            for (var stream of station.streams) stream.url = Platform.environment("DNBRADIO_API_BASE") + "/audio.wav";
    }
    function check(value, message) { if (!value) throw new Error(message); }
    function nodes(item, seen) {
        seen = seen || [];
        if (!item || seen.indexOf(item) !== -1) return [];
        seen.push(item);
        var found = [item];
        if (item.contentItem) found = found.concat(nodes(item.contentItem, seen));
        if (item.children) for (var child of item.children) found = found.concat(nodes(child, seen));
        return found;
    }
    function find(name, item) { return nodes(item || miniPlayer.contentItem).find(function(n) { return n.objectName === name; }); }
    function click(name) {
        var item = find(name);
        check(item && item.visible, "Missing mini control: " + name);
        miniInput.mouseClick(item, item.width / 2, item.height / 2);
    }
    function luminance(color) {
        function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b);
    }
    function checkContrast(selector) {
        for (var i = 0; i < selector.count; i++) {
            var option = find("dropdown-option-" + i, selector.popup.contentItem);
            check(option && option.contentItem.text.length, "Empty dropdown option " + i);
            var light = luminance(option.contentItem.color), dark = luminance(option.background.color);
            check((Math.max(light, dark) + 0.05) / (Math.min(light, dark) + 0.05) >= 4.5, "Unreadable dropdown option " + i);
        }
    }
    function advance() { stage++; ticks = 0; }
    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: {
            try {
                if (++app.ticks > 150) throw new Error("Timeout at stage " + app.stage + "; mini visible=" + app.miniPlayer.visible + ", active=" + app.miniPlayer.active);
                var mini = app.miniPlayer;
                if (mini.active) app.nativeFocusObserved = true;
                var selector = find("stationSelector", app.contentItem);
                switch (app.stage) {
                case 0:
                    if (!app.library.storageReady || !app.radio.metadataFresh || !app.radio.recordings.length) return;
                    check(Platform.trayAvailable, "Tray icon unavailable (run with a tray host)");
                    app.radio.muted = true;
                    app.radio.tune(2, false);
                    selector.popup.open(); advance(); break;
                case 1:
                    if (!find("dropdown-option-5", selector.popup.contentItem)) return;
                    checkContrast(selector);
                    selector.forceActiveFocus();
                    input.keyClick(Qt.Key_Down); input.keyClick(Qt.Key_Return);
                    check(app.radio.stationIndex === 3, "Dropdown keyboard activation");
                    app.radio.pause();
                    app.close();
                    check(!app.visible, "Close hides the full window");
                    Platform.miniPlayerRequested(); advance(); break;
                case 2:
                    if (!mini.visible || (Qt.platform.os === "linux" && !mini.active)) return;
                    check(!app.visible, "Opening mini should not show full window");
                    check(mini.radio === app.radio, "Mini must share playback state");
                    click("mini-station-0"); advance(); break;
                case 3:
                    if (!app.radio.playing || app.radio.position < 200) return;
                    check(app.radio.stationIndex === 0, "Mini station selection");
                    click("mini-mute"); advance(); break;
                case 4:
                    check(!app.radio.muted, "Mini mute toggle");
                    app.radio.muted = true;
                    find("mini-quality").popup.open(); advance(); break;
                case 5:
                    var quality = find("mini-quality");
                    var option = find("dropdown-option-1", quality.popup.contentItem);
                    if (!option) return;
                    checkContrast(quality);
                    check(mini.visible, "Dropdown must not dismiss mini");
                    miniInput.mouseClick(option, 30, option.height / 2);
                    check(app.radio.qualityIndex === 1, "Mini quality selection");
                    var slider = nodes(find("mini-volume")).find(function(n) { return typeof n.from === "number" && typeof n.to === "number"; });
                    miniInput.mouseClick(slider, slider.width * 0.75, slider.height / 2);
                    advance(); break;
                case 6:
                    if (app.radio.volume < 0.6) return;
                    click("mini-station-2"); advance(); break;
                case 7:
                    if (!app.radio.playing || app.radio.stationIndex !== 2) return;
                    check(selector.currentText === "JungleTrain", "Station state shared with full player");
                    click("mini-play"); check(!app.radio.wantsPlay, "Mini pause");
                    click("mini-tab-mixes"); advance(); break;
                case 8:
                    check(nodes(mini.contentItem).some(function(n) { return n.text === "Test mix" && n.visible; }), "Recent mixes in mini");
                    click("mini-tab-explore"); advance(); break;
                case 9:
                    click("mini-nav-schedule"); advance(); break;
                case 10:
                    if (Qt.platform.os === "linux" && !app.active) return;
                    check(app.visible && !mini.visible && app.library.tab === "schedule", "Explore opens full page");
                    Platform.miniPlayerRequested(); advance(); break;
                case 11:
                    if (!mini.visible || (Qt.platform.os === "linux" && !mini.active)) return;
                    click("mini-history"); advance(); break;
                case 12:
                    if (Qt.platform.os === "linux" && !app.active) return;
                    check(app.visible && !mini.visible && app.library.tab === "history", "Mini history navigation");
                    Platform.miniPlayerRequested(); advance(); break;
                case 13:
                    if (!mini.visible || (Qt.platform.os === "linux" && !mini.active)) return;
                    mini.contentItem.children[1].forceActiveFocus();
                    miniInput.keyClick(Qt.Key_Escape);
                    advance(); break;
                case 14:
                    if (Qt.platform.os === "linux" && !app.active) return;
                    check(!mini.visible, "Escape dismisses mini");
                    Platform.miniPlayerRequested(); advance(); break;
                case 15:
                    if (!mini.visible || (Qt.platform.os === "linux" && !mini.active)) return;
                    app.requestActivate(); advance(); break;
                case 16:
                    if (app.ticks < 3) return;
                    if (Qt.platform.os === "linux") check(app.nativeFocusObserved, "Linux mini must receive focus");
                    if (app.nativeFocusObserved) check(!mini.visible, "Focus loss dismisses mini");
                    else { console.log("SKIP: native focus-loss check; macOS did not activate the test app"); mini.hide(); }
                    Platform.miniPlayerRequested(); advance(); break;
                case 17:
                    if (!mini.visible || (Qt.platform.os === "linux" && !mini.active)) return;
                    Platform.miniPlayerRequested(); check(!mini.visible, "Menu-bar toggle closes mini");
                    app.radio.play(); advance(); break;
                case 18:
                    if (!app.radio.playing) return;
                    app.close(); advance(); break;
                case 19:
                    check(!app.visible && app.radio.playing, "Playback survives closing main window");
                    Platform.miniPlayerRequested(); advance(); break;
                case 20:
                    if (!mini.visible || (Qt.platform.os === "linux" && !mini.active)) return;
                    console.log("PASS: menu-bar shared playback, close-to-tray, station/quality/volume/mute, pause, mixes, navigation, history, Escape/toggle dismissal, dropdown contrast and keyboard selection");
                    click("mini-quit"); break;
                }
            } catch (error) { console.error("FAIL:", error.message); Qt.exit(1); }
        }
    }
}
