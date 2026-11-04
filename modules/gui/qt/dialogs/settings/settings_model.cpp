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

#include <QColor>
#include <QDesktopServices>
#include <QFileDialog>
#include <QFileInfo>
#include <QQmlEngine>
#include <QSettings>
#include <QUrl>

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
    if (name == QLatin1String("media-library"))
        return new MediaLibraryOption(m_ctx, this);
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

    // the accent colour is saved by MainCtx itself
    if (!qobject_cast<AccentOption*>(edited))
        save();
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
