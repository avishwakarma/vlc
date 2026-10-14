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

#include "config_option.hpp"

#include "qt.hpp"

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>

#include <QColor>
#include <QSet>

#include <cfloat>
#include <cstdlib>
#include <cstring>

namespace {

ConfigOption::Type typeFromVLC(int vlcType)
{
    switch (vlcType)
    {
    case CONFIG_ITEM_BOOL:            return ConfigOption::Bool;
    case CONFIG_ITEM_INTEGER:         return ConfigOption::Int;
    case CONFIG_ITEM_RGB:             return ConfigOption::Color;
    case CONFIG_ITEM_FLOAT:           return ConfigOption::Float;
    case CONFIG_ITEM_STRING:          return ConfigOption::String;
    case CONFIG_ITEM_PASSWORD:        return ConfigOption::Password;
    case CONFIG_ITEM_KEY:             return ConfigOption::Key;
    case CONFIG_ITEM_MODULE:
    case CONFIG_ITEM_MODULE_CAT:      return ConfigOption::Module;
    case CONFIG_ITEM_MODULE_LIST:
    case CONFIG_ITEM_MODULE_LIST_CAT: return ConfigOption::ModuleList;
    case CONFIG_ITEM_LOADFILE:
    case CONFIG_ITEM_SAVEFILE:        return ConfigOption::File;
    case CONFIG_ITEM_DIRECTORY:       return ConfigOption::Directory;
    case CONFIG_ITEM_FONT:            return ConfigOption::Font;
    default:                          return ConfigOption::Unknown;
    }
}

/* VLC stores floats: convert through the shortest decimal representation so
 * that 0.8f reads as 0.8 and not 0.800000011920929 */
double floatToDouble(float f)
{
    return QString::number(f, 'g', 7).toDouble();
}

QString rgbToString(int64_t rgb)
{
    return QColor::fromRgb(QRgb(rgb & 0xFFFFFF)).name(QColor::HexRgb).toUpper();
}

/* Options that are only read when the interface (or VLC) starts. This is
 * necessarily incomplete: most core/module options are read when the next
 * media is opened, which does not need a restart. */
const char* const restartOptions[] = {
    "intf",
    "extraintf",
    "control",
    "language",
    "one-instance",
    "one-instance-when-started-from-file",
    "playlist-enqueue",
    "media-library",
    "plugins-cache",
    "plugins-scan",
    "reset-plugins-cache",
    "qt-system-tray",
    "qt-start-minimized",
    "qt-close-to-system-tray",
    "qt-notification",
    "qt-embedded-open",
    "qt-updates-notif",
    "qt-updates-days",
    "qt-privacy-ask",
    "qt-icon-change",
    "qt-disable-volume-keys",
    "qt-backdrop-blur",
    "qt-pip-mode",
    "qt-use-scroll-handler",
    "qt-ui-font",
    "qt-qml-settings",
    "qt-x11-compositor",
    "qt-compositor",
    "qt-opengl",
    "qt-verbose",
    "qt-continue",
    "qt-recentplay",
    "qt-recentplay-filter",
    "qt-titlebar",
    "metadata-network-access",
};

} // anonymous namespace

ConfigOption::ConfigOption(const QString& name, QObject* parent)
    : QObject(parent)
    , m_name(name)
{
    // the returned item belongs to the core and lives as long as libvlc,
    // only its static fields (type, texts, range, defaults) are used here,
    // the current value is always read with config_Get*()
    const module_config_t* item = config_FindConfig(qtu(m_name));

    m_requiresRestart = isRestartOption(m_name) || m_name.startsWith("key-")
                        || m_name.startsWith("global-key-");

    if (!item || !CONFIG_ITEM(item->i_type) || !item->psz_text)
    {
        // missing in this build/platform, or an obsolete (removed) option
        m_available = false;
        return;
    }

    m_vlcType = item->i_type;
    m_type = typeFromVLC(m_vlcType);
    if (m_type == Unknown)
        return;

    m_available = true;
    m_saveFile = (m_vlcType == CONFIG_ITEM_SAVEFILE);
    m_text = qfut(item->psz_text);
    if (item->psz_longtext)
        m_longText = qfut(item->psz_longtext);

    if (IsConfigIntegerType(m_vlcType))
    {
        if (m_type == Bool)
            m_default = QVariant(item->orig.i != 0);
        else if (m_type == Color)
            m_default = rgbToString(item->orig.i);
        else
        {
            m_default = QVariant::fromValue<qint64>(item->orig.i);
            if (item->min.i != INT64_MIN || item->max.i != INT64_MAX)
                setRange(QVariant::fromValue<qint64>(item->min.i),
                         QVariant::fromValue<qint64>(item->max.i));
        }
    }
    else if (IsConfigFloatType(m_vlcType))
    {
        m_default = QVariant(floatToDouble(item->orig.f));
        const bool unbounded = (item->min.f == -FLT_MAX && item->max.f == FLT_MAX)
                            || (item->min.f == 0.f && item->max.f == 0.f);
        if (!unbounded)
            setRange(floatToDouble(item->min.f), floatToDouble(item->max.f));
    }
    else
    {
        m_default = item->orig.psz ? qfu(item->orig.psz) : QString();
    }

    m_value = readValue();
}

ConfigOption::ConfigOption(const QString& name, Type type, const QString& text,
                           const QString& longText, QObject* parent)
    : QObject(parent)
    , m_name(name)
    , m_type(type)
    , m_text(text)
    , m_longText(longText)
    , m_virtual(true)
{
    // subclasses must call refresh() once they are fully constructed
}

ConfigOption::~ConfigOption() = default;

bool ConfigOption::isRestartOption(const QString& name)
{
    static const QSet<QString> set = [] {
        QSet<QString> s;
        for (const char* n : restartOptions)
            s.insert(QString::fromLatin1(n));
        return s;
    }();
    return set.contains(name);
}

QVariantMap ConfigOption::makeChoice(const QVariant& value, const QString& text)
{
    return QVariantMap{ { QStringLiteral("value"), value },
                        { QStringLiteral("text"), text } };
}

void ConfigOption::setRange(const QVariant& min, const QVariant& max)
{
    m_min = min;
    m_max = max;
    m_hasRange = true;
}

void ConfigOption::setDefaultValue(const QVariant& value)
{
    if (sameValue(m_type, value, m_default) && m_default.isValid() == value.isValid())
        return;
    m_default = value;
    emit defaultValueChanged();
    emit valueChanged(); // modified may have changed
}

void ConfigOption::setAvailable(bool available)
{
    if (available == m_available)
        return;
    m_available = available;
    emit availableChanged();
}

/* value */

QVariant ConfigOption::readValue() const
{
    if (!m_available || m_vlcType == 0)
        return {};

    const QByteArray name = m_name.toUtf8();
    switch (m_type)
    {
    case Bool:
        return QVariant(config_GetInt(name.constData()) != 0);
    case Int:
        return QVariant::fromValue<qint64>(config_GetInt(name.constData()));
    case Color:
        return rgbToString(config_GetInt(name.constData()));
    case Float:
        return QVariant(floatToDouble(config_GetFloat(name.constData())));
    case Unknown:
    case FolderList:
        return {};
    default:
    {
        // config_GetPsz returns a heap copy (or NULL for empty strings)
        char* psz = config_GetPsz(name.constData());
        QString str = psz ? qfu(psz) : QString();
        free(psz);
        return str;
    }
    }
}

void ConfigOption::writeValue(const QVariant& value)
{
    if (!m_available || m_vlcType == 0)
        return;

    const QByteArray name = m_name.toUtf8();
    switch (m_type)
    {
    case Bool:
        config_PutInt(name.constData(), value.toBool() ? 1 : 0);
        break;
    case Int:
        config_PutInt(name.constData(), value.toLongLong());
        break;
    case Color:
        config_PutInt(name.constData(), QColor(value.toString()).rgb() & 0xFFFFFF);
        break;
    case Float:
        config_PutFloat(name.constData(), float(value.toDouble()));
        break;
    case Unknown:
    case FolderList:
        break;
    default:
    {
        const QByteArray str = value.toString().toUtf8();
        // an empty string is stored as NULL by the core
        config_PutPsz(name.constData(), str.isEmpty() ? nullptr : str.constData());
        break;
    }
    }
}

bool ConfigOption::readAvailable() const
{
    if (m_vlcType == 0)
        return m_available;
    return config_FindConfig(qtu(m_name)) != nullptr;
}

QVariant ConfigOption::normalize(const QVariant& value) const
{
    switch (m_type)
    {
    case Bool:
        return QVariant(value.toBool());
    case Int:
        // accepts numbers and numeric strings (QML may hand doubles)
        if (value.typeId() == QMetaType::Double || value.typeId() == QMetaType::Float)
            return QVariant::fromValue<qint64>(qRound64(value.toDouble()));
        return QVariant::fromValue<qint64>(value.toLongLong());
    case Float:
        return QVariant(value.toDouble());
    case Color:
    {
        QColor color;
        if (value.typeId() == QMetaType::QColor)
            color = value.value<QColor>();
        else if (value.typeId() == QMetaType::Int || value.typeId() == QMetaType::LongLong
                 || value.typeId() == QMetaType::UInt || value.typeId() == QMetaType::Double)
            color = QColor::fromRgb(QRgb(value.toLongLong() & 0xFFFFFF));
        else
            color = QColor(value.toString());
        if (!color.isValid())
            return {};
        return color.name(QColor::HexRgb).toUpper();
    }
    case FolderList:
    case Unknown:
        return {};
    default:
        return value.toString();
    }
}

bool ConfigOption::sameValue(Type type, const QVariant& a, const QVariant& b)
{
    switch (type)
    {
    case Bool:
        return a.toBool() == b.toBool();
    case Int:
        return a.toLongLong() == b.toLongLong();
    case Float:
        return qFuzzyCompare(1.0 + a.toDouble(), 1.0 + b.toDouble());
    case Color:
        return a.toString().compare(b.toString(), Qt::CaseInsensitive) == 0;
    case FolderList:
    case Unknown:
        return true;
    default:
        // NULL and "" are the same for the core
        return a.toString() == b.toString();
    }
}

void ConfigOption::setValue(const QVariant& value)
{
    if (!m_available)
        return;

    const QVariant v = normalize(value);
    if (!v.isValid() && m_type != FolderList)
        return;

    const int oldIndex = m_choicesLoaded ? currentIndex() : -1;
    writeValue(v);

    // read back: the core clamps integers/floats to their range
    const QVariant newValue = readValue();
    const bool changed = !sameValue(m_type, newValue, m_value)
                         || m_value.isValid() != newValue.isValid();
    m_value = newValue;
    if (changed)
    {
        emit valueChanged();
        if (!m_choicesLoaded || oldIndex != currentIndex())
            emit currentIndexChanged();
    }
    // always notify, the write itself may have side effects (virtual options)
    emit edited();
}

bool ConfigOption::modified() const
{
    if (!m_available || !m_default.isValid())
        return false;
    return !sameValue(m_type, m_value, m_default);
}

void ConfigOption::reset()
{
    if (!m_default.isValid())
        return;
    setValue(m_default);
}

void ConfigOption::refresh()
{
    const bool available = readAvailable();
    setAvailable(available);

    const QVariant newValue = readValue();
    if (!sameValue(m_type, newValue, m_value) || m_value.isValid() != newValue.isValid())
    {
        m_value = newValue;
        emit valueChanged();
        emit currentIndexChanged();
    }
}

/* choices */

QVariantList ConfigOption::choices()
{
    if (!m_choicesLoaded)
    {
        m_choices = m_available ? buildChoices() : QVariantList{};
        m_choicesLoaded = true;
    }
    return m_choices;
}

void ConfigOption::invalidateChoices()
{
    m_choicesLoaded = false;
    m_choices.clear();
    emit choicesChanged();
    emit currentIndexChanged();
}

void ConfigOption::reloadChoices()
{
    invalidateChoices();
}

int ConfigOption::currentIndex()
{
    const QVariantList list = choices();
    for (int i = 0; i < list.size(); ++i)
    {
        const QVariant v = list[i].toMap().value(QStringLiteral("value"));
        if (sameValue(m_type, v, m_value))
            return i;
    }
    return -1;
}

void ConfigOption::setCurrentIndex(int index)
{
    const QVariantList list = choices();
    if (index < 0 || index >= list.size())
        return;
    setValue(list[index].toMap().value(QStringLiteral("value")));
}

QString ConfigOption::textForValue(const QVariant& value)
{
    const QVariantList list = choices();
    for (const QVariant& c : list)
    {
        const QVariantMap map = c.toMap();
        if (sameValue(m_type, map.value(QStringLiteral("value")), value))
            return map.value(QStringLiteral("text")).toString();
    }
    return value.toString();
}

QVariantList ConfigOption::buildChoices()
{
    QVariantList list;
    if (m_vlcType == 0)
        return list;

    const QByteArray name = m_name.toUtf8();

    if (IsConfigIntegerType(m_vlcType) && m_type != Bool)
    {
        int64_t* values = nullptr;
        char** texts = nullptr;
        const ssize_t count = config_GetIntChoices(name.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            const QVariant v = (m_type == Color)
                    ? QVariant(rgbToString(values[i]))
                    : QVariant::fromValue<qint64>(values[i]);
            // texts are already translated by the core (vlc_gettext)
            list.append(makeChoice(v, qfu(texts[i])));
            free(texts[i]);
        }
        free(values);
        free(texts);
        return list;
    }

    if (!IsConfigStringType(m_vlcType))
        return list;

    const module_config_t* item = config_FindConfig(name.constData());
    if (!item)
        return list;

    switch (m_vlcType)
    {
    case CONFIG_ITEM_MODULE_CAT:
        // "Hack: required subcategory is stored in i_min"
        return moduleCatChoices(int(item->min.i));
    case CONFIG_ITEM_MODULE_LIST:
        return moduleListChoices(false, 0, qfu(item->psz_type));
    case CONFIG_ITEM_MODULE_LIST_CAT:
        return moduleListChoices(true, int(item->min.i), QString());
    case CONFIG_ITEM_KEY:
        return list;
    default:
        break;
    }

    // CONFIG_ITEM_MODULE lists the modules by capability ("any", ..., "none")
    char** values = nullptr;
    char** texts = nullptr;
    const ssize_t count = config_GetPszChoices(name.constData(), &values, &texts);
    for (ssize_t i = 0; i < count; ++i)
    {
        list.append(makeChoice(values[i] ? qfu(values[i]) : QString(),
                               texts[i] ? qfu(texts[i]) : QString()));
        free(values[i]);
        free(texts[i]);
    }
    free(values);
    free(texts);
    return list;
}

/* same logic as ModuleConfigControl::finish() */
QVariantList ConfigOption::moduleCatChoices(int subcategory) const
{
    QVariantList list;
    list.append(makeChoice(QString(), qtr("Default")));

    size_t count;
    module_t** modules = module_list_get(&count);
    for (size_t i = 0; i < count; i++)
    {
        module_t* module = modules[i];
        if (!strcmp(module_get_object(module), "core"))
            continue;

        unsigned confsize;
        module_config_t* config = module_config_get(module, &confsize);
        for (unsigned j = 0; j < confsize; j++)
        {
            const module_config_t* cfg = config + j;
            if (cfg->i_type == CONFIG_SUBCATEGORY && cfg->value.i == subcategory)
            {
                list.append(makeChoice(qfu(module_get_object(module)),
                                       qfut(module_GetLongName(module))));
                break;
            }
        }
        module_config_free(config);
    }
    module_list_free(modules);
    return list;
}

/* same logic as ModuleListConfigControl::finish() */
QVariantList ConfigOption::moduleListChoices(bool byCategory, int subcategory,
                                             const QString& capability) const
{
    QVariantList list;
    const QByteArray cap = capability.toUtf8();

    size_t count;
    module_t** modules = module_list_get(&count);
    for (size_t i = 0; i < count; i++)
    {
        module_t* module = modules[i];

        if (byCategory)
        {
            if (!strcmp(module_get_object(module), "core"))
                continue;

            unsigned confsize;
            module_config_t* config = module_config_get(module, &confsize);
            bool added = false;
            for (unsigned j = 0; j < confsize; j++)
            {
                const module_config_t* cfg = config + j;
                if (cfg->i_type != CONFIG_SUBCATEGORY || cfg->value.i != subcategory)
                    continue;

                if (!added)
                {
                    list.append(makeChoice(qfu(module_get_object(module)),
                                           qfut(module_GetLongName(module))));
                    added = true;
                }
                /* the http/telnet/cli interfaces are provided by lua */
                if (!strcmp(module_get_object(module), "lua") && m_name == "extraintf")
                {
                    list.append(makeChoice(QStringLiteral("http"), QStringLiteral("Web")));
                    list.append(makeChoice(QStringLiteral("telnet"), QStringLiteral("Telnet")));
#ifndef _WIN32
                    list.append(makeChoice(QStringLiteral("cli"), QStringLiteral("Console")));
#endif
                }
            }
            module_config_free(config);
        }
        else if (!cap.isEmpty() && module_provides(module, cap.constData()))
        {
            list.append(makeChoice(qfu(module_get_object(module)),
                                   qfut(module_GetLongName(module))));
        }
    }
    module_list_free(modules);
    return list;
}

/* ModuleList helpers */

bool ConfigOption::hasListItem(const QString& item) const
{
    return m_value.toString().split(':', Qt::SkipEmptyParts).contains(item);
}

void ConfigOption::setListItem(const QString& item, bool enabled)
{
    QStringList items = m_value.toString().split(':', Qt::SkipEmptyParts);
    if (enabled == items.contains(item))
        return;
    if (enabled)
        items.append(item);
    else
        items.removeAll(item);
    setValue(items.join(':'));
}
