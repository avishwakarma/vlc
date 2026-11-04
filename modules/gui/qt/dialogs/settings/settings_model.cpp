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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "settings_model.hpp"
#include "virtual_options.hpp"

#include "qt.hpp"
#include "maininterface/mainctx.hpp"
#include "dialogs/dialogs_provider.hpp"
#include "dialogs/dialogs/dialogmodel.hpp"

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_player.h>
#include <vlc_vout.h>

#include <QColor>
#include <QDesktopServices>
#include <QFileDialog>
#include <QFileInfo>
#include <QQmlEngine>
#include <QSettings>
#include <QUrl>

#include <algorithm>
#include <cstdlib>

namespace {
constexpr int saveDelayMs = 500;
}

SettingsModel::SettingsModel(qt_intf_t* intf, MainCtx* ctx, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_ctx(ctx)
    , m_hotkeys(new HotkeysModel(this))
{
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(saveDelayMs);
    connect(&m_saveTimer, &QTimer::timeout, this, &SettingsModel::saveNow);

    m_subRefreshTimer.setSingleShot(true);
    m_subRefreshTimer.setInterval(250);
    connect(&m_subRefreshTimer, &QTimer::timeout, this, &SettingsModel::refreshSubtitleCue);

    connect(m_hotkeys, &HotkeysModel::edited, this, [this]() {
        markRestart();
        save();
    });
}

SettingsModel::~SettingsModel()
{
    // don't lose the last change; the interface may already be going away,
    // so only write the file, without reloading the preferences
    if (m_saveTimer.isActive())
    {
        m_saveTimer.stop();
        config_SaveConfigFile(m_intf);
    }
}

ConfigOption* SettingsModel::option(const QString& name)
{
    auto it = m_options.constFind(name);
    if (it != m_options.cend())
        return it.value();

    ConfigOption* opt = createOption(name);
    // owned by the model, never by the QML engine
    QQmlEngine::setObjectOwnership(opt, QQmlEngine::CppOwnership);
    connect(opt, &ConfigOption::edited, this, [this, opt]() { onOptionEdited(opt); });
    m_options.insert(name, opt);
    return opt;
}

ConfigOption* SettingsModel::createOption(const QString& name)
{
    if (name == QLatin1String("theme"))
        return new ThemeOption(m_ctx, this);
    if (name == QLatin1String("accent"))
        return new AccentOption(m_ctx, this);
    if (name == QLatin1String("audioDevice"))
        return new AudioDeviceOption(m_intf, this);
    if (name == QLatin1String("mlFolders"))
        return new MLFoldersOption(m_ctx, false, this);
    if (name == QLatin1String("mlBannedFolders"))
        return new MLFoldersOption(m_ctx, true, this);
    if (name.startsWith(QLatin1String(ExtraInterfaceOption::prefix)))
        return new ExtraInterfaceOption(name.mid(int(strlen(ExtraInterfaceOption::prefix))), this);
    return new ConfigOption(name, this);
}

void SettingsModel::onOptionEdited(ConfigOption* edited)
{
    // options may depend on each other (aout -> audioDevice,
    // extraintf <-> extraInterface:*), re-read the other cached ones
    for (ConfigOption* opt : std::as_const(m_options))
    {
        if (opt != edited)
            opt->refresh();
    }

    if (edited->requiresRestart())
        markRestart();

    applySubtitleOptionLive(edited->name());

    // the accent colour is saved by MainCtx itself
    if (!qobject_cast<AccentOption*>(edited))
        save();
}

/*
 * Subtitle options reach the running video output here. The size is a variable of
 * the player (created from the config once, when the player starts), so writing the
 * config alone never changed the subtitle on screen. The margin is a vout variable.
 * The freetype-* appearance options are re-read by the text renderer on every render.
 */
void SettingsModel::applySubtitleOptionLive(const QString& name)
{
    const bool isScale = name == QLatin1String("sub-text-scale");
    const bool isMargin = name == QLatin1String("sub-margin");
    const bool isStyle = name.startsWith(QLatin1String("freetype-"));
    if (name == QLatin1String("spu") && m_intf && m_intf->p_player)
    {
        // "Enable subtitles": also a player variable that was read from the config at start
        vlc_player_Lock(m_intf->p_player);
        vlc_player_t* p = m_intf->p_player;
        const bool enable = config_GetInt("spu") != 0;
        vlc_player_SetSubtitleEnabled(p, enable);
        if (enable)
        {
            // the core only sets the flag; with no subtitle track selected nothing would show
            bool selected = false;
            const size_t count = vlc_player_GetTrackCount(p, SPU_ES);
            for (size_t i = 0; i < count && !selected; i++)
                selected = vlc_player_GetTrackAt(p, SPU_ES, i)->selected;
            if (!selected && count > 0)
                vlc_player_SelectTrack(p, vlc_player_GetTrackAt(p, SPU_ES, 0),
                                       VLC_PLAYER_SELECT_EXCLUSIVE);
            m_subRefreshTimer.start();
        }
        vlc_player_Unlock(m_intf->p_player);
        return;
    }
    if (!isScale && !isMargin && !isStyle)
        return;
    if (!m_intf || !m_intf->p_player)
        return;

    vlc_player_t* player = m_intf->p_player;
    vlc_player_Lock(player);
    if (isMargin)
    {
        size_t count = 0;
        vout_thread_t** vouts = vlc_player_vout_HoldAll(player, &count);
        const int margin = int(config_GetInt("sub-margin"));
        for (size_t i = 0; vouts && i < count; i++)
        {
            var_SetInteger(vouts[i], "sub-margin", margin);
            vout_Release(vouts[i]);
        }
        free(vouts);
    }
    else
    {
        unsigned scale = unsigned(config_GetInt("sub-text-scale"));
        scale = std::clamp(scale, 10u, 500u);
        vlc_player_SetSubtitleTextScale(player, scale);
    }
    vlc_player_Unlock(player);

    // coalesce slider drags into one refresh
    m_subRefreshTimer.start();
}

void SettingsModel::refreshSubtitleCue()
{
    // The spu renders a subtitle once and keeps the picture until the cue ends, so the
    // cue on screen would keep the old look. Seeking to the current position makes the
    // subtitle decoder send the cue again, rendered with the new options.
    if (!m_intf || !m_intf->p_player)
        return;
    vlc_player_t* player = m_intf->p_player;
    vlc_player_Lock(player);
    const vlc_tick_t now = vlc_player_GetTime(player);
    if (now != VLC_TICK_INVALID && vlc_player_IsStarted(player))
        vlc_player_SetTime(player, now);
    vlc_player_Unlock(player);
}

void SettingsModel::markRestart()
{
    if (m_restartPending)
        return;
    m_restartPending = true;
    emit restartRequired();
}

void SettingsModel::save()
{
    const bool wasActive = m_saveTimer.isActive();
    m_saveTimer.start();
    if (!wasActive)
        emit savePendingChanged();
}

void SettingsModel::flush()
{
    if (!m_saveTimer.isActive())
        return;
    m_saveTimer.stop();
    saveNow();
}

/* same as PrefsDialog::save() */
void SettingsModel::saveNow()
{
    emit savePendingChanged();

    const bool success = config_SaveConfigFile(m_intf) == 0;
    if (!success)
    {
        DialogErrorModel::getInstance(m_intf)->pushError(
            qtr("Cannot save Configuration"),
            qtr("Preferences file could not be saved"));
    }

    if (m_intf->p_mi)
        m_intf->p_mi->reloadPrefs();

    emit saved(success);
}

/* same as PrefsDialog::reset() */
void SettingsModel::resetAll()
{
    m_saveTimer.stop();

    config_ResetAll();
    config_SaveConfigFile(m_intf);
    qt_intf_t* p_intf = m_intf;
    getSettings()->clear();
    m_intf->preferencesResetPending = true;
    if (m_intf->p_mi)
    {
        m_intf->p_mi->reloadPrefs();
        m_intf->p_mi->reloadFromSettings();
    }
    if (m_ctx && !m_ctx->accentPresets().isEmpty())
    {
        // the accent colour is cached by MainCtx, apply the default live
        // (setAccentColor stores the colour, keep the "default" keyword)
        m_ctx->setAccentColor(QColor(m_ctx->accentPresets().first()));
        config_PutPsz("qt-accent-color", "default");
        config_SaveConfigFile(m_intf);
    }

    for (ConfigOption* opt : std::as_const(m_options))
        opt->refresh();
    m_hotkeys->reload();

    emit savePendingChanged();
    emit saved(true);
    markRestart();
}

QString SettingsModel::configFolder() const
{
    char* dir = config_GetUserDir(VLC_CONFIG_DIR);
    const QString path = dir ? qfu(dir) : QString();
    free(dir);
    return path;
}

void SettingsModel::openConfigFolder() const
{
    const QString path = configFolder();
    if (!path.isEmpty())
        QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

QString SettingsModel::pickFile(const QString& current, bool save) const
{
    const QString dir = current.isEmpty() ? QString() : QFileInfo(current).absolutePath();
    return save ? QFileDialog::getSaveFileName(nullptr, qtr("Save File"), dir)
                : QFileDialog::getOpenFileName(nullptr, qtr("Select File"), dir);
}

QString SettingsModel::pickDirectory(const QString& current) const
{
    return QFileDialog::getExistingDirectory(nullptr, qtr("Select Directory"), current);
}

void SettingsModel::openAllOptions() const
{
    if (DialogsProvider* dp = DialogsProvider::getInstance())
        dp->classicPrefsDialog(true);
}

void SettingsModel::quitForRestart() const
{
    if (m_intf->p_mi)
        emit m_intf->p_mi->askToQuit();
}
