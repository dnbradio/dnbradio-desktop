#include "platform.h"
#include <QApplication>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QMenu>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>

Platform::Platform(QObject *parent) : QObject(parent) {}

QString Platform::environment(const QString &name) const {
    // These overrides support local fixture servers without exposing arbitrary environment values to QML.
    static const QStringList allowed = {"DNBRADIO_API_BASE", "DNBRADIO_NOWPLAYING_URL", "DNBRADIO_BASSDRIVE_URL"};
    return allowed.contains(name) ? qEnvironmentVariable(name.toUtf8().constData()) : QString();
}

QString Platform::stateDirectory() const {
    const auto override = qEnvironmentVariable("DNBRADIO_DATA_DIR");
    return override.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) : override;
}

QString Platform::libraryPath() const { return QDir(stateDirectory()).filePath("library.json"); }

static bool validLibrary(const QJsonDocument &document) {
    const auto data = document.object();
    return document.isObject() && data.value("version").toInt() == 1
        && data.value("favorites").isArray() && data.value("recent").isArray()
        && data.value("reminders").isArray();
}

QVariantMap Platform::loadLibrary() {
    m_libraryReadable = false;
    if (!QDir().mkpath(stateDirectory()))
        return {{"error", "Library storage is unavailable. Check folder permissions."}};
    QFile file(libraryPath());
    if (!file.exists()) {
        m_libraryReadable = true;
        return {{"text", "{\"version\":1,\"favorites\":[],\"recent\":[],\"reminders\":[],\"notified\":[]}"}};
    }
    if (!file.open(QIODevice::ReadOnly))
        return {{"error", "Saved library could not be opened. Your existing file has been kept."}};
    const auto bytes = file.readAll();
    if (!validLibrary(QJsonDocument::fromJson(bytes)))
        return {{"error", "Saved library could not be read. Your existing file has been kept."}};
    m_libraryReadable = true;
    return {{"text", QString::fromUtf8(bytes)}};
}

QString Platform::saveLibrary(const QString &text) {
    if (!m_libraryReadable || !validLibrary(QJsonDocument::fromJson(text.toUtf8())))
        return "Library saving is disabled to protect your existing file.";
    QSaveFile file(libraryPath());
    const auto bytes = text.toUtf8();
    if (!file.open(QIODevice::WriteOnly) || file.write(bytes) != bytes.size() || !file.commit())
        return "Could not save your library. Check available disk space and permissions.";
    return {};
}

QVariantMap Platform::loadPlayer() const {
    QSettings settings(QDir(stateDirectory()).filePath("player.ini"), QSettings::IniFormat);
    return {{"station", settings.value("station", "dnbradio")},
        {"volume", settings.value("volume", 0.45).toDouble()},
        {"muted", settings.value("muted", false).toBool()},
        {"quality", settings.value("quality", 0).toInt()}};
}

void Platform::savePlayer(const QVariantMap &values) {
    QDir().mkpath(stateDirectory());
    QSettings settings(QDir(stateDirectory()).filePath("player.ini"), QSettings::IniFormat);
    for (const auto &key : {"station", "volume", "muted", "quality"})
        if (values.contains(key)) settings.setValue(key, values.value(key));
    settings.sync();
}

void Platform::setupTray() {
    if (!QSystemTrayIcon::isSystemTrayAvailable()) return;
    m_tray = new QSystemTrayIcon(QIcon(":/packaging/com.dnbradio.Player.svg"), this);
    m_tray->setToolTip("DNBRADIO");
    auto *menu = new QMenu;
    connect(m_tray, &QObject::destroyed, menu, &QObject::deleteLater);
    menu->addAction("Show DNBRADIO", this, &Platform::showRequested);
    menu->addAction("Quit", qApp, &QApplication::closeAllWindows);
    m_tray->setContextMenu(menu);
    connect(m_tray, &QSystemTrayIcon::activated, this, [this](auto reason) {
        if (reason == QSystemTrayIcon::Trigger) emit showRequested();
    });
    m_tray->show();
}

void Platform::notify(const QString &title, const QString &body) {
    m_notification = title + " · " + body;
    emit notificationChanged();
    if (m_tray) m_tray->showMessage(title, body, QSystemTrayIcon::Information, 10000);
    QTimer::singleShot(15000, this, [this] { m_notification.clear(); emit notificationChanged(); });
}
