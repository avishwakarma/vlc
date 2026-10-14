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

#include "effects_controller.hpp"

#include "maininterface/mainctx.hpp"
#include "player/player_controller.hpp"

#include "../../../../audio_filter/equalizer_presets.h"

#include <vlc_configuration.h>
#include <vlc_variables.h>
#include <vlc_player.h>
#include <vlc_interface.h>
#include <vlc_modules.h>

#undef THEMIM
#define THEMIM m_intf->p_mainPlayerController

#include <QLocale>
#include <QSettings>
#include <cmath>

namespace {

QString cstr(char* s)
{
    QString r = s ? QString::fromUtf8(s) : QString();
    free(s);
    return r;
}

QString joinBands(const QStringList& l) { return l.join(' '); }

QString formatBand(double v)
{
    return QLocale::c().toString(v, 'f', 1);
}

} // namespace

/* ---------------------------------------------------------------------- */
/* EffectParam                                                            */
/* ---------------------------------------------------------------------- */

EffectParam::EffectParam(FilterEffect* effect, Kind kind, const QString& name, const QString& label,
                         qreal from, qreal to, qreal neutral)
    : QObject(effect)
    , m_effect(effect)
    , m_kind(kind)
    , m_name(name)
    , m_label(label)
    , m_from(from)
    , m_to(to)
    , m_neutral(neutral)
    , m_value(neutral)
{
    if (kind == Bool)
        m_neutral = m_value = (neutral != 0);
    else if (kind == Int || kind == Color || kind == Crop)
        m_neutral = m_value = int(neutral);
    if (kind == Int || kind == Crop)
        m_step = 1;
}

void EffectParam::setSilently(const QVariant& v)
{
    QVariant n;
    switch (m_kind) {
    case Bool: n = v.toBool(); break;
    case Int: case Color: case Crop: n = v.toInt(); break;
    case String: n = v.toString(); break;
    default: n = v.toDouble(); break;
    }
    if (n == m_value)
        return;
    m_value = n;
    emit valueChanged();
}

void EffectParam::setValue(const QVariant& v)
{
    QVariant before = m_value;
    setSilently(v);
    if (before == m_value)
        return;
    m_effect->controller()->applyParam(this);
}

void EffectParam::reset()
{
    setValue(m_neutral);
}

void EffectParam::refresh()
{
    setSilently(m_effect->controller()->readParam(this));
}

/* ---------------------------------------------------------------------- */
/* FilterEffect                                                           */
/* ---------------------------------------------------------------------- */

FilterEffect::FilterEffect(EffectsController* controller, Domain domain, const QString& module,
                           bool autoEnable, QObject* parent)
    : QObject(parent)
    , m_controller(controller)
    , m_domain(domain)
    , m_module(module)
    , m_autoEnable(autoEnable)
{
    m_available = module_exists(qtu(module));
}

QString FilterEffect::chainVar() const
{
    if (!m_chainVar.isEmpty())
        return m_chainVar;
    return m_domain == Audio ? QStringLiteral("audio-filter") : QStringLiteral("video-filter");
}

EffectParam* FilterEffect::add(EffectParam* p)
{
    m_params.append(p);
    return p;
}

QVariantList FilterEffect::params() const
{
    QVariantList l;
    for (EffectParam* p : m_params)
        l.append(QVariant::fromValue(p));
    return l;
}

void FilterEffect::setEnabled(bool enable)
{
    if (!m_available || enable == m_enabled)
        return;
    m_enabled = enable;
    m_controller->setFilterEnabled(this, enable);
    emit enabledChanged();
}

void FilterEffect::resetAll()
{
    for (EffectParam* p : m_params)
        p->reset();
}

void FilterEffect::refresh()
{
    for (EffectParam* p : m_params)
        p->refresh();
    const bool on = m_available && m_controller->filterInChain(this);
    if (on != m_enabled) {
        m_enabled = on;
        emit enabledChanged();
    }
    // a filter that is not running shows its neutral values, not the module defaults
    if (m_autoEnable && !on)
        for (EffectParam* p : m_params)
            p->setSilently(p->neutral());
}

void FilterEffect::paramChanged()
{
    if (!m_autoEnable)
        return;
    bool any = false;
    for (EffectParam* p : m_params)
        any = any || p->modified();
    setEnabled(any);
}

/* ---------------------------------------------------------------------- */
/* EffectsController                                                      */
/* ---------------------------------------------------------------------- */

EffectsController::EffectsController(qt_intf_t* intf, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
{
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(600);
    connect(&m_saveTimer, &QTimer::timeout, this, [this] { config_SaveConfigFile(m_intf); });

    using A = FilterEffect::Domain;
    auto audio = [&](const char* m) { return new FilterEffect(this, A::Audio, m, false, this); };
    auto video = [&](const char* m, bool autoEn) { return new FilterEffect(this, A::Video, m, autoEn, this); };
    using K = EffectParam::Kind;

    /* ---- equalizer ---- */
    m_eq = audio("equalizer");
    m_preamp = m_eq->add(new EffectParam(m_eq, K::Float, "equalizer-preamp", qtr("Preamp"), -20, 20, 12.0));
    m_preamp->withUnit(" dB")->withStep(0.1);
    const bool vlcBands = var_InheritBool(m_intf, "equalizer-vlcfreqs");
    static const char* const vlcLabels[10] = { "60 Hz", "170 Hz", "310 Hz", "600 Hz", "1 KHz",
                                               "3 KHz", "6 KHz", "12 KHz", "14 KHz", "16 KHz" };
    static const char* const isoLabels[10] = { "31 Hz", "63 Hz", "125 Hz", "250 Hz", "500 Hz",
                                               "1 KHz", "2 KHz", "4 KHz", "8 KHz", "16 KHz" };
    for (int i = 0; i < 10; ++i) {
        auto* b = m_eq->add(new EffectParam(m_eq, K::Band, "equalizer-bands",
                                            qtr(vlcBands ? vlcLabels[i] : isoLabels[i]), -20, 20, 0.0));
        b->withUnit(" dB")->withStep(0.1)->withBandIndex(i);
        m_bands.append(b);
    }
    m_twoPass = new EffectParam(m_eq, K::Bool, "equalizer-2pass", qtr("2 Pass"), 0, 1, 0);
    m_eq->add(m_twoPass);

    for (int i = 0; i < NB_PRESETS; ++i) {
        QVariantList amps;
        for (int j = 0; j < eqz_preset_10b[i].i_band; ++j)
            amps << double(eqz_preset_10b[i].f_amp[j]);
        m_presets.append(QVariantMap {
            { "name", QString::fromLatin1(preset_list[i]) },
            { "text", qfut(preset_list_text[i]) },
            { "preamp", double(eqz_preset_10b[i].f_preamp) },
            { "amps", amps },
        });
    }

    /* ---- compressor ---- */
    m_compressor = audio("compressor");
    auto cp = [&](const char* n, const QString& l, double a, double b, double d, double step, const char* unit, int ticks = 0) {
        return m_compressor->add((new EffectParam(m_compressor, K::Float, n, l, a, b, d))
                                     ->withStep(step)->withUnit(unit)->withTicks(ticks));
    };
    cp("compressor-rms-peak", qtr("FM5 / Peak"), 0.0, 1.0, 0.0, 0.001, "");
    cp("compressor-attack", qtr("Attack"), 1.5, 400.0, 25.0, 0.1, " ms");
    cp("compressor-release", qtr("Release"), 2.0, 800.0, 100.0, 0.1, " ms");
    cp("compressor-threshold", qtr("Threshold"), -30.0, 0.0, -11.0, 0.01, " dB");
    cp("compressor-ratio", qtr("Ratio"), 1.0, 20.0, 8.0, 0.01, " : 1");
    cp("compressor-knee", qtr("Knee Radius"), 1.0, 10.0, 2.5, 0.01, " dB");
    cp("compressor-makeup-gain", qtr("Makeup Gain"), 0.0, 24.0, 7.0, 0.01, " dB");

    /* ---- spatializer ---- */
    m_spatializer = audio("spatializer");
    auto sp = [&](const char* n, const QString& l, double a, double b, double d) {
        m_spatializer->add((new EffectParam(m_spatializer, K::Float, n, l, a, b, d))
                               ->withStep(0.01)->withMultiplier(10.0)->withTicks(10));
    };
    sp("spatializer-roomsize", qtr("Size"), 0.0, 1.1, 0.85);
    sp("spatializer-width", qtr("Width"), 0.0, 1.0, 1.0);
    sp("spatializer-wet", qtr("Wet"), 0.0, 1.0, 0.4);
    sp("spatializer-dry", qtr("Dry"), 0.0, 1.0, 0.5);
    sp("spatializer-damp", qtr("Damp"), 0.0, 1.0, 0.5);

    /* ---- stereo widener ---- */
    m_widener = audio("stereo_widen");
    auto sw = [&](const char* n, const QString& l, double a, double b, double d, const char* unit, int ticks, double step) {
        m_widener->add((new EffectParam(m_widener, K::Float, n, l, a, b, d))
                           ->withStep(step)->withUnit(unit)->withTicks(ticks));
    };
    sw("stereowiden-delay", qtr("Delay Time"), 1.0, 100.0, 20.0, " ms", 0, 1.0);
    sw("stereowiden-feedback", qtr("Feedback Gain"), 0.0, 0.9, 0.3, " %", 9, 0.01);
    sw("stereowiden-crossfeed", qtr("Crossfeed"), 0.0, 0.8, 0.3, " %", 8, 0.01);
    sw("stereowiden-dry-mix", qtr("Dry Mix"), 0.0, 1.0, 0.8, " %", 10, 0.01);

    /* ---- video: essential ---- */
    m_adjust = video("adjust", true);
    auto adj = [&](const char* n, const QString& l, double a, double b, double d, int ticks) {
        m_adjust->add((new EffectParam(m_adjust, K::Float, n, l, a, b, d))->withStep(0.01)->withTicks(ticks));
    };
    adj("hue", qtr("Hue"), -180.0, 180.0, 0.0, 0);
    adj("brightness", qtr("Brightness"), 0.0, 2.0, 1.0, 0);
    adj("contrast", qtr("Contrast"), 0.0, 2.0, 1.0, 0);
    adj("saturation", qtr("Saturation"), 0.0, 3.0, 1.0, 3);
    adj("gamma", qtr("Gamma"), 0.01, 10.0, 1.0, 10);
    m_sharpen = video("sharpen", true);
    m_sharpen->add((new EffectParam(m_sharpen, K::Float, "sharpen-sigma", qtr("Sharpen Sigma"), 0.0, 2.0, 0.0))
                       ->withStep(0.01)->withTicks(4));
    m_gradfun = video("gradfun", true);
    m_gradfun->add((new EffectParam(m_gradfun, K::Int, "gradfun-radius", qtr("Banding Removal Radius"), 4, 32, 4))
                       ->withTicks(7));
    m_grain = video("grain", true);
    m_grain->add((new EffectParam(m_grain, K::Float, "grain-variance", qtr("Film Grain Variance"), 0.0, 10.0, 0.0))
                     ->withStep(0.1)->withTicks(10));

    /* ---- subtitles: duration factor (sub filter "subsdelay") ---- */
    m_subsDelay = video("subsdelay", true);
    m_subsDelay->setChainVar(QStringLiteral("sub-filter"));
    m_subsDelay->add((new EffectParam(m_subsDelay, K::Float, "subsdelay-factor", qtr("Subtitle Duration Factor"), 0.0, 10.0, 0.0))
                         ->withStep(0.001)->withDecimals(3));

    /* ---- video: flip / rotate ---- */
    m_flip = video("transform", false);
    m_flip->add((new EffectParam(m_flip, K::String, "transform-type", qtr("Flip"), 0, 0, 0))
                    ->withNeutral(QStringLiteral("hflip")));
    m_rotate = video("rotate", true);
    m_rotate->add((new EffectParam(m_rotate, K::Float, "rotate-angle", qtr("Rotate"), 0, 359, 0))
                      ->withStep(1)->withDecimals(0)->withUnit(" deg"));

    /* ---- video: crop (live only, on the vout) ---- */
    m_cropEffect = video("crop", false);
    for (auto c : { std::pair<const char*, QString>{ "crop-top", qtr("Top") },
                    { "crop-bottom", qtr("Bottom") },
                    { "crop-left", qtr("Left") },
                    { "crop-right", qtr("Right") } }) {
        auto* p = m_cropEffect->add(new EffectParam(m_cropEffect, K::Crop, c.first, c.second, 0, 100000, 0));
        p->withUnit(" px");
        m_crop.append(p);
    }

    /* ---- video: colours ---- */
    m_extract = video("extract", false);
    m_extract->add(new EffectParam(m_extract, K::Color, "extract-component", qtr("Color Extraction"), 1, 0xFFFFFF, 0xFF0000));
    m_colorthres = video("colorthres", false);
    m_colorthres->add(new EffectParam(m_colorthres, K::Color, "colorthres-color", qtr("Color Threshold"), 0, 0xFFFFFF, 0xFF0000));
    m_colorthres->add((new EffectParam(m_colorthres, K::Int, "colorthres-saturationthres", qtr("Saturation"), 0, 100, 20))
                          ->withTicks(0));
    m_colorthres->add((new EffectParam(m_colorthres, K::Int, "colorthres-similaritythres", qtr("Similarity"), 0, 100, 15))
                          ->withTicks(0));
    m_invert = video("invert", false);
    m_posterize = video("posterize", false);
    m_gradient = video("gradient", false);
    m_gradient->add((new EffectParam(m_gradient, K::String, "gradient-mode", qtr("Gradient"), 0, 0, 0))
                        ->withNeutral(QStringLiteral("gradient"))
                        ->withChoices({ QVariantMap{ { "value", "gradient" }, { "text", qtr("Gradient") } },
                                        QVariantMap{ { "value", "edge" }, { "text", qtr("Edge") } },
                                        QVariantMap{ { "value", "hough" }, { "text", qtr("Hough") } } }));
    m_gradient->add(new EffectParam(m_gradient, K::Bool, "gradient-color", qtr("Color"), 0, 1, 0));
    m_gradient->add(new EffectParam(m_gradient, K::Bool, "gradient-cartoon", qtr("Cartoon"), 0, 1, 1));
    m_sepia = video("sepia", true);
    m_sepia->add((new EffectParam(m_sepia, K::Int, "sepia-intensity", qtr("Sepia Intensity"), 0, 255, 0))
                     ->withTicks(3));

    m_all = { m_eq, m_compressor, m_spatializer, m_widener, m_subsDelay, m_flip, m_rotate, m_adjust,
              m_sharpen, m_gradfun, m_grain, m_extract, m_colorthres, m_invert, m_posterize,
              m_gradient, m_sepia };

    m_activePreset = m_intf->mainSettings->value("EffectPresets/active", QString()).toString();

    refresh();
}

QVariantList EffectsController::bands() const
{
    QVariantList l;
    for (EffectParam* p : m_bands)
        l.append(QVariant::fromValue(p));
    return l;
}

QVariantList EffectsController::essential() const
{
    QVariantList l;
    for (FilterEffect* e : { m_adjust, m_sharpen, m_gradfun, m_grain })
        for (EffectParam* p : e->list())
            l.append(QVariant::fromValue(p));
    return l;
}

QVariantList EffectsController::crop() const
{
    QVariantList l;
    for (EffectParam* p : m_crop)
        l.append(QVariant::fromValue(p));
    return l;
}

void EffectsController::scheduleSave()
{
    m_saveTimer.start();
}

/* the string of the equalizer bands, as VLC would use it now */
QStringList EffectsController::currentBands() const
{
    QString str;
    auto aout = THEMIM->getAout();
    if (aout && var_Type(aout.get(), "equalizer-bands") == VLC_VAR_STRING)
        str = cstr(var_GetString(aout.get(), "equalizer-bands"));
    if (str.trimmed().isEmpty() && config_FindConfig("equalizer-bands"))
        str = cstr(config_GetPsz("equalizer-bands"));
    QStringList l = str.split(' ', Qt::SkipEmptyParts);
    if (l.size() >= 10)
        return l;

    /* no explicit bands: the preset gives them */
    QString preset;
    if (aout && var_Type(aout.get(), "equalizer-preset") == VLC_VAR_STRING)
        preset = cstr(var_GetString(aout.get(), "equalizer-preset"));
    if (preset.isEmpty())
        preset = cstr(config_GetPsz("equalizer-preset"));
    l.clear();
    for (int i = 0; i < 10; ++i)
        l << QStringLiteral("0.0");
    for (int i = 0; i < NB_PRESETS; ++i) {
        if (preset.compare(QLatin1String(preset_list[i]), Qt::CaseInsensitive) == 0) {
            for (int j = 0; j < 10 && j < eqz_preset_10b[i].i_band; ++j)
                l[j] = formatBand(eqz_preset_10b[i].f_amp[j]);
            break;
        }
    }
    return l;
}

QVariant EffectsController::readParam(EffectParam* p) const
{
    using K = EffectParam::Kind;
    const std::string name = p->name().toStdString();
    const char* n = name.c_str();

    if (p->kind() == K::Band) {
        const QStringList l = currentBands();
        const int i = p->bandIndex();
        return i < l.size() ? QVariant(QLocale::c().toDouble(l[i])) : p->neutral();
    }

    vlc_object_t* obj = nullptr;
    audio_output_t* aout = nullptr;
    vout_thread_t* vout = nullptr;
    auto sharedAout = THEMIM->getAout();
    auto sharedVout = THEMIM->getVout();
    if (p->effect()->domain() == FilterEffect::Audio) {
        aout = sharedAout.get();
        obj = VLC_OBJECT(aout);
    } else {
        vout = sharedVout.get();
        obj = VLC_OBJECT(vout);
    }
    const bool live = obj && var_Type(obj, n) != 0;
    const bool cfg = config_FindConfig(n) != nullptr;

    switch (p->kind()) {
    case K::Float:
        if (live) return double(var_GetFloat(obj, n));
        if (cfg) return double(config_GetFloat(n));
        break;
    case K::Int: case K::Color:
        if (live) return int(var_GetInteger(obj, n));
        if (cfg) return int(config_GetInt(n));
        break;
    case K::Crop:
        if (live) return int(var_GetInteger(obj, n));
        return 0;
    case K::Bool:
        if (live) return bool(var_GetBool(obj, n));
        if (cfg) return config_GetInt(n) != 0;
        break;
    case K::String:
        if (live) return cstr(var_GetString(obj, n));
        if (cfg) return cstr(config_GetPsz(n));
        break;
    default: break;
    }
    return p->neutral();
}

void EffectsController::applyBands()
{
    QStringList l;
    for (EffectParam* b : m_bands)
        l << formatBand(b->value().toDouble());
    const QString str = joinBands(l);
    auto aout = THEMIM->getAout();
    if (aout && var_Type(aout.get(), "equalizer-bands") == VLC_VAR_STRING)
        var_SetString(aout.get(), "equalizer-bands", qtu(str));
    config_PutPsz("equalizer-bands", qtu(str));
    scheduleSave();
    updatePreset();
}

void EffectsController::updatePreset()
{
    QString match;
    for (int i = 0; i < NB_PRESETS && match.isEmpty(); ++i) {
        if (std::fabs(eqz_preset_10b[i].f_preamp - m_preamp->value().toDouble()) > 0.05)
            continue;
        bool same = true;
        for (int j = 0; j < 10 && same; ++j)
            same = std::fabs(eqz_preset_10b[i].f_amp[j] - m_bands[j]->value().toDouble()) < 0.05;
        if (same)
            match = QString::fromLatin1(preset_list[i]);
    }
    if (match != m_preset) {
        m_preset = match;
        emit presetChanged();
    }
}

void EffectsController::applyPreset(const QString& name)
{
    int idx = -1;
    for (int i = 0; i < NB_PRESETS; ++i)
        if (name == QLatin1String(preset_list[i]))
            idx = i;
    if (idx < 0)
        return;

    m_updating = true;
    m_preamp->setSilently(double(eqz_preset_10b[idx].f_preamp));
    for (int i = 0; i < 10 && i < eqz_preset_10b[idx].i_band; ++i)
        m_bands[i]->setSilently(double(eqz_preset_10b[idx].f_amp[i]));
    m_updating = false;

    /* the equalizer module loads the bands and the preamp when the preset
     * variable changes (PresetCallback) */
    auto aout = THEMIM->getAout();
    if (aout && var_Type(aout.get(), "equalizer-preset") == VLC_VAR_STRING)
        var_SetString(aout.get(), "equalizer-preset", preset_list[idx]);
    config_PutPsz("equalizer-preset", preset_list[idx]);
    config_PutFloat("equalizer-preamp", eqz_preset_10b[idx].f_preamp);
    applyBands();
}

void EffectsController::resetEqualizer()
{
    applyPreset(QStringLiteral("flat"));
}

void EffectsController::applyCrop(EffectParam* changed)
{
    auto set = [&](EffectParam* p, int v) {
        for (auto vout : THEMIM->getVouts())
            var_SetInteger(vout.get(), qtu(p->name()), v);
    };
    // order: top, bottom, left, right
    if (changed == m_crop[0] && m_linkV) { m_crop[1]->setSilently(changed->value()); set(m_crop[1], changed->value().toInt()); }
    if (changed == m_crop[1] && m_linkV) { m_crop[0]->setSilently(changed->value()); set(m_crop[0], changed->value().toInt()); }
    if (changed == m_crop[2] && m_linkH) { m_crop[3]->setSilently(changed->value()); set(m_crop[3], changed->value().toInt()); }
    if (changed == m_crop[3] && m_linkH) { m_crop[2]->setSilently(changed->value()); set(m_crop[2], changed->value().toInt()); }
    set(changed, changed->value().toInt());
}

void EffectsController::setCropLinkVertical(bool b)
{
    if (b == m_linkV) return;
    m_linkV = b;
    if (b) m_crop[1]->setValue(m_crop[0]->value());
    emit cropLinkChanged();
}

void EffectsController::setCropLinkHorizontal(bool b)
{
    if (b == m_linkH) return;
    m_linkH = b;
    if (b) m_crop[3]->setValue(m_crop[2]->value());
    emit cropLinkChanged();
}

void EffectsController::resetCrop()
{
    for (EffectParam* p : m_crop)
        p->reset();
}

void EffectsController::applyParam(EffectParam* p)
{
    using K = EffectParam::Kind;
    if (m_updating)
        return;

    if (p->kind() == K::Band) {
        applyBands();
        return;
    }
    if (p->kind() == K::Crop) {
        applyCrop(p);
        return;
    }

    const std::string name = p->name().toStdString();
    const char* n = name.c_str();
    const QVariant v = p->value();

    vlc_object_t* obj = nullptr;
    auto sharedAout = THEMIM->getAout();
    auto sharedVout = THEMIM->getVout();
    if (p->effect()->domain() == FilterEffect::Audio)
        obj = sharedAout ? VLC_OBJECT(sharedAout.get()) : nullptr;
    else
        obj = sharedVout ? VLC_OBJECT(sharedVout.get()) : nullptr;
    const bool live = obj && var_Type(obj, n) != 0;
    const bool cfg = config_FindConfig(n) != nullptr;

    switch (p->kind()) {
    case K::Float:
        if (live) var_SetFloat(obj, n, v.toFloat());
        if (cfg) config_PutFloat(n, v.toFloat());
        break;
    case K::Int: case K::Color:
        if (live) var_SetInteger(obj, n, v.toInt());
        if (cfg) config_PutInt(n, v.toInt());
        break;
    case K::Bool:
        if (live) var_SetBool(obj, n, v.toBool());
        if (cfg) config_PutInt(n, v.toBool() ? 1 : 0);
        break;
    case K::String: {
        const std::string s = v.toString().toStdString();
        if (live) var_SetString(obj, n, s.c_str());
        if (cfg) config_PutPsz(n, s.c_str());
        break;
    }
    default: break;
    }
    msg_Dbg(m_intf, "effects: %s = %s (%s)", n, qtu(v.toString()), live ? "live" : "config only");
    scheduleSave();

    if (p == m_preamp)
        updatePreset();
    p->effect()->paramChanged();
}

bool EffectsController::filterInChain(FilterEffect* e) const
{
    QString chain;
    const std::string cv = e->chainVar().toStdString();
    if (e->domain() == FilterEffect::Audio) {
        auto aout = THEMIM->getAout();
        if (aout)
            chain = cstr(var_GetNonEmptyString(aout.get(), "audio-filter"));
        else
            chain = cstr(config_GetPsz("audio-filter"));
    } else {
        auto vout = THEMIM->getVout();
        if (vout)
            chain = cstr(var_GetNonEmptyString(vout.get(), cv.c_str()));
        else
            chain = cstr(config_GetPsz(cv.c_str()));
    }
    return chain.split(':', Qt::SkipEmptyParts).contains(e->module());
}

void EffectsController::setFilterEnabled(FilterEffect* e, bool enable)
{
    const std::string varName = e->chainVar().toStdString();
    const char* var = varName.c_str();
    const std::string module = e->module().toStdString();

    /* configuration chain (persisted) */
    QStringList cfgChain = cstr(config_GetPsz(var)).split(':', Qt::SkipEmptyParts);
    if (enable && !cfgChain.contains(e->module()))
        cfgChain << e->module();
    else if (!enable)
        cfgChain.removeAll(e->module());
    config_PutPsz(var, qtu(cfgChain.join(':')));
    scheduleSave();

    if (e->domain() == FilterEffect::Audio) {
        vlc_player_aout_EnableFilter(m_intf->p_player, module.c_str(), enable);
        msg_Dbg(m_intf, "effects: audio filter %s %s", module.c_str(), enable ? "enabled" : "disabled");
    } else if (auto vout = THEMIM->getVout()) {
        /* live chain of the vout (ExtVideo::changeVFiltersString) */
        QStringList chain = cstr(var_GetNonEmptyString(vout.get(), var)).split(':', Qt::SkipEmptyParts);
        if (enable && !chain.contains(e->module()))
            chain << e->module();
        else if (!enable)
            chain.removeAll(e->module());
        var_SetString(vout.get(), var, qtu(chain.join(':')));
        msg_Dbg(m_intf, "effects: video-filter = %s", qtu(chain.join(':')));
    }
}

void EffectsController::refresh()
{
    m_updating = true;
    for (FilterEffect* e : m_all)
        e->refresh();
    for (EffectParam* p : m_crop)
        p->refresh();
    m_updating = false;
    updatePreset();
}

/* ---------------------------------------------------------------------- */
/* saved presets                                                          */
/* ---------------------------------------------------------------------- */

QStringList EffectsController::presetNames() const
{
    QSettings* st = m_intf->mainSettings;
    st->beginGroup("EffectPresets");
    st->beginGroup("sets");
    const QStringList names = st->childGroups();
    st->endGroup();
    st->endGroup();
    return names;
}

QVariantList EffectsController::presetList() const
{
    QVariantList l;
    l.append(QVariantMap { { "name", QString() }, { "text", qtr("Default Preset") }, { "custom", false }, { "dim", false } });
    for (const QString& n : presetNames())
        l.append(QVariantMap { { "name", n }, { "text", n }, { "custom", true }, { "dim", false } });
    return l;
}

void EffectsController::loadSettingsPreset(const QString& name)
{
    QSettings* st = m_intf->mainSettings;
    const bool isDefault = name.isEmpty();
    if (!isDefault)
        st->beginGroup("EffectPresets/sets/" + name);

    for (FilterEffect* e : m_all) {
        for (EffectParam* p : e->list()) {
            QString key = e->module() + "." + p->name();
            if (p->kind() == EffectParam::Band)
                key += "." + QString::number(p->bandIndex());
            QVariant v = isDefault ? p->neutral() : st->value(key, p->neutral());
            p->setValue(v);
        }
        const bool on = isDefault ? false : st->value(e->module() + ".enabled", false).toBool();
        if (!e->autoEnable())
            e->setEnabled(on);
    }
    if (!isDefault)
        st->endGroup();
    if (isDefault)
        applyPreset(QStringLiteral("flat")); // equalizer back to its default curve

    m_activePreset = name;
    st->setValue("EffectPresets/active", name);
    emit activePresetChanged();
}

QString EffectsController::saveSettingsPreset()
{
    const QStringList names = presetNames();
    int n = 1;
    QString name;
    do {
        name = qtr("Custom Preset %1").arg(n++, 2, 10, QLatin1Char('0'));
    } while (names.contains(name));

    QSettings* st = m_intf->mainSettings;
    st->beginGroup("EffectPresets/sets/" + name);
    for (FilterEffect* e : m_all) {
        for (EffectParam* p : e->list()) {
            QString key = e->module() + "." + p->name();
            if (p->kind() == EffectParam::Band)
                key += "." + QString::number(p->bandIndex());
            st->setValue(key, p->value());
        }
        st->setValue(e->module() + ".enabled", e->enabled());
    }
    st->endGroup();

    m_activePreset = name;
    st->setValue("EffectPresets/active", name);
    emit presetListChanged();
    emit activePresetChanged();
    return name;
}

void EffectsController::deleteSettingsPreset(const QString& name)
{
    QSettings* st = m_intf->mainSettings;
    st->remove("EffectPresets/sets/" + name);
    if (m_activePreset == name) {
        m_activePreset.clear();
        st->setValue("EffectPresets/active", QString());
        emit activePresetChanged();
    }
    emit presetListChanged();
}
