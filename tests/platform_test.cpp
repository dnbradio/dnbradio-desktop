#include "platform.h"
#include <QFile>
#include <QTemporaryDir>
#include <QTest>

class PlatformTest : public QObject {
    Q_OBJECT
private slots:
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
