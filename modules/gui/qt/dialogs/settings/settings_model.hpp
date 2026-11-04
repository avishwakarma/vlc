/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifndef QT_SETTINGS_SETTINGS_MODEL_HPP
#define QT_SETTINGS_SETTINGS_MODEL_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QObject>
#include <QHash>
#include <QTimer>

#include "config_option.hpp"
#include "hotkeys_model.hpp"

class MainCtx;
struct qt_intf_t;

/**
 * Entry point of the QML settings window (singleton SettingsModel in
 * VLC.Dialogs).
 *
 * Changes apply immediately: every ConfigOption writes the running
 * configuration when its value is set, and the model saves the configuration
 * file shortly after (debounced), then reloads the interface preferences like
 * the QWidget preferences dialog does.
 */
class SettingsModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(HotkeysModel* hotkeys READ hotkeys CONSTANT FINAL)
    // true once an option that needs a restart was changed (or after resetAll)
    Q_PROPERTY(bool restartPending READ restartPending NOTIFY restartRequired FINAL)
    // true while a save is scheduled
    Q_PROPERTY(bool savePending READ savePending NOTIFY savePendingChanged FINAL)
    // absolute path of the folder containing vlcrc
    Q_PROPERTY(QString configFolder READ configFolder CONSTANT FINAL)

public:
    SettingsModel(qt_intf_t* intf, MainCtx* ctx, QObject* parent = nullptr);
    ~SettingsModel() override;

    /**
     * Returns the option `name`, created on first use and cached.
     * `name` is a VLC option name (as in vlcrc) or a virtual option name:
     * theme, accent, audioDevice, mlFolders, mlBannedFolders,
     * extraInterface:<intf>. Never returns null: unknown options have
     * available == false.
     */
    Q_INVOKABLE ConfigOption* option(const QString& name);

    /// reset every VLC option and the interface settings to their default
    /// values (same as "Reset Preferences" in the QWidget dialog)
    Q_INVOKABLE void resetAll();

    /// schedule a save of the configuration file (debounced)
    Q_INVOKABLE void save();
    /// save now if a save is scheduled (call when the window closes)
    Q_INVOKABLE void flush();

    Q_INVOKABLE void openConfigFolder() const;

    /// open the QWidget preferences in the expert view ("All options...")
    Q_INVOKABLE void openAllOptions() const;

    /// ask the interface to quit (the user restarts VLC)
    Q_INVOKABLE void quitForRestart() const;

    /// native file / folder pickers for the Browse buttons. They return the
    /// chosen local path, or an empty string when cancelled.
    Q_INVOKABLE QString pickFile(const QString& current, bool save) const;
    Q_INVOKABLE QString pickDirectory(const QString& current) const;

    HotkeysModel* hotkeys() const { return m_hotkeys; }
    bool restartPending() const { return m_restartPending; }
    bool savePending() const { return m_saveTimer.isActive(); }
    QString configFolder() const;

signals:
    void restartRequired();
    void savePendingChanged();
    /// emitted after the configuration file was written
    void saved(bool success);

private:
    ConfigOption* createOption(const QString& name);
    void onOptionEdited(ConfigOption* option);
    void applySubtitleOptionLive(const QString& name);
    void refreshSubtitleCue();
    QTimer m_subRefreshTimer;
    void saveNow();
    void markRestart();

    qt_intf_t* m_intf;
    MainCtx* m_ctx;
    HotkeysModel* m_hotkeys;
    QHash<QString, ConfigOption*> m_options;
    QTimer m_saveTimer;
    bool m_restartPending = false;
};

#endif // QT_SETTINGS_SETTINGS_MODEL_HPP
