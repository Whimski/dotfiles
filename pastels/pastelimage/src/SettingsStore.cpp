#include "SettingsStore.h"

SettingsStore::SettingsStore(QObject *parent)
    : QObject(parent)
    , m_settings(QSettings::IniFormat, QSettings::UserScope, "PastelImage", "PastelImage")
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

QString SettingsStore::background() const { return m_settings.value("ui/background", "theme").toString(); }
void SettingsStore::setBackground(const QString &b)
{ if (background() == b) return; m_settings.setValue("ui/background", b); emit backgroundChanged(); }

bool SettingsStore::saveClipboardOnly() const { return m_settings.value("ui/saveClipboardOnly", false).toBool(); }
void SettingsStore::setSaveClipboardOnly(bool b)
{ if (saveClipboardOnly() == b) return; m_settings.setValue("ui/saveClipboardOnly", b); emit saveClipboardOnlyChanged(); }

void SettingsStore::saveWindow(int w, int h)
{ m_settings.setValue("ui/winW", w); m_settings.setValue("ui/winH", h); }
int SettingsStore::windowWidth() const  { return m_settings.value("ui/winW", 1100).toInt(); }
int SettingsStore::windowHeight() const { return m_settings.value("ui/winH", 720).toInt(); }
