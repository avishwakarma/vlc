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
#ifndef QT_SETTINGS_VIRTUAL_OPTIONS_HPP
#define QT_SETTINGS_VIRTUAL_OPTIONS_HPP

#include "config_option.hpp"

#include <QPointer>

class MainCtx;
struct qt_intf_t;

/**
 * "theme": colour scheme, stored in QSettings (MainWindow/color-scheme-index).
 * Int option whose values are ColorSchemeModel::ColorScheme. choices only
 * list the redesign schemes (System = Auto, Light = Day, Dark = Night); the
 * value can still be ColorSchemeModel.System (native palette), in which case
 * currentIndex is -1.
 */
class ThemeOption : public ConfigOption
{
    Q_OBJECT
public:
    ThemeOption(MainCtx* ctx, QObject* parent);

protected:
    QVariant readValue() const override;
    void writeValue(const QVariant& value) override;
    QVariantList buildChoices() override;
    bool readAvailable() const override;

private:
    MainCtx* m_ctx;
};

/**
 * "accent": accent colour (MainCtx::accentColor, persisted by MainCtx in
 * qt-accent-color). Color option, choices are MainCtx::accentPresets.
 */
class AccentOption : public ConfigOption
{
    Q_OBJECT
public:
    AccentOption(MainCtx* ctx, QObject* parent);

protected:
    QVariant readValue() const override;
    void writeValue(const QVariant& value) override;
    QVariantList buildChoices() override;
    bool readAvailable() const override;

private:
    MainCtx* m_ctx;
};

/**
 * "audioDevice": the "<aout>-audio-device" option of the selected audio
 * output ("aout"), or of the default output of the platform when aout is
 * "any". Choices come from the option itself when it provides a list, or
 * from the running audio output otherwise (eg. auhal on macOS).
 * Unavailable when the selected output has no device option.
 */
class AudioDeviceOption : public ConfigOption
{
    Q_OBJECT
public:
    AudioDeviceOption(qt_intf_t* intf, QObject* parent);

    /// the VLC option currently backing this one, empty if none
    QString target() const { return m_target; }

    void refresh() override;

protected:
    QVariant readValue() const override;
    void writeValue(const QVariant& value) override;
    QVariantList buildChoices() override;
    bool readAvailable() const override;

private:
    static QString findTarget();

    qt_intf_t* m_intf;
    QString m_target;
    bool m_liveChoices = false;
};

/**
 * "extraInterface:<name>": whether the interface <name> (http, telnet, cli,
 * audioscrobbler, ...) is started with VLC, through config_AddIntf() /
 * config_RemoveIntf() (extraintf/control options). Bool, needs a restart.
 */
class ExtraInterfaceOption : public ConfigOption
{
    Q_OBJECT
public:
    ExtraInterfaceOption(const QString& intfName, QObject* parent);

    static constexpr const char* prefix = "extraInterface:";

protected:
    QVariant readValue() const override;
    void writeValue(const QVariant& value) override;
    QVariantList buildChoices() override { return {}; }
    bool readAvailable() const override;

private:
    QString m_intf;
};

/**
 * "mlFolders" / "mlBannedFolders": media library entry points. FolderList
 * option, no value: use `model` (an MLFoldersModel / MLBannedFoldersModel
 * with add(url), remove(url), removeAt(row)). Unavailable without a media
 * library.
 */
class MLFoldersOption : public ConfigOption
{
    Q_OBJECT
public:
    MLFoldersOption(MainCtx* ctx, bool banned, QObject* parent);

    QObject* model() const override { return m_model; }

protected:
    QVariant readValue() const override { return {}; }
    void writeValue(const QVariant&) override {}
    QVariantList buildChoices() override { return {}; }
    bool readAvailable() const override;

private:
    MainCtx* m_ctx;
    QObject* m_model = nullptr;
};

/**
 * "media-library": the saved option is not the whole story, the stock
 * launchers pass --media-library on every start, so the config item can be
 * off while the library is running. Reports the running state too.
 */
class MediaLibraryOption : public ConfigOption
{
    Q_OBJECT
public:
    MediaLibraryOption(MainCtx* ctx, QObject* parent);

protected:
    QVariant readValue() const override;

private:
    MainCtx* m_ctx;
};

#endif // QT_SETTINGS_VIRTUAL_OPTIONS_HPP
