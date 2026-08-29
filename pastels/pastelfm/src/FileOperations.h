#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QVariantList>
#include <functional>

// File operations exposed to QML. Long-running copy/move/delete run on a worker
// thread via QtConcurrent so the UI stays responsive.
class FileOperations : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool trashAvailable READ trashAvailable CONSTANT)

public:
    explicit FileOperations(QObject *parent = nullptr);

    bool busy() const { return m_busy; }
    bool trashAvailable() const;

    Q_INVOKABLE bool mkdir(const QString &parentDir, const QString &name);
    Q_INVOKABLE bool rename(const QString &path, const QString &newName);
    Q_INVOKABLE bool createFile(const QString &parentDir, const QString &name);

    // Asynchronous bulk operations. Emit finished()/error() when done.
    Q_INVOKABLE void copy(const QStringList &sources, const QString &destDir);
    Q_INVOKABLE void move(const QStringList &sources, const QString &destDir);
    Q_INVOKABLE void remove(const QStringList &paths);   // permanent delete
    Q_INVOKABLE void trash(const QStringList &paths);    // move to trash via gio

    Q_INVOKABLE QVariantMap properties(const QString &path);

    // Recursively measure a folder: total bytes + per-child breakdown.
    // Runs on a worker thread; result arrives via folderAnalyzed().
    Q_INVOKABLE void analyzeFolder(const QString &path);

signals:
    void busyChanged();
    void progress(int done, int total, const QString &current);
    void finished(const QString &summary);
    void error(const QString &message);
    // children: list of { name, size (qlonglong), isDir } sorted largest-first.
    void folderAnalyzed(const QString &path, const QVariantList &children, qlonglong total);

private:
    void setBusy(bool v);
    void runAsync(const std::function<void()> &job);

    bool m_busy = false;
};
