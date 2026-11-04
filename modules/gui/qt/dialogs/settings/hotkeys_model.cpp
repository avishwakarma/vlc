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

#include "hotkeys_model.hpp"

#include "qt.hpp"
#include "util/vlchotkeyconverter.hpp"

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>
#include <vlc_actions.h>

#include <QKeyEvent>

#include <cstdlib>
#include <cstring>

namespace {

const QChar keySeparator = QLatin1Char('\t');

QString readKeys(const QString& name)
{
    if (name.isEmpty())
        return {};
    char* psz = config_GetPsz(qtu(name));
    QString keys = psz ? qfu(psz) : QString();
    free(psz);
    return keys;
}

QStringList splitKeys(const QString& keys)
{
    return keys.split(keySeparator, Qt::SkipEmptyParts);
}

} // anonymous namespace

HotkeysModel::HotkeysModel(QObject* parent)
    : QAbstractListModel(parent)
{
    load();
}

/* same enumeration as KeySelectorControl::finish() */
void HotkeysModel::load()
{
    m_items.clear();

    module_t* main = module_get_main();
    if (!main)
        return;

    unsigned confsize;
    module_config_t* config = module_config_get(main, &confsize);

    QVector<const module_config_t*> globals;
    for (unsigned i = 0; i < confsize; i++)
    {
        const module_config_t* item = config + i;
        if (item->i_type != CONFIG_ITEM_KEY)
            continue;

        if (strncmp(item->psz_name, "global-", 7) == 0)
        {
            globals.append(item);
            continue;
        }

        Item entry;
        entry.text = item->psz_text ? qfut(item->psz_text) : qfu(item->psz_name);
        if (item->psz_longtext)
            entry.longText = qfut(item->psz_longtext);
        entry.normal.name = qfu(item->psz_name);
        entry.normal.defaults = qfu(item->orig.psz);
        // value.psz may be replaced concurrently, read a copy
        entry.normal.keys = readKeys(entry.normal.name);
        m_items.append(entry);
    }

    for (const module_config_t* item : globals)
    {
        const QString normalName = qfu(item->psz_name + 7);
        for (Item& entry : m_items)
        {
            if (entry.normal.name != normalName)
                continue;
            entry.global.name = qfu(item->psz_name);
            entry.global.defaults = qfu(item->orig.psz);
            entry.global.keys = readKeys(entry.global.name);
            break;
        }
    }

    module_config_free(config);
}

void HotkeysModel::reload()
{
    beginResetModel();
    load();
    endResetModel();
    emit countChanged();
}

int HotkeysModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.size();
}

QHash<int, QByteArray> HotkeysModel::roleNames() const
{
    return {
        { NameRole, "name" },
        { ActionRole, "action" },
        { DescriptionRole, "description" },
        { KeysRole, "keys" },
        { KeysTextRole, "keysText" },
        { KeyListRole, "keyList" },
        { DefaultKeysRole, "defaultKeys" },
        { ModifiedRole, "modified" },
        { HasGlobalRole, "hasGlobal" },
        { GlobalNameRole, "globalName" },
        { GlobalKeysRole, "globalKeys" },
        { GlobalKeysTextRole, "globalKeysText" },
        { GlobalDefaultKeysRole, "globalDefaultKeys" },
        { GlobalModifiedRole, "globalModified" },
    };
}

QVariant HotkeysModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return {};

    const Item& item = m_items[index.row()];
    switch (role)
    {
    case Qt::DisplayRole:
    case ActionRole:            return item.text;
    case NameRole:              return item.normal.name;
    case DescriptionRole:       return item.longText;
    case KeysRole:              return item.normal.keys;
    case KeysTextRole:          return keyText(item.normal.keys);
    case KeyListRole:           return splitKeys(item.normal.keys);
    case DefaultKeysRole:       return item.normal.defaults;
    case ModifiedRole:          return item.normal.keys != item.normal.defaults;
    case HasGlobalRole:         return !item.global.name.isEmpty();
    case GlobalNameRole:        return item.global.name;
    case GlobalKeysRole:        return item.global.keys;
    case GlobalKeysTextRole:    return keyText(item.global.keys);
    case GlobalDefaultKeysRole: return item.global.defaults;
    case GlobalModifiedRole:    return item.global.keys != item.global.defaults;
    default:                    return {};
    }
}

int HotkeysModel::indexOf(const QString& name) const
{
    for (int i = 0; i < m_items.size(); ++i)
    {
        if (m_items[i].normal.name == name || m_items[i].global.name == name)
            return i;
    }
    return -1;
}

QVariantMap HotkeysModel::get(int row) const
{
    QVariantMap map;
    if (row < 0 || row >= m_items.size())
        return map;
    const QModelIndex idx = index(row);
    const auto roles = roleNames();
    for (auto it = roles.cbegin(); it != roles.cend(); ++it)
        map.insert(QString::fromLatin1(it.value()), data(idx, it.key()));
    return map;
}

HotkeysModel::Binding& HotkeysModel::binding(int row, bool global)
{
    return global ? m_items[row].global : m_items[row].normal;
}

const HotkeysModel::Binding& HotkeysModel::binding(int row, bool global) const
{
    return global ? m_items[row].global : m_items[row].normal;
}

int HotkeysModel::findConflict(const QString& key, int ignoreRow, bool global) const
{
    if (key.isEmpty())
        return -1;
    for (int i = 0; i < m_items.size(); ++i)
    {
        if (i == ignoreRow)
            continue;
        if (splitKeys(binding(i, global).keys).contains(key))
            return i;
    }
    return -1;
}

void HotkeysModel::store(int row, bool global, const QString& keys)
{
    Binding& b = binding(row, global);
    if (b.name.isEmpty() || b.keys == keys)
        return;
    b.keys = keys;
    const QByteArray value = keys.toUtf8();
    config_PutPsz(qtu(b.name), value.isEmpty() ? nullptr : value.constData());
    const QModelIndex idx = index(row);
    emit dataChanged(idx, idx);
}

void HotkeysModel::removeKeyFromOthers(int row, const QString& key, bool global)
{
    for (int i = 0; i < m_items.size(); ++i)
    {
        if (i == row)
            continue;
        QStringList keys = splitKeys(binding(i, global).keys);
        if (keys.removeAll(key) > 0)
            store(i, global, keys.join(keySeparator));
    }
}

int HotkeysModel::setKey(int row, const QString& key, bool global, bool force)
{
    if (row < 0 || row >= m_items.size() || binding(row, global).name.isEmpty())
        return -1;

    for (const QString& k : splitKeys(key))
    {
        const int conflict = findConflict(k, row, global);
        if (conflict >= 0 && !force)
            return conflict;
    }
    for (const QString& k : splitKeys(key))
        removeKeyFromOthers(row, k, global);
    store(row, global, key);
    emit edited();
    return -1;
}

int HotkeysModel::addKey(int row, const QString& key, bool global, bool force)
{
    if (row < 0 || row >= m_items.size() || key.isEmpty())
        return -1;
    QStringList keys = splitKeys(binding(row, global).keys);
    if (keys.contains(key))
        return -1;
    keys.append(key);
    return setKey(row, keys.join(keySeparator), global, force);
}

void HotkeysModel::clearKey(int row, bool global)
{
    if (row < 0 || row >= m_items.size())
        return;
    store(row, global, QString());
    emit edited();
}

int HotkeysModel::resetKey(int row, bool global, bool force)
{
    if (row < 0 || row >= m_items.size())
        return -1;
    return setKey(row, binding(row, global).defaults, global, force);
}

void HotkeysModel::resetAll()
{
    for (int i = 0; i < m_items.size(); ++i)
    {
        store(i, false, m_items[i].normal.defaults);
        store(i, true, m_items[i].global.defaults);
    }
    emit edited();
}

QString HotkeysModel::keyFromEvent(int key, int modifiers) const
{
    switch (key)
    {
    case Qt::Key_unknown:
    case Qt::Key_Tab:
    case Qt::Key_Shift:
    case Qt::Key_Control:
    case Qt::Key_Meta:
    case Qt::Key_Alt:
    case Qt::Key_AltGr:
        return {};
    default:
        break;
    }
    QKeyEvent event(QEvent::KeyPress, key, Qt::KeyboardModifiers(modifiers));
    return VLCKeyToString(qtEventToVLCKey(&event), false);
}

QString HotkeysModel::keyText(const QString& keys) const
{
    QStringList texts;
    for (const QString& key : splitKeys(keys))
    {
        // only translate names the core parses back to themselves
        const uint_fast32_t code = vlc_str2keycode(qtu(key));
        QString text;
        if (code != KEY_UNSET && VLCKeyToString(code, false) == key)
            text = VLCKeyToString(code, true);
        texts.append(text.isEmpty() ? key : text);
    }
    return texts.join(QStringLiteral(", "));
}

QStringList HotkeysModel::keyCaps(const QString& keys, int which) const
{
    const QStringList list = splitKeys(keys);
    if (which < 0 || which >= list.size())
        return {};
    return VLCHotkeyCaps(list.at(which));
}

QString HotkeysModel::keyGlyphs(const QString& keys) const
{
    QStringList texts;
    for (const QString& key : splitKeys(keys))
    {
        const QString glyphs = VLCHotkeyGlyphs(key);
        texts.append(glyphs.isEmpty() ? key : glyphs);
    }
    return texts.join(QStringLiteral(", "));
}
