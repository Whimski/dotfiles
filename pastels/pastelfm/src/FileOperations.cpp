#include "FileOperations.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QProcess>
#include <QLocale>
#include <QVariantMap>
#include <QVariantList>
#include <QDateTime>
#include <QtConcurrent>
#include <algorithm>
#include <functional>

FileOperations::FileOperations(QObject *parent)
    : QObject(parent)
{
}

bool FileOperations::trashAvailable() const
{
    return !QStandardPaths::findExecutable("gio").isEmpty();
}

void FileOperations::setBusy(bool v)
{
    if (m_busy == v) return;
    m_busy = v;
    emit busyChanged();
}

bool FileOperations::mkdir(const QString &parentDir, const QString &name)
{
    if (name.trimmed().isEmpty()) {
        emit error(tr("Folder name cannot be empty."));
        return false;
    }
    QDir dir(parentDir);
    if (dir.exists(name)) {
        emit error(tr("“%1” already exists.").arg(name));
        return false;
    }
    if (!dir.mkdir(name)) {
        emit error(tr("Could not create folder “%1”.").arg(name));
        return false;
    }
    return true;
}

bool FileOperations::createFile(const QString &parentDir, const QString &name)
{
    if (name.trimmed().isEmpty()) {
        emit error(tr("File name cannot be empty."));
        return false;
    }
    const QString path = QDir(parentDir).filePath(name);
    if (QFileInfo::exists(path)) {
        emit error(tr("“%1” already exists.").arg(name));
        return false;
    }
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly)) {
        emit error(tr("Could not create file “%1”.").arg(name));
        return false;
    }
    f.close();
    return true;
}

bool FileOperations::rename(const QString &path, const QString &newName)
{
    if (newName.trimmed().isEmpty()) {
        emit error(tr("Name cannot be empty."));
        return false;
    }
    QFileInfo fi(path);
    const QString target = fi.absoluteDir().filePath(newName);
    if (target == path)
        return true;
    if (QFileInfo::exists(target)) {
        emit error(tr("“%1” already exists.").arg(newName));
        return false;
    }
    if (!QFile::rename(path, target)) {
        emit error(tr("Could not rename to “%1”.").arg(newName));
        return false;
    }
    return true;
}

// --- recursive helpers (run on worker thread) ---

static bool copyRecursive(const QString &src, const QString &dst, QString *err)
{
    QFileInfo srcInfo(src);
    if (srcInfo.isDir()) {
        QDir().mkpath(dst);
        const QFileInfoList entries = QDir(src).entryInfoList(
            QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
        for (const QFileInfo &e : entries) {
            const QString childDst = QDir(dst).filePath(e.fileName());
            if (!copyRecursive(e.absoluteFilePath(), childDst, err))
                return false;
        }
        return true;
    }
    if (QFileInfo::exists(dst))
        QFile::remove(dst);
    if (!QFile::copy(src, dst)) {
        if (err) *err = FileOperations::tr("Failed to copy “%1”.").arg(srcInfo.fileName());
        return false;
    }
    return true;
}

static bool removeRecursive(const QString &path, QString *err)
{
    QFileInfo fi(path);
    if (fi.isDir() && !fi.isSymLink()) {
        QDir d(path);
        if (!d.removeRecursively()) {
            if (err) *err = FileOperations::tr("Failed to delete “%1”.").arg(fi.fileName());
            return false;
        }
        return true;
    }
    if (!QFile::remove(path)) {
        if (err) *err = FileOperations::tr("Failed to delete “%1”.").arg(fi.fileName());
        return false;
    }
    return true;
}

static QString uniqueDest(const QString &destDir, const QString &name)
{
    QString candidate = QDir(destDir).filePath(name);
    if (!QFileInfo::exists(candidate))
        return candidate;
    QFileInfo fi(name);
    const QString base = fi.completeBaseName();
    const QString suf = fi.suffix().isEmpty() ? QString() : "." + fi.suffix();
    for (int i = 1; i < 10000; ++i) {
        candidate = QDir(destDir).filePath(QStringLiteral("%1 (copy %2)%3").arg(base).arg(i).arg(suf));
        if (!QFileInfo::exists(candidate))
            return candidate;
    }
    return candidate;
}

void FileOperations::runAsync(const std::function<void()> &job)
{
    if (m_busy) {
        emit error(tr("Another operation is already in progress."));
        return;
    }
    setBusy(true);
    (void)QtConcurrent::run(job);
}

void FileOperations::copy(const QStringList &sources, const QString &destDir)
{
    runAsync([this, sources, destDir]() {
        QString err;
        int done = 0;
        const int total = sources.size();
        bool ok = true;
        for (const QString &src : sources) {
            QFileInfo fi(src);
            emit progress(done, total, fi.fileName());
            QString dst = uniqueDest(destDir, fi.fileName());
            if (!copyRecursive(src, dst, &err)) { ok = false; break; }
            ++done;
        }
        setBusy(false);
        if (ok) emit finished(tr("Copied %1 item(s).").arg(total));
        else    emit error(err);
    });
}

void FileOperations::move(const QStringList &sources, const QString &destDir)
{
    runAsync([this, sources, destDir]() {
        QString err;
        int done = 0;
        const int total = sources.size();
        bool ok = true;
        for (const QString &src : sources) {
            QFileInfo fi(src);
            emit progress(done, total, fi.fileName());
            const QString dst = uniqueDest(destDir, fi.fileName());
            // Try a fast rename first; fall back to copy+delete across filesystems.
            if (!QFile::rename(src, dst)) {
                if (!copyRecursive(src, dst, &err)) { ok = false; break; }
                if (!removeRecursive(src, &err))    { ok = false; break; }
            }
            ++done;
        }
        setBusy(false);
        if (ok) emit finished(tr("Moved %1 item(s).").arg(total));
        else    emit error(err);
    });
}

void FileOperations::remove(const QStringList &paths)
{
    runAsync([this, paths]() {
        QString err;
        int done = 0;
        const int total = paths.size();
        bool ok = true;
        for (const QString &p : paths) {
            emit progress(done, total, QFileInfo(p).fileName());
            if (!removeRecursive(p, &err)) { ok = false; break; }
            ++done;
        }
        setBusy(false);
        if (ok) emit finished(tr("Deleted %1 item(s).").arg(total));
        else    emit error(err);
    });
}

void FileOperations::trash(const QStringList &paths)
{
    const QString gio = QStandardPaths::findExecutable("gio");
    if (gio.isEmpty()) {
        emit error(tr("Trash is unavailable (gio not found). Use permanent delete."));
        return;
    }
    runAsync([this, paths, gio]() {
        QStringList args{"trash"};
        args += paths;
        QProcess proc;
        proc.start(gio, args);
        proc.waitForFinished(-1);
        setBusy(false);
        if (proc.exitStatus() == QProcess::NormalExit && proc.exitCode() == 0)
            emit finished(tr("Moved %1 item(s) to Trash.").arg(paths.size()));
        else
            emit error(tr("Trash failed: %1")
                           .arg(QString::fromUtf8(proc.readAllStandardError()).trimmed()));
    });
}

// Sum of all regular-file bytes under `path` (symlinks not followed).
static qlonglong dirSizeRecursive(const QString &path)
{
    qlonglong total = 0;
    QDirIterator it(path, QDir::Files | QDir::Hidden | QDir::System | QDir::NoSymLinks,
                    QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        total += it.fileInfo().size();
    }
    return total;
}

void FileOperations::analyzeFolder(const QString &path)
{
    // Read-only; runs alongside other work without touching the busy flag.
    (void)QtConcurrent::run([this, path]() {
        QVariantList children;
        qlonglong total = 0;
        const QFileInfoList entries = QDir(path).entryInfoList(
            QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
        for (const QFileInfo &e : entries) {
            const qlonglong sz = (e.isDir() && !e.isSymLink())
                                     ? dirSizeRecursive(e.absoluteFilePath())
                                     : e.size();
            total += sz;
            QVariantMap m;
            m["name"] = e.fileName();
            m["size"] = sz;
            m["isDir"] = e.isDir();
            children.append(m);
        }
        std::sort(children.begin(), children.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap().value("size").toLongLong() > b.toMap().value("size").toLongLong();
        });
        emit folderAnalyzed(path, children, total);
    });
}

QVariantMap FileOperations::properties(const QString &path)
{
    QFileInfo fi(path);
    QVariantMap m;
    m["name"] = fi.fileName();
    m["path"] = fi.absoluteFilePath();
    m["isDir"] = fi.isDir();
    m["isSymlink"] = fi.isSymLink();
    m["symlinkTarget"] = fi.symLinkTarget();
    m["size"] = fi.isDir() ? -1 : fi.size();
    m["sizeText"] = fi.isDir() ? QStringLiteral("—")
                               : QLocale().formattedDataSize(fi.size());
    m["modified"] = QLocale().toString(fi.lastModified(), QLocale::LongFormat);
    m["created"] = QLocale().toString(fi.birthTime(), QLocale::LongFormat);
    m["owner"] = fi.owner();
    m["group"] = fi.group();
    m["readable"] = fi.isReadable();
    m["writable"] = fi.isWritable();
    m["executable"] = fi.isExecutable();

    QFile::Permissions p = fi.permissions();
    auto bit = [&](QFile::Permission b, QChar c) { return (p & b) ? c : QChar('-'); };
    QString perms;
    perms += fi.isDir() ? 'd' : '-';
    perms += bit(QFile::ReadOwner,'r'); perms += bit(QFile::WriteOwner,'w'); perms += bit(QFile::ExeOwner,'x');
    perms += bit(QFile::ReadGroup,'r'); perms += bit(QFile::WriteGroup,'w'); perms += bit(QFile::ExeGroup,'x');
    perms += bit(QFile::ReadOther,'r'); perms += bit(QFile::WriteOther,'w'); perms += bit(QFile::ExeOther,'x');
    m["permissions"] = perms;
    return m;
}
