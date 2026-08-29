#include "SettingsStore.h"

#include <QDir>
#include <QFileInfo>

SettingsStore::SettingsStore(QObject *parent)
    : QObject(parent)
    , m_settings(QSettings::IniFormat, QSettings::UserScope, "PastelFM", "PastelFM")
{
}

QString SettingsStore::theme() const
{
    return m_settings.value("ui/theme", "Lavender").toString();
}

void SettingsStore::setTheme(const QString &t)
{
    if (theme() == t) return;
    m_settings.setValue("ui/theme", t);
    emit themeChanged();
}

QString SettingsStore::mode() const
{
    // Migrate from the legacy followSystemTheme/darkMode keys on first read.
    if (m_settings.contains("ui/mode"))
        return m_settings.value("ui/mode").toString();
    if (m_settings.value("ui/followSystemTheme", false).toBool())
        return "auto";
    return m_settings.value("ui/darkMode", false).toBool() ? "dark" : "light";
}

void SettingsStore::setMode(const QString &m)
{
    if (mode() == m) return;
    m_settings.setValue("ui/mode", m);
    emit modeChanged();
}

QString SettingsStore::customPrimary() const
{
    return m_settings.value("ui/customPrimary", "#7aa2f7").toString();
}

void SettingsStore::setCustomPrimary(const QString &c)
{
    if (customPrimary() == c) return;
    m_settings.setValue("ui/customPrimary", c);
    emit customPrimaryChanged();
}

QString SettingsStore::customSecondary() const
{
    return m_settings.value("ui/customSecondary", "#bb9af7").toString();
}

void SettingsStore::setCustomSecondary(const QString &c)
{
    if (customSecondary() == c) return;
    m_settings.setValue("ui/customSecondary", c);
    emit customSecondaryChanged();
}

bool SettingsStore::darkMode() const
{
    return m_settings.value("ui/darkMode", false).toBool();
}

void SettingsStore::setDarkMode(bool v)
{
    if (darkMode() == v) return;
    m_settings.setValue("ui/darkMode", v);
    emit darkModeChanged();
}

bool SettingsStore::followSystemTheme() const
{
    return m_settings.value("ui/followSystemTheme", false).toBool();
}

void SettingsStore::setFollowSystemTheme(bool v)
{
    if (followSystemTheme() == v) return;
    m_settings.setValue("ui/followSystemTheme", v);
    emit followSystemThemeChanged();
}

int SettingsStore::windowOpacity() const
{
    return m_settings.value("ui/windowOpacity", 100).toInt();
}

void SettingsStore::setWindowOpacity(int v)
{
    v = qBound(50, v, 100);
    if (windowOpacity() == v) return;
    m_settings.setValue("ui/windowOpacity", v);
    emit windowOpacityChanged();
}

QString SettingsStore::viewMode() const
{
    return m_settings.value("ui/viewMode", "grid").toString();
}

void SettingsStore::setViewMode(const QString &v)
{
    if (viewMode() == v) return;
    m_settings.setValue("ui/viewMode", v);
    emit viewModeChanged();
}

bool SettingsStore::showHidden() const
{
    return m_settings.value("ui/showHidden", false).toBool();
}

void SettingsStore::setShowHidden(bool v)
{
    if (showHidden() == v) return;
    m_settings.setValue("ui/showHidden", v);
    emit showHiddenChanged();
}

QVariantList SettingsStore::bookmarks() const
{
    return m_settings.value("bookmarks").toList();
}

void SettingsStore::writeBookmarks(const QVariantList &list)
{
    m_settings.setValue("bookmarks", list);
    emit bookmarksChanged();
}

void SettingsStore::addBookmark(const QString &path, const QString &name)
{
    if (path.isEmpty()) return;
    QVariantList list = bookmarks();
    for (const QVariant &v : list)
        if (v.toMap().value("path").toString() == path)
            return; // already bookmarked
    QVariantMap m;
    m["path"] = path;
    m["name"] = name.isEmpty() ? QFileInfo(path).fileName() : name;
    if (m["name"].toString().isEmpty())
        m["name"] = path; // root
    list.append(m);
    writeBookmarks(list);
}

void SettingsStore::removeBookmark(const QString &path)
{
    QVariantList list = bookmarks();
    for (int i = 0; i < list.size(); ++i) {
        if (list.at(i).toMap().value("path").toString() == path) {
            list.removeAt(i);
            writeBookmarks(list);
            return;
        }
    }
}

bool SettingsStore::isBookmarked(const QString &path) const
{
    for (const QVariant &v : bookmarks())
        if (v.toMap().value("path").toString() == path)
            return true;
    return false;
}

QVariantList SettingsStore::connections() const
{
    return m_settings.value("connections").toList();
}

void SettingsStore::writeConnections(const QVariantList &list)
{
    m_settings.setValue("connections", list);
    emit connectionsChanged();
}

void SettingsStore::addConnection(const QVariantMap &conn)
{
    QVariantMap c = conn;
    c.remove("password"); // never persist secrets
    QVariantList list = connections();
    list.append(c);
    writeConnections(list);
}

void SettingsStore::removeConnection(int index)
{
    QVariantList list = connections();
    if (index < 0 || index >= list.size()) return;
    list.removeAt(index);
    writeConnections(list);
}

void SettingsStore::renameConnection(int index, const QString &label)
{
    QVariantList list = connections();
    if (index < 0 || index >= list.size() || label.trimmed().isEmpty()) return;
    QVariantMap m = list.at(index).toMap();
    m["label"] = label.trimmed();
    list[index] = m;
    writeConnections(list);
}

void SettingsStore::saveWindow(int w, int h)
{
    m_settings.setValue("ui/winW", w);
    m_settings.setValue("ui/winH", h);
}

int SettingsStore::windowWidth() const  { return m_settings.value("ui/winW", 1180).toInt(); }
int SettingsStore::windowHeight() const { return m_settings.value("ui/winH", 720).toInt(); }
