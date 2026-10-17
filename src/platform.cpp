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
#include <QCursor>
#include <QScreen>

#ifdef Q_OS_MACOS
void activateMacApplication();
#endif

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
    if (m_tray) return;
    QIcon icon(":/packaging/com.dnbradio.Player.svg");
#ifdef Q_OS_MACOS
    icon = QIcon(":/packaging/menu-bar.svg");
    icon.setIsMask(true);
#endif
    m_tray = new QSystemTrayIcon(icon, this);
    m_tray->setToolTip("DNBRADIO");
#ifndef Q_OS_MACOS
    auto *menu = new QMenu;
    connect(m_tray, &QObject::destroyed, menu, &QObject::deleteLater);
#ifdef Q_OS_LINUX
    menu->addAction("Mini player", this, &Platform::miniPlayerRequested);
#endif
    menu->addAction("Open player", this, &Platform::showRequested);
    menu->addAction("Quit", this, &Platform::quitRequested);
    m_tray->setContextMenu(menu);
#endif
    connect(m_tray, &QSystemTrayIcon::activated, this, [this](auto reason) {
#ifdef Q_OS_MACOS
        if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::Context)
            emit miniPlayerRequested();
#elif defined(Q_OS_LINUX)
        if (reason == QSystemTrayIcon::Trigger) emit miniPlayerRequested();
#else
        if (reason == QSystemTrayIcon::Trigger) emit showRequested();
#endif
    });
    m_tray->show();
    emit trayAvailableChanged();
#if defined(Q_OS_MACOS) || defined(Q_OS_LINUX)
    QApplication::setQuitOnLastWindowClosed(!trayAvailable());
    // A panel may start late or restart. Never strand a hidden player without its tray.
    auto *availability = new QTimer(this);
    connect(availability, &QTimer::timeout, this, [this, previous = trayAvailable()]() mutable {
        const bool available = trayAvailable();
        if (available == previous) return;
        previous = available;
        QApplication::setQuitOnLastWindowClosed(!available);
        emit trayAvailableChanged();
    });
    availability->start(2000);
#endif
}

bool Platform::trayAvailable() const {
    return m_tray && m_tray->isVisible() && QSystemTrayIcon::isSystemTrayAvailable();
}

QRect Platform::miniPlayerGeometry(const QRect &anchor, const QRect &available, const QSize &requested) {
    const auto size = requested.boundedTo(available.size());
    const int below = anchor.bottom() + 7;
    const int above = anchor.top() - size.height() - 6;
    const int y = below + size.height() <= available.bottom() + 1 ? below : above;
    return QRect(QPoint(
        qBound(available.left(), anchor.center().x() - size.width() / 2, available.right() - size.width() + 1),
        qBound(available.top(), y, available.bottom() - size.height() + 1)), size);
}

void Platform::positionMiniPlayer(QWindow *window) {
    if (!window) return;
    auto *screen = QGuiApplication::screenAt(m_miniAnchor.center());
    if (!screen) screen = QGuiApplication::primaryScreen();
    if (!screen) return;
    window->setScreen(screen);
    window->setGeometry(miniPlayerGeometry(m_miniAnchor,
        screen->availableGeometry().adjusted(8, 8, -8, -8), window->size()));
}

void Platform::presentMiniPlayer(QWindow *window) {
    if (!window) return;
    if (window->isVisible()) {
        window->hide();
        return;
    }
    m_miniAnchor = m_tray ? m_tray->geometry() : QRect();
    // StatusNotifier hosts often omit icon geometry; use the click's screen/location.
    if (m_miniAnchor.isEmpty()) m_miniAnchor = QRect(QCursor::pos(), QSize(1, 1));
    positionMiniPlayer(window);
    window->show();
#ifdef Q_OS_MACOS
    activateMacApplication();
#endif
    window->raise();
    window->requestActivate();
}

void Platform::notify(const QString &title, const QString &body) {
    m_notification = title + " · " + body;
    emit notificationChanged();
    if (m_tray) m_tray->showMessage(title, body, QSystemTrayIcon::Information, 10000);
    QTimer::singleShot(15000, this, [this] { m_notification.clear(); emit notificationChanged(); });
}
