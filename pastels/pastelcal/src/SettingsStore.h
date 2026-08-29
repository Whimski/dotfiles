#pragma once

#include <QObject>
#include <QSettings>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// Persisted preferences for PastelCal via QSettings (~/.config/PastelCal).
// Theme keys mirror pastelfm so both apps share the pasteltheme look; plus the
// Google OAuth refresh token and the set of hidden (unchecked) calendars.
class SettingsStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)                 // "light"|"dark"|"auto"
    Q_PROPERTY(QString customPrimary READ customPrimary WRITE setCustomPrimary NOTIFY customPrimaryChanged)
    Q_PROPERTY(QString customSecondary READ customSecondary WRITE setCustomSecondary NOTIFY customSecondaryChanged)
    Q_PROPERTY(int windowOpacity READ windowOpacity WRITE setWindowOpacity NOTIFY windowOpacityChanged)

public:
    explicit SettingsStore(QObject *parent = nullptr);

    QString theme() const;             void setTheme(const QString &t);
    QString mode() const;              void setMode(const QString &m);
    QString customPrimary() const;     void setCustomPrimary(const QString &c);
    QString customSecondary() const;   void setCustomSecondary(const QString &c);
    int windowOpacity() const;         void setWindowOpacity(int v);   // percent 50..100

    // Google OAuth client credentials (entered in the UI) + refresh token.
    // Kept out of QML properties; accessed by GoogleCalendarService.
    QString googleClientId() const;
    void setGoogleClientId(const QString &id);
    QString googleClientSecret() const;
    void setGoogleClientSecret(const QString &secret);
    QString googleRefreshToken() const;
    void setGoogleRefreshToken(const QString &t);
    QString googleAccount() const;
    void setGoogleAccount(const QString &email);

    // Hidden calendar ids (unchecked in the sidebar).
    QStringList hiddenCalendars() const;
    void setCalendarHidden(const QString &id, bool hidden);

    // iCal / ICS read-only feed URLs: a list of { url, name, color }.
    QVariantList icsFeeds() const;
    void setIcsFeeds(const QVariantList &feeds);

    // Per-calendar colour overrides: { calendarId: "#rrggbb" }.
    QVariantMap calendarColors() const;
    void setCalendarColor(const QString &id, const QString &hex);

    Q_INVOKABLE void saveWindow(int w, int h);
    Q_INVOKABLE int windowWidth() const;
    Q_INVOKABLE int windowHeight() const;

signals:
    void themeChanged();
    void modeChanged();
    void customPrimaryChanged();
    void customSecondaryChanged();
    void windowOpacityChanged();
    void googleChanged();

private:
    QSettings m_settings;
};
