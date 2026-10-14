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
#ifndef QT_SETTINGS_HOTKEYS_MODEL_HPP
#define QT_SETTINGS_HOTKEYS_MODEL_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QAbstractListModel>
#include <QVector>
#include <QVariantMap>

/**
 * List of the hotkeys of the core module (CONFIG_ITEM_KEY "key-*" options and
 * their "global-key-*" counterpart), same data as KeySelectorControl.
 *
 * A binding is a '\t' separated list of VLC key names ("Ctrl+a\tMedia Play").
 * Changes are written to the configuration immediately (edited() is emitted
 * so that SettingsModel saves it); they are applied by VLC after a restart.
 */
class HotkeysModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)
    Q_PROPERTY(bool requiresRestart READ requiresRestart CONSTANT FINAL)

public:
    enum Roles
    {
        NameRole = Qt::UserRole + 1,  // "key-play"
        ActionRole,                   // translated action label ("Play/Pause")
        DescriptionRole,              // long text, may be empty
        KeysRole,                     // raw binding ("Space\tMedia Play")
        KeysTextRole,                 // translated, ", " separated
        KeyListRole,                  // raw binding as a list
        DefaultKeysRole,
        ModifiedRole,                 // keys != default
        HasGlobalRole,                // a global-key-* option exists
        GlobalNameRole,
        GlobalKeysRole,
        GlobalKeysTextRole,
        GlobalDefaultKeysRole,
        GlobalModifiedRole,
    };
    Q_ENUM(Roles)

    explicit HotkeysModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool requiresRestart() const { return true; }

    /// row of the action "key-xxx" (or "global-key-xxx"), -1 if not found
    Q_INVOKABLE int indexOf(const QString& name) const;
    /// all the roles of a row, as a map keyed by role name
    Q_INVOKABLE QVariantMap get(int row) const;

    /// row (other than ignoreRow) whose binding contains key, -1 if none
    Q_INVOKABLE int findConflict(const QString& key, int ignoreRow = -1,
                                 bool global = false) const;

    /**
     * Bind key to the action at row (replacing its current binding).
     * If another action uses key and force is false, nothing is changed and
     * the row of that action is returned. Otherwise key is removed from the
     * other action, the binding is set and -1 is returned.
     */
    Q_INVOKABLE int setKey(int row, const QString& key, bool global = false,
                           bool force = false);
    /// add key to the binding of row (same conflict handling as setKey)
    Q_INVOKABLE int addKey(int row, const QString& key, bool global = false,
                           bool force = false);
    Q_INVOKABLE void clearKey(int row, bool global = false);
    /// restore the default binding of row (same conflict handling as setKey)
    Q_INVOKABLE int resetKey(int row, bool global = false, bool force = false);
    /// restore every default binding
    Q_INVOKABLE void resetAll();
    /// re-read every binding from the configuration
    Q_INVOKABLE void reload();

    /**
     * VLC key name for a QML key event (KeyEvent.key, KeyEvent.modifiers),
     * eg. "Ctrl+Shift+a". Returns an empty string for modifier-only keys.
     */
    Q_INVOKABLE QString keyFromEvent(int key, int modifiers) const;
    /// translated text of a raw binding ("Ctrl+a\tSpace" -> "Ctrl+A, Space")
    Q_INVOKABLE QString keyText(const QString& keys) const;

signals:
    void countChanged();
    /// emitted after a binding was changed through this model
    void edited();

private:
    struct Binding
    {
        QString name;      // config name, empty if none
        QString keys;      // '\t' separated
        QString defaults;
    };
    struct Item
    {
        QString text;
        QString longText;
        Binding normal;
        Binding global;
    };

    Binding& binding(int row, bool global);
    const Binding& binding(int row, bool global) const;
    void store(int row, bool global, const QString& keys);
    void removeKeyFromOthers(int row, const QString& key, bool global);
    void load();

    QVector<Item> m_items;
};

#endif // QT_SETTINGS_HOTKEYS_MODEL_HPP
