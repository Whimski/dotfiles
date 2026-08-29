#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QProcess>
#include <QString>

// Manages remote mounts for SSH (sftp/sshfs) and Samba (smb/cifs).
// Auto-detect strategy: prefer userspace gio/gvfs, fall back to native
// sshfs / mount.cifs when available. Also acts as the list model of active
// mounts consumed by the sidebar.
class MountManager : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool gioAvailable READ gioAvailable CONSTANT)
    Q_PROPERTY(bool sshfsAvailable READ sshfsAvailable CONSTANT)
    Q_PROPERTY(bool cifsAvailable READ cifsAvailable CONSTANT)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    enum Roles {
        LabelRole = Qt::UserRole + 1,
        TypeRole,       // "ssh" | "samba"
        UriRole,
        LocalPathRole,
        BackendRole,    // "gvfs" | "sshfs" | "cifs"
        StatusRole,
    };
    Q_ENUM(Roles)

    struct Mount {
        QString label;
        QString type;
        QString uri;
        QString localPath;
        QString backend;
        QString status;
    };

    explicit MountManager(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool gioAvailable() const;
    bool sshfsAvailable() const;
    bool cifsAvailable() const;
    bool busy() const { return m_busy; }

    // password may be empty (uses keys / prompts handled by gvfs agent).
    Q_INVOKABLE void mountSsh(const QString &host, int port, const QString &user,
                              const QString &remotePath, const QString &password,
                              const QString &label);
    Q_INVOKABLE void mountSamba(const QString &host, const QString &share,
                                const QString &user, const QString &password,
                                const QString &domain, const QString &label);
    Q_INVOKABLE void unmount(int index);
    Q_INVOKABLE void renameMount(int index, const QString &label);
    Q_INVOKABLE QString localPathAt(int index) const;

signals:
    void countChanged();
    void busyChanged();
    void mounted(const QString &label, const QString &localPath);
    void error(const QString &message);
    void info(const QString &message);

private:
    void setBusy(bool v);
    void addMount(const Mount &m);
    QString gioLocalPathFor(const QString &uri) const;  // resolve gvfs path via `gio info`
    int existingMountIndex(const QString &uri, const QString &localPath) const;

    // Backend implementations return true if they launched successfully.
    void mountSshGvfs(const QString &host, int port, const QString &user,
                      const QString &remotePath, const QString &password,
                      const QString &label);
    void mountSshSshfs(const QString &host, int port, const QString &user,
                       const QString &remotePath, const QString &label);
    void mountSambaGvfs(const QString &host, const QString &share, const QString &user,
                        const QString &password, const QString &domain, const QString &label);

    QList<Mount> m_mounts;
    bool m_busy = false;
};
