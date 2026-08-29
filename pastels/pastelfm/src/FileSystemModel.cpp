#include "FileSystemModel.h"

#include <QDir>
#include <QLocale>
#include <QMimeDatabase>
#include <QMimeType>
#include <QCollator>
#include <algorithm>

FileSystemModel::FileSystemModel(QObject *parent)
    : QAbstractListModel(parent)
{
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this](const QString &) {
        reload();
    });
}

int FileSystemModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_entries.size();
}

static QString humanSize(qint64 bytes)
{
    return QLocale().formattedDataSize(bytes, 1, QLocale::DataSizeTraditionalFormat);
}

static QString iconNameFor(const QFileInfo &fi)
{
    if (fi.isDir())
        return "folder";
    const QString s = fi.suffix().toLower();
    static const QHash<QString, QString> map = {
        {"png","image"}, {"jpg","image"}, {"jpeg","image"}, {"gif","image"},
        {"svg","image"}, {"webp","image"}, {"bmp","image"},
        {"mp3","audio"}, {"flac","audio"}, {"wav","audio"}, {"ogg","audio"}, {"m4a","audio"},
        {"mp4","video"}, {"mkv","video"}, {"webm","video"}, {"mov","video"}, {"avi","video"},
        {"pdf","pdf"},
        {"zip","archive"}, {"tar","archive"}, {"gz","archive"}, {"xz","archive"},
        {"7z","archive"}, {"rar","archive"}, {"bz2","archive"}, {"zst","archive"},
        {"txt","text"}, {"md","text"}, {"log","text"},
        {"cpp","code"}, {"c","code"}, {"h","code"}, {"hpp","code"}, {"py","code"},
        {"js","code"}, {"ts","code"}, {"qml","code"}, {"json","code"}, {"xml","code"},
        {"sh","code"}, {"rs","code"}, {"go","code"}, {"java","code"}, {"html","code"},
        {"css","code"}, {"yml","code"}, {"yaml","code"}, {"toml","code"},
    };
    return map.value(s, "file");
}

QVariant FileSystemModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_entries.size())
        return {};
    const QFileInfo &fi = m_entries.at(index.row());
    switch (role) {
    case FileNameRole:     return fi.fileName();
    case FilePathRole:     return fi.absoluteFilePath();
    case IsDirRole:        return fi.isDir();
    case SizeRole:         return fi.isDir() ? -1 : fi.size();
    case SizeTextRole:     return fi.isDir() ? QStringLiteral("—") : humanSize(fi.size());
    case ModifiedRole:     return fi.lastModified();
    case ModifiedTextRole: return QLocale().toString(fi.lastModified(), QLocale::ShortFormat);
    case SuffixRole:       return fi.suffix();
    case IconNameRole:     return iconNameFor(fi);
    case IsHiddenRole:     return fi.isHidden();
    case IsSymlinkRole:    return fi.isSymLink();
    }
    return {};
}

QHash<int, QByteArray> FileSystemModel::roleNames() const
{
    return {
        {FileNameRole, "fileName"},
        {FilePathRole, "filePath"},
        {IsDirRole, "isDir"},
        {SizeRole, "size"},
        {SizeTextRole, "sizeText"},
        {ModifiedRole, "modified"},
        {ModifiedTextRole, "modifiedText"},
        {SuffixRole, "suffix"},
        {IconNameRole, "iconName"},
        {IsHiddenRole, "isHidden"},
        {IsSymlinkRole, "isSymlink"},
    };
}

void FileSystemModel::setPath(const QString &path)
{
    QString p = path;
    if (p.isEmpty())
        p = QDir::homePath();
    QFileInfo fi(p);
    if (fi.exists() && !fi.isDir())
        p = fi.absolutePath();
    p = QDir(p).absolutePath();
    if (p == m_path)
        return;

    if (!m_path.isEmpty() && !m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());

    m_path = p;
    if (QFileInfo::exists(m_path))
        m_watcher.addPath(m_path);

    emit pathChanged();
    reload();
}

void FileSystemModel::setShowHidden(bool v)
{
    if (m_showHidden == v) return;
    m_showHidden = v;
    emit showHiddenChanged();
    reload();
}

void FileSystemModel::setSortRole(const QString &r)
{
    if (m_sortRole == r) return;
    m_sortRole = r;
    emit sortRoleChanged();
    reload();
}

void FileSystemModel::setSortReversed(bool v)
{
    if (m_sortReversed == v) return;
    m_sortReversed = v;
    emit sortReversedChanged();
    reload();
}

void FileSystemModel::setFoldersFirst(bool v)
{
    if (m_foldersFirst == v) return;
    m_foldersFirst = v;
    emit foldersFirstChanged();
    reload();
}

void FileSystemModel::setFilter(const QString &f)
{
    if (m_filter == f) return;
    m_filter = f;
    emit filterChanged();
    reload();
}

bool FileSystemModel::writable() const
{
    return !m_path.isEmpty() && QFileInfo(m_path).isWritable();
}

void FileSystemModel::refresh()
{
    reload();
}

QString FileSystemModel::homePath() const { return QDir::homePath(); }
QString FileSystemModel::rootPath() const { return QDir::rootPath(); }

void FileSystemModel::reload()
{
    QDir dir(m_path);
    QDir::Filters filters = QDir::AllEntries | QDir::NoDotAndDotDot;
    if (m_showHidden)
        filters |= QDir::Hidden;

    QList<QFileInfo> list = dir.entryInfoList(filters, QDir::NoSort);

    if (!m_filter.isEmpty()) {
        const QString needle = m_filter.toLower();
        QList<QFileInfo> filtered;
        for (const QFileInfo &fi : list)
            if (fi.fileName().toLower().contains(needle))
                filtered.append(fi);
        list = filtered;
    }

    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);

    const QString role = m_sortRole;
    const bool rev = m_sortReversed;
    const bool foldersFirst = m_foldersFirst;

    std::sort(list.begin(), list.end(), [&](const QFileInfo &a, const QFileInfo &b) {
        if (foldersFirst && a.isDir() != b.isDir())
            return a.isDir();
        int cmp = 0;
        if (role == "size") {
            cmp = (a.size() < b.size()) ? -1 : (a.size() > b.size() ? 1 : 0);
        } else if (role == "modified") {
            cmp = (a.lastModified() < b.lastModified()) ? -1
                : (a.lastModified() > b.lastModified() ? 1 : 0);
        } else if (role == "suffix") {
            cmp = collator.compare(a.suffix(), b.suffix());
        } else { // fileName
            cmp = collator.compare(a.fileName(), b.fileName());
        }
        if (cmp == 0)
            cmp = collator.compare(a.fileName(), b.fileName());
        return rev ? cmp > 0 : cmp < 0;
    });

    beginResetModel();
    m_entries = list;
    endResetModel();
    emit countChanged();
}

QString FileSystemModel::cdInto(int index)
{
    if (index < 0 || index >= m_entries.size())
        return {};
    const QFileInfo &fi = m_entries.at(index);
    if (fi.isDir())
        return fi.absoluteFilePath();
    return {};
}

QString FileSystemModel::parentPath() const
{
    QDir dir(m_path);
    if (dir.isRoot())
        return {};
    if (!dir.cdUp())
        return {};
    return dir.absolutePath();
}

QString FileSystemModel::entryPath(int index) const
{
    if (index < 0 || index >= m_entries.size())
        return {};
    return m_entries.at(index).absoluteFilePath();
}

bool FileSystemModel::entryIsDir(int index) const
{
    if (index < 0 || index >= m_entries.size())
        return false;
    return m_entries.at(index).isDir();
}
