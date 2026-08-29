#pragma once

#include <QObject>
#include <QSettings>

// Persisted preferences for PastelImage (QSettings, ~/.config/PastelImage).
// Theme keys mirror the other pastel apps so they share the pasteltheme look.
class SettingsStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)                 // "light"|"dark"|"auto"
    Q_PROPERTY(QString customPrimary READ customPrimary WRITE setCustomPrimary NOTIFY customPrimaryChanged)
    Q_PROPERTY(QString customSecondary READ customSecondary WRITE setCustomSecondary NOTIFY customSecondaryChanged)
    Q_PROPERTY(int windowOpacity READ windowOpacity WRITE setWindowOpacity NOTIFY windowOpacityChanged)
    Q_PROPERTY(QString background READ background WRITE setBackground NOTIFY backgroundChanged)  // "theme"|"dark"|"checker"
    Q_PROPERTY(bool saveClipboardOnly READ saveClipboardOnly WRITE setSaveClipboardOnly NOTIFY saveClipboardOnlyChanged)  // Save copies to clipboard instead of writing a file

public:
    explicit SettingsStore(QObject *parent = nullptr);

    QString theme() const;             void setTheme(const QString &t);
    QString mode() const;              void setMode(const QString &m);
    QString customPrimary() const;     void setCustomPrimary(const QString &c);
    QString customSecondary() const;   void setCustomSecondary(const QString &c);
    int windowOpacity() const;         void setWindowOpacity(int v);
    QString background() const;        void setBackground(const QString &b);
    bool saveClipboardOnly() const;    void setSaveClipboardOnly(bool b);

    Q_INVOKABLE void saveWindow(int w, int h);
    Q_INVOKABLE int windowWidth() const;
    Q_INVOKABLE int windowHeight() const;

signals:
    void themeChanged();
    void modeChanged();
    void customPrimaryChanged();
    void customSecondaryChanged();
    void windowOpacityChanged();
    void backgroundChanged();
    void saveClipboardOnlyChanged();

private:
    QSettings m_settings;
};
