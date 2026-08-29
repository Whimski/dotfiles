#pragma once

#include <QObject>
#include <QUrl>
#include <QStringList>

// Viewer state: the current image plus the list of images in its folder, so the
// user can page through a directory. `source` feeds a QML Image; `rotation` is a
// per-image view rotation (not written to disk — that's for the editor later).
class ImageController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl source READ source NOTIFY currentChanged)
    Q_PROPERTY(QString fileName READ fileName NOTIFY currentChanged)
    Q_PROPERTY(int index READ index NOTIFY currentChanged)     // 1-based (0 = none)
    Q_PROPERTY(int count READ count NOTIFY listChanged)
    Q_PROPERTY(bool hasImage READ hasImage NOTIFY currentChanged)
    Q_PROPERTY(int rotation READ rotation NOTIFY rotationChanged)

public:
    explicit ImageController(QObject *parent = nullptr);

    QUrl source() const;
    QString fileName() const;
    int index() const { return m_pos >= 0 ? m_pos + 1 : 0; }
    int count() const { return m_files.size(); }
    bool hasImage() const { return m_pos >= 0; }
    int rotation() const { return m_rotation; }

    Q_INVOKABLE void openPath(const QString &pathOrUrl);   // local path or file:// url
    Q_INVOKABLE void openUrl(const QUrl &url) { openPath(url.toLocalFile()); }
    Q_INVOKABLE void next();
    Q_INVOKABLE void prev();
    Q_INVOKABLE void rotateCW();
    Q_INVOKABLE void rotateCCW();

    // Copy a grabbed image to the system clipboard. Pass the QQuickItemGrabResult
    // from imageItem.grabToImage() (as a QObject); returns true if it was copied.
    Q_INVOKABLE bool copyToClipboard(QObject *grabResult);

signals:
    void currentChanged();
    void listChanged();
    void rotationChanged();

private:
    void select(int pos);
    QStringList m_files;    // absolute paths of images in the current folder
    int m_pos = -1;
    int m_rotation = 0;
};
