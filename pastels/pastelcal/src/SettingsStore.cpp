#include "SettingsStore.h"

#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>

SettingsStore::SettingsStore(QObject *parent)
    : QObject(parent)
    , m_settings(QSettings::IniFormat, QSettings::UserScope, "PastelCal", "PastelCal")
{
}

QString SettingsStore::theme() const { return m_settings.value("ui/theme", "Mint").toString(); }
void SettingsStore::setTheme(const QString &t)
{ if (theme() == t) return; m_settings.setValue("ui/theme", t); emit themeChanged(); }

QString SettingsStore::mode() const { return m_settings.value("ui/mode", "dark").toString(); }
void SettingsStore::setMode(const QString &m)
{ if (mode() == m) return; m_settings.setValue("ui/mode", m); emit modeChanged(); }

QString SettingsStore::customPrimary() const { return m_settings.value("ui/customPrimary", "#7aa2f7").toString(); }
void SettingsStore::setCustomPrimary(const QString &c)
{ if (customPrimary() == c) return; m_settings.setValue("ui/customPrimary", c); emit customPrimaryChanged(); }

QString SettingsStore::customSecondary() const { return m_settings.value("ui/customSecondary", "#bb9af7").toString(); }
void SettingsStore::setCustomSecondary(const QString &c)
{ if (customSecondary() == c) return; m_settings.setValue("ui/customSecondary", c); emit customSecondaryChanged(); }

int SettingsStore::windowOpacity() const { return m_settings.value("ui/windowOpacity", 100).toInt(); }
void SettingsStore::setWindowOpacity(int v)
{ v = qBound(50, v, 100); if (windowOpacity() == v) return; m_settings.setValue("ui/windowOpacity", v); emit windowOpacityChanged(); }

QString SettingsStore::googleClientId() const { return m_settings.value("google/clientId").toString(); }
void SettingsStore::setGoogleClientId(const QString &id) { m_settings.setValue("google/clientId", id); }

QString SettingsStore::googleClientSecret() const { return m_settings.value("google/clientSecret").toString(); }
void SettingsStore::setGoogleClientSecret(const QString &secret) { m_settings.setValue("google/clientSecret", secret); }

QString SettingsStore::googleRefreshToken() const { return m_settings.value("google/refreshToken").toString(); }
void SettingsStore::setGoogleRefreshToken(const QString &t)
{ m_settings.setValue("google/refreshToken", t); emit googleChanged(); }

QString SettingsStore::googleAccount() const { return m_settings.value("google/account").toString(); }
void SettingsStore::setGoogleAccount(const QString &email)
{ m_settings.setValue("google/account", email); emit googleChanged(); }

QStringList SettingsStore::hiddenCalendars() const { return m_settings.value("calendars/hidden").toStringList(); }
void SettingsStore::setCalendarHidden(const QString &id, bool hidden)
{
    QStringList list = hiddenCalendars();
    const bool has = list.contains(id);
    if (hidden && !has) list.append(id);
    else if (!hidden && has) list.removeAll(id);
    else return;
    m_settings.setValue("calendars/hidden", list);
}

QVariantList SettingsStore::icsFeeds() const
{
    const QByteArray raw = m_settings.value("ics/feeds").toString().toUtf8();
    QVariantList out;
    for (const QJsonValue &v : QJsonDocument::fromJson(raw).array())
        out.append(v.toObject().toVariantMap());
    return out;
}

void SettingsStore::setIcsFeeds(const QVariantList &feeds)
{
    QJsonArray arr;
    for (const QVariant &v : feeds)
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    m_settings.setValue("ics/feeds",
        QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
}

QVariantMap SettingsStore::calendarColors() const
{
    const QByteArray raw = m_settings.value("calendars/colors").toString().toUtf8();
    return QJsonDocument::fromJson(raw).object().toVariantMap();
}

void SettingsStore::setCalendarColor(const QString &id, const QString &hex)
{
    QVariantMap m = calendarColors();
    m[id] = hex;
    m_settings.setValue("calendars/colors",
        QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(m)).toJson(QJsonDocument::Compact)));
}

void SettingsStore::saveWindow(int w, int h)
{ m_settings.setValue("ui/winW", w); m_settings.setValue("ui/winH", h); }
int SettingsStore::windowWidth() const  { return m_settings.value("ui/winW", 1120).toInt(); }
int SettingsStore::windowHeight() const { return m_settings.value("ui/winH", 720).toInt(); }
