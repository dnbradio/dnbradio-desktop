#include "platform.h"
#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QLockFile>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QTimer>
#include <memory>

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    app.setOrganizationName("DNBRADIO");
    app.setApplicationName("DNBRADIO");
    app.setApplicationVersion(APP_VERSION);
    app.setDesktopFileName("com.dnbradio.Player");
    app.setWindowIcon(QIcon(":/packaging/com.dnbradio.Player.svg"));
    QQuickStyle::setStyle("Basic");
    QCommandLineParser parser;
    parser.setApplicationDescription("DNBRADIO desktop radio player");
    parser.addHelpOption();
    parser.addVersionOption();
#ifdef DNBRADIO_TEST_HARNESS
    parser.addOption({"test-qml", "Load an isolated QML test harness (development builds only).", "file"});
#endif
    parser.process(app);
    Platform platform;
    if (!QDir().mkpath(platform.stateDirectory())) {
        qCritical("Could not create the application data directory.");
        return 1;
    }
    QLockFile lock(QDir(platform.stateDirectory()).filePath("player.lock"));
    if (!lock.tryLock()) {
        qCritical("DNBRADIO is already running or its data directory cannot be locked.");
        return 1;
    }
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::exit, &app, &QCoreApplication::exit);
    QObject::connect(&engine, &QQmlApplicationEngine::quit, &app, &QCoreApplication::quit);
    engine.rootContext()->setContextProperty("Platform", &platform);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
#ifdef DNBRADIO_TEST_HARNESS
    if (parser.isSet("test-qml")) {
        engine.load(QUrl::fromLocalFile(parser.value("test-qml")));
    } else
#endif
    {
        platform.setupTray();
        engine.loadFromModule("DnbRadio", "Main");
    }
    return app.exec();
}
