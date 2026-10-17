#include "platform.h"
#include <QFile>
#include <QTemporaryDir>
#include <QTest>
#include <QMenu>
#include <QSignalSpy>

class PlatformTest : public QObject {
    Q_OBJECT
private slots:
    void trayActivation() {
        Platform platform;
        platform.setupTray();
        auto *tray = platform.findChild<QSystemTrayIcon *>();
        QVERIFY(tray);
        QSignalSpy mini(&platform, &Platform::miniPlayerRequested);
        QSignalSpy full(&platform, &Platform::showRequested);
        emit tray->activated(QSystemTrayIcon::Trigger);
#if defined(Q_OS_MACOS) || defined(Q_OS_LINUX)
        QCOMPARE(mini.count(), 1);
        QCOMPARE(full.count(), 0);
#else
        QCOMPARE(full.count(), 1);
#endif
#ifdef Q_OS_LINUX
        QVERIFY(tray->contextMenu());
        const auto actions = tray->contextMenu()->actions();
        QCOMPARE(actions.size(), 3);
        actions[0]->trigger();
        QCOMPARE(mini.count(), 2);
        actions[1]->trigger();
        QCOMPARE(full.count(), 1);
        QSignalSpy quit(&platform, &Platform::quitRequested);
        actions[2]->trigger();
        QCOMPARE(quit.count(), 1);
#endif
    }

    void panelStaysOnScreen() {
        const QRect available(-1920, 24, 1920, 1024);
        const QRect bottom(-100, 1048, 24, 32);
        const auto panel = Platform::miniPlayerGeometry(bottom, available, QSize(440, 580));
        QVERIFY(available.contains(panel));
        QVERIFY(panel.bottom() < bottom.top());
        const auto taller = Platform::miniPlayerGeometry(bottom, available, QSize(440, 700));
        QCOMPARE(panel.bottom(), taller.bottom());
        const QRect top(-1900, 0, 24, 24);
        const auto fromTop = Platform::miniPlayerGeometry(top, available, QSize(440, 580));
        QVERIFY(available.contains(fromTop));
        QVERIFY(fromTop.top() > top.bottom());
        const auto fromSide = Platform::miniPlayerGeometry(QRect(-1920, 500, 32, 24), available, QSize(440, 580));
        QVERIFY(available.contains(fromSide));
        const QRect smallScreen(0, 0, 320, 240);
        QVERIFY(smallScreen.contains(Platform::miniPlayerGeometry(QRect(310, 230, 1, 1), smallScreen, QSize(440, 580))));
    }

    void persistenceAndCorruption() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        qputenv("DNBRADIO_DATA_DIR", dir.path().toUtf8());
        Platform platform;
        QVERIFY(!platform.loadLibrary().contains("error"));
        const QString text = "{\"version\":1,\"favorites\":[{\"id\":42}],\"recent\":[],\"reminders\":[]}";
        QCOMPARE(platform.saveLibrary(text), QString());
        Platform restarted;
        QCOMPARE(restarted.loadLibrary().value("text").toString(), text);
        QFile file(dir.filePath("library.json"));
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("damaged file"); file.close();
        Platform damaged;
        QVERIFY(damaged.loadLibrary().contains("error"));
        QVERIFY(!damaged.saveLibrary(text).isEmpty());
        QVERIFY(file.open(QIODevice::ReadOnly));
        QCOMPARE(file.readAll(), QByteArray("damaged file"));
        platform.savePlayer({{"station", "bassdrive"}, {"volume", 0.12}, {"muted", true}, {"quality", 1}});
        const auto settings = restarted.loadPlayer();
        QCOMPARE(settings.value("station").toString(), QString("bassdrive"));
        QCOMPARE(settings.value("volume").toDouble(), 0.12);
        QVERIFY(settings.value("muted").toBool());
        QVERIFY(!settings.contains("playing"));
    }
};
QTEST_MAIN(PlatformTest)
#include "platform_test.moc"
