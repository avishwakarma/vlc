/*****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#include "compositor_platform.hpp"

#include <QApplication>
#include <QQuickView>
#include <QOperatingSystemVersion>

#include "maininterface/interface_window_handler.hpp"
#include "maininterface/mainctx.hpp"

#include <vlc_window.h>

#ifdef __APPLE__
#include <objc/runtime.h>
#include <objc/message.h>
#include <TargetConditionals.h>
#endif

using namespace vlc;

#if defined(__APPLE__) && TARGET_OS_OSX
// The video output only covers the picture rectangle of the native video view. Paint the rest
// (letterbox/pillarbox) black, as the window behind it may have no background (frameless window).
static void setVideoViewBackgroundBlack(WId wid)
{
    id view = reinterpret_cast<id>(wid);
    if (!view)
        return;

    using SetBoolFn = void (*)(id, SEL, BOOL);
    using GetIdFn = id (*)(id, SEL);
    using SetColorFn = void (*)(id, SEL, void *);
    using GetPtrFn = void *(*)(id, SEL);

    reinterpret_cast<SetBoolFn>(objc_msgSend)(view, sel_registerName("setWantsLayer:"), YES);
    id layer = reinterpret_cast<GetIdFn>(objc_msgSend)(view, sel_registerName("layer"));
    Class nsColor = objc_getClass("NSColor");
    if (!layer || !nsColor)
        return;
    id black = reinterpret_cast<GetIdFn>(objc_msgSend)(reinterpret_cast<id>(nsColor), sel_registerName("blackColor"));
    void *cgColor = reinterpret_cast<GetPtrFn>(objc_msgSend)(black, sel_registerName("CGColor"));
    reinterpret_cast<SetColorFn>(objc_msgSend)(layer, sel_registerName("setBackgroundColor:"), cgColor);
}
#endif

#ifdef __APPLE__
// The native fullscreen transition of an NSWindow is announced before the window is resized, and
// AppKit animates between a snapshot of the window before and the content drawn right after the
// resize. Qt only reports the new window state at the end of the animation for a transition
// started by the system (green button, menu), and the QML animations do not run during it. Switch
// the layout as soon as the transition is announced, so that the content drawn for the animation
// already is the final layout (edge-to-edge video in fullscreen, the docked layout when leaving).
void CompositorPlatform::observeNativeFullScreen()
{
    using IdFn = id (*)(id, SEL);
    using StrFn = id (*)(id, SEL, const char *);
    using ObserveFn = id (*)(id, SEL, id, id, id, void (^)(id));

    id center = reinterpret_cast<IdFn>(objc_msgSend)(reinterpret_cast<id>(objc_getClass("NSNotificationCenter")),
                                                    sel_registerName("defaultCenter"));
    Class nsString = objc_getClass("NSString");
    if (!center || !nsString)
        return;

    static const struct { const char *name; int layout; } notifications[] = {
        { "NSWindowWillEnterFullScreenNotification", 1 },
        { "NSWindowWillExitFullScreenNotification", 0 },
        // a transition that failed or ended: follow the real window state
        { "NSWindowDidFailToEnterFullScreenNotification", -1 },
        { "NSWindowDidFailToExitFullScreenNotification", -1 },
        { "NSWindowDidEnterFullScreenNotification", -1 },
        { "NSWindowDidExitFullScreenNotification", -1 },
    };
    for (const auto &n : notifications)
    {
        id name = reinterpret_cast<StrFn>(objc_msgSend)(reinterpret_cast<id>(nsString),
                                                       sel_registerName("stringWithUTF8String:"), n.name);
        const int layout = n.layout;
        id token = reinterpret_cast<ObserveFn>(objc_msgSend)(center,
            sel_registerName("addObserverForName:object:queue:usingBlock:"), name, nil, nil,
            ^(id note) {
                if (!m_rootWindow || !m_mainCtx || !m_rootWindow->handle())
                    return;
                id view = reinterpret_cast<id>(m_rootWindow->winId());
                id window = view ? reinterpret_cast<IdFn>(objc_msgSend)(view, sel_registerName("window")) : nil;
                if (!window || reinterpret_cast<IdFn>(objc_msgSend)(note, sel_registerName("object")) != window)
                    return;
                if (layout >= 0)
                {
                    m_mainCtx->setFullScreenLayout(layout == 1);
                    presetVideoViewForTransition(layout == 1);
                }
                else
                {
                    presetVideoViewForTransition(std::nullopt);
                    // NSWindowStyleMaskFullScreen = 1 << 14
                    using MaskFn = unsigned long (*)(id, SEL);
                    const unsigned long mask = reinterpret_cast<MaskFn>(objc_msgSend)(window, sel_registerName("styleMask"));
                    m_mainCtx->setFullScreenLayout((mask & (1ul << 14)) != 0);
                }
            });
        if (token)
        {
            reinterpret_cast<IdFn>(objc_msgSend)(token, sel_registerName("retain"));
            m_fullScreenObservers.push_back(token);
        }
    }
}

// The video view follows the VideoSurface item, but Qt only moves it with the next frame of the
// scene, after AppKit has drawn the resized window for the transition (and the video output
// places the picture even later). In the player view the video takes the whole window in
// fullscreen and goes back to its docked rectangle when leaving: let AppKit resize the view
// with the window, so the transition shows the picture where it will be. Qt sets the exact
// geometry with its next frame, and the autoresizing is turned off when the transition ends.
void CompositorPlatform::presetVideoViewForTransition(std::optional<bool> enter)
{
    struct Rect { double x, y, w, h; };
    using IdFn = id (*)(id, SEL);
    using RectFn = Rect (*)(id, SEL);
    using SetRectFn = void (*)(id, SEL, Rect);
    using SetMaskFn = void (*)(id, SEL, unsigned long);
    // NSViewWidthSizable | NSViewHeightSizable: fixed margins, the size follows the superview
    constexpr unsigned long sizable = 2 | 16;

    if (!m_videoWindow || !m_videoWindow->handle() || !m_mainCtx)
        return;
    id view = reinterpret_cast<id>(m_videoWindow->winId());
    id superview = view ? reinterpret_cast<IdFn>(objc_msgSend)(view, sel_registerName("superview")) : nil;
    if (!superview)
        return;

    if (!enter)
    {
        if (m_videoViewAutoresizing)
            reinterpret_cast<SetMaskFn>(objc_msgSend)(view, sel_registerName("setAutoresizingMask:"), 0);
        m_videoViewAutoresizing = false;
        return;
    }
    if (!m_mainCtx->isPlayerView() || !m_mainCtx->hasEmbededVideo())
        return;

    const Rect bounds = reinterpret_cast<RectFn>(objc_msgSend)(superview, sel_registerName("bounds"));
    const Rect frame = reinterpret_cast<RectFn>(objc_msgSend)(view, sel_registerName("frame"));
    Rect target = bounds;
    if (*enter)
    {
        // remember the docked rectangle as margins, for the way back
        m_dockedVideoMargins = QMarginsF(frame.x - bounds.x, frame.y - bounds.y,
                                         bounds.x + bounds.w - frame.x - frame.w,
                                         bounds.y + bounds.h - frame.y - frame.h);
    }
    else
    {
        if (!m_dockedVideoMargins)
            return;
        const QMarginsF &m = *m_dockedVideoMargins;
        target = { bounds.x + m.left(), bounds.y + m.top(),
                   bounds.w - m.left() - m.right(), bounds.h - m.top() - m.bottom() };
        if (target.w <= 0 || target.h <= 0)
            return;
    }
    reinterpret_cast<SetRectFn>(objc_msgSend)(view, sel_registerName("setFrame:"), target);
    reinterpret_cast<SetMaskFn>(objc_msgSend)(view, sel_registerName("setAutoresizingMask:"), sizable);
    m_videoViewAutoresizing = true;
}

void CompositorPlatform::stopObservingNativeFullScreen()
{
    using IdFn = id (*)(id, SEL);
    using RemoveFn = void (*)(id, SEL, id);
    if (m_fullScreenObservers.empty())
        return;
    id center = reinterpret_cast<IdFn>(objc_msgSend)(reinterpret_cast<id>(objc_getClass("NSNotificationCenter")),
                                                    sel_registerName("defaultCenter"));
    for (void *token : m_fullScreenObservers)
    {
        reinterpret_cast<RemoveFn>(objc_msgSend)(center, sel_registerName("removeObserver:"), static_cast<id>(token));
        reinterpret_cast<IdFn>(objc_msgSend)(static_cast<id>(token), sel_registerName("release"));
    }
    m_fullScreenObservers.clear();
}
#endif

CompositorPlatform::CompositorPlatform(qt_intf_t *p_intf, QObject *parent)
    : CompositorVideo(p_intf, parent)
{

}

bool CompositorPlatform::init()
{
    // TODO: For now only qwindows and qdirect2d
    //       running on Windows 8+, and cocoa
    //       platforms are supported.

    const QString& platformName = qApp->platformName();

#ifdef _WIN32
    if (QOperatingSystemVersion::current() >= QOperatingSystemVersion::Windows8)
    {
        if (platformName == QLatin1String("windows") || platformName == QLatin1String("direct2d"))
        {
            // Video embedding with RHI often does not work, VirtualBox drivers may work, but VMWare
            // and Nvidia drivers (non-VM) don't. So we only allow this in non-RHI modes at the
            // moment. Note that using software rasterizer (such as D3D Warp), that can be requested
            // with `QSG_RHI_PREFER_SOFTWARE_RENDERER`, also does not work.
            if (qEnvironmentVariable("QT_QUICK_BACKEND", QStringLiteral("rhi")) == QLatin1String("rhi"))
                return false;

            return true; // Practically "software" and "openvg" modes (non-RHI).
        }
    }
#endif

#ifdef __APPLE__
    if (platformName == QLatin1String("cocoa") || platformName == QLatin1String("ios"))
        return true;
#endif

    return false;
}

bool CompositorPlatform::makeMainInterface(MainCtx *mainCtx, std::function<void (QQuickWindow *)> aboutToShowQuickWindowCallback)
{
    m_mainCtx = mainCtx;

    m_rootWindow = std::make_unique<QWindow>();

    m_videoWindow = new QWindow(m_rootWindow.get());
#if defined(__APPLE__) && TARGET_OS_OSX
    setVideoViewBackgroundBlack(m_videoWindow->winId());
#endif

    m_quickWindow = new QQuickView(m_rootWindow.get());
    m_quickWindow->setResizeMode(QQuickView::SizeRootObjectToView);

    {
        // Transparency set-up:
        m_quickWindow->setColor(Qt::transparent);

        QSurfaceFormat format = m_quickWindow->format();
        format.setAlphaBufferSize(8);
        m_quickWindow->setFormat(format);
    }

    // Make sure the UI child window has the same size as the root parent window:
    connect(m_rootWindow.get(), &QWindow::widthChanged, m_quickWindow, &QWindow::setWidth);
    connect(m_rootWindow.get(), &QWindow::heightChanged, m_quickWindow, &QWindow::setHeight);

    m_quickWindow->create();

    const bool ret = commonGUICreate(m_rootWindow.get(), m_quickWindow, CompositorVideo::CAN_SHOW_PIP | CompositorVideo::HAS_ACRYLIC);

    m_quickWindow->setFlag(Qt::FramelessWindowHint);
    // Qt QPA Bug (qwindows, qdirect2d(?)): to trigger WS_EX_LAYERED set up.
    m_quickWindow->setOpacity(0.0);
    m_quickWindow->setOpacity(1.0);

    m_rootWindow->installEventFilter(this);

    if (aboutToShowQuickWindowCallback)
        aboutToShowQuickWindowCallback(m_quickWindow);

    m_rootWindow->setVisible(true);
    m_videoWindow->setVisible(true);
    m_quickWindow->setVisible(true);

    m_quickWindow->raise(); // Make sure quick window is above the video window.

#if defined(__APPLE__) && TARGET_OS_OSX
    observeNativeFullScreen();
#endif

    return ret;
}

void CompositorPlatform::destroyMainInterface()
{
#if defined(__APPLE__) && TARGET_OS_OSX
    stopObservingNativeFullScreen();
#endif
    commonIntfDestroy();
}

void CompositorPlatform::unloadGUI()
{
#if defined(__APPLE__) && TARGET_OS_OSX
    stopObservingNativeFullScreen();
#endif
    m_rootWindow->removeEventFilter(this);
    m_interfaceWindowHandler.reset();
    m_quickWindow->setSource(QUrl());
    commonGUIDestroy();
}

bool CompositorPlatform::setupVoutWindow(vlc_window_t *p_wnd, VoutDestroyCb destroyCb)
{
    if (m_wnd)
        return false;

    commonSetupVoutWindow(p_wnd, destroyCb);

#ifdef __WIN32
    p_wnd->type = VLC_WINDOW_TYPE_HWND;
    p_wnd->handle.hwnd = reinterpret_cast<void*>(m_videoWindow->winId());

    return true;
#endif

#ifdef __APPLE__
    p_wnd->type = VLC_WINDOW_TYPE_NSOBJECT;
    p_wnd->handle.nsobject = reinterpret_cast<id>(m_videoWindow->winId());

    return true;
#endif

    vlc_assert_unreachable();
}

QWindow *CompositorPlatform::interfaceMainWindow() const
{
    return m_rootWindow.get();
}

QQuickWindow *CompositorPlatform::quickWindow() const
{
    return m_quickWindow.get();
}

Compositor::Type CompositorPlatform::type() const
{
    return Compositor::PlatformCompositor;
}

QQuickItem *CompositorPlatform::activeFocusItem() const
{
    assert(m_quickWindow);
    return m_quickWindow->activeFocusItem();
}

bool CompositorPlatform::eventFilter(QObject *watched, QEvent *event)
{
    // Forward drag events to the child quick window,
    // as it is not done automatically by Qt with
    // nested windows:
    if (m_quickWindow && watched == m_rootWindow.get())
    {
        switch (event->type()) {
        case QEvent::DragEnter:
        case QEvent::DragLeave:
        case QEvent::DragMove:
        case QEvent::DragResponse:
        case QEvent::Drop:
            QApplication::sendEvent(m_quickWindow, event);
            return true;
        default:
            break;
        };
    }
    return false;
}

void CompositorPlatform::commitSurface()
{
    if (!m_videoWindow)
        return;

#if defined(__APPLE__) && TARGET_OS_OSX
    // Qt places the view from now on (see presetVideoViewForTransition())
    if (m_videoViewAutoresizing && (m_pendingPosition || m_pendingSize))
        presetVideoViewForTransition(std::nullopt);
#endif

    if (m_pendingPosition && m_pendingSize)
    {
        m_videoWindow->setGeometry(m_pendingPosition->x(), m_pendingPosition->y(),
                                   m_pendingSize->width(), m_pendingSize->height());
        m_pendingPosition.reset();
        m_pendingSize.reset();
    }
    else
    {
        if (m_pendingSize)
        {
            m_videoWindow->resize(*m_pendingSize);
            m_pendingSize.reset();
        }
        else if (m_pendingPosition)
        {
            m_videoWindow->setPosition(*m_pendingPosition);
            m_pendingPosition.reset();
        }
    }
}

int CompositorPlatform::windowEnable(const vlc_window_cfg_t *)
{
    commonWindowEnable();
    return VLC_SUCCESS;
}

void CompositorPlatform::windowDisable()
{
    commonWindowDisable();
}

void CompositorPlatform::onSurfacePositionChanged(const QPointF &position)
{
    const QPointF point = position / m_videoWindow->devicePixelRatio();
    m_pendingPosition = QPoint{static_cast<int>(point.x()), static_cast<int>(point.y())};
}

void CompositorPlatform::onSurfaceSizeChanged(const QSizeF &size)
{
    const QSizeF area = (size / m_videoWindow->devicePixelRatio());
    m_pendingSize = QSize{static_cast<int>(std::ceil(area.width())), static_cast<int>(std::ceil(area.height()))};
}
