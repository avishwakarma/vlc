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
#ifndef EFFECTS_CONTROLLER_HPP
#define EFFECTS_CONTROLLER_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QObject>
#include <QTimer>
#include <QVariant>
#include <QVariantList>
#include <QString>
#include <QList>

#include "qt.hpp"

class EffectsController;
class FilterEffect;

/**
 * One adjustable value of an audio / video effect (slider, toggle, colour,
 * choice). A change is applied live to the playing aout / vout (when the
 * variable exists there) and written to the configuration, which is saved
 * shortly after (debounced), like the "Apply" of the QWidget extended panel.
 */
class EffectParam : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString name READ name CONSTANT FINAL)
    Q_PROPERTY(QString label READ label CONSTANT FINAL)
    Q_PROPERTY(QString unit READ unit CONSTANT FINAL)
    Q_PROPERTY(Kind kind READ kind CONSTANT FINAL)
    Q_PROPERTY(qreal from READ from CONSTANT FINAL)
    Q_PROPERTY(qreal to READ to CONSTANT FINAL)
    Q_PROPERTY(qreal stepSize READ stepSize CONSTANT FINAL)
    Q_PROPERTY(qreal displayMultiplier READ displayMultiplier CONSTANT FINAL)
    Q_PROPERTY(int decimals READ decimals CONSTANT FINAL)
    Q_PROPERTY(int ticks READ ticks CONSTANT FINAL)
    Q_PROPERTY(QVariant neutral READ neutral CONSTANT FINAL)
    Q_PROPERTY(QVariant value READ value WRITE setValue NOTIFY valueChanged FINAL)
    Q_PROPERTY(bool modified READ modified NOTIFY valueChanged FINAL)
    Q_PROPERTY(QVariantList choices READ choices CONSTANT FINAL)

public:
    enum Kind { Float, Int, Bool, String, Color, Band, Crop };
    Q_ENUM(Kind)

    EffectParam(FilterEffect* effect, Kind kind, const QString& name, const QString& label,
                qreal from, qreal to, qreal neutral);

    QString name() const { return m_name; }
    QString label() const { return m_label; }
    QString unit() const { return m_unit; }
    Kind kind() const { return m_kind; }
    qreal from() const { return m_from; }
    qreal to() const { return m_to; }
    qreal stepSize() const { return m_step; }
    qreal displayMultiplier() const { return m_mult; }
    int decimals() const { return m_decimals; }
    int ticks() const { return m_ticks; }
    QVariant neutral() const { return m_neutral; }
    QVariant value() const { return m_value; }
    bool modified() const { return m_value != m_neutral; }
    QVariantList choices() const { return m_choices; }

    void setValue(const QVariant& v);
    Q_INVOKABLE void reset();

    // builder style helpers
    EffectParam* withUnit(const QString& u) { m_unit = u; return this; }
    EffectParam* withStep(qreal s) { m_step = s; return this; }
    EffectParam* withMultiplier(qreal m) { m_mult = m; return this; }
    EffectParam* withDecimals(int d) { m_decimals = d; return this; }
    EffectParam* withTicks(int t) { m_ticks = t; return this; }
    EffectParam* withChoices(const QVariantList& c) { m_choices = c; return this; }
    EffectParam* withBandIndex(int i) { m_bandIndex = i; return this; }
    EffectParam* withNeutral(const QVariant& n) { m_neutral = m_value = n; return this; }
    EffectParam* withConfigName(const QString& n) { m_name = n; return this; }

    int bandIndex() const { return m_bandIndex; }
    FilterEffect* effect() const { return m_effect; }

    /// re-read the value from the aout/vout variable or the configuration
    void refresh();
    /// store a value without applying it
    void setSilently(const QVariant& v);

signals:
    void valueChanged();

private:
    FilterEffect* m_effect;
    Kind m_kind;
    QString m_name, m_label, m_unit;
    qreal m_from, m_to, m_step = 0.01, m_mult = 1.0;
    int m_decimals = 1, m_ticks = 0, m_bandIndex = -1;
    QVariant m_neutral, m_value;
    QVariantList m_choices;
};

/**
 * A filter module (equalizer, adjust, ...) with its parameters. Audio filters
 * are switched with vlc_player_aout_EnableFilter(), video filters through the
 * "video-filter" chain of the vout (ExtVideo::changeVFiltersString).
 * With autoEnable the filter is on exactly while a parameter differs from its
 * neutral value (the video sliders have no switch in the design).
 */
class FilterEffect : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString module READ module CONSTANT FINAL)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged FINAL)
    Q_PROPERTY(bool available READ available CONSTANT FINAL)
    Q_PROPERTY(QVariantList params READ params CONSTANT FINAL)

public:
    enum Domain { Audio, Video };

    FilterEffect(EffectsController* controller, Domain domain, const QString& module,
                 bool autoEnable, QObject* parent);

    QString module() const { return m_module; }
    /// the variable holding the filter chain ("audio-filter", "video-filter", "sub-filter")
    QString chainVar() const;
    void setChainVar(const QString& v) { m_chainVar = v; }
    Domain domain() const { return m_domain; }
    bool enabled() const { return m_enabled; }
    bool available() const { return m_available; }
    QVariantList params() const;
    bool autoEnable() const { return m_autoEnable; }
    EffectsController* controller() const { return m_controller; }

    void setEnabled(bool enable);
    EffectParam* add(EffectParam* p);
    const QList<EffectParam*>& list() const { return m_params; }

    Q_INVOKABLE void resetAll();
    void refresh();
    /// called after a parameter changed (auto enable)
    void paramChanged();

signals:
    void enabledChanged();

private:
    EffectsController* m_controller;
    Domain m_domain;
    QString m_module;
    QString m_chainVar;
    bool m_autoEnable;
    bool m_enabled = false;
    bool m_available = false;
    QList<EffectParam*> m_params;
};

class EffectsController : public QObject
{
    Q_OBJECT

    // audio
    Q_PROPERTY(FilterEffect* equalizer READ equalizer CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* compressor READ compressor CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* spatializer READ spatializer CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* stereoWidener READ stereoWidener CONSTANT FINAL)
    Q_PROPERTY(EffectParam* preamp READ preamp CONSTANT FINAL)
    Q_PROPERTY(QVariantList bands READ bands CONSTANT FINAL)
    Q_PROPERTY(EffectParam* twoPass READ twoPass CONSTANT FINAL)
    Q_PROPERTY(QVariantList presets READ presets CONSTANT FINAL)
    // name of the preset matching the current bands, "" when custom
    Q_PROPERTY(QString preset READ preset NOTIFY presetChanged FINAL)

    // video
    Q_PROPERTY(QVariantList essential READ essential CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* adjust READ adjust CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* subsDelay READ subsDelay CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* flip READ flip CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* rotate READ rotate CONSTANT FINAL)
    Q_PROPERTY(QVariantList crop READ crop CONSTANT FINAL)
    Q_PROPERTY(bool cropLinkVertical READ cropLinkVertical WRITE setCropLinkVertical NOTIFY cropLinkChanged FINAL)
    Q_PROPERTY(bool cropLinkHorizontal READ cropLinkHorizontal WRITE setCropLinkHorizontal NOTIFY cropLinkChanged FINAL)
    Q_PROPERTY(FilterEffect* extract READ extract CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* colorThreshold READ colorThreshold CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* invert READ invert CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* posterize READ posterize CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* gradient READ gradient CONSTANT FINAL)
    Q_PROPERTY(FilterEffect* sepia READ sepia CONSTANT FINAL)
    // saved sets of all the effect settings (Figma 2372:8834)
    Q_PROPERTY(QVariantList presetList READ presetList NOTIFY presetListChanged FINAL)
    Q_PROPERTY(QString activePreset READ activePreset NOTIFY activePresetChanged FINAL)
    // tone mapping is read once when the vout opens (core job), see HdrButton
    Q_PROPERTY(bool hdrAvailable READ hdrAvailable CONSTANT FINAL)

public:
    explicit EffectsController(qt_intf_t* intf, QObject* parent = nullptr);

    FilterEffect* equalizer() const { return m_eq; }
    FilterEffect* compressor() const { return m_compressor; }
    FilterEffect* spatializer() const { return m_spatializer; }
    FilterEffect* stereoWidener() const { return m_widener; }
    EffectParam* preamp() const { return m_preamp; }
    QVariantList bands() const;
    EffectParam* twoPass() const { return m_twoPass; }
    QVariantList presets() const { return m_presets; }
    QString preset() const { return m_preset; }

    QVariantList essential() const;
    FilterEffect* adjust() const { return m_adjust; }
    FilterEffect* subsDelay() const { return m_subsDelay; }
    FilterEffect* flip() const { return m_flip; }
    FilterEffect* rotate() const { return m_rotate; }
    QVariantList crop() const;
    bool cropLinkVertical() const { return m_linkV; }
    bool cropLinkHorizontal() const { return m_linkH; }
    void setCropLinkVertical(bool b);
    void setCropLinkHorizontal(bool b);
    FilterEffect* extract() const { return m_extract; }
    FilterEffect* colorThreshold() const { return m_colorthres; }
    FilterEffect* invert() const { return m_invert; }
    FilterEffect* posterize() const { return m_posterize; }
    FilterEffect* gradient() const { return m_gradient; }
    FilterEffect* sepia() const { return m_sepia; }
    bool hdrAvailable() const { return false; }

    QVariantList presetList() const;
    QString activePreset() const { return m_activePreset; }
    /// loads a saved set ("" = Default Preset: everything back to neutral)
    Q_INVOKABLE void loadSettingsPreset(const QString& name);
    /// stores the current settings under a new "Custom Preset NN" name
    Q_INVOKABLE QString saveSettingsPreset();
    Q_INVOKABLE void deleteSettingsPreset(const QString& name);

    Q_INVOKABLE void applyPreset(const QString& name);
    /// re-read every value from the running aout / vout or the configuration
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void resetEqualizer();
    Q_INVOKABLE void resetCrop();

    // used by EffectParam / FilterEffect
    qt_intf_t* intf() const { return m_intf; }
    bool filterInChain(FilterEffect* effect) const;
    void setFilterEnabled(FilterEffect* effect, bool enable);
    QVariant readParam(EffectParam* p) const;
    void applyParam(EffectParam* p);
    void scheduleSave();

signals:
    void presetChanged();
    void cropLinkChanged();
    void presetListChanged();
    void activePresetChanged();

private:
    void updatePreset();
    void applyBands();
    QStringList currentBands() const;
    void applyCrop(EffectParam* changed);

    qt_intf_t* m_intf;
    QTimer m_saveTimer;
    FilterEffect *m_eq, *m_compressor, *m_spatializer, *m_widener;
    FilterEffect *m_flip, *m_rotate, *m_subsDelay;
    FilterEffect *m_adjust, *m_sharpen, *m_gradfun, *m_grain, *m_cropEffect;
    FilterEffect *m_extract, *m_colorthres, *m_invert, *m_posterize, *m_gradient, *m_sepia;
    EffectParam* m_preamp;
    EffectParam* m_twoPass;
    QList<EffectParam*> m_bands;
    QList<EffectParam*> m_crop;
    QVariantList m_presets;
    QString m_preset;
    bool m_linkV = false, m_linkH = false;
    QList<FilterEffect*> m_all;
    QString m_activePreset;
    bool m_updating = false;
    QStringList presetNames() const;
};

#endif
