import QtQuick
import QtTest
import DnbRadio

Main {
    id: app
    TestCase { id: input; name: "NativePlayer"; when: false }
    property int stage: 0
    property int ticks: 0
    property string action: ""
    function check(value, message) { if (!value) throw new Error(message); }
    function nodes(item, seen) {
        seen = seen || [];
        if (!item || seen.indexOf(item) !== -1) return [];
        seen.push(item);
        var result = [item];
        if (item.contentItem) result = result.concat(nodes(item.contentItem, seen));
        if (item.children) for (var child of item.children) result = result.concat(nodes(child, seen));
        return result;
    }
    function find(name) { return nodes(app.contentItem).find(function(item) { return item.objectName === name; }); }
    function hasText(text) { return nodes(app.contentItem).some(function(item) { return typeof item.text === "string" && item.text.indexOf(text) !== -1; }); }
    function checkButtonLabels() {
        var labels = ["Home", "Recorded mixes", "Show schedule", "My library", "Contributors", "Play", "Song history", "Live radio"];
        nodes(app.contentItem).forEach(function(item) {
            if (item.contentItem && labels.indexOf(item.text) !== -1)
                check(!item.contentItem.truncated, "button label clipped: " + item.text);
        });
    }
    function advance() { stage++; ticks = 0; }
    Timer {
        interval: 80; running: true; repeat: true
        onTriggered: {
            try {
                if (++app.ticks > 250) throw new Error("Timeout at stage " + app.stage);
                var library = app.radio.library;
                switch (app.stage) {
                case 0:
                    if (!library.storageReady || library.latest.length !== 5 || !library.events.length) return;
                    check(app.radio.stations.length === 6, "station list");
                    check(!app.radio.wantsPlay, "never autoplay");
                    check(hasText("Recently aired"), "home screen");
                    checkButtonLabels();
                    library.open("mixes"); advance(); break;
                case 1:
                    var card = find("mix-card-58079");
                    if (!card || !find("artwork-image") || find("artwork-image").status !== Image.Ready) return;
                    input.mouseClick(card, card.width / 2, 15);
                    advance(); break;
                case 2:
                    if (!hasText("Full mix description")) return;
                    check(library.selectedMix.id === "58079", "click opens mix details");
                    library.toggleFavorite(library.selectedMix);
                    library.open("library"); advance(); break;
                case 3:
                    if (!find("library-artwork")) return;
                    check(find("library-artwork").width >= 96, "large saved artwork");
                    library.open("schedule"); advance(); break;
                case 4:
                    if (!find("schedule-artwork")) return;
                    check(find("schedule-artwork").width >= 112, "large schedule artwork");
                    library.toggleReminder(library.events[0]);
                    check(library.notificationsSent === 1, "show reminder");
                    library.open("contributors"); advance(); break;
                case 5: case 7: case 9:
                    if (library.supportLoading || !find("contributor-card-0")) return;
                    check(library.selectedProfile === null, "profile reset before action");
                    var donor = find("contributor-card-0");
                    if (app.stage === 5) input.mouseClick(donor, donor.width / 2, 12);
                    else { donor.forceActiveFocus(); input.keyClick(app.stage === 7 ? Qt.Key_Return : Qt.Key_Space); }
                    advance(); break;
                case 6: case 8: case 10:
                    if (!hasText("Original jungle")) return;
                    check(library.selectedProfile.slug === "djfk", "contributor profile action");
                    check(library.selectedProfile.stats.plays === 12345, "DJ stats");
                    if (app.stage < 10) library.open("contributors");
                    else library.fetchProfileMixes(2);
                    advance(); break;
                case 11:
                    if (library.profilePage !== 2 || library.profileMixLoading) return;
                    check(library.profileRecords[0].id === "58078", "DJ mix pagination");
                    library.open("history"); advance(); break;
                case 12:
                    if (!hasText("History tune 15")) return;
                    check(app.radio.purchaseLinks[0].label === "Bandcamp", "purchase link");
                    app.radio.muted = true;
                    app.radio.mode = "archive";
                    app.radio.recording = {id: "58079", title: "Playback fixture", artist: "Test DJ", audio: Platform.environment("DNBRADIO_API_BASE") + "/audio.wav"};
                    app.radio.play(); advance(); break;
                case 13:
                    if (!app.radio.playing || !app.radio.seekable || app.radio.position < 100) return;
                    app.radio.seek(3000); advance(); break;
                case 14:
                    if (app.radio.position < 2900) return;
                    app.radio.pause();
                    library.saveNow();
                    check(library.recent.length === 1, "resume position saved");
                    library.open("mixes"); app.width = 800; app.height = 650;
                    advance(); break;
                case 15:
                    if (app.ticks < 3) return;
                    check(find("mix-card-58079").width > 100, "narrow mix grid");
                    checkButtonLabels();
                    app.radio.volume = 0.37;
                    console.log("PASS: standalone home, mixes, artwork fallback, library, schedule, reminders, contributor click/Return/Space, DJ stats/pagination, history, purchase links, real audio playback/seek, saved resume, narrow layout");
                    Platform.quitRequested(); break;
                }
            } catch (error) {
                console.error("FAIL:", error.message, app.radio.status());
                Qt.exit(1);
            }
        }
    }
}
