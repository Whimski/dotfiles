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
#include <QSurfaceFormat>
#include <QDir>

#include "SettingsStore.h"
#include "CalendarController.h"
#include "GoogleCalendarService.h"
#include "IcsService.h"

int main(int argc, char *argv[])
{
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    QSurfaceFormat fmt = QSurfaceFormat::defaultFormat();
    fmt.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(fmt);

    QGuiApplication app(argc, argv);
    app.setApplicationName("PastelCal");
    app.setOrganizationName("PastelCal");
    app.setApplicationDisplayName("Pastel Calendar");
    app.setDesktopFileName("pastelcal");
    app.setWindowIcon(QIcon::fromTheme("office-calendar"));

    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        QQuickStyle::setStyle("Material");

    SettingsStore       settings;
    CalendarController  calendar;
    calendar.setColorOverrides(settings.calendarColors());
    GoogleCalendarService google(&settings, &calendar);
    IcsService          ics(&settings, &calendar);
    QObject::connect(&calendar, &CalendarController::calendarColorChanged, &settings,
                     [&settings](const QString &id, const QString &hex) { settings.setCalendarColor(id, hex); });

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
    engine.rootContext()->setContextProperty("Cal", &calendar);
    engine.rootContext()->setContextProperty("Google", &google);
    engine.rootContext()->setContextProperty("Ics", &ics);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);

    // Shared pasteltheme module (default ~/dotfiles/pastels; override PASTEL_QML_IMPORT_PATH).
    engine.addImportPath(qEnvironmentVariable(
        "PASTEL_QML_IMPORT_PATH", QDir::homePath() + "/dotfiles/pastels"));

    engine.loadFromModule("PastelCal", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    // Verification aid: PASTELCAL_SCREENSHOT=/path.png renders the window and exits.
    const QByteArray shot = qgetenv("PASTELCAL_SCREENSHOT");
    if (!shot.isEmpty()) {
        if (auto *w = qobject_cast<QQuickWindow *>(engine.rootObjects().first())) {
            const int delay = qEnvironmentVariableIntValue("PASTELCAL_SHOT_DELAY");
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
