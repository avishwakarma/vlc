/*****************************************************************************
 * menus.cpp : Qt menus
 *****************************************************************************
 * Copyright © 2006-2011 the VideoLAN team
 *
 * Authors: Clément Stenac <zorglub@videolan.org>
 *          Jean-Baptiste Kempf <jb@videolan.org>
 *          Jean-Philippe André <jpeg@videolan.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
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

/** \todo
 * - Remove static currentGroup
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <vlc_common.h>
#include <vlc_intf_strings.h>
#include <vlc_aout.h>                             /* audio_output_t */
#include <vlc_interface.h>
#include <vlc_actions.h>

#include "menus.hpp"

#include "maininterface/mainctx.hpp"                     /* View modifications */
#include "maininterface/mainctx_submodels.hpp"
#include "dialogs/dialogs_provider.hpp"                   /* Dialogs display */
#include "dialogs/help/help.hpp"
#include "player/player_controller.hpp"                      /* Input Management */
#include "playlist/playlist_controller.hpp"
#include "dialogs/extensions/extensions_manager.hpp"                 /* Extensions menu */
#include "dialogs/extended/extended_panels.hpp"
#include "dialogs/systray/systray.hpp"
#include "util/varchoicemodel.hpp"
#include "util/color_scheme_model.hpp"
#include "util/colorizedsvgicon.hpp"
#include "util/vlc_menu_style.hpp"
#include "medialibrary/medialib.hpp"
#include "medialibrary/mlrecentmediamodel.hpp"
#include "medialibrary/mlbookmarkmodel.hpp"


#include "util/vlchotkeyconverter.hpp"

#include <QMenu>
#include <QDesktopServices>
#include <QGuiApplication>
#include <QWindow>
#include <QUrl>
#include <QKeySequence>
#include <QPainter>
#include <QMenuBar>
#include <QAction>
#include <QActionGroup>
#include <QSignalMapper>

using namespace vlc::playlist;

/*
  This file defines the main menus and the pop-up menu (right-click menu)
  and the systray menu (in that order in the file)

  There are 4 menus that have to be rebuilt every time there are called:
  Audio, Video, Navigation, view
  4 functions are building those menus: AudioMenu, VideoMenu, NavigMenu, View

  */

RendererMenu *VLCMenuBar::rendererMenu = NULL;

/*
 * Shortcut labels.
 *
 * One source of truth: the effective VLC hotkey configuration ("key-*"), plus a short list of
 * fixed Qt shortcuts for dialogs. Two ways to show a binding:
 *  - in the native macOS menu bar (s_nativeBar): a real key equivalent, so macOS draws the glyphs
 *    (only for bindings with a Command/Ctrl/Alt modifier, a bare key as menu key equivalent would
 *    steal the key from text fields);
 *  - everywhere else (pop-up menus, the ... menu, right-click menu): a right aligned label, never a
 *    live shortcut (the key is handled once, by the hotkey layer or GlobalShortcuts.qml).
 */
namespace {

bool s_nativeBar = false;

#ifdef __APPLE__
# define PLATFORM_SC(mac, other) mac
#else
# define PLATFORM_SC(mac, other) other
#endif

QStringList hotkeyBindings( qt_intf_t *p_intf, const char *action )
{
    const QByteArray name = QByteArray( "key-" ) + action;
    char *keys = var_InheritString( p_intf, name.constData() );
    if( !keys )
        return {};
    const QStringList list = qfu( keys ).split( QLatin1Char('\t'), Qt::SkipEmptyParts );
    free( keys );
    return list;
}

void appendLabel( QAction *action, const QString& label )
{
    if( label.isEmpty() )
        return;
    action->setText( action->text() + ( s_nativeBar ? QStringLiteral("\u2003") : QStringLiteral("\t") ) + label );
}

/** Label the action with the effective binding of the VLC hotkey "key-<hotkey>". */
QAction *labelHotkey( qt_intf_t *p_intf, QAction *action, const char *hotkey )
{
    const QStringList keys = hotkeyBindings( p_intf, hotkey );
    if( keys.isEmpty() )
        return action;
    if( s_nativeBar )
    {
        for( const QString& key : keys )
        {
            const QKeySequence seq = VLCHotkeyHasModifier( key ) ? VLCHotkeyToKeySequence( key ) : QKeySequence();
            if( !seq.isEmpty() )
            {
                action->setShortcut( seq );
                return action;
            }
        }
    }
    appendLabel( action, VLCHotkeyGlyphs( keys.first() ) );
    return action;
}

/** Label the action with a fixed Qt shortcut ("Ctrl+O" is Command+O on macOS). */
QAction *labelShortcut( QAction *action, const char *shortcut )
{
    if( EMPTY_STR( shortcut ) )
        return action;
    const QKeySequence seq( qfu( shortcut ) );
    if( s_nativeBar )
        action->setShortcut( seq );
    else
        appendLabel( action, seq.toString( QKeySequence::NativeText ) );
    return action;
}

/** I3: one icon set (the twotone one) in every builder; entries without a twotone icon have none. */
QIcon menuIcon( const char *legacy )
{
    static const struct { const char *legacy; const char *name; } map[] = {
        { ":/menu/file.svg", "file-twotone" }, { ":/menu/folder.svg", "folder-twotone" },
        { ":/menu/disc.svg", "disc-twotone" }, { ":/menu/network.svg", "streaming-twotone" },
        { ":/menu/capture-card.svg", "capture-device-twotone" }, { ":/menu/stream.svg", "streaming-twotone" },
        { ":/menu/exit.svg", "quit-twotone" }, { ":/menu/info.svg", "info-twotone" },
        { ":/menu/messages.svg", "info-twotone" }, { ":/menu/help.svg", "info-twotone" },
        { ":/menu/ic_fluent_options.svg", "settings-twotone" }, { ":/menu/preferences.svg", "settings-twotone" },
        { ":/menu/ic_playlist.svg", "queue-twotone" }, { ":/menu/ic_fluent_play_filled.svg", "playback-twotone" },
        { ":/menu/ic_pause_filled.svg", "pause" }, { ":/menu/ic_fluent_stop.svg", "stop-twotone" },
        { ":/menu/ic_fluent_previous.svg", "previous-twotone" }, { ":/menu/ic_fluent_next.svg", "next-twotone" },
        { ":/menu/ic_fluent_record.svg", "record-twotone" },
    };
    if( s_nativeBar )
        return {};
    for( const auto& m : map )
        if( !strcmp( m.legacy, legacy ) )
            return VLCMenuStyle::icon( QString::fromLatin1( m.name ) );
    return {};
}

/** Strips the '&' mnemonics of the legacy strings and uses the real ellipsis character. */
QString menuTitle( QString text )
{
    text.replace( QStringLiteral("..."), QStringLiteral("\u2026") );
    QString out;
    for( int i = 0; i < text.size(); ++i )
    {
        if( text[i] == QLatin1Char('&') && i + 1 < text.size() )
        {
            if( text[i + 1] == QLatin1Char('&') ) { out += QLatin1Char('&'); ++i; }
            continue;
        }
        out += text[i];
    }
    return out;
}

} // namespace

/**
 * @brief Add static entries to DP in menus
 **/
template<typename Functor>
QAction *addDPStaticEntry( QMenu *menu,
                       const QString& text,
                       const char *icon,
                       const Functor member,
                       const char *shortcut = NULL,
                       QAction::MenuRole role = QAction::NoRole
                       )
{
    QAction *action = NULL;
    const QString title = menuTitle( text );
#ifndef __APPLE__ /* We don't set icons in menus in MacOS X */
    if( !EMPTY_STR( icon ) )
    {
        action = menu->addAction( menuIcon( icon ), title, THEDP, member );
    }
    else
#endif
    {
        action = menu->addAction( title, THEDP, member );
    }
    labelShortcut( action, shortcut );
#ifdef __APPLE__
    action->setMenuRole( role );
#else
    Q_UNUSED( role );
#endif
    return action;
}

/**
 * @brief Add static entries to MIM in menus
 **/
template<typename Fun>
static QAction* addMIMStaticEntry( qt_intf_t *p_intf,
                            QMenu *menu,
                            const QString& text,
                            const char *icon,
                            Fun member )
{
    QAction *action;
#ifndef __APPLE__ /* We don't set icons in menus in MacOS X */
    if( !EMPTY_STR( icon ) )
    {
        action = menu->addAction( text, THEMIM,  member );
        action->setIcon( menuIcon( icon ) );
    }
    else
#endif
    {
        action = menu->addAction( text, THEMIM, member );
    }
    return action;
}

template<typename Fun>
static QAction* addMPLStaticEntry( qt_intf_t *p_intf,
                            QMenu *menu,
                            const QString& text,
                            const char *icon,
                            Fun member )
{
    QAction *action;
#ifndef __APPLE__ /* We don't set icons in menus in MacOS X */
    if( !EMPTY_STR( icon ) )
    {
        action = menu->addAction( text, THEMPL,  member );
        action->setIcon( menuIcon( icon ) );
    }
    else
#endif
    {
        action = menu->addAction( text, THEMPL, member );
    }
    return action;
}

/*****************************************************************************
 * All normal menus
 * Simple Code
 *****************************************************************************/

/**
 * Main Menu Bar Creation
 **/
VLCMenuBar::VLCMenuBar(QObject* parent)
    : QObject(parent)
{}


/**
 * Media ( File ) Menu
 * Opening, streaming and quit
 **/
void VLCMenuBar::FileMenu(qt_intf_t *p_intf, QMenu *menu)
{
    auto mi = p_intf->p_mi;
    QAction *action;

    //use a lambda here as the Triggrered signal is emiting and it will pass false (checked) as a first argument
    addDPStaticEntry( menu, qtr( "Open File…" ),
        ":/menu/file.svg", []() { THEDP->simpleOpenDialog(); } , "Ctrl+O" );
#ifdef __APPLE__
    addDPStaticEntry( menu, qtr( "Open Folder…" ),
        ":/menu/folder.svg", &DialogsProvider::PLOpenDir, "Ctrl+Shift+O" );
    addDPStaticEntry( menu, qtr( "Open Multiple Files…" ),
        ":/menu/file.svg", &DialogsProvider::openFileDialog );
#else
    addDPStaticEntry( menu, qtr( "Open Multiple Files…" ),
        ":/menu/file.svg", &DialogsProvider::openFileDialog, "Ctrl+Shift+O" );
    addDPStaticEntry( menu, qtr( "Open Folder…" ),
        ":/menu/folder.svg", &DialogsProvider::PLOpenDir, "Ctrl+F" );
#endif
    addDPStaticEntry( menu, qtr( "Open Disc…" ),
        ":/menu/disc.svg", &DialogsProvider::openDiscDialog, "Ctrl+D" );
    addDPStaticEntry( menu, qtr( "Open Location…" ),
        ":/menu/network.svg", &DialogsProvider::openNetDialog, "Ctrl+N" );
    addDPStaticEntry( menu, qtr( "Open Capture Device…" ),
        ":/menu/capture-card.svg", &DialogsProvider::openCaptureDialog,
        PLATFORM_SC( NULL, "Ctrl+C" ) );

    if( mi && var_InheritBool( p_intf, "save-recentplay" ) && mi->hasMediaLibrary() )
    {
        MLRecentMediaModel* recentModel = new MLRecentMediaModel(nullptr);
        recentModel->setMl(mi->getMediaLibrary());
        recentModel->setLimit(10);
        QMenu* recentsMenu = new RecentMenu(recentModel, mi->getMediaLibrary(), menu);
        recentsMenu->setTitle(qtr( "Open Recent" ) );
        recentModel->setParent(recentsMenu);
        menu->addMenu( recentsMenu );
    }

    menu->addSeparator();

    addDPStaticEntry( menu, qtr( "Save Queue as Playlist…" ), "", &DialogsProvider::savePlayingToPlaylist,
        "Ctrl+Y" );

    addDPStaticEntry( menu, qtr( "Convert / Save…" ), "",
        &DialogsProvider::openAndTranscodingDialogs, "Ctrl+R" );
    addDPStaticEntry( menu, qtr( "Stream…" ),
        ":/menu/stream.svg", &DialogsProvider::openAndStreamingDialogs,
        PLATFORM_SC( "Ctrl+Shift+S", "Ctrl+S" ) );
    menu->addSeparator();

    action = menu->addAction( qtr( "Quit at the End of the Queue" ), [playlist = THEMPL](bool checked){
        if (checked)
            playlist->setMediaStopAction(PlaylistController::MEDIA_STOPPED_EXIT);
        else
            playlist->setMediaStopAction(PlaylistController::MEDIA_STOPPED_CONTINUE);
    });
    action->setCheckable( true );
    action->setChecked( THEMPL->getMediaStopAction() ==  PlaylistController::MEDIA_STOPPED_EXIT);

    VLCSystray* systray = mi ? mi->getSysTray() : nullptr;
    if( systray )
    {
        action = menu->addAction( qtr( "Close to Systray"), systray,
                                 &VLCSystray::toggleUpdateMenu );
    }

    addDPStaticEntry( menu, qtr( "Quit" ) ,
        ":/menu/exit.svg", &DialogsProvider::quit, "Ctrl+Q", QAction::QuitRole );
}

void VLCMenu::setRightCheck(bool descending)
{
    m_rightCheck = true;
    m_descending = descending;
    setStyleSheet(VLCMenuStyle::rightCheckStyleSheet());
}

void VLCMenu::paintEvent(QPaintEvent *event)
{
    QMenu::paintEvent(event);

    if (!m_rightCheck)
        return;

    const int size = 24;
    const QIcon mark = VLCMenuStyle::icon(m_descending ? QStringLiteral("arrow-down") : QStringLiteral("check-active"));

    QPainter painter(this);
    for (QAction *action : actions())
    {
        if (!action->isCheckable() || !action->isChecked())
            continue;

        const QRect r = actionGeometry(action);
        mark.paint(&painter, QRect(r.right() - 10 - size, r.top() + (r.height() - size) / 2, size, size));
    }
}

/**
 * Content of the main "..." menu of the slim title bar (Figma 6062:13354):
 * open entries, recent media, then keyboard shortcuts, player customization, settings and about.
 **/
void VLCMenuBar::MainMenu(qt_intf_t *p_intf, QMenu *menu)
{
    auto mi = p_intf->p_mi;

    auto add = [menu](const QString& text, const char *svg, auto member, const char *shortcut = nullptr) {
        QAction *action = menu->addAction( VLCMenuStyle::icon( svg ), text, THEDP, member );
        labelShortcut( action, shortcut );
        return action;
    };

    add( qtr( "Open File…" ), "file-twotone", []() { THEDP->simpleOpenDialog(); }, "Ctrl+O" );
    add( qtr( "Open Folder…" ), "folder-twotone", &DialogsProvider::PLOpenDir,
         PLATFORM_SC( "Ctrl+Shift+O", "Ctrl+F" ) );
    add( qtr( "Open Location…" ), "streaming-twotone", &DialogsProvider::openNetDialog, "Ctrl+N" );
    add( qtr( "Open Disc…" ), "disc-twotone", &DialogsProvider::openDiscDialog, "Ctrl+D" );
    add( qtr( "Open Capture Device…" ), "capture-device-twotone", &DialogsProvider::openCaptureDialog,
         PLATFORM_SC( NULL, "Ctrl+C" ) );
    add( qtr( "Convert / Save…" ), "swap-twotone", &DialogsProvider::openAndTranscodingDialogs, "Ctrl+R" );

    if( mi && var_InheritBool( p_intf, "save-recentplay" ) && mi->hasMediaLibrary() )
    {
        MLRecentMediaModel* recentModel = new MLRecentMediaModel(nullptr);
        recentModel->setMl(mi->getMediaLibrary());
        recentModel->setLimit(10);
        QMenu* recentsMenu = new RecentMenu(recentModel, mi->getMediaLibrary(), menu);
        recentsMenu->setTitle(qtr( "Open Recent" ) );
        recentsMenu->setIcon( VLCMenuStyle::icon( "recent-twotone" ) );
        recentModel->setParent(recentsMenu);
        menu->addMenu( recentsMenu );
    }

    menu->addSeparator();

    // TODO: "Profile (...)" submenu once the profile model exists
    add( qtr( "Keyboard Shortcuts" ), "hotkeys-twotone", &DialogsProvider::keyboardShortcutsDialog, "Ctrl+/" );
    add( qtr( "Customize Player…" ), "paint-twotone", &DialogsProvider::showToolbarEditorDialog );
    add( qtr( "Settings…" ), "settings-twotone", &DialogsProvider::prefsDialog,
         PLATFORM_SC( "Ctrl+,", "Ctrl+P" ) );
    add( qtr( "Help" ), "info-twotone", &DialogsProvider::helpDialog, PLATFORM_SC( "Ctrl+?", "F1" ) );
    add( qtr( "About VLC Redesign" ), "info-twotone", &DialogsProvider::aboutDialog,
         PLATFORM_SC( NULL, "Shift+F1" ) )->setMenuRole( QAction::AboutRole );
}

/**
 * Media Information, Codec Information, Effects, Track Synchronization and Messages.
 * (VLM, Program Guide and Plugins entries are not shown: no redesigned UI for them.)
 **/
void VLCMenuBar::InfoToolsMenu( qt_intf_t *p_intf, QMenu *menu )
{
    Q_UNUSED( p_intf );
    addDPStaticEntry( menu, qtr( "Media Information" ), ":/menu/info.svg",
        QOverload<>::of(&DialogsProvider::mediaInfoDialog), "Ctrl+I" );

    addDPStaticEntry( menu, qtr( "Codec Information" ),
        ":/menu/info.svg", &DialogsProvider::mediaCodecDialog, "Ctrl+J" );

    addDPStaticEntry( menu, qtr( "Effects and Filters"), ":/menu/ic_fluent_options.svg",
            &DialogsProvider::extendedDialog, PLATFORM_SC( "Ctrl+Alt+E", "Ctrl+E" ) );

    addDPStaticEntry( menu, qtr( "Track Synchronization"), ":/menu/ic_fluent_options.svg",
            &DialogsProvider::synchroDialog, "" );

    addDPStaticEntry( menu, qtr( "Messages" ),
        ":/menu/messages.svg", &DialogsProvider::messagesDialog,
        PLATFORM_SC( "Ctrl+Shift+M", "Ctrl+M" ) );
}

/**
 * Tools, like Media Information, Settings or Messages
 **/
void VLCMenuBar::ToolsMenu( qt_intf_t *p_intf, QMenu *menu )
{
    InfoToolsMenu( p_intf, menu );
    menu->addSeparator();

    if( !p_intf->b_isDialogProvider )
        addDPStaticEntry( menu, qtr( "Customize Player…" ),
            ":/menu/preferences.svg", &DialogsProvider::showToolbarEditorDialog);

    addDPStaticEntry( menu, qtr( "Settings…" ),
        ":/menu/preferences.svg", &DialogsProvider::prefsDialog, PLATFORM_SC( NULL, "Ctrl+P" ),
        QAction::NoRole );
}

/**
 * View Menu
 * Interface modification, load other interfaces, activate Extensions
 * \param current, set to NULL for menu creation, else for menu update
 **/
void VLCMenuBar::ViewMenu(qt_intf_t *p_intf, QMenu *menu)
{
    QAction *action;

    MainCtx *mi = p_intf->p_mi;
    assert( mi );
    assert(menu);

    //menu->clear();
    //HACK menu->clear() does not delete submenus
    QList<QAction*> actions = menu->actions();
    foreach( QAction *a, actions )
    {
        QMenu *m = a->menu();
        if( a->parent() == menu ) delete a;
        else menu->removeAction( a );
        if( m && m->parent() == menu ) delete m;
    }

    action = menu->addAction(
#ifndef __APPLE__
            menuIcon( ":/menu/ic_playlist.svg" ),
#endif
            qtr( "Queue" ));
    action->setCheckable( true );
    connect( action, &QAction::triggered, mi->getPlayqueuePanel(), &SidePanelCtx::setVisible );
    labelShortcut( action, "Ctrl+L" );
    action->setChecked( mi->getPlayqueuePanel()->isVisible() );

    /* Docked Play Queue */
    action = menu->addAction( qtr( "Docked Queue" ) );
    action->setCheckable( true );
    connect( action, &QAction::triggered, mi->getPlayqueuePanel(), &SidePanelCtx::setDocked );
    action->setChecked( mi->getPlayqueuePanel()->isDocked() );

    menu->addSeparator();

    action = menu->addAction( qtr( "Always on Top" ) );
    action->setCheckable( true );
    action->setChecked( mi->isInterfaceAlwaysOnTop() );
    connect( action, &QAction::triggered, mi, &MainCtx::setInterfaceAlwaysOnTop );

    menu->addSeparator();

    {
        bool isPlayerVisible = mi->getMainInterfaceModes() & MainCtx::MAININTERFACE_MODE_PLAYER;
        action = menu->addAction(qtr("Big Player View"));
        action->setCheckable( true );
        action->setChecked( isPlayerVisible );
        connect( action, &QAction::triggered, mi, &MainCtx::setPlayerView);
    }

    /* FullScreen View */
    action = menu->addAction( qtr( "Fullscreen Interface" ), mi,
            &MainCtx::toggleInterfaceFullScreen );
    labelShortcut( action, "F11" );
    action->setCheckable( true );
    action->setChecked( mi->interfaceVisibility() == QWindow::FullScreen );

    /*Minimal View*/
    action = menu->addAction( qtr( "Minimal View" ) );
    labelShortcut( action, PLATFORM_SC( "Ctrl+Shift+H", "Ctrl+H" ) );
    action->setCheckable( true );
    connect( action, &QAction::triggered, mi, &MainCtx::setMinimalView );
    action->setChecked( mi->isMinimalView() );

    action = menu->addAction( qtr( "View Items as Grid" ), mi,
            &MainCtx::setGridView );
    action->setCheckable( true );
    action->setChecked( mi->hasGridView() );

    menu->addMenu( new CheckableListMenu(qtr( "Color Scheme" ), mi->getColorScheme(), QActionGroup::ExclusionPolicy::Exclusive, menu) );

    menu->addSeparator();

    InterfacesMenu( p_intf, menu );
    menu->addSeparator();

    /* Extensions */
    ExtensionsMenu( p_intf, menu );
}

/**
 * Interface Sub-Menu, to list extras interface and skins
 **/
void VLCMenuBar::InterfacesMenu( qt_intf_t *p_intf, QMenu *current )
{
    assert(current);
    VLCVarChoiceModel* model = new VLCVarChoiceModel(VLC_OBJECT(p_intf->intf), "intf-add", current);
    CheckableListMenu* submenu = new CheckableListMenu(qtr("Interfaces"), model, QActionGroup::ExclusionPolicy::None, current);
    current->addMenu(submenu);
}

/**
 * Extensions menu: populate the current menu with extensions
 **/
void VLCMenuBar::ExtensionsMenu( qt_intf_t *p_intf, QMenu *extMenu )
{
    /* Get ExtensionsManager and load extensions if needed */
    ExtensionsManager *extMgr = ExtensionsManager::getInstance( p_intf );

    if( !var_InheritBool( p_intf, "qt-autoload-extensions")
        && !extMgr->isLoaded() )
    {
        return;
    }

    if( !extMgr->isLoaded() && !extMgr->cannotLoad() )
    {
        extMgr->loadExtensions();
    }

    /* Let the ExtensionsManager build itself the menu */
    extMenu->addSeparator();
    extMgr->menu( extMenu );
}

void VLCMenuBar::VolumeEntries( qt_intf_t *p_intf, QMenu *current )
{
    current->addSeparator();

    labelHotkey( p_intf, current->addAction( qtr( "Increase Volume" ), THEMIM, &PlayerController::setVolumeUp ), "vol-up" );
    labelHotkey( p_intf, current->addAction( qtr( "Decrease Volume" ), THEMIM, &PlayerController::setVolumeDown ), "vol-down" );
    labelHotkey( p_intf, current->addAction( qtr( "Mute" ), THEMIM, &PlayerController::toggleMuted ), "vol-mute" );
}

/**
 * Main Audio Menu
 **/
void VLCMenuBar::AudioMenu( qt_intf_t *p_intf, QMenu * current )
{
    if( current->isEmpty() )
    {
        current->addMenu(new CheckableListMenu(qtr( "Audio Track" ), THEMIM->getAudioTracks(), QActionGroup::ExclusionPolicy::ExclusiveOptional, current));

        current->addMenu(new CheckableListMenu(qtr( "Audio Device" ), THEMIM->getAudioDevices(), QActionGroup::ExclusionPolicy::Exclusive, current));

        VLCVarChoiceModel *mix_mode = THEMIM->getAudioMixMode();
        if (mix_mode->rowCount() == 0)
            current->addMenu( new CheckableListMenu(qtr( "Stereo Mode" ), THEMIM->getAudioStereoMode(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        else
            current->addMenu( new CheckableListMenu(qtr( "Mix Mode" ), mix_mode, QActionGroup::ExclusionPolicy::Exclusive, current) );
        current->addSeparator();

        current->addMenu( new CheckableListMenu(qtr( "Visualizations" ), THEMIM->getAudioVisualizations(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        VolumeEntries( p_intf, current );
    }
}

/* Subtitles */
void VLCMenuBar::SubtitleMenu( qt_intf_t *p_intf, QMenu *current, bool b_popup )
{
    if( current->isEmpty() || b_popup )
    {
        addDPStaticEntry( current, qtr( "Add Subtitle File\u2026" ), "",
                &DialogsProvider::loadSubtitlesFile);
        current->addMenu(new CheckableListMenu(qtr( "Subtitle Track" ), THEMIM->getSubtitleTracks(), QActionGroup::ExclusionPolicy::ExclusiveOptional, current));
        current->addSeparator();
    }
}

/**
 * Main Video Menu
 * Subtitles are part of Video.
 **/
void VLCMenuBar::VideoMenu( qt_intf_t *p_intf, QMenu *current )
{
    if( current->isEmpty() )
    {
        current->addMenu(new CheckableListMenu(qtr( "Video Track" ), THEMIM->getVideoTracks(), QActionGroup::ExclusionPolicy::None, current));

        current->addSeparator();
        current->addMenu( new CheckableListMenu(qtr( "3D Output" ), THEMIM->getVideoStereoMode(), QActionGroup::ExclusionPolicy::Exclusive, current) );

        current->addSeparator();
        /* Surface modifiers */
        {
            QAction *fullscreen = new BooleanPropertyAction(qtr( "Fullscreen"), THEMIM, "fullscreen", current);
            labelHotkey( p_intf, fullscreen, "toggle-fullscreen" );
            current->addAction( fullscreen );
        }
        QAction* action = new BooleanPropertyAction(qtr( "Always Fit Window"), THEMIM, "autoscale", current);
        action->setEnabled( THEMIM->hasVideoOutput() );
        connect(THEMIM, &PlayerController::hasVideoOutputChanged, action, &QAction::setEnabled);
        current->addAction(action);
        current->addAction(new BooleanPropertyAction(qtr( "Set as Wallpaper"), THEMIM, "wallpaperMode", current));

        current->addSeparator();
        /* Size modifiers */
        current->addMenu( new CheckableListMenu(qtr( "Zoom" ), THEMIM->getZoom(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        current->addMenu( new CheckableListMenu(qtr( "Aspect Ratio" ), THEMIM->getAspectRatio(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        current->addMenu( new CheckableListMenu(qtr( "Crop" ), THEMIM->getCrop(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        current->addMenu( new CheckableListMenu(qtr( "Fit" ), THEMIM->getFit(), QActionGroup::ExclusionPolicy::Exclusive, current) );

        current->addSeparator();
        /* Rendering modifiers */
        current->addMenu( new CheckableListMenu(qtr( "Deinterlace" ), THEMIM->getDeinterlace(), QActionGroup::ExclusionPolicy::Exclusive, current) );
        current->addMenu( new CheckableListMenu(qtr( "Deinterlace Mode" ), THEMIM->getDeinterlaceMode(), QActionGroup::ExclusionPolicy::Exclusive, current) );

        current->addSeparator();
        /* Other actions */
        QAction* snapshotAction = new QAction(qtr( "Take Snapshot" ), current);
        connect(snapshotAction, &QAction::triggered, THEMIM, &PlayerController::snapshot);
        labelHotkey( p_intf, snapshotAction, "snapshot" );
        current->addAction(snapshotAction);
    }
}

/**
 * Navigation Menu
 * For DVD, MP4, MOV and other chapter based format
 **/
void VLCMenuBar::NavigMenu( qt_intf_t *p_intf, QMenu *menu )
{
    NavigTracksEntries( p_intf, menu );

    menu->addSeparator();

    if ( !VLCMenuBar::rendererMenu )
        VLCMenuBar::rendererMenu = new RendererMenu( NULL, p_intf, p_intf->p_mainPlayerController );

    menu->addMenu( VLCMenuBar::rendererMenu );
    menu->addSeparator();


    PopupMenuControlEntries( menu, p_intf );

    RebuildNavigMenu( p_intf, menu );
}

/** Titles, chapters, programs and bookmarks */
void VLCMenuBar::NavigTracksEntries( qt_intf_t *p_intf, QMenu *menu )
{
    QAction *action;
    QMenu *submenu;

    menu->addMenu( new CheckableListMenu( qtr( "Title" ), THEMIM->getTitles(), QActionGroup::ExclusionPolicy::Exclusive, menu) );
    submenu = new CheckableListMenu( qtr( "Chapter" ), THEMIM->getChapters(), QActionGroup::ExclusionPolicy::Exclusive, menu );
    submenu->setTearOffEnabled( true );
    menu->addMenu( submenu );
    menu->addMenu( new CheckableListMenu( qtr("Program") , THEMIM->getPrograms(), QActionGroup::ExclusionPolicy::Exclusive, menu) );

    MainCtx * mi = p_intf->p_mi;

    if (mi && p_intf->p_mi->hasMediaLibrary() )
    {
        MediaLib * mediaLib = mi->getMediaLibrary();

        BookmarkMenu * bookmarks = new BookmarkMenu(mediaLib, p_intf->p_player, menu);

        bookmarks->setTitle(menuTitle(qfut(I_MENU_BOOKMARK)));

        action = menu->addMenu(bookmarks);

        action->setData("bookmark");
    }

}

void VLCMenuBar::RebuildNavigMenu( qt_intf_t *p_intf, QMenu *menu )
{
    QAction* action;

#define ADD_ACTION( title, slot, visibleSignal, visible ) \
    action = menu->addAction( title, THEMIM,  slot ); \
    if (! visible)\
        action->setVisible(false); \
    connect( THEMIM, visibleSignal, action, &QAction::setVisible );

    ADD_ACTION( qtr("Previous Title"), &PlayerController::titlePrev, &PlayerController::hasTitlesChanged, THEMIM->hasTitles() );
    ADD_ACTION( qtr("Next Title"), &PlayerController::titleNext, &PlayerController::hasTitlesChanged, THEMIM->hasTitles() );
    ADD_ACTION( qtr("Previous Chapter"), &PlayerController::chapterPrev, &PlayerController::hasChaptersChanged, THEMIM->hasChapters() );
    ADD_ACTION( qtr("Next Chapter"), &PlayerController::chapterNext, &PlayerController::hasChaptersChanged, THEMIM->hasChapters() );

#undef ADD_ACTION

    PopupMenuPlaylistEntries( menu, p_intf );
}

/**
 * Help/About Menu
**/
void VLCMenuBar::HelpMenu(qt_intf_t *p_intf, QMenu *menu )
{
    addDPStaticEntry( menu, qtr( "VLC Help" ) ,
        ":/menu/help.svg", &DialogsProvider::helpDialog, PLATFORM_SC( "Ctrl+?", "F1" ) );
    addDPStaticEntry( menu, qtr( "Keyboard Shortcuts" ),
        "", &DialogsProvider::keyboardShortcutsDialog, "Ctrl+/" );
    menu->addAction( qtr( "VLC Website" ), []() {
        QDesktopServices::openUrl( QUrl( QStringLiteral("https://www.videolan.org/") ) );
    } );
    menu->addAction( qtr( "Report an Issue\u2026" ), []() {
        QDesktopServices::openUrl( QUrl( QStringLiteral("https://github.com/avishwakarma/vlc/issues") ) );
    } );
#ifdef UPDATE_CHECK
    addDPStaticEntry( menu, qtr( "Check for Updates\u2026" ) , "",
                     [ctx = QPointer(p_intf->p_mi)]() {
        if (Q_LIKELY(ctx))
        {
            const auto updateModel = ctx->getUpdateModel();
            assert(updateModel);
            updateModel->checkUpdate(true);
        }
    });
#endif
    menu->addSeparator();
    addDPStaticEntry( menu, qtr( "About VLC Redesign" ), ":/menu/info.svg",
            &DialogsProvider::aboutDialog, PLATFORM_SC( NULL, "Shift+F1" ), QAction::AboutRole );
}

/*****************************************************************************
 * Popup menus - Right Click menus                                           *
 *****************************************************************************/

void VLCMenuBar::PopupMenuPlaylistEntries( QMenu *menu, qt_intf_t *p_intf )
{
    QAction *action;
    bool hasInput = THEMIM->hasInput();

    /* Play or Pause action and icon */
    if( !hasInput || THEMIM->getPlayingState() != PlayerController::PLAYING_STATE_PLAYING )
    {
        action = menu->addAction( qtr( "Play" ), [p_intf]() {
            if ( THEMPL->isEmpty() )
                THEDP->openFileDialog();
            else
                THEMPL->togglePlayPause();
        });
        labelHotkey( p_intf, action, "play-pause" );
#ifndef __APPLE__ /* No icons in menus in Mac */
        action->setIcon( menuIcon( ":/menu/ic_fluent_play_filled.svg" ) );
#endif
    }
    else
    {
        action = addMPLStaticEntry( p_intf, menu, qtr( "Pause" ),
                ":/menu/ic_pause_filled.svg", &PlaylistController::togglePlayPause );
        labelHotkey( p_intf, action, "play-pause" );
    }

    /* Stop */
    action = addMPLStaticEntry( p_intf, menu, qtr( "Stop" ),
            ":/menu/ic_fluent_stop.svg", &PlaylistController::stop );
    labelHotkey( p_intf, action, "stop" );
    if( !hasInput )
        action->setEnabled( false );

    /* Next / Previous */
    bool bPlaylistEmpty = THEMPL->isEmpty();
    QAction* previousAction = addMPLStaticEntry( p_intf, menu, qtr( "Previous" ),
            ":/menu/ic_fluent_previous.svg", &PlaylistController::prev );
    labelHotkey( p_intf, previousAction, "prev" );
    previousAction->setEnabled( !bPlaylistEmpty );
    connect( THEMPL, &PlaylistController::isEmptyChanged, previousAction, &QAction::setDisabled);

    QAction* nextAction = addMPLStaticEntry( p_intf, menu, qtr( "Next" ),
            ":/menu/ic_fluent_next.svg", &PlaylistController::next );
    labelHotkey( p_intf, nextAction, "next" );
    nextAction->setEnabled( !bPlaylistEmpty );
    connect( THEMPL, &PlaylistController::isEmptyChanged, nextAction, &QAction::setDisabled);

    action = menu->addAction( qtr( "Record" ), THEMIM, &PlayerController::toggleRecord );
    action->setIcon( menuIcon( ":/menu/ic_fluent_record.svg" ) );
    labelHotkey( p_intf, action, "record" );
    if( !hasInput )
        action->setEnabled( false );
    menu->addSeparator();
}

void VLCMenuBar::PopupMenuControlEntries( QMenu *menu, qt_intf_t *p_intf,
                                        bool b_normal )
{
    QAction *action;
    QMenu *rateMenu = new QMenu( qtr( "Speed" ), menu );
    rateMenu->setTearOffEnabled( true );

    if( b_normal )
    {
        /* Faster/Slower */
        action = rateMenu->addAction( qtr( "Faster" ), THEMIM,
                                  &PlayerController::faster );
        labelHotkey( p_intf, action, "faster" );
#ifndef __APPLE__ /* No icons in menus in Mac */
        action->setIcon( menuIcon( ":/menu/ic_fluent_fast_forward.svg" ) );
#endif
    }

    action = rateMenu->addAction( menuIcon( ":/menu/ic_fluent_fast_forward.svg" ), qtr( "Faster (Fine)" ), THEMIM,
                              &PlayerController::littlefaster );
    labelHotkey( p_intf, action, "rate-faster-fine" );

    action = rateMenu->addAction( qtr( "Normal Speed" ), THEMIM,
                              &PlayerController::normalRate );
    labelHotkey( p_intf, action, "rate-normal" );

    action = rateMenu->addAction( menuIcon( ":/menu/ic_fluent_rewind.svg" ), qtr( "Slower (Fine)" ), THEMIM,
                              &PlayerController::littleslower );
    labelHotkey( p_intf, action, "rate-slower-fine" );

    if( b_normal )
    {
        action = rateMenu->addAction( qtr( "Slower" ), THEMIM,
                                  &PlayerController::slower );
        labelHotkey( p_intf, action, "slower" );
#ifndef __APPLE__ /* No icons in menus in Mac */
        action->setIcon( menuIcon( ":/menu/ic_fluent_rewind.svg" ) );
#endif
    }

    action = menu->addMenu( rateMenu );

    menu->addSeparator();

    if( !b_normal ) return;

    action = menu->addAction( qtr( "Jump Forward" ), THEMIM,
             &PlayerController::jumpFwd );
    labelHotkey( p_intf, action, "jump+short" );
#ifndef __APPLE__ /* No icons in menus in Mac */
    action->setIcon( menuIcon( ":/menu/ic_fluent_skip_forward_10.svg" ) );
#endif

    action = menu->addAction( qtr( "Jump Backward" ), THEMIM,
             &PlayerController::jumpBwd );
    labelHotkey( p_intf, action, "jump-short" );
#ifndef __APPLE__ /* No icons in menus in Mac */
    action->setIcon( menuIcon( ":/menu/ic_fluent_skip_back_10.svg" ) );
#endif

    action = menu->addAction( qtr( "Go to Time\u2026" ), THEDP, &DialogsProvider::gotoTimeDialog );
    labelShortcut( action, "Ctrl+T" );

    menu->addSeparator();
}

void VLCMenuBar::PopupMenuStaticEntries( QMenu *menu )
{
    QMenu *openmenu = new QMenu( qtr( "Open Media" ), menu );
    addDPStaticEntry( openmenu, qtr( "Open File\u2026" ),
        ":/menu/file.svg", &DialogsProvider::openFileDialog);
    addDPStaticEntry( openmenu, qtr( "Open Folder\u2026" ),
        ":/menu/folder.svg", &DialogsProvider::PLOpenDir);
    addDPStaticEntry( openmenu, qtr( "Open Disc…" ),
        ":/menu/disc.svg", &DialogsProvider::openDiscDialog);
    addDPStaticEntry( openmenu, qtr( "Open Location\u2026" ),
        ":/menu/network.svg", &DialogsProvider::openNetDialog);
    addDPStaticEntry( openmenu, qtr( "Open Capture Device…" ),
        ":/menu/capture-card.svg", &DialogsProvider::openCaptureDialog);
    menu->addMenu( openmenu );

    menu->addSeparator();

    addDPStaticEntry( menu, qtr( "Quit" ), ":/menu/exit.svg",
                      &DialogsProvider::quit, "Ctrl+Q", QAction::QuitRole );
}

/* Video Tracks and Subtitles tracks */
QMenu* VLCMenuBar::VideoPopupMenu( qt_intf_t *p_intf, bool show )
{
    QMenu* menu = new VLCMenu(p_intf);
    VideoMenu(p_intf, menu);
    if( show )
        menu->popup( QCursor::pos() );
    return menu;
}

/* Audio Tracks */
QMenu* VLCMenuBar::AudioPopupMenu( qt_intf_t *p_intf, bool show )
{
    QMenu* menu = new VLCMenu(p_intf);
    AudioMenu(p_intf, menu);
    if( show )
        menu->popup( QCursor::pos() );
    return menu;
}

/* Navigation stuff, and general menus ( open ), used only for skins */
QMenu* VLCMenuBar::MiscPopupMenu( qt_intf_t *p_intf, bool show )
{
    QMenu* menu = new VLCMenu(p_intf);

    menu->addSeparator();
    PopupMenuPlaylistEntries( menu, p_intf );

    menu->addSeparator();
    PopupMenuControlEntries( menu, p_intf );

    menu->addSeparator();
    PopupMenuStaticEntries( menu );

    if( show )
        menu->popup( QCursor::pos() );
    return menu;
}

/* Figma right-click menu */
QMenu* VLCMenuBar::PopupMenu( qt_intf_t *p_intf, bool show )
{
    /* Figma right-click menu (6065:13616): playback entries, hide UI, track
     * submenus, then settings / playlist / open / quit. */
    QMenu* menu = new VLCMenu(p_intf);
    menu->setMinimumWidth( 292 ); // Figma 6065:13616
    MainCtx *mi = p_intf->p_mi;
    const bool hasInput = THEMIM->hasInput();

    // shortcut is the name of a VLC hotkey ("key-<name>"), shown as a label only: the hotkey layer handles the key
    auto add = [=](const char *svg, const QString& text, const char *hotkey, auto &&slot) {
        QAction *action = menu->addAction( VLCMenuStyle::icon( svg ), text );
        if( !EMPTY_STR( hotkey ) )
            labelHotkey( p_intf, action, hotkey );
        QObject::connect( action, &QAction::triggered, menu, slot );
        return action;
    };
    auto addSub = [menu](const char *svg, const QString& text) {
        QMenu *submenu = new QMenu( text, menu );
        submenu->setIcon( VLCMenuStyle::icon( svg ) );
        return submenu;
    };

    QAction *action;

    if( !hasInput || THEMIM->getPlayingState() != PlayerController::PLAYING_STATE_PLAYING )
        add( "playback-twotone", qtr( "Play" ), "play-pause", [p_intf]() {
            if ( THEMPL->isEmpty() )
                THEDP->openFileDialog();
            else
                THEMPL->togglePlayPause();
        } );
    else
        add( "pause", qtr( "Pause" ), "play-pause", [=]() { THEMPL->togglePlayPause(); } );

    action = add( "stop-twotone", qtr( "Stop" ), "stop", [=]() { THEMPL->stop(); } );
    action->setEnabled( hasInput );

    const bool playlistEmpty = THEMPL->isEmpty();
    action = add( "previous-twotone", qtr( "Previous Item" ), "prev", [=]() { THEMPL->prev(); } );
    action->setEnabled( !playlistEmpty );
    action = add( "next-twotone", qtr( "Next Item" ), "next", [=]() { THEMPL->next(); } );
    action->setEnabled( !playlistEmpty );
    action = add( "record-twotone", qtr( "Record" ), "record", [=]() { THEMIM->toggleRecord(); } );
    action->setEnabled( hasInput );

    menu->addSeparator();

    if( mi )
        add( "ui-twotone", qtr( "Hide UI" ), nullptr, [mi]() { emit mi->toggleHideUIRequested(); } );

    menu->addSeparator();

    QMenu *submenu = addSub( "playback-selected-twotone", qtr( "Playback" ) );
    NavigMenu( p_intf, submenu );
    menu->addMenu( submenu )->setEnabled( hasInput && !submenu->isEmpty() );

    submenu = addSub( "video-twotone", qtr( "Video" ) );
    VideoMenu( p_intf, submenu );
    menu->addMenu( submenu )->setEnabled( hasInput && !submenu->isEmpty() );

    submenu = addSub( "audio-twotone", qtr( "Audio" ) );
    AudioMenu( p_intf, submenu );
    menu->addMenu( submenu )->setEnabled( hasInput && !submenu->isEmpty() );

    submenu = addSub( "subtitles-twotone", qtr( "Subtitles" ) );
    SubtitleMenu( p_intf, submenu, true );
    menu->addMenu( submenu )->setEnabled( hasInput );

    menu->addSeparator();

    {
        submenu = addSub( "settings-twotone", qtr( "More Settings" ) );
        ToolsMenu( p_intf, submenu );
        submenu->addSeparator();
        QMenu *viewmenu = new QMenu( qtr( "View" ), submenu );
        ViewMenu( p_intf, viewmenu );
        submenu->addMenu( viewmenu );
        menu->addMenu( submenu );

        submenu = addSub( "queue-twotone", qtr( "Queue" ) );
        action = submenu->addAction( VLCMenuStyle::icon( "shuffle-right-twotone" ), qtr( "Shuffle" ),
                                     [=](bool checked) { THEMPL->setRandom( checked ); } );
        action->setCheckable( true );
        action->setChecked( THEMPL->isRandom() );
        QActionGroup *repeatGroup = new QActionGroup( submenu );
        const struct { const char *title; PlaylistController::PlaybackRepeat mode; } repeats[] = {
            { N_("Repeat Off"), PlaylistController::PLAYBACK_REPEAT_NONE },
            { N_("Repeat One"), PlaylistController::PLAYBACK_REPEAT_CURRENT },
            { N_("Repeat All"), PlaylistController::PLAYBACK_REPEAT_ALL } };
        submenu->addSeparator();
        for( const auto& r : repeats )
        {
            action = submenu->addAction( VLCMenuStyle::icon( "repeat-right-twotone" ), qtr( r.title ),
                                         [=, mode = r.mode]() { THEMPL->setRepeatMode( mode ); } );
            action->setCheckable( true );
            action->setActionGroup( repeatGroup );
            action->setChecked( THEMPL->getRepeatMode() == r.mode );
        }
        submenu->addSeparator();
        submenu->addAction( VLCMenuStyle::icon( "save-twotone" ), qtr( "Save Queue as Playlist\u2026" ),
                            [=]() { THEDP->savePlayingToPlaylist(); } );
        menu->addMenu( submenu );

        submenu = addSub( "file-twotone", qtr( "Open Media" ) );
        submenu->addAction( VLCMenuStyle::icon( "file-twotone" ), qtr( "Open File\u2026" ), [=]() { THEDP->simpleOpenDialog(); } );
        submenu->addAction( VLCMenuStyle::icon( "folder-twotone" ), qtr( "Open Folder\u2026" ), [=]() { THEDP->PLOpenDir(); } );
        submenu->addAction( VLCMenuStyle::icon( "disc-twotone" ), qtr( "Open Disc\u2026" ), [=]() { THEDP->openDiscDialog(); } );
        submenu->addAction( VLCMenuStyle::icon( "streaming-twotone" ), qtr( "Open Location\u2026" ), [=]() { THEDP->openNetDialog(); } );
        submenu->addAction( VLCMenuStyle::icon( "capture-device-twotone" ), qtr( "Open Capture Device\u2026" ), [=]() { THEDP->openCaptureDialog(); } );
        menu->addMenu( submenu );
    }

    menu->addSeparator();
    action = add( "quit-twotone", qtr( "Quit" ), nullptr, [=]() { THEDP->quit(); } );
    labelShortcut( action, "Ctrl+Q" );
    action->setMenuRole( QAction::NoRole );

    if( show )
        menu->popup( QCursor::pos() );
    return menu;
}

#ifdef __APPLE__
/*****************************************************************************
 * macOS menu bar
 *****************************************************************************/

static QWindow *appTopLevelWindow()
{
    QWindow *w = QGuiApplication::focusWindow();
    if( !w )
    {
        for( QWindow *t : QGuiApplication::topLevelWindows() )
            if( t->isVisible() ) { w = t; break; }
    }
    while( w && w->parent() )
        w = w->parent();
    return w;
}

/**
 * Builds the whole menu bar: VLC, File, Playback, Audio, Video, Subtitles, Window, Help.
 * The entries come from the same builders as the pop-up menus; the shortcut labels are the real
 * key equivalents of the effective hotkey configuration (see labelHotkey).
 **/
void VLCMenuBar::MacMenuBar( qt_intf_t *p_intf, QMenuBar *bar )
{
    MainCtx *mi = p_intf->p_mi;
    s_nativeBar = true;

    // an entry that fires a VLC hotkey action, so the menu does exactly what the key does
    auto hotkeyEntry = [p_intf]( QMenu *menu, const QString& title, const char *hotkey ) {
        const QByteArray name = QByteArray( "key-" ) + hotkey;
        const vlc_action_id_t id = vlc_actions_get_id( name.constData() );
        QAction *action = menu->addAction( title );
        action->setMenuRole( QAction::NoRole );
        action->setProperty( "vlc-hotkey", QString::fromLatin1( hotkey ) );
        QObject::connect( action, &QAction::triggered, menu, [p_intf, id]() {
            var_SetInteger( vlc_object_instance( p_intf ), "key-action", id );
        } );
        labelHotkey( p_intf, action, hotkey );
        return action;
    };
    auto entry = []( QMenu *menu, const QString& title, auto &&slot, const char *shortcut = nullptr ) {
        QAction *action = menu->addAction( title );
        action->setMenuRole( QAction::NoRole );
        QObject::connect( action, &QAction::triggered, menu, slot );
        labelShortcut( action, shortcut );
        return action;
    };

    /* --- VLC (application menu): About, Settings, Quit; Hide/Services are added by Qt/macOS */
    QMenu *app = bar->addMenu( QStringLiteral("VLC") );
    QAction *about = app->addAction( qtr( "About VLC Redesign" ) );
    about->setMenuRole( QAction::AboutRole );
    QObject::connect( about, &QAction::triggered, app, []() { THEDP->aboutDialog(); } );
    QAction *prefs = app->addAction( qtr( "Settings…" ) );
    prefs->setMenuRole( QAction::PreferencesRole );
    prefs->setShortcut( QKeySequence( QKeySequence::Preferences ) );
    QObject::connect( prefs, &QAction::triggered, app, []() { THEDP->prefsDialog(); } );

    /* --- File */
    QMenu *file = bar->addMenu( qtr( "File" ) );
    FileMenu( p_intf, file );   // contains Quit (QuitRole: macOS moves it to the VLC menu)
    file->addSeparator();
    entry( file, qtr( "Close Window" ), []() {
        if( QWindow *w = appTopLevelWindow() ) w->close();
    }, "Ctrl+W" );

    /* --- Playback */
    QMenu *playback = bar->addMenu( qtr( "Playback" ) );
    hotkeyEntry( playback, qtr( "Play/Pause" ), "play-pause" );
    hotkeyEntry( playback, qtr( "Stop" ), "stop" );
    hotkeyEntry( playback, qtr( "Next Item" ), "next" );
    hotkeyEntry( playback, qtr( "Previous Item" ), "prev" );
    playback->addSeparator();
    PopupMenuControlEntries( playback, p_intf );   // Speed, Jump Forward/Backward, Go to Time
    hotkeyEntry( playback, qtr( "Next Frame" ), "frame-next" );
    hotkeyEntry( playback, qtr( "Previous Frame" ), "frame-previous" );
    playback->addSeparator();
    NavigTracksEntries( p_intf, playback );        // Title, Chapter, Program, Bookmarks
    playback->addSeparator();
    {
        QAction *shuffle = hotkeyEntry( playback, qtr( "Shuffle" ), "random" );
        shuffle->setCheckable( true );
        auto *repeatGroup = new QActionGroup( playback );
        const struct { const char *title; PlaylistController::PlaybackRepeat mode; } repeats[] = {
            { N_("Repeat Off"), PlaylistController::PLAYBACK_REPEAT_NONE },
            { N_("Repeat One"), PlaylistController::PLAYBACK_REPEAT_CURRENT },
            { N_("Repeat All"), PlaylistController::PLAYBACK_REPEAT_ALL } };
        QList<QPair<QAction *, PlaylistController::PlaybackRepeat>> repeatActions;
        for( const auto& r : repeats )
        {
            QAction *a = entry( playback, qtr( r.title ), [p_intf, mode = r.mode]() { THEMPL->setRepeatMode( mode ); } );
            a->setCheckable( true );
            a->setActionGroup( repeatGroup );
            repeatActions.append( { a, r.mode } );
        }
        QObject::connect( playback, &QMenu::aboutToShow, playback, [p_intf, shuffle, repeatActions]() {
            shuffle->setChecked( THEMPL->isRandom() );
            for( const auto& r : repeatActions )
                r.first->setChecked( THEMPL->getRepeatMode() == r.second );
        } );
    }

    /* --- Audio */
    QMenu *audio = bar->addMenu( qtr( "Audio" ) );
    AudioMenu( p_intf, audio );   // Track, Device, Stereo/Mix mode, Visualizations, Volume, Mute
    audio->addSeparator();
    hotkeyEntry( audio, qtr( "Next Audio Track" ), "audio-track" );
    hotkeyEntry( audio, qtr( "Next Audio Device" ), "audiodevice-cycle" );
    hotkeyEntry( audio, qtr( "Audio Delay Earlier" ), "audiodelay-down" );
    hotkeyEntry( audio, qtr( "Audio Delay Later" ), "audiodelay-up" );

    /* --- Video */
    QMenu *video = bar->addMenu( qtr( "Video" ) );
    VideoMenu( p_intf, video );   // Track, Fullscreen, Zoom, Aspect Ratio, Crop, Deinterlace, Snapshot
    if( mi )
    {
        video->addSeparator();
        QAction *top = entry( video, qtr( "Float on Top" ), [mi](bool checked) { mi->setInterfaceAlwaysOnTop( checked ); } );
        top->setCheckable( true );
        QObject::connect( video, &QMenu::aboutToShow, video, [top, mi]() { top->setChecked( mi->isInterfaceAlwaysOnTop() ); } );
    }

    /* --- Subtitles */
    QMenu *subs = bar->addMenu( qtr( "Subtitles" ) );
    SubtitleMenu( p_intf, subs );   // Add Subtitle File, Subtitle Track
    subs->addSeparator();
    hotkeyEntry( subs, qtr( "Next Subtitle Track" ), "subtitle-track" );
    hotkeyEntry( subs, qtr( "Show/Hide Subtitles" ), "subtitle-toggle" );
    subs->addSeparator();
    hotkeyEntry( subs, qtr( "Larger" ), "subtitle-text-scale-up" );
    hotkeyEntry( subs, qtr( "Smaller" ), "subtitle-text-scale-down" );
    hotkeyEntry( subs, qtr( "Normal Size" ), "subtitle-text-scale-normal" );
    subs->addSeparator();
    hotkeyEntry( subs, qtr( "Subtitle Delay Earlier" ), "subdelay-down" );
    hotkeyEntry( subs, qtr( "Subtitle Delay Later" ), "subdelay-up" );

    /* --- Window */
    QMenu *window = bar->addMenu( qtr( "Window" ) );
    entry( window, qtr( "Minimize" ), []() {
        if( QWindow *w = appTopLevelWindow() ) w->showMinimized();
    }, "Ctrl+M" );
    entry( window, qtr( "Zoom" ), []() {
        if( QWindow *w = appTopLevelWindow() )
        {
            if( w->visibility() == QWindow::Maximized ) w->showNormal(); else w->showMaximized();
        }
    } );
    window->addSeparator();
    if( mi )
    {
        entry( window, qtr( "Library" ), [mi]() { mi->setPlayerView( false ); } );
        QAction *queue = entry( window, qtr( "Queue" ), [mi](bool checked) { mi->getPlayqueuePanel()->setVisible( checked ); }, "Ctrl+L" );
        queue->setCheckable( true );
        QAction *minimal = entry( window, qtr( "Minimal View" ), [mi](bool checked) { mi->setMinimalView( checked ); },
                                  "Ctrl+Shift+H" );
        minimal->setCheckable( true );
        QObject::connect( window, &QMenu::aboutToShow, window, [queue, minimal, mi]() {
            queue->setChecked( mi->getPlayqueuePanel()->isVisible() );
            minimal->setChecked( mi->isMinimalView() );
        } );
        window->addSeparator();
    }
    InfoToolsMenu( p_intf, window );
    window->addSeparator();
    entry( window, qtr( "Customize Player…" ), []() { THEDP->showToolbarEditorDialog(); } );

    /* --- Help */
    QMenu *help = bar->addMenu( qtr( "Help" ) );
    HelpMenu( p_intf, help );
    // About lives in the VLC menu on macOS
    for( int i = 0; i < 2 && !help->actions().isEmpty(); ++i )
        delete help->actions().last();

    s_nativeBar = false;
}
#endif
