#pragma once

#include <QAbstractListModel>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QList>

// A list model of one directory's entries. Works on any locally-reachable path,
// including gvfs / sshfs mount points, since those look like ordinary paths.
class FileSystemModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(QString sortRole READ sortRole WRITE setSortRole NOTIFY sortRoleChanged)
    Q_PROPERTY(bool sortReversed READ sortReversed WRITE setSortReversed NOTIFY sortReversedChanged)
    Q_PROPERTY(bool foldersFirst READ foldersFirst WRITE setFoldersFirst NOTIFY foldersFirstChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool writable READ writable NOTIFY pathChanged)

public:
    enum Roles {
        FileNameRole = Qt::UserRole + 1,
        FilePathRole,
        IsDirRole,
        SizeRole,
        SizeTextRole,
        ModifiedRole,
        ModifiedTextRole,
        SuffixRole,
        IconNameRole,
        IsHiddenRole,
        IsSymlinkRole,
    };
    Q_ENUM(Roles)

    explicit FileSystemModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString path() const { return m_path; }
    void setPath(const QString &path);

    bool showHidden() const { return m_showHidden; }
    void setShowHidden(bool v);

    QString sortRole() const { return m_sortRole; }
    void setSortRole(const QString &r);

    bool sortReversed() const { return m_sortReversed; }
    void setSortReversed(bool v);

    bool foldersFirst() const { return m_foldersFirst; }
    void setFoldersFirst(bool v);

    QString filter() const { return m_filter; }
    void setFilter(const QString &f);

    bool writable() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QString homePath() const;
    Q_INVOKABLE QString rootPath() const;
    Q_INVOKABLE QString cdInto(int index);   // returns new path if a dir, else empty
    Q_INVOKABLE QString parentPath() const;  // parent of current dir ("" if at root)
    Q_INVOKABLE QString entryPath(int index) const;
    Q_INVOKABLE bool entryIsDir(int index) const;

signals:
    void pathChanged();
    void showHiddenChanged();
    void sortRoleChanged();
    void sortReversedChanged();
    void foldersFirstChanged();
    void filterChanged();
    void countChanged();

private:
    void reload();

    QString m_path;
    bool m_showHidden = false;
    QString m_sortRole = "fileName";
    bool m_sortReversed = false;
    bool m_foldersFirst = true;
    QString m_filter;
    QList<QFileInfo> m_entries;
    QFileSystemWatcher m_watcher;
};
