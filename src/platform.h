#pragma once
#include <QObject>
#include <QVariantMap>
#include <QSystemTrayIcon>
#include <QWindow>

class Platform : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString lastNotification READ lastNotification NOTIFY notificationChanged)
    Q_PROPERTY(bool trayAvailable READ trayAvailable NOTIFY trayAvailableChanged)
public:
    explicit Platform(QObject *parent = nullptr);
    QString lastNotification() const { return m_notification; }
    QString stateDirectory() const;
    void setupTray();
    bool trayAvailable() const;
    static QRect miniPlayerGeometry(const QRect &anchor, const QRect &available, const QSize &requested);
    Q_INVOKABLE void presentMiniPlayer(QWindow *window);
    Q_INVOKABLE void positionMiniPlayer(QWindow *window);
    Q_INVOKABLE void fitWindowToScreen(QWindow *window);
    Q_INVOKABLE QString environment(const QString &name) const;
    Q_INVOKABLE QVariantMap loadLibrary();
    Q_INVOKABLE QString saveLibrary(const QString &text);
    Q_INVOKABLE QVariantMap loadPlayer() const;
    Q_INVOKABLE void savePlayer(const QVariantMap &settings);
    Q_INVOKABLE void notify(const QString &title, const QString &body);
signals:
    void notificationChanged();
    void showRequested();
    void quitRequested();
    void miniPlayerRequested();
    void shutdownRequested();
    void trayAvailableChanged();
private:
    QString libraryPath() const;
    QString m_notification;
    QSystemTrayIcon *m_tray = nullptr;
    bool m_libraryReadable = false;
    QRect m_miniAnchor;
};
