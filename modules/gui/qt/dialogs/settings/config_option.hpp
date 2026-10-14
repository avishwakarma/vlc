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
#ifndef QT_SETTINGS_CONFIG_OPTION_HPP
#define QT_SETTINGS_CONFIG_OPTION_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QObject>
#include <QVariant>
#include <QVariantList>
#include <QString>

/**
 * ConfigOption exposes a single VLC configuration item (see vlcrc) to QML.
 *
 * The metadata (text, type, range, default value) comes from the
 * module_config_t returned by config_FindConfig(). The value is read with
 * config_Get{Int,Float,Psz}() and written with config_Put{Int,Float,Psz}():
 * a write is applied to the running configuration immediately; persisting it
 * to the configuration file is done by SettingsModel (debounced).
 *
 * Options that do not exist in this build or platform are still returned,
 * with available == false, so that QML can hide the row.
 *
 * Subclasses implement "virtual" options that are not backed by a single
 * VLC option (theme, accent colour, audio device, ...), see virtual_options.hpp.
 */
class ConfigOption : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString name READ name CONSTANT FINAL)
    Q_PROPERTY(Type type READ type CONSTANT FINAL)
    Q_PROPERTY(QString text READ text CONSTANT FINAL)
    Q_PROPERTY(QString longText READ longText CONSTANT FINAL)

    Q_PROPERTY(QVariant value READ value WRITE setValue NOTIFY valueChanged FINAL)
    Q_PROPERTY(QVariant defaultValue READ defaultValue NOTIFY defaultValueChanged FINAL)
    Q_PROPERTY(bool modified READ modified NOTIFY valueChanged FINAL)

    // range, only meaningful for Int and Float (hasRange == false otherwise)
    Q_PROPERTY(QVariant min READ min CONSTANT FINAL)
    Q_PROPERTY(QVariant max READ max CONSTANT FINAL)
    Q_PROPERTY(bool hasRange READ hasRange CONSTANT FINAL)

    // list of { value, text } maps; empty if the option is free-form
    Q_PROPERTY(QVariantList choices READ choices NOTIFY choicesChanged FINAL)
    // index of value in choices, -1 if none matches; writable
    Q_PROPERTY(int currentIndex READ currentIndex WRITE setCurrentIndex NOTIFY currentIndexChanged FINAL)

    Q_PROPERTY(bool available READ available NOTIFY availableChanged FINAL)
    Q_PROPERTY(bool requiresRestart READ requiresRestart CONSTANT FINAL)
    Q_PROPERTY(bool isVirtual READ isVirtual CONSTANT FINAL)
    // true for File options that pick a file to write (CONFIG_ITEM_SAVEFILE)
    Q_PROPERTY(bool saveFile READ saveFile CONSTANT FINAL)
    // auxiliary model, only used by some virtual options (mlFolders)
    Q_PROPERTY(QObject* model READ model CONSTANT FINAL)

public:
    enum Type
    {
        Unknown,
        Bool,       // value: bool
        Int,        // value: integer (qint64)
        Float,      // value: double
        String,     // value: string
        Module,     // value: string, module name ("any"/"none"/"" are special)
        ModuleList, // value: string, ':' separated module names
        Key,        // value: string, '\t' separated VLC key names
        Color,      // value: string "#RRGGBB"
        File,       // value: string, path
        Directory,  // value: string, path
        Font,       // value: string, font family
        Password,   // value: string
        FolderList, // virtual only: no value, see model
    };
    Q_ENUM(Type)

    /// wraps the VLC configuration item `name`
    explicit ConfigOption(const QString& name, QObject* parent = nullptr);
    ~ConfigOption() override;

    QString name() const { return m_name; }
    Type type() const { return m_type; }
    QString text() const { return m_text; }
    QString longText() const { return m_longText; }

    QVariant value() const { return m_value; }
    void setValue(const QVariant& value);

    QVariant defaultValue() const { return m_default; }
    bool modified() const;

    QVariant min() const { return m_min; }
    QVariant max() const { return m_max; }
    bool hasRange() const { return m_hasRange; }

    QVariantList choices();

    int currentIndex();
    void setCurrentIndex(int index);

    bool available() const { return m_available; }
    bool requiresRestart() const { return m_requiresRestart; }
    bool isVirtual() const { return m_virtual; }
    bool saveFile() const { return m_saveFile; }
    virtual QObject* model() const { return nullptr; }

    /// set the option back to its default value
    Q_INVOKABLE void reset();

    /// re-read the value (and availability) from the configuration,
    /// emits the change signals if needed. Does not emit edited().
    Q_INVOKABLE virtual void refresh();

    /// rebuild the list of choices (eg. after a module was loaded)
    Q_INVOKABLE void reloadChoices();

    /// ModuleList helpers, operate on the ':' separated value
    Q_INVOKABLE bool hasListItem(const QString& item) const;
    Q_INVOKABLE void setListItem(const QString& item, bool enabled);

    /// returns the "text" of the choice matching value (or value as a string)
    Q_INVOKABLE QString textForValue(const QVariant& value);

    /// whether this option is known to be read only once at startup
    static bool isRestartOption(const QString& name);

signals:
    void valueChanged();
    void defaultValueChanged();
    void choicesChanged();
    void currentIndexChanged();
    void availableChanged();

    /// emitted after the value was changed through setValue()/reset(), not
    /// when it changes because of refresh(). SettingsModel listens to it to
    /// save the configuration.
    void edited();

protected:
    /// constructor for virtual options
    ConfigOption(const QString& name, Type type, const QString& text,
                 const QString& longText, QObject* parent);

    // hooks, the default implementation uses the VLC option m_name
    virtual QVariant readValue() const;
    virtual void writeValue(const QVariant& value);
    virtual QVariantList buildChoices();
    virtual bool readAvailable() const;

    /// convert any input (string, number, colour...) to the value type
    QVariant normalize(const QVariant& value) const;
    static bool sameValue(Type type, const QVariant& a, const QVariant& b);

    void setDefaultValue(const QVariant& value);
    void setAvailable(bool available);
    void setRequiresRestart(bool restart) { m_requiresRestart = restart; }
    void setRange(const QVariant& min, const QVariant& max);
    /// invalidate cached choices and emit choicesChanged
    void invalidateChoices();

    static QVariantMap makeChoice(const QVariant& value, const QString& text);

private:
    QVariantList moduleCatChoices(int subcategory) const;
    QVariantList moduleListChoices(bool byCategory, int subcategory,
                                   const QString& capability) const;

    QString m_name;
    Type m_type = Unknown;
    int m_vlcType = 0; // CONFIG_ITEM_*, 0 for virtual options
    QString m_text;
    QString m_longText;
    QVariant m_value;
    QVariant m_default;
    QVariant m_min;
    QVariant m_max;
    bool m_hasRange = false;
    QVariantList m_choices;
    bool m_choicesLoaded = false;
    bool m_available = false;
    bool m_requiresRestart = false;
    bool m_virtual = false;
    bool m_saveFile = false;
};

#endif // QT_SETTINGS_CONFIG_OPTION_HPP
