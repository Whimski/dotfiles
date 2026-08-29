#pragma once

#include <QObject>
#include <QSettings>
#include <QVariantList>
#include <QVariantMap>

// Persists bookmarks, saved connection profiles, and UI preferences
// (theme, view mode, window geometry) via QSettings under ~/.config/PastelFM.
// Passwords are intentionally never stored.
class SettingsStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)                       // "light"|"dark"|"auto"
    Q_PROPERTY(QString customPrimary READ customPrimary WRITE setCustomPrimary NOTIFY customPrimaryChanged)
    Q_PROPERTY(QString customSecondary READ customSecondary WRITE setCustomSecondary NOTIFY customSecondaryChanged)
    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)
    Q_PROPERTY(bool followSystemTheme READ followSystemTheme WRITE setFollowSystemTheme NOTIFY followSystemThemeChanged)
    Q_PROPERTY(int windowOpacity READ windowOpacity WRITE setWindowOpacity NOTIFY windowOpacityChanged)
    Q_PROPERTY(QString viewMode READ viewMode WRITE setViewMode NOTIFY viewModeChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(QVariantList bookmarks READ bookmarks NOTIFY bookmarksChanged)
    Q_PROPERTY(QVariantList connections READ connections NOTIFY connectionsChanged)

public:
    explicit SettingsStore(QObject *parent = nullptr);

    QString theme() const;
    void setTheme(const QString &t);

    QString mode() const;
    void setMode(const QString &m);

    QString customPrimary() const;
    void setCustomPrimary(const QString &c);

    QString customSecondary() const;
    void setCustomSecondary(const QString &c);

    bool darkMode() const;
    void setDarkMode(bool v);

    bool followSystemTheme() const;
    void setFollowSystemTheme(bool v);

    int windowOpacity() const;      // percent, 50..100
    void setWindowOpacity(int v);

    QString viewMode() const;
    void setViewMode(const QString &v);

    bool showHidden() const;
    void setShowHidden(bool v);

    QVariantList bookmarks() const;
    QVariantList connections() const;

    Q_INVOKABLE void addBookmark(const QString &path, const QString &name = QString());
    Q_INVOKABLE void removeBookmark(const QString &path);
    Q_INVOKABLE bool isBookmarked(const QString &path) const;

    // conn: {type:"ssh"|"samba", label, host, port, user, remotePath, share, domain}
    Q_INVOKABLE void addConnection(const QVariantMap &conn);
    Q_INVOKABLE void removeConnection(int index);
    Q_INVOKABLE void renameConnection(int index, const QString &label);

    Q_INVOKABLE void saveWindow(int w, int h);
    Q_INVOKABLE int windowWidth() const;
    Q_INVOKABLE int windowHeight() const;

signals:
    void themeChanged();
    void modeChanged();
    void customPrimaryChanged();
    void customSecondaryChanged();
    void darkModeChanged();
    void followSystemThemeChanged();
    void windowOpacityChanged();
    void viewModeChanged();
    void showHiddenChanged();
    void bookmarksChanged();
    void connectionsChanged();

private:
    void writeBookmarks(const QVariantList &list);
    void writeConnections(const QVariantList &list);

    QSettings m_settings;
};
