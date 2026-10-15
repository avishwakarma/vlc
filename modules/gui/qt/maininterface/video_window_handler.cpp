/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
#include "video_window_handler.hpp"
#include "mainctx.hpp"

#include <QApplication>
#include <QScreen>

#include <vlc_window.h>
#include "compositor.hpp"

VideoWindowHandler::VideoWindowHandler(qt_intf_t* intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
    /* Does the interface resize to video size or the opposite */
    m_autoresize = var_InheritBool( m_intf, "qt-video-autoresize" );

    assert(qGuiApp);
    m_hasWayland = qGuiApp->platformName().startsWith(QLatin1String("wayland"));

    connect( this, &VideoWindowHandler::askVideoToResize,
             this, &VideoWindowHandler::setVideoSize, Qt::QueuedConnection );
    connect( this, &VideoWindowHandler::askVideoSetFullScreen,
             this, &VideoWindowHandler::setVideoFullScreen, Qt::QueuedConnection );
    connect( this, &VideoWindowHandler::askVideoOnTop,
             this, &VideoWindowHandler::setVideoOnTop, Qt::QueuedConnection );
}

void VideoWindowHandler::setWindow(QWindow* window)
{
    if (m_window == window)
        return;
    if (m_window)
    {
        WindowStateHolder::holdOnTop(m_window, WindowStateHolder::VIDEO, false);
        WindowStateHolder::holdFullscreen(m_window, WindowStateHolder::VIDEO, false);
    }

    m_window = window;
}

void VideoWindowHandler::disable()
{
    emit askVideoSetFullScreen( false );
    emit askVideoOnTop( false );
}

void VideoWindowHandler::requestResizeVideo( unsigned i_width, unsigned i_height )
{
    if (!m_window)
        return;
    emit askVideoToResize( i_width, i_height, m_window->windowStates() );
}

void VideoWindowHandler::requestVideoWindowed( )
{
   emit askVideoSetFullScreen( false );
}

void VideoWindowHandler::requestVideoFullScreen(const char * )
{
    emit askVideoSetFullScreen( true );
}

void VideoWindowHandler::requestVideoState(  unsigned i_arg )
{
    bool on_top = (i_arg & VLC_WINDOW_STATE_ABOVE) != 0;
    emit askVideoOnTop( on_top );
}

void VideoWindowHandler::setVideoSize(unsigned int w, unsigned int h, Qt::WindowStates currentStates)
{
    if (!m_window)
        return;
    Qt::WindowStates states = m_window->windowStates();

    // This slot is queued, so by the time it is called
    // the window states reflect the final states.
    // `qt-video-autoresize` should not apply during state
    // transition, that was also the behavior in VLC 3.
    // Otherwise, when getting disengaged from fullscreen
    // the interface/video would forget its old (overridden)
    // size.

    // Do not resize when transitioning between states:
    if (currentStates != states)
        return;

    if ((states & (Qt::WindowFullScreen | Qt::WindowMaximized)) == 0)
    {
        /* Resize video widget to video size, or keep it at the same
         * size. Call setSize() either way so that vlc_window_ReportSize
         * will always get called.
         * If the video size is too large for the screen, resize it
         * to the screen size.
         */
        if (m_autoresize)
        {
            // Keep the width of the window and adjust its height, so that the video viewport
            // (the window minus the title bar, the control bar and the rim, which the player
            // page reports with setVideoChromeInsets) has the aspect ratio of the video: no
            // bars around the picture. The video size (w x h) is the display size of the vout
            // (sample aspect ratio included). If it does not fit on the screen, the height is
            // limited to the screen and the width follows.
            const QRect screen = m_window->screen()->availableGeometry();
            const QSizeF chrome = m_intf->p_mi ? m_intf->p_mi->videoChromeInsets() : QSizeF(20, 94);
            if (w == 0 || h == 0)
                return;
            const double aspect = double(w) / double(h);

            // Keep the current width. A tiny window gets a sensible default width, and the width
            // never exceeds 90% of the visible screen area.
            double windowW = m_window->width();
            if (windowW < 640)
                windowW = std::min<double>(960, screen.width() * 0.9);
            windowW = std::min<double>(windowW, screen.width() * 0.9);
            double viewportW = std::max<double>(windowW - chrome.width(), 64);
            double windowH = viewportW / aspect + chrome.height();
            const double maxH = screen.height() * 0.9;
            if (windowH > maxH)
            {
                windowH = maxH;
                viewportW = (windowH - chrome.height()) * aspect;
            }
            msg_Dbg( m_intf, "Autoresize interface window to the video aspect %f: viewport %f, chrome %fx%f",
                     aspect, viewportW, chrome.width(), chrome.height() );
            w = qRound(viewportW + chrome.width());
            h = qRound(windowH);

            m_window->resize(std::clamp<int>(w, m_window->minimumWidth(), m_window->maximumWidth()),
                             std::clamp<int>(h, m_window->minimumHeight(), m_window->maximumHeight()));

            // keep the whole window on the screen
            QRect frame = m_window->geometry();
            frame.moveLeft(std::clamp(frame.left(), screen.left(), std::max(screen.left(), screen.right() + 1 - frame.width())));
            frame.moveTop(std::clamp(frame.top(), screen.top(), std::max(screen.top(), screen.bottom() + 1 - frame.height())));
            m_window->setPosition(frame.topLeft());
        }
    }
}

void VideoWindowHandler::setVideoFullScreen( bool fs )
{
    if (!m_window)
        return;
    m_videoFullScreen = fs;
    if( fs )
    {
        int numscreen = var_InheritInteger( m_intf, "qt-fullscreen-screennumber" );

        auto screenList = QApplication::screens();
        if ( numscreen >= 0 && numscreen < screenList.count() )
        {
            QRect screenres = screenList[numscreen]->geometry();
            m_lastWinScreen = m_window->screen();
            if( !m_hasWayland )
                m_window->setScreen(screenList[numscreen]);

            /* To be sure window is on proper-screen in xinerama */
            if( !screenres.contains( m_window->position() ) )
            {
                m_window->setPosition(screenres.x(), screenres.y() );
            }
        }
        WindowStateHolder::holdFullscreen(m_window,  WindowStateHolder::VIDEO, true);
    }
    else
    {
        WindowStateHolder::holdFullscreen(m_window,  WindowStateHolder::VIDEO, false);

        if( m_lastWinScreen != NULL && !m_hasWayland )
            m_window->setScreen(m_lastWinScreen);
    }
}


/* Slot to change the video always-on-top flag.
 * Emit askVideoOnTop() to invoke this from other thread. */
void VideoWindowHandler::setVideoOnTop( bool on_top )
{
    if (!m_window)
        return;
    WindowStateHolder::holdOnTop(m_window, WindowStateHolder::VIDEO, on_top);
}
