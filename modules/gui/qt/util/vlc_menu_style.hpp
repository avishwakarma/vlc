/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
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

#ifndef VLC_MENU_STYLE_HPP
#define VLC_MENU_STYLE_HPP

#include <QColor>
#include <QIcon>
#include <QString>

// Palette driven styling of native QMenu (Figma menu: radius 10, translucent
// BG/A4 surface, 48 px rows, separators, accent check marks, SVG icons).
//
// SystemPalette publishes the colors of its `Menu` set with `setColors()`
// whenever the theme or accent changes; this regenerates an application wide
// style sheet that only targets QMenu. Menus are made translucent and
// frameless (needed for the rounded corners) when they are polished.
namespace VLCMenuStyle
{
    struct Colors
    {
        QColor surface;       // Menu Bg.Primary (translucent)
        QColor hover;         // Menu Bg.Primary@Hovered
        QColor text;          // Menu Fg.Primary
        QColor textHover;     // Menu Fg.Primary@Hovered
        QColor textSecondary; // Menu Fg.Secondary (shortcuts)
        QColor textDisabled;  // Menu Fg.Primary@Disabled
        QColor separator;     // Menu Decoration.Separator
        QColor accent;        // Menu Decoration.Accent
    };

    // Installs the style sheet and the menu polish filter (first call), then updates colors.
    void setColors(const Colors& colors);

    // The style sheet generated for `colors`.
    QString styleSheet(const Colors& colors, const QString& checkImage, const QString& arrowImage);

    // Menu-local style sheet for menus whose check marks are drawn at the right edge.
    QString rightCheckStyleSheet(bool descending);

    // Menu icon from pixmaps/svg_icons (`name` without extension, e.g. "home"),
    // recoloured with the current menu colors. Use with QAction::setIcon().
    QIcon icon(const QString& name);
}

#endif // VLC_MENU_STYLE_HPP
