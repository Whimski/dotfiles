#include "MountManager.h"

#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>
#include <QtConcurrent>
#include <unistd.h>

MountManager::MountManager(QObject *parent)
    : QAbstractListModel(parent)
{
}

int MountManager::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_mounts.size();
}

QVariant MountManager::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_mounts.size())
        return {};
    const Mount &m = m_mounts.at(index.row());
    switch (role) {
    case LabelRole:     return m.label;
    case TypeRole:      return m.type;
    case UriRole:       return m.uri;
    case LocalPathRole: return m.localPath;
    case BackendRole:   return m.backend;
    case StatusRole:    return m.status;
    }
    return {};
}

QHash<int, QByteArray> MountManager::roleNames() const
{
    return {
        {LabelRole, "label"},
        {TypeRole, "type"},
        {UriRole, "uri"},
        {LocalPathRole, "localPath"},
        {BackendRole, "backend"},
        {StatusRole, "status"},
    };
}

bool MountManager::gioAvailable() const
{
    return !QStandardPaths::findExecutable("gio").isEmpty();
}

bool MountManager::sshfsAvailable() const
{
    return !QStandardPaths::findExecutable("sshfs").isEmpty();
}

bool MountManager::cifsAvailable() const
{
    return !QStandardPaths::findExecutable("mount.cifs").isEmpty();
}

void MountManager::setBusy(bool v)
{
    if (m_busy == v) return;
    m_busy = v;
    emit busyChanged();
}

void MountManager::addMount(const Mount &m)
{
    beginInsertRows(QModelIndex(), m_mounts.size(), m_mounts.size());
    m_mounts.append(m);
    endInsertRows();
    emit countChanged();
    emit mounted(m.label, m.localPath);
}

static QString gvfsRuntimeBase()
{
    QString runtime = qEnvironmentVariable("XDG_RUNTIME_DIR");
    if (runtime.isEmpty())
        runtime = QStringLiteral("/run/user/%1").arg(::getuid());
    return runtime + "/gvfs/";
}

void MountManager::renameMount(int idx, const QString &label)
{
    if (idx < 0 || idx >= m_mounts.size() || label.trimmed().isEmpty())
        return;
    m_mounts[idx].label = label.trimmed();
    const QModelIndex mi = index(idx, 0);
    emit dataChanged(mi, mi, {LabelRole});
}

QString MountManager::localPathAt(int index) const
{
    if (index < 0 || index >= m_mounts.size())
        return {};
    return m_mounts.at(index).localPath;
}

// ---------------- SSH ----------------

void MountManager::mountSsh(const QString &host, int port, const QString &user,
                            const QString &remotePath, const QString &password,
                            const QString &label)
{
    if (host.trimmed().isEmpty()) {
        emit error(tr("Host is required."));
        return;
    }
    if (m_busy) {
        emit error(tr("Another mount operation is in progress."));
        return;
    }
    const QString lbl = label.trimmed().isEmpty()
        ? QStringLiteral("%1@%2").arg(user.isEmpty() ? QStringLiteral("ssh") : user, host)
        : label.trimmed();

    if (gioAvailable()) {
        mountSshGvfs(host, port, user, remotePath, password, lbl);
    } else if (sshfsAvailable()) {
        emit info(tr("gio/gvfs not found — using native sshfs."));
        mountSshSshfs(host, port, user, remotePath, lbl);
    } else {
        emit error(tr("Cannot mount SSH: neither gio/gvfs nor sshfs is installed.\n"
                       "Install sshfs (e.g. 'pacman -S sshfs') or enable gvfs."));
    }
}

void MountManager::mountSshGvfs(const QString &host, int port, const QString &user,
                                const QString &remotePath, const QString &password,
                                const QString &label)
{
    QString rp = remotePath.trimmed();
    if (!rp.startsWith('/')) rp = "/" + rp;
    if (rp == "/") rp.clear();

    QString uri = "sftp://";
    if (!user.isEmpty()) uri += user + "@";
    uri += host;
    if (port > 0 && port != 22) uri += ":" + QString::number(port);
    uri += rp.isEmpty() ? "/" : rp;

    // Deterministic gvfs FUSE path (documented naming convention).
    QString name = "sftp:host=" + host;
    if (port > 0 && port != 22) name += ",port=" + QString::number(port);
    if (!user.isEmpty()) name += ",user=" + user;
    QString localPath = gvfsRuntimeBase() + name + rp;

    // Already mounted in this session? Just open it instead of re-mounting.
    const int existing = existingMountIndex(uri, localPath);
    if (existing >= 0) {
        emit info(tr("Already mounted — opening."));
        emit mounted(m_mounts.at(existing).label, m_mounts.at(existing).localPath);
        return;
    }

    setBusy(true);
    const QString gio = QStandardPaths::findExecutable("gio");
    (void)QtConcurrent::run([=]() {
        QProcess proc;
        proc.setProcessChannelMode(QProcess::MergedChannels);
        proc.start(gio, {"mount", uri});
        if (proc.waitForStarted(5000) && !password.isEmpty()) {
            // gvfs prompts for the password (and, for unknown hosts, an authenticity
            // question). Answer the host question then supply the password.
            proc.write("yes\n");
            proc.write(password.toUtf8() + "\n");
        }
        const bool ok = proc.waitForFinished(60000)
                        && proc.exitStatus() == QProcess::NormalExit
                        && proc.exitCode() == 0;
        const QString out = QString::fromUtf8(proc.readAll()).trimmed();
        // gio reports this when the share is already mounted (e.g. from a previous
        // session) — treat it as success and browse the existing mount.
        const bool alreadyMounted = out.contains("already mounted", Qt::CaseInsensitive);
        setBusy(false);
        if ((ok || alreadyMounted) && QFileInfo::exists(localPath)) {
            addMount({label, "ssh", uri, localPath, "gvfs", tr("mounted")});
        } else if (ok || alreadyMounted) {
            // Mounted but path not where predicted; hand back the gvfs base so the
            // user can still browse.
            addMount({label, "ssh", uri, gvfsRuntimeBase() + name, "gvfs", tr("mounted")});
        } else {
            emit error(tr("SSH mount failed:\n%1").arg(out.isEmpty() ? tr("unknown error") : out));
        }
    });
}

void MountManager::mountSshSshfs(const QString &host, int port, const QString &user,
                                 const QString &remotePath, const QString &label)
{
    const QString mountRoot = QDir::homePath() + "/.pastelfm/mounts";
    QDir().mkpath(mountRoot);
    const QString mp = QDir(mountRoot).filePath(
        QString(label).replace('/', '_').replace(' ', '_'));
    QDir().mkpath(mp);

    QString remote = user.isEmpty() ? host : (user + "@" + host);
    remote += ":" + (remotePath.isEmpty() ? QStringLiteral("/") : remotePath);

    QStringList args;
    if (port > 0 && port != 22) args << "-p" << QString::number(port);
    args << remote << mp
         << "-o" << "reconnect"
         << "-o" << "ServerAliveInterval=15";

    setBusy(true);
    const QString sshfs = QStandardPaths::findExecutable("sshfs");
    (void)QtConcurrent::run([=]() {
        QProcess proc;
        proc.setProcessChannelMode(QProcess::MergedChannels);
        proc.start(sshfs, args);
        const bool ok = proc.waitForFinished(60000)
                        && proc.exitStatus() == QProcess::NormalExit
                        && proc.exitCode() == 0;
        const QString out = QString::fromUtf8(proc.readAll()).trimmed();
        setBusy(false);
        if (ok)
            addMount({label, "ssh", "sshfs://" + remote, mp, "sshfs", tr("mounted")});
        else
            emit error(tr("sshfs failed:\n%1").arg(out.isEmpty() ? tr("unknown error") : out));
    });
}

// ---------------- Samba ----------------

void MountManager::mountSamba(const QString &host, const QString &share,
                              const QString &user, const QString &password,
                              const QString &domain, const QString &label)
{
    if (host.trimmed().isEmpty() || share.trimmed().isEmpty()) {
        emit error(tr("Host and share are required."));
        return;
    }
    if (m_busy) {
        emit error(tr("Another mount operation is in progress."));
        return;
    }
    const QString lbl = label.trimmed().isEmpty()
        ? QStringLiteral("%1/%2").arg(host, share) : label.trimmed();

    if (gioAvailable()) {
        mountSambaGvfs(host, share, user, password, domain, lbl);
    } else if (cifsAvailable()) {
        emit info(tr("gio/gvfs not found. Samba via mount.cifs requires root; "
                     "run the app with sufficient privileges or install gvfs."));
        emit error(tr("Userspace Samba mount unavailable (no gvfs)."));
    } else {
        emit error(tr("Cannot mount Samba: gio/gvfs is not available."));
    }
}

void MountManager::mountSambaGvfs(const QString &host, const QString &share, const QString &user,
                                  const QString &password, const QString &domain,
                                  const QString &label)
{
    QString uri = "smb://";
    if (!user.isEmpty()) {
        if (!domain.isEmpty()) uri += domain + ";";
        uri += user + "@";
    }
    uri += host + "/" + share;

    QString name = "smb-share:server=" + host + ",share=" + share;
    if (!user.isEmpty()) name += ",user=" + user;
    if (!domain.isEmpty()) name += ",domain=" + domain;
    QString localPath = gvfsRuntimeBase() + name;

    // Already mounted in this session? Just open it instead of re-mounting.
    const int existing = existingMountIndex(uri, localPath);
    if (existing >= 0) {
        emit info(tr("Already mounted — opening."));
        emit mounted(m_mounts.at(existing).label, m_mounts.at(existing).localPath);
        return;
    }

    setBusy(true);
    const QString gio = QStandardPaths::findExecutable("gio");
    (void)QtConcurrent::run([=]() {
        QProcess proc;
        proc.setProcessChannelMode(QProcess::MergedChannels);
        proc.start(gio, {"mount", uri});
        if (proc.waitForStarted(5000) && !password.isEmpty()) {
            // gvfs smb asks: user, domain, password (when not embedded in the URI).
            proc.write(password.toUtf8() + "\n");
        }
        const bool ok = proc.waitForFinished(60000)
                        && proc.exitStatus() == QProcess::NormalExit
                        && proc.exitCode() == 0;
        const QString out = QString::fromUtf8(proc.readAll()).trimmed();
        const bool alreadyMounted = out.contains("already mounted", Qt::CaseInsensitive);
        setBusy(false);
        if ((ok || alreadyMounted) && QFileInfo::exists(localPath))
            addMount({label, "samba", uri, localPath, "gvfs", tr("mounted")});
        else if (ok || alreadyMounted)
            addMount({label, "samba", uri, gvfsRuntimeBase() + name, "gvfs", tr("mounted")});
        else
            emit error(tr("Samba mount failed:\n%1").arg(out.isEmpty() ? tr("unknown error") : out));
    });
}

int MountManager::existingMountIndex(const QString &uri, const QString &localPath) const
{
    for (int i = 0; i < m_mounts.size(); ++i) {
        const Mount &m = m_mounts.at(i);
        if (m.uri == uri || (!localPath.isEmpty() && m.localPath == localPath))
            return i;
    }
    return -1;
}

// ---------------- Unmount ----------------

void MountManager::unmount(int index)
{
    if (index < 0 || index >= m_mounts.size())
        return;
    const Mount m = m_mounts.at(index);

    if (m.backend == "gvfs") {
        const QString gio = QStandardPaths::findExecutable("gio");
        QProcess::startDetached(gio, {"mount", "-u", m.uri});
    } else if (m.backend == "sshfs") {
        const QString fuser = QStandardPaths::findExecutable("fusermount3");
        if (!fuser.isEmpty())
            QProcess::startDetached(fuser, {"-u", m.localPath});
    }

    beginRemoveRows(QModelIndex(), index, index);
    m_mounts.removeAt(index);
    endRemoveRows();
    emit countChanged();
    emit info(tr("Unmounted “%1”.").arg(m.label));
}
