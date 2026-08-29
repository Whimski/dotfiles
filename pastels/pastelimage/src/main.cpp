#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QQuickItem>
#include <QQuickItemGrabResult>
#include <QIcon>
#include <QTimer>
#include <QSurfaceFormat>
#include <QDir>

#include "SettingsStore.h"
#include "ImageController.h"

int main(int argc, char *argv[])
{
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    QSurfaceFormat fmt = QSurfaceFormat::defaultFormat();
    fmt.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(fmt);

    QGuiApplication app(argc, argv);
    app.setApplicationName("PastelImage");
    app.setOrganizationName("PastelImage");
    app.setApplicationDisplayName("Pastel Image");
    app.setDesktopFileName("pastelimage");
    app.setWindowIcon(QIcon::fromTheme("image-x-generic"));

    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        QQuickStyle::setStyle("Material");

    SettingsStore   settings;
    ImageController image;

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                     [](const QList<QQmlError> &ws) {
        for (const QQmlError &w : ws) {
            const QByteArray s = w.toString().toUtf8();
            fprintf(stderr, "[qml] %s\n", s.constData());
        }
        fflush(stderr);
    });
    engine.rootContext()->setContextProperty("Settings", &settings);
    engine.rootContext()->setContextProperty("Img", &image);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);

    engine.addImportPath(qEnvironmentVariable(
        "PASTEL_QML_IMPORT_PATH", QDir::homePath() + "/dotfiles/pastels"));

    engine.loadFromModule("PastelImage", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    // Open a file from CLI arg or PASTELIMAGE_START (after the window exists).
    QString start = QString::fromUtf8(qgetenv("PASTELIMAGE_START"));
    if (start.isEmpty() && argc > 1)
        start = QString::fromUtf8(argv[argc - 1]);
    if (!start.isEmpty())
        image.openPath(start);

    // Verification aid: PASTELIMAGE_SCREENSHOT=/path.png renders the window and exits.
    const QByteArray shot = qgetenv("PASTELIMAGE_SCREENSHOT");
    if (!shot.isEmpty()) {
        if (auto *w = qobject_cast<QQuickWindow *>(engine.rootObjects().first())) {
            const int delay = qEnvironmentVariableIntValue("PASTELIMAGE_SHOT_DELAY");
            QTimer::singleShot(delay > 0 ? delay : 1400, [w, shot]() {
                QQuickItem *content = w->contentItem();
                auto result = content->grabToImage(w->size());
                if (!result) { QCoreApplication::exit(2); return; }
                QObject::connect(result.data(), &QQuickItemGrabResult::ready,
                                 [result, shot]() {
                    const bool ok = result->saveToFile(QString::fromUtf8(shot));
                    QCoreApplication::exit(ok ? 0 : 3);
                });
                QTimer::singleShot(4000, []() { QCoreApplication::exit(4); });
            });
        }
    }

    return app.exec();
}
