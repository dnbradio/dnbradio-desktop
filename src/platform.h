#pragma once
#include <QObject>
#include <QVariantMap>
#include <QSystemTrayIcon>

class Platform : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString lastNotification READ lastNotification NOTIFY notificationChanged)
public:
    explicit Platform(QObject *parent = nullptr);
    QString lastNotification() const { return m_notification; }
    QString stateDirectory() const;
    void setupTray();
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
private:
    QString libraryPath() const;
    QString m_notification;
    QSystemTrayIcon *m_tray = nullptr;
    bool m_libraryReadable = false;
};
