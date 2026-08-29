#include "ImageController.h"

#include <QDir>
#include <QFileInfo>
#include <QQuickItemGrabResult>
#include <QGuiApplication>
#include <QClipboard>
#include <QImage>

static const QStringList kFilters = {
    "*.png", "*.jpg", "*.jpeg", "*.jpe", "*.webp", "*.bmp", "*.gif",
    "*.tif", "*.tiff", "*.avif", "*.jxl", "*.ico", "*.svg"
};

ImageController::ImageController(QObject *parent) : QObject(parent) {}

bool ImageController::copyToClipboard(QObject *grabResult)
{
    auto *g = qobject_cast<QQuickItemGrabResult *>(grabResult);
    if (!g) return false;
    const QImage img = g->image();
    if (img.isNull()) return false;
    QGuiApplication::clipboard()->setImage(img);
    return true;
}

QUrl ImageController::source() const
{
    return (m_pos >= 0 && m_pos < m_files.size())
        ? QUrl::fromLocalFile(m_files.at(m_pos)) : QUrl();
}

QString ImageController::fileName() const
{
    return (m_pos >= 0 && m_pos < m_files.size())
        ? QFileInfo(m_files.at(m_pos)).fileName() : QString();
}

void ImageController::openPath(const QString &pathOrUrl)
{
    QString path = pathOrUrl;
    if (path.startsWith("file://")) path = QUrl(path).toLocalFile();
    if (path.isEmpty()) return;

    QFileInfo fi(path);
    const QString dirPath = fi.isDir() ? fi.absoluteFilePath() : fi.absolutePath();

    QDir dir(dirPath);
    const QFileInfoList entries = dir.entryInfoList(kFilters, QDir::Files, QDir::Name | QDir::IgnoreCase);
    m_files.clear();
    for (const QFileInfo &e : entries) m_files.append(e.absoluteFilePath());
    emit listChanged();

    int pos = 0;
    if (!fi.isDir()) {
        const int i = m_files.indexOf(fi.absoluteFilePath());
        if (i >= 0) pos = i;
        else if (fi.exists()) { m_files.prepend(fi.absoluteFilePath()); emit listChanged(); pos = 0; }
    }
    select(m_files.isEmpty() ? -1 : pos);
}

void ImageController::select(int pos)
{
    m_pos = (pos >= 0 && pos < m_files.size()) ? pos : -1;
    m_rotation = 0;
    emit rotationChanged();
    emit currentChanged();
}

void ImageController::next()
{
    if (m_files.isEmpty()) return;
    select(m_pos + 1 >= m_files.size() ? 0 : m_pos + 1);   // wrap
}

void ImageController::prev()
{
    if (m_files.isEmpty()) return;
    select(m_pos - 1 < 0 ? m_files.size() - 1 : m_pos - 1); // wrap
}

void ImageController::rotateCW()  { m_rotation = (m_rotation + 90) % 360; emit rotationChanged(); }
void ImageController::rotateCCW() { m_rotation = (m_rotation + 270) % 360; emit rotationChanged(); }
