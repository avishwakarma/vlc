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

#include "vlc_menu_style.hpp"

#include "colorizedsvgicon.hpp"

#include <QAction>
#include <QActionEvent>
#include <QApplication>
#include <QDir>
#include <QEvent>
#include <QFile>
#include <QMenu>
#include <QObject>
#include <QStandardPaths>

namespace
{
    VLCMenuStyle::Colors s_colors;
    bool s_installed = false;

    class MenuPolishFilter : public QObject
    {
    public:
        using QObject::QObject;

        bool eventFilter(QObject *watched, QEvent *event) override
        {
            if (event->type() == QEvent::ActionAdded && qobject_cast<QMenu *>(watched))
            {
                // macOS hides action shortcuts in context menus by default, the Figma menus show them
                static_cast<QActionEvent *>(event)->action()->setShortcutVisibleInContextMenu(true);
            }
            else if (event->type() == QEvent::Polish)
            {
                if (auto menu = qobject_cast<QMenu *>(watched))
                {
                    // rounded translucent surface: frameless, no system shadow
                    menu->setWindowFlag(Qt::FramelessWindowHint, true);
                    menu->setWindowFlag(Qt::NoDropShadowWindowHint, true);
                    menu->setAttribute(Qt::WA_TranslucentBackground, true);
                }
            }
            return false;
        }
    };

    QString css(const QColor& c)
    {
        return QStringLiteral("rgba(%1, %2, %3, %4)")
            .arg(c.red()).arg(c.green()).arg(c.blue()).arg(c.alphaF(), 0, 'f', 3);
    }

    // The style sheet can only reference image files: write recoloured copies
    // of the resource icons to a cache folder.
    QString writeColorizedSvg(const QString& name, const QColor& color1, const QColor& accent)
    {
        QFile in(QStringLiteral(":/svgicons/%1.svg").arg(name));
        if (!in.open(QIODevice::ReadOnly))
            return {};
        QByteArray data = in.readAll();
        data.replace("#FF00FF", color1.name(QColor::HexRgb).toLatin1());
        data.replace("#FF8800", accent.name(QColor::HexRgb).toLatin1());
        data.replace("#00FFFF", accent.name(QColor::HexRgb).toLatin1());

        const QString dirPath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                                + QStringLiteral("/menu-style");
        QDir().mkpath(dirPath);
        const QString path = QStringLiteral("%1/%2-%3-%4.svg").arg(dirPath, name,
            color1.name(QColor::HexRgb).mid(1), accent.name(QColor::HexRgb).mid(1));
        QFile out(path);
        if (out.open(QIODevice::WriteOnly | QIODevice::Truncate))
            out.write(data);
        return path;
    }
}

namespace VLCMenuStyle
{

QString styleSheet(const Colors& c, const QString& checkImage, const QString& arrowImage)
{
    QString s;
    s += QStringLiteral("QMenu { background-color: %1; border: 1px solid %2; border-radius: 10px; padding: 4px; font-size: 14px; icon-size: 24px; }\n")
            .arg(css(c.surface), css(c.separator));
    s += QStringLiteral("QMenu::item { background: transparent; color: %1; min-height: 48px; max-height: 48px;"
                        " padding: 0px 24px 0px 19px; margin: 0px; min-width: 180px; border-radius: 6px; }\n")
            .arg(css(c.text));
    s += QStringLiteral("QMenu::item:selected { background-color: %1; color: %2; }\n")
            .arg(css(c.hover), css(c.textHover));
    s += QStringLiteral("QMenu::item:disabled { color: %1; background: transparent; }\n").arg(css(c.textDisabled));
    s += QStringLiteral("QMenu::icon { padding-left: 28px; width: 24px; height: 24px; }\n");
    s += QStringLiteral("QMenu::separator { height: 1px; background-color: %1; margin: 2px 0px 4px 0px; }\n")
            .arg(css(c.separator));
    s += QStringLiteral("QMenu::indicator { width: 24px; height: 24px; left: 10px; }\n");
    if (!checkImage.isEmpty())
        s += QStringLiteral("QMenu::indicator:non-exclusive:checked, QMenu::indicator:exclusive:checked"
                            " { image: url(%1); }\n").arg(checkImage);
    if (!arrowImage.isEmpty())
        s += QStringLiteral("QMenu::right-arrow { image: url(%1); width: 24px; height: 24px; }\n").arg(arrowImage);
    return s;
}

void setColors(const Colors& colors)
{
    if (!qApp)
        return;

    s_colors = colors;

    if (!s_installed)
    {
        s_installed = true;
        qApp->installEventFilter(new MenuPolishFilter(qApp));
    }

    const QString check = writeColorizedSvg(QStringLiteral("check-active"), colors.text, colors.accent);
    const QString arrow = writeColorizedSvg(QStringLiteral("chevron-right"), colors.textSecondary, colors.accent);

    QString sheet = styleSheet(colors, check, arrow);
    qApp->setStyleSheet(sheet);
}

QString iconImagePath(const QString& name)
{
    const QColor accent = s_colors.accent.isValid() ? s_colors.accent : QColor(QStringLiteral("#D37918"));
    const QColor color1 = s_colors.text.isValid() ? s_colors.text : QColor(QStringLiteral("#8F8F8F"));
    return writeColorizedSvg(name, color1, accent);
}

QString rightCheckStyleSheet()
{
    // checkable rows do not reserve a column for the indicator: the mark is painted by the menu
    // at the right edge (VLCMenu::setRightCheck). The rules replace the application ones.
    return qApp->styleSheet() + QStringLiteral(
        "QMenu::indicator { width: 0px; height: 0px; }\n"
        "QMenu::item:checked { background-color: %1; }\n").arg(css(s_colors.hover));
}

QIcon icon(const QString& name)
{
    const QColor accent = s_colors.accent.isValid() ? s_colors.accent : QColor(QStringLiteral("#D37918"));
    const QColor color1 = s_colors.text.isValid() ? s_colors.text : QColor(QStringLiteral("#8F8F8F"));
    return ColorizedSvgIcon(QStringLiteral(":/svgicons/%1.svg").arg(name), color1, accent.darker(125), accent);
}

}
