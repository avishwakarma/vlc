/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
#include "systempalette.hpp"
#include "util/vlc_menu_style.hpp"
#include <QGuiApplication>
#include <QStyleHints>
#include <QPalette>
#include <QSettings>
#include <QFile>
#include <maininterface/mainctx.hpp>
#include <vlc_modules.h>
#include <vlc_picture.h>

namespace {

QColor setColorAlpha(const QColor& c1, float alpha)
{
    QColor c(c1);
    c.setAlphaF(alpha);
    return c;
}

#ifndef _WIN32
/**
 * function taken from QtBase gui/platform/unix/qgenericunixservices.cpp
 */
static inline QByteArray detectLinuxDesktopEnvironment()
{
    const QByteArray xdgCurrentDesktop = qgetenv("XDG_CURRENT_DESKTOP");
    if (!xdgCurrentDesktop.isEmpty())
        return xdgCurrentDesktop.toUpper(); // KDE, GNOME, UNITY, LXDE, MATE, XFCE...

    // Classic fallbacks
    if (!qEnvironmentVariableIsEmpty("KDE_FULL_SESSION"))
        return QByteArrayLiteral("KDE");
    if (!qEnvironmentVariableIsEmpty("GNOME_DESKTOP_SESSION_ID"))
        return QByteArrayLiteral("GNOME");

    // Fallback to checking $DESKTOP_SESSION (unreliable)
    QByteArray desktopSession = qgetenv("DESKTOP_SESSION");

    // This can be a path in /usr/share/xsessions
    int slash = desktopSession.lastIndexOf('/');
    if (slash != -1) {
        QSettings desktopFile(QFile::decodeName(desktopSession + ".desktop"), QSettings::IniFormat);
        desktopFile.beginGroup(QStringLiteral("Desktop Entry"));
        QByteArray desktopName = desktopFile.value(QStringLiteral("DesktopNames")).toByteArray();
        if (!desktopName.isEmpty())
            return desktopName;

        // try decoding just the basename
        desktopSession = desktopSession.mid(slash + 1);
    }

    if (desktopSession == "gnome")
        return QByteArrayLiteral("GNOME");
    else if (desktopSession == "xfce")
        return QByteArrayLiteral("XFCE");
    else if (desktopSession == "kde")
        return QByteArrayLiteral("KDE");

    return QByteArrayLiteral("UNKNOWN");
}

bool isGTKBasedEnvironment()
{
    QList<QByteArray> gtkBasedEnvironments{
        "GNOME",
        "X-CINNAMON",
        "UNITY",
        "MATE",
        "XFCE",
        "LXDE"
    };
    const QList<QByteArray> desktopNames = detectLinuxDesktopEnvironment().split(':');
    for (const QByteArray& desktopName: desktopNames)
    {
        if (gtkBasedEnvironments.contains(desktopName))
            return true;
    }
    return false;
}
#endif


static void PaletteChangedCallback(vlc_qt_theme_provider_t*, void* data)
{
    auto priv = static_cast<ExternalPaletteImpl*>(data);
    emit priv->paletteChanged();
}

static void MetricsChangedCallback(vlc_qt_theme_provider_t*, vlc_qt_theme_image_type type, void* data)
{
    auto priv = static_cast<ExternalPaletteImpl*>(data);
    assert(priv);
    priv->updateMetrics(type);
}


static void ReleaseVLCPictureCb(void* data)
{
    auto pic = static_cast<picture_t*>(data);
    if (pic)
        picture_Release(pic);
}


static void setColorRBGAInt(
    vlc_qt_theme_provider_t* obj,
    vlc_qt_theme_color_set set, vlc_qt_theme_color_section section,
    vlc_qt_theme_color_name name, vlc_qt_theme_color_state state,
    int r, int g, int b, int a)
{
    auto palette = static_cast<SystemPalette*>(obj->setColorData);
    QColor color(r,g,b,a);
    palette->setColor(
        static_cast<ColorContext::ColorSet>(set), static_cast<ColorContext::ColorSection>(section),
        static_cast<ColorContext::ColorName>(name), static_cast<ColorContext::ColorState>(state),
        color);
}

static void setColorRBGAFloat(
    vlc_qt_theme_provider_t* obj,
    vlc_qt_theme_color_set set, vlc_qt_theme_color_section section,
    vlc_qt_theme_color_name name, vlc_qt_theme_color_state state,
    double r, double g, double b, double a)
{
    auto palette = static_cast<SystemPalette*>(obj->setColorData);
    QColor color;
    color.setRgbF(r,g,b,a);
    palette->setColor(
        static_cast<ColorContext::ColorSet>(set), static_cast<ColorContext::ColorSection>(section),
        static_cast<ColorContext::ColorName>(name), static_cast<ColorContext::ColorState>(state),
        color);
}

}

//ExternalPaletteImpl

ExternalPaletteImpl::ExternalPaletteImpl(MainCtx* ctx, SystemPalette& palette, QObject* parent)
    : QObject(parent)
    , m_palette(palette)
    , m_ctx(ctx)
{
}

ExternalPaletteImpl::~ExternalPaletteImpl()
{
    if (m_provider)
    {
        if (m_provider->close)
            m_provider->close(m_provider);
        if (m_module)
            module_unneed(m_provider, m_module);
        vlc_object_delete(m_provider);
    }
}

bool ExternalPaletteImpl::init()
{
    QString preferedProvider;
#ifndef _WIN32
    if (isGTKBasedEnvironment())
        preferedProvider = "qt-themeprovider-gtk";
#endif

    m_provider = vlc_object_create<vlc_qt_theme_provider_t>(m_ctx->getIntf());
    if (!m_provider)
        return false;


    m_provider->paletteUpdated = PaletteChangedCallback;
    m_provider->paletteUpdatedData = this;

    m_provider->metricsUpdated = MetricsChangedCallback;
    m_provider->metricsUpdatedData = this;

    m_provider->setColorF = setColorRBGAFloat;
    m_provider->setColorInt = setColorRBGAInt;
    m_provider->setColorData = &m_palette;

    m_module = module_need(m_provider, "qt theme provider",
                           preferedProvider.isNull() ? nullptr : qtu(preferedProvider),
                           true);
    if (!m_module)
        return false;
    return true;
}

bool ExternalPaletteImpl::isThemeDark() const
{
    if (!m_provider->isThemeDark)
        return false;
    return m_provider->isThemeDark(m_provider);
}

bool ExternalPaletteImpl::hasCSDImages() const
{
    if (!m_provider->supportThemeImage)
        return false;
    return m_provider->supportThemeImage(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON);
}


QImage ExternalPaletteImpl::getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight)
{
    if (!m_provider->getThemeImage)
        return {};
    vlc_qt_theme_image_setting imageSettings;
    imageSettings.windowScaleFactor = m_ctx->intfMainWindow()->devicePixelRatio();
    imageSettings.userScaleFacor = m_ctx->getIntfUserScaleFactor();
    imageSettings.u.csdButton.buttonType = type;
    imageSettings.u.csdButton.state = state;
    imageSettings.u.csdButton.maximized = maximized;
    imageSettings.u.csdButton.active = active;
    imageSettings.u.csdButton.bannerHeight = bannerHeight;
    picture_t* pic = m_provider->getThemeImage(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON, &imageSettings);
    if (!pic)
        return {};

    QImage::Format format = QImage::Format_Invalid;
    switch (pic->format.i_chroma)
    {
    case VLC_CODEC_ARGB:
        format = QImage::Format_ARGB32_Premultiplied;
        break;
    case VLC_CODEC_RGBA:
        format = QImage::Format_RGBA8888_Premultiplied;
        break;
    case VLC_CODEC_RGB24:
        format = QImage::Format_RGB888;
        break;
    default:
        msg_Err(m_ctx->getIntf(), "unexpected image format from theme provider");
        break;
    }

    return QImage(pic->p[0].p_pixels,
            pic->format.i_visible_width, pic->format.i_visible_height, pic->p[0].i_pitch,
            format,
            ReleaseVLCPictureCb, pic
            );
}

CSDMetrics* ExternalPaletteImpl::getCSDMetrics() const
{
    return m_csdMetrics.get();
}

int ExternalPaletteImpl::update()
{
    if (m_provider->updatePalette)
        return m_provider->updatePalette(m_provider);
    return VLC_EGENERIC;
}

void ExternalPaletteImpl::updateMetrics(vlc_qt_theme_image_type type)
{
    if (m_provider->getThemeMetrics)
    {
        if (type == VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON)
        {
            m_csdMetrics.reset();
            [&](){
                if (!m_provider->getThemeMetrics)
                    return;
                vlc_qt_theme_metrics metrics;
                memset(&metrics, 0, sizeof(metrics));
                bool ret = m_provider->getThemeMetrics(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON, &metrics);
                if (!ret)
                    return;
                m_csdMetrics = std::make_unique<CSDMetrics>();
                m_csdMetrics->interNavButtonSpacing = metrics.u.csd.interNavButtonSpacing;

                m_csdMetrics->csdFrameMarginLeft = metrics.u.csd.csdFrameMarginLeft;
                m_csdMetrics->csdFrameMarginRight = metrics.u.csd.csdFrameMarginRight;
                m_csdMetrics->csdFrameMarginTop = metrics.u.csd.csdFrameMarginTop;
                m_csdMetrics->csdFrameMarginBottom = metrics.u.csd.csdFrameMarginBottom;
            }();
            emit CSDMetricsChanged();
        }
    }
}

SystemPalette::SystemPalette(QObject* parent)
    : QObject(parent)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    // Auto follows the OS light/dark setting
    if (qGuiApp && qGuiApp->styleHints())
    {
        connect(qGuiApp->styleHints(), &QStyleHints::colorSchemeChanged, this,
                [this]() {
                    if (m_source == ColorSchemeModel::Auto)
                        updatePalette();
                });
    }
#endif
}

void SystemPalette::componentComplete()
{
    updatePalette();
}

ColorSchemeModel::ColorScheme SystemPalette::source() const
{
    return m_source;
}

QImage SystemPalette::getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight)
{
    if (!hasCSDImage())
        return QImage();
    assert(m_palettePriv);
    return m_palettePriv->getCSDImage(type, state, maximized, active, bannerHeight);

}

CSDMetrics* SystemPalette::getCSDMetrics() const
{
    if (!m_palettePriv)
        return nullptr;
    return m_palettePriv->getCSDMetrics();
}

bool SystemPalette::hasCSDImage() const
{
    if (!m_palettePriv)
        return false;
    return m_palettePriv->hasCSDImages();
}

void SystemPalette::setSource(ColorSchemeModel::ColorScheme source)
{
    if (m_source == source)
        return;
    m_source = source;

    updatePalette();
    emit sourceChanged();
}

void SystemPalette::setCtx(MainCtx* ctx)
{
    if (ctx == m_ctx)
        return;
    QObject::disconnect(m_accentConnection);
    m_ctx = ctx;
    if (m_ctx)
        m_accentConnection = connect(m_ctx, &MainCtx::accentColorChanged, this, &SystemPalette::updatePalette);
    emit ctxChanged();
    updatePalette();
}

void SystemPalette::updatePalette()
{
    m_palettePriv.reset();
    switch(m_source)
    {
    case ColorSchemeModel::System:
        makeSystemPalette();
        break;
    case ColorSchemeModel::Day:
        makeLightPalette();
        break;
    case ColorSchemeModel::Night:
        makeDarkPalette();
        break;
    case ColorSchemeModel::Auto:
        if (resolveAutoDark())
            makeDarkPalette();
        else
            makeLightPalette();
        break;
    default:
        break;
    }

    if (m_palettePriv)
    {
        connect(
            m_palettePriv.get(), &ExternalPaletteImpl::paletteChanged,
            this, &SystemPalette::updatePalette);
        connect(
            m_palettePriv.get(), &ExternalPaletteImpl::CSDMetricsChanged,
            this, &SystemPalette::CSDMetricsChanged);
    }
    emit paletteChanged();

    if (objectName() == QLatin1String("themePalette"))
    {
        typedef ColorContext C;
        VLCMenuStyle::Colors colors;
        colors.surface = getColor(C::Menu, C::Bg, C::Primary, C::Normal);
        colors.hover = getColor(C::Menu, C::Bg, C::Primary, C::Hovered);
        colors.text = getColor(C::Menu, C::Fg, C::Primary, C::Normal);
        colors.textHover = getColor(C::Menu, C::Fg, C::Primary, C::Hovered);
        colors.textSecondary = getColor(C::Menu, C::Fg, C::Secondary, C::Normal);
        colors.textDisabled = getColor(C::Menu, C::Fg, C::Primary, C::Disabled);
        colors.separator = getColor(C::Menu, C::Decoration, C::Separator, C::Normal);
        colors.accent = getColor(C::Menu, C::Decoration, C::Accent, C::Normal);
        colors.dlgSurface = getColor(C::View, C::Bg, C::Primary, C::Normal);
        colors.dlgHeader = getColor(C::View, C::Bg, C::Secondary, C::Normal);
        colors.dlgText = getColor(C::View, C::Fg, C::Primary, C::Normal);
        colors.dlgTextSecondary = getColor(C::View, C::Fg, C::Secondary, C::Normal);
        colors.dlgSeparator = getColor(C::View, C::Decoration, C::Separator, C::Normal);
        colors.dlgButton = getColor(C::Window, C::Bg, C::Primary, C::Normal);
        colors.dlgButtonHover = getColor(C::Item, C::Bg, C::Primary, C::Hovered);
        colors.dlgPrimary = getColor(C::ButtonTonal, C::Bg, C::Primary, C::Normal);
        colors.dlgPrimaryHover = getColor(C::ButtonTonal, C::Bg, C::Primary, C::Hovered);
        colors.dlgPrimaryText = getColor(C::ButtonTonal, C::Fg, C::Primary, C::Normal);
        VLCMenuStyle::setColors(colors);
    }

    bool hasCSDImage = m_palettePriv && m_palettePriv->hasCSDImages();
    if (m_hasCSDImage != hasCSDImage)
    {
        m_hasCSDImage = hasCSDImage;
        emit hasCSDImageChanged();
    }
}

static quint64 makeKey(ColorContext::ColorSet colorSet, ColorContext::ColorSection section,
                       ColorContext::ColorName name, ColorContext::ColorState state)
{
    static_assert(VQTC_STATE_COUNT < (1<<4), "");
    static_assert(VQTC_SECTION_COUNT < (1<<4), "");
    static_assert(VQTC_NAME_COUNT < (1<<8), "");
    static_assert(VQTC_SET_COUNT < (1<<16), "");
    return  (colorSet << 16)
        + (name << 8)
        + (section << 4)
        + state;
}

void SystemPalette::setColor(ColorContext::ColorSet colorSet,  ColorContext::ColorSection section,
                             ColorContext::ColorName name, ColorContext::ColorState state, QColor color)
{

    quint64 key = makeKey(colorSet, section, name, state);
    m_colorMap[key] = color;
}


QColor SystemPalette::getColor(ColorContext::ColorSet colorSet, ColorContext::ColorSection section,
                               ColorContext::ColorName name, ColorContext::ColorState state) const
{
    typedef ColorContext C;

    quint64 key = makeKey(colorSet, section, name, state);
    auto it = m_colorMap.find(key);
    if (it != m_colorMap.cend())
        return *it;
    //we don't have the role explicitly set, fallback to the normal state
    key = makeKey(colorSet, section, name, C::Normal);
    it = m_colorMap.find(key);
    if (it != m_colorMap.cend())
        return *it;
    //we don't have the role explicitly set, fallback to the colorSet View
    //TODO do we want finer hierarchy?
    if (colorSet != C::View)
    {
        return getColor(C::View, section, name, state);
    }
    else
    {
        //a Heading that isn't defined by the theme (external providers) is a Primary
        if (name == C::Heading)
            return getColor(colorSet, section, C::Primary, state);
        //nothing matches, that's probably an issue, return an ugly color
        return Qt::magenta;
    }
}


bool SystemPalette::resolveAutoDark() const
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    if (qGuiApp && qGuiApp->styleHints())
        return qGuiApp->styleHints()->colorScheme() != Qt::ColorScheme::Light;
#endif
    return true;
}

void SystemPalette::updateAccent(bool dark)
{
    // preset/user accent, MainCtx resolves "default" and "system"
    QColor base(QStringLiteral("#D37918"));
    if (m_ctx && m_ctx->accentColor().isValid())
        base = m_ctx->accentColor();

    auto blend = [](const QColor& top, const QColor& bottom, qreal alpha) {
        return QColor::fromRgbF(
            top.redF() * alpha + bottom.redF() * (1 - alpha),
            top.greenF() * alpha + bottom.greenF() * (1 - alpha),
            top.blueF() * alpha + bottom.blueF() * (1 - alpha));
    };

    if (dark)
    {
        accentMain = base;
        accentDim = QColor::fromHsvF(base.hsvHueF() < 0 ? 0 : base.hsvHueF(), base.hsvSaturationF(), base.valueF() * 0.81);
        accentBright = blend(base, bgB2, 0.24);
    }
    else
    {
        accentMain = base.lighter(110);
        accentDim = base.darker(115); // derived, see tokens.md
        accentBright = blend(base, bgB2, 0.30);
    }
    accentDark = blend(base, bgB2, 0.08);
    orange500 = accentMain;
    orange800 = accentMain.lighter(150); // legacy
}

void SystemPalette::makeLightPalette()
{
    m_isDark = false;

    // Figma "Light/*" variables
    bgB2 = QColor("#DEDEDE");
    bgB1 = QColor("#E7E7E7");
    bgA3 = QColor("#D5D5D5");
    bgA4 = QColor("#D5D5D5"); // derived
    bgA5 = QColor("#CBCBCB"); // derived (Figma A5 #888888 is not usable as a field background)
    bgA2 = QColor("#CDCDCD"); // derived
    bgA1 = QColor("#C6C6C6"); // derived
    fg1 = QColor("#161616"); // derived
    fg2 = QColor("#262626"); // derived
    fgA2 = QColor("#2E2E2E");
    fgA3 = QColor("#6B6B6B");
    fgA4 = QColor("#9B9B9B"); // derived
    fgB1 = QColor("#161616"); // derived
    dividerDim = QColor("#ACACAC");
    dividerBright = QColor("#9B9B9B");

    updateAccent(false);
    fillPalette(false);
}

void SystemPalette::makeDarkPalette()
{
    m_isDark = true;

    // Figma "Dark/*" variables
    bgB2 = QColor("#090909");
    bgB1 = QColor("#0E0E0E");
    bgA5 = QColor("#151515");
    bgA4 = QColor("#191919");
    bgA3 = QColor("#1B1B1B");
    bgA2 = QColor("#1F1F1F");
    bgA1 = QColor("#222222");
    fg1 = QColor("#EAEAEA");
    fg2 = QColor("#C6C6C6");
    fgA2 = QColor("#8F8F8F");
    fgA3 = QColor("#6B6B6B");
    fgA4 = QColor("#404040");
    fgB1 = QColor("#161616");
    dividerDim = QColor("#222222");
    dividerBright = QColor("#373737");

    updateAccent(true);
    fillPalette(true);
}

void SystemPalette::fillPalette(bool dark)
{
    m_colorMap.clear();

    typedef ColorContext C;

    // colour overlaid on surfaces for translucent borders/states
    const QColor on = dark ? QColor(Qt::white) : QColor(Qt::black);
    const QColor windowBg = dark ? bgA3 : QColor("#ABABAA"); // derived (light: sampled window chrome)
    const QColor paneBg = dark ? bgB1 : QColor("#C1C1C1");   // derived (light: sampled sidebar panel)
    const QColor menuHighlight = dark ? QColor("#202020") : QColor("#CFCFCF"); // sampled / derived
    const qreal shadowAlpha = dark ? 0.46 : 0.25;

    //base set
    {
        C::ColorSet CS = C::View;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA3);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgB2);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fgA3);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fg1);
        setColor(CS, C::Fg, C::Heading, C::Normal, fg2);

        setColor(CS, C::Bg, C::Negative, C::Normal, dark ? QColor(Qt::darkRed) : QColor("#fde7e9")); //FIXME
        setColor(CS, C::Fg, C::Negative, C::Normal, Qt::red);

        setColor(CS, C::Bg, C::Neutral, C::Normal, dark ? QColor(Qt::darkYellow) : QColor("#e4dab8")); //FIXME
        setColor(CS, C::Fg, C::Neutral, C::Normal, accentMain);

        setColor(CS, C::Bg, C::Positive, C::Normal, dark ? QColor(Qt::darkGreen) : QColor("#dff6dd")); //FIXME
        setColor(CS, C::Fg, C::Positive, C::Normal, Qt::green);

        setColor(CS, C::Decoration, C::VisualFocus, C::Normal, setColorAlpha(on, 0.0) );
        setColor(CS, C::Decoration, C::VisualFocus, C::Focused, on );

        setColor(CS, C::Decoration, C::Border, C::Normal, dividerBright);
        setColor(CS, C::Decoration, C::Border, C::Focused, setColorAlpha(on, 0.7) );
        setColor(CS, C::Decoration, C::Border, C::Hovered, setColorAlpha(on, 0.7) );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(on, 0.0) );

        setColor(CS, C::Decoration, C::Shadow, C::Normal, setColorAlpha(Qt::black, shadowAlpha));

        setColor(CS, C::Decoration, C::Separator, C::Normal, dividerDim);

        setColor(CS, C::Decoration, C::Accent, C::Normal, accentMain);
        setColor(CS, C::Fg, C::Link, C::Normal, accentMain);
    }

    //window banner & miniplayer
    {
        C::ColorSet CS = C::Window;
        setColor(CS, C::Bg, C::Primary, C::Normal, windowBg);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgA4);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerDim);
    }

    //badges
    {
        C::ColorSet CS = C::Badge;
        setColor(CS, C::Bg, C::Primary, C::Normal, dark ? setColorAlpha(Qt::white, 0.8) : setColorAlpha(Qt::black, 0.6));
        setColor(CS, C::Fg, C::Primary, C::Normal, dark ? QColor(Qt::black) : QColor(Qt::white));
    }

    //tab button
    {
        C::ColorSet CS = C::TabButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(bgA2, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA2);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA2);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA2);
        setColor(CS, C::Fg, C::Primary, C::Focused, fg1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, fg1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fg1);
    }

    //tool button
    {
        C::ColorSet CS = C::ToolButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgB2);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA2);
        setColor(CS, C::Fg, C::Primary, C::Focused, fg1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, fg1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fg1);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //menubar
    {
        C::ColorSet CS = C::MenuBar;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(bgA2, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA2);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA2);
        setColor(CS, C::Fg, C::Primary, C::Normal, fgA2);
        setColor(CS, C::Fg, C::Primary, C::Hovered, fg1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
    }

    //Item
    {
        C::ColorSet CS = C::Item;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(bgA2, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA2);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA2);
        setColor(CS, C::Bg, C::Primary, C::Pressed, bgA1);

        // cover/thumbnail placeholder tiles (Figma #303030, untokened)
        setColor(CS, C::Bg, C::Secondary, C::Normal, dark ? darkGrey800 : bgB2);

        setColor(CS, C::Bg, C::Highlight, C::Normal, bgA1);
        setColor(CS, C::Bg, C::Highlight, C::Focused, accentDark);
        setColor(CS, C::Bg, C::Highlight, C::Hovered, bgA1);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fg1);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA2);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fgA3);

        setColor(CS, C::Decoration, C::Indicator, C::Normal, fgA4);
    }

    //Accent Buttons
    {
        C::ColorSet CS = C::ButtonAccent;
        setColor(CS, C::Bg, C::Primary, C::Normal, accentMain);
        setColor(CS, C::Bg, C::Primary, C::Hovered, accentMain.lighter(110)); // derived
        setColor(CS, C::Bg, C::Primary, C::Pressed, accentDim);
        setColor(CS, C::Bg, C::Primary, C::Disabled, accentBright);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgB1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, setColorAlpha(accentMain, 0.6));

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //Tonal Buttons (tinted accent: dialog Save, selected segment)
    {
        C::ColorSet CS = C::ButtonTonal;
        setColor(CS, C::Bg, C::Primary, C::Normal, accentBright);
        setColor(CS, C::Bg, C::Primary, C::Hovered, QColor::fromRgbF(
            accentMain.redF() * 0.32 + bgB2.redF() * 0.68,
            accentMain.greenF() * 0.32 + bgB2.greenF() * 0.68,
            accentMain.blueF() * 0.32 + bgB2.blueF() * 0.68)); // derived
        setColor(CS, C::Bg, C::Primary, C::Pressed, accentBright);
        setColor(CS, C::Bg, C::Primary, C::Disabled, accentBright);

        setColor(CS, C::Fg, C::Primary, C::Normal, accentMain);
        setColor(CS, C::Fg, C::Primary, C::Disabled, setColorAlpha(accentMain, 0.5));

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //Standard Buttons
    {
        C::ColorSet CS = C::ButtonStandard;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA2);
        setColor(CS, C::Fg, C::Primary, C::Focused, fg1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, fg1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //Menu: floating surfaces (menus, popups, dialogs)
    {
        C::ColorSet CS = C::Menu;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(bgA4, 0.95));
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA2);
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA2);
        setColor(CS, C::Bg, C::Primary, C::Pressed, bgA1);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgB2);
        setColor(CS, C::Bg, C::Highlight, C::Normal, menuHighlight);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA2);
        setColor(CS, C::Fg, C::Primary, C::Hovered, fg1);
        setColor(CS, C::Fg, C::Primary, C::Focused, fg1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fgA3);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fg1);
        setColor(CS, C::Fg, C::Heading, C::Normal, fg2);

        setColor(CS, C::Decoration, C::Separator, C::Normal, dividerDim);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerDim);
        setColor(CS, C::Decoration, C::Shadow, C::Normal, setColorAlpha(Qt::black, shadowAlpha));
        setColor(CS, C::Decoration, C::Accent, C::Normal, accentMain);
    }

    //Pane: sidebar panel, settings window, onboarding window
    {
        C::ColorSet CS = C::Pane;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(paneBg, 0.95));
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgA4);
        setColor(CS, C::Bg, C::Highlight, C::Normal, bgA1);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fgA3);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fg1);
        setColor(CS, C::Fg, C::Heading, C::Normal, fg2);

        setColor(CS, C::Decoration, C::Separator, C::Normal, dividerDim);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerDim);
        setColor(CS, C::Decoration, C::Shadow, C::Normal, setColorAlpha(Qt::black, shadowAlpha));
        setColor(CS, C::Decoration, C::Accent, C::Normal, accentMain);
    }

    //tooltip
    {
        C::ColorSet CS = C::Tooltip;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA4);
        setColor(CS, C::Fg, C::Primary, C::Normal, fg2);
    }

    //slider
    {
        C::ColorSet CS = C::Slider;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgB2); // track
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgB2);

        setColor(CS, C::Fg, C::Primary, C::Normal, accentBright); // played fill
        setColor(CS, C::Decoration, C::Accent, C::Normal, accentMain); // thumb
        setColor(CS, C::Fg, C::Secondary, C::Normal, accentDim); // waveform played bars
        setColor(CS, C::Decoration, C::Indicator, C::Normal, fgA4); // waveform remaining bars
        setColor(CS, C::Fg, C::Positive, C::Normal, "#0F7B0F");  //FIXME
        setColor(CS, C::Fg, C::Neutral, C::Normal, "#9D5D00");  //FIXME
        setColor(CS, C::Fg, C::Negative, C::Normal, "#C42B1C");  //FIXME
    }

    //Combo box
    {
        C::ColorSet CS = C::ComboBox;
        setColor(CS, C::Fg, C::Primary, C::Normal, fgA2);
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA4);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgB2);
    }

    //TextField
    {
        C::ColorSet CS = C::TextField;
        setColor(CS, C::Decoration, C::Border, C::Normal, bgA4);
        setColor(CS, C::Decoration, C::Border, C::Focused, accentMain);
        setColor(CS, C::Decoration, C::Border, C::Hovered, dividerBright);
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(on, 0.0) );

        setColor(CS, C::Bg, C::Primary, C::Normal, bgA5);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgB2);
        setColor(CS, C::Fg, C::Primary, C::Normal, fg2);
        setColor(CS, C::Bg, C::Highlight, C::Normal, accentMain);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fgB1);
    }

    //Switch
    {
        C::ColorSet CS = C::Switch;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgB2);          // OFF track (well)
        setColor(CS, C::Fg, C::Primary, C::Normal, fgA4);          // OFF thumb
        setColor(CS, C::Decoration, C::Border, C::Normal, fgA4);
        setColor(CS, C::Bg, C::Secondary, C::Normal, accentBright); // ON track
        setColor(CS, C::Fg, C::Secondary, C::Normal, accentDim);    // ON thumb
    }

    //Spinbox
    {
        C::ColorSet CS = C::SpinBox;
        setColor(CS, C::Decoration, C::Border, C::Normal, bgA4);
        setColor(CS, C::Decoration, C::Border, C::Focused, accentMain);
        setColor(CS, C::Decoration, C::Border, C::Hovered, dividerBright);
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(on, 0.0) );

        setColor(CS, C::Bg, C::Primary, C::Normal, bgA5);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgB2);
        setColor(CS, C::Fg, C::Primary, C::Normal, fg2);
        setColor(CS, C::Bg, C::Highlight, C::Normal, accentMain);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fgB1);
    }
}

void SystemPalette::makeSystemPalette()
{
    if (!m_ctx)
    {
        //can't initialise system palette, fallback to default
        makeLightPalette();
        return;
    }

    auto palette = std::make_unique<ExternalPaletteImpl>(m_ctx, *this);
    if (!palette->init())
    {
        //can't initialise system palette, fallback to default
        makeLightPalette();
        return;
    }

    m_colorMap.clear();
    int ret = palette->update();
    if (ret != VLC_SUCCESS)
    {
        if (palette->isThemeDark())
            makeDarkPalette();
        else
            makeLightPalette();
    }
    else
    {
        m_isDark = palette->isThemeDark();
    }

    m_palettePriv = std::move(palette);
}
