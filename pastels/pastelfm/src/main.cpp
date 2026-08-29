#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QQuickItem>
#include <QQuickItemGrabResult>
#include <QIcon>
#include <QTimer>
#include <QImage>
#include <QSharedPointer>
#include <QSurfaceFormat>
#include <QDir>

#include "FileSystemModel.h"
#include "FileOperations.h"
#include "MountManager.h"
#include "SettingsStore.h"

int main(int argc, char *argv[])
{
    // Good behaviour on HiDPI / fractional-scaling Wayland compositors, harmless on X11.
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    // Request an alpha channel so a translucent window surface is possible
    // (needed for the transparency setting to work, especially on Wayland).
    QSurfaceFormat fmt = QSurfaceFormat::defaultFormat();
    fmt.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(fmt);

    QGuiApplication app(argc, argv);

    // App identity — Wayland uses this for the app id / icon association.
    app.setApplicationName("PastelFM");
    app.setOrganizationName("PastelFM");
    app.setApplicationDisplayName("PastelFM");
    app.setDesktopFileName("pastelfm");
    app.setWindowIcon(QIcon::fromTheme("system-file-manager"));

    // Material gives us the modern rounded look; we recolour it from Theme.qml.
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        QQuickStyle::setStyle("Material");

    // Backend singletons exposed to QML.
    qmlRegisterType<FileSystemModel>("PastelFM.Backend", 1, 0, "FileSystemModel");

    FileOperations fileOps;
    MountManager   mountManager;
    SettingsStore  settings;

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     [](const QList<QQmlError> &ws) {
        for (const QQmlError &w : ws) {
            const QByteArray s = w.toString().toUtf8();
            fprintf(stderr, "[qml] %s\n", s.constData());
        }
        fflush(stderr);
    });
    engine.rootContext()->setContextProperty("FileOps", &fileOps);
    engine.rootContext()->setContextProperty("Mounts", &mountManager);
    engine.rootContext()->setContextProperty("Settings", &settings);
    // Optional: open at a specific path (CLI arg or PASTELFM_START env).
    QString startPath = QString::fromUtf8(qgetenv("PASTELFM_START"));
    if (startPath.isEmpty() && argc > 1)
        startPath = QString::fromUtf8(argv[argc - 1]);
    engine.rootContext()->setContextProperty("StartPath", startPath);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);

    // Locate the shared "pasteltheme" QML module (default ~/dotfiles/pastels; override
    // with PASTEL_QML_IMPORT_PATH). Its parent dir must be on the import path so
    // `import pasteltheme` resolves.
    engine.addImportPath(qEnvironmentVariable(
        "PASTEL_QML_IMPORT_PATH", QDir::homePath() + "/dotfiles/pastels"));

    engine.loadFromModule("PastelFM", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    // Verification aid: PASTELFM_SCREENSHOT=/path.png renders the real window
    // (works under the offscreen platform) and exits. No effect in normal use.
    const QByteArray shot = qgetenv("PASTELFM_SCREENSHOT");
    if (!shot.isEmpty()) {
        if (auto *w = qobject_cast<QQuickWindow *>(engine.rootObjects().first())) {
            const int delay = qEnvironmentVariableIntValue("PASTELFM_SHOT_DELAY");
            QTimer::singleShot(delay > 0 ? delay : 1400, [w, shot]() {
                QQuickItem *content = w->contentItem();
                auto result = content->grabToImage(w->size());
                if (!result) { QCoreApplication::exit(2); return; }
                QObject::connect(result.data(), &QQuickItemGrabResult::ready,
                                 [result, shot]() {
                    const bool ok = result->saveToFile(QString::fromUtf8(shot));
                    QCoreApplication::exit(ok ? 0 : 3);
                });
                // Safety net if the grab never signals ready.
                QTimer::singleShot(4000, []() { QCoreApplication::exit(4); });
            });
        }
    }

    return app.exec();
}
