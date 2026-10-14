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

#include "virtual_options.hpp"

#include "qt.hpp"
#include "maininterface/mainctx.hpp"
#include "medialibrary/mlfoldersmodel.hpp"
#include "util/color_scheme_model.hpp"

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_player.h>
#include <vlc_aout.h>

#include <QColor>
#include <QSettings>

#include <cstdlib>

/* theme */

ThemeOption::ThemeOption(MainCtx* ctx, QObject* parent)
    : ConfigOption(QStringLiteral("theme"), Int, qtr("Theme"),
                   qtr("Color scheme of the interface"), parent)
    , m_ctx(ctx)
{
    // MainCtx loads MainWindow/color-scheme-index with a default of 0
    const auto schemes = m_ctx->getColorScheme()->getSchemes();
    if (!schemes.isEmpty())
        setDefaultValue(int(schemes.first().scheme));
    connect(m_ctx->getColorScheme(), &ColorSchemeModel::currentChanged,
            this, &ConfigOption::refresh);
    refresh();
}

bool ThemeOption::readAvailable() const
{
    return m_ctx && m_ctx->getColorScheme();
}

QVariant ThemeOption::readValue() const
{
    return int(m_ctx->getColorScheme()->currentScheme());
}

void ThemeOption::writeValue(const QVariant& value)
{
    ColorSchemeModel* model = m_ctx->getColorScheme();
    const auto schemes = model->getSchemes();
    const int scheme = value.toInt();
    for (int i = 0; i < schemes.size(); ++i)
    {
        if (int(schemes[i].scheme) != scheme)
            continue;
        model->setCurrentIndex(i);
        // MainCtx only stores it on exit, store it now as well
        if (qt_intf_t* p_intf = m_ctx->getIntf())
            getSettings()->setValue(QStringLiteral("MainWindow/color-scheme-index"), i);
        return;
    }
}

QVariantList ThemeOption::buildChoices()
{
    return {
        makeChoice(int(ColorSchemeModel::Auto), qtr("System")),
        makeChoice(int(ColorSchemeModel::Day), qtr("Light")),
        makeChoice(int(ColorSchemeModel::Night), qtr("Dark")),
    };
}

/* accent */

namespace {
const char* const accentNames[] = {
    N_("Orange"), N_("Red"), N_("Yellow"), N_("Green"), N_("Teal"),
    N_("Blue"), N_("Purple"), N_("Pink"), N_("Gray"),
};
}

AccentOption::AccentOption(MainCtx* ctx, QObject* parent)
    : ConfigOption(QStringLiteral("accent"), Color, qtr("Accent color"),
                   qtr("Color used to highlight the interface elements"), parent)
    , m_ctx(ctx)
{
    const QStringList presets = m_ctx->accentPresets();
    if (!presets.isEmpty())
        setDefaultValue(presets.first().toUpper());
    connect(m_ctx, &MainCtx::accentColorChanged, this, &ConfigOption::refresh);
    refresh();
}

bool AccentOption::readAvailable() const
{
    return m_ctx != nullptr;
}

QVariant AccentOption::readValue() const
{
    return m_ctx->accentColor().name(QColor::HexRgb).toUpper();
}

void AccentOption::writeValue(const QVariant& value)
{
    // MainCtx stores qt-accent-color and saves the configuration itself
    m_ctx->setAccentColor(QColor(value.toString()));
}

QVariantList AccentOption::buildChoices()
{
    QVariantList list;
    const QStringList presets = m_ctx->accentPresets();
    for (int i = 0; i < presets.size(); ++i)
    {
        const QString text = (size_t(i) < ARRAY_SIZE(accentNames))
                ? qtr(accentNames[i]) : presets[i];
        list.append(makeChoice(presets[i].toUpper(), text));
    }
    return list;
}

/* audio device */

AudioDeviceOption::AudioDeviceOption(qt_intf_t* intf, QObject* parent)
    : ConfigOption(QStringLiteral("audioDevice"), String, qtr("Output device"),
                   qtr("Audio device used by the selected audio output"), parent)
    , m_intf(intf)
{
    setDefaultValue(QString());
    refresh();
}

QString AudioDeviceOption::findTarget()
{
    char* psz_aout = config_GetPsz("aout");
    const QString aout = psz_aout ? qfu(psz_aout) : QString();
    free(psz_aout);

    auto deviceOption = [](const QString& module) -> QString {
        const QString name = module + QStringLiteral("-audio-device");
        if (config_FindConfig(qtu(name)) == nullptr)
            return {};
        return name;
    };

    if (aout == QLatin1String("none"))
        return {};
    if (!aout.isEmpty() && aout != QLatin1String("any"))
        return deviceOption(aout.section(',', 0, 0));

    /* "any": the output the platform picks first, same set as the
     * simple preferences (simple_preferences.cpp) */
    static const char* const defaults[] = {
#if defined(_WIN32)
        "mmdevice", "waveout",
#elif defined(__APPLE__)
        "auhal",
#elif defined(__OS2__)
        "kai",
#else
        "pulse", "alsa", "oss",
#endif
    };
    for (const char* module : defaults)
    {
        if (!module_exists(module))
            continue;
        // pulse has no device option: the device is chosen in the sound server
        return deviceOption(qfu(module));
    }
    return {};
}

void AudioDeviceOption::refresh()
{
    const QString target = findTarget();
    if (target != m_target)
    {
        m_target = target;
        invalidateChoices();
    }
    ConfigOption::refresh();
}

bool AudioDeviceOption::readAvailable() const
{
    return !m_target.isEmpty();
}

QVariant AudioDeviceOption::readValue() const
{
    if (m_target.isEmpty())
        return QString();
    char* psz = config_GetPsz(qtu(m_target));
    const QString value = psz ? qfu(psz) : QString();
    free(psz);
    return value;
}

void AudioDeviceOption::writeValue(const QVariant& value)
{
    if (m_target.isEmpty())
        return;
    const QByteArray id = value.toString().toUtf8();
    config_PutPsz(qtu(m_target), id.isEmpty() ? nullptr : id.constData());

    /* the list came from the running output: switch it live too */
    if (m_liveChoices && !id.isEmpty() && m_intf && m_intf->p_player)
    {
        audio_output_t* aout = vlc_player_aout_Hold(m_intf->p_player);
        if (aout)
        {
            aout_DeviceSet(aout, id.constData());
            aout_Release(aout);
        }
    }
}

QVariantList AudioDeviceOption::buildChoices()
{
    QVariantList list;
    m_liveChoices = false;
    if (m_target.isEmpty())
        return list;

    char** values = nullptr;
    char** texts = nullptr;
    const ssize_t count = config_GetPszChoices(qtu(m_target), &values, &texts);
    for (ssize_t i = 0; i < count; ++i)
    {
        list.append(makeChoice(values[i] ? qfu(values[i]) : QString(),
                               texts[i] ? qfu(texts[i]) : QString()));
        free(values[i]);
        free(texts[i]);
    }
    free(values);
    free(texts);
    if (!list.isEmpty())
        return list;

    /* the option has no list (auhal...): ask the running audio output */
    if (!m_intf || !m_intf->p_player)
        return list;
    audio_output_t* aout = vlc_player_aout_Hold(m_intf->p_player);
    if (!aout)
        return list;

    /* the output lists its own default entry (eg. auhal "0", "System Sound
     * Output Device"); the empty value (core default) only means "not chosen
     * yet" and is not listed, currentIndex is -1 in that case */
    char** ids = nullptr;
    char** names = nullptr;
    const int n = aout_DevicesList(aout, &ids, &names);
    for (int i = 0; i < n; ++i)
    {
        const QString id = ids[i] ? qfu(ids[i]) : QString();
        list.append(makeChoice(id, names[i] ? qfu(names[i]) : id));
        free(ids[i]);
        free(names[i]);
    }
    if (n >= 0) // on error, the tables are released by the core
    {
        free(ids);
        free(names);
    }
    aout_Release(aout);

    m_liveChoices = true;
    return list;
}

/* extra interfaces */

ExtraInterfaceOption::ExtraInterfaceOption(const QString& intfName, QObject* parent)
    : ConfigOption(QLatin1String(prefix) + intfName, Bool, QString(), QString(), parent)
    , m_intf(intfName)
{
    setRequiresRestart(true);
    setDefaultValue(false);
    refresh();
}

bool ExtraInterfaceOption::readAvailable() const
{
    if (m_intf.isEmpty() || m_intf.contains(':'))
        return false;
    /* the http, telnet and cli interfaces are lua scripts */
    if (m_intf == QLatin1String("http") || m_intf == QLatin1String("telnet")
        || m_intf == QLatin1String("cli"))
        return module_exists("lua");
    return module_exists(qtu(m_intf));
}

QVariant ExtraInterfaceOption::readValue() const
{
    if (m_intf.isEmpty())
        return false;
    return config_ExistIntf(qtu(m_intf));
}

void ExtraInterfaceOption::writeValue(const QVariant& value)
{
    if (value.toBool())
        config_AddIntf(qtu(m_intf));
    else
        config_RemoveIntf(qtu(m_intf));
}

/* media library folders */

MLFoldersOption::MLFoldersOption(MainCtx* ctx, bool banned, QObject* parent)
    : ConfigOption(banned ? QStringLiteral("mlBannedFolders") : QStringLiteral("mlFolders"),
                   FolderList,
                   banned ? qtr("Banned folders") : qtr("Media folders"),
                   banned ? qtr("Folders excluded from the media library")
                          : qtr("Folders scanned by the media library"),
                   parent)
    , m_ctx(ctx)
{
    if (m_ctx && m_ctx->hasMediaLibrary())
    {
        MLFoldersBaseModel* model = banned
                ? static_cast<MLFoldersBaseModel*>(new MLBannedFoldersModel(this))
                : static_cast<MLFoldersBaseModel*>(new MLFoldersModel(this));
        model->setCtx(m_ctx);
        m_model = model;
    }
    refresh();
}

bool MLFoldersOption::readAvailable() const
{
    return m_model != nullptr;
}
