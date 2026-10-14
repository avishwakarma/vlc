/*****************************************************************************
 * Copyright (C) 2025 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifndef DIALOG_FORMS_HPP
#define DIALOG_FORMS_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantList>

#include "maininterface/mainctx.hpp"

/**
 * Backend of the QML form dialogs (Open Network Stream, New Playlist,
 * Add Subtitles). Instantiate it from QML with `ctx: MainCtx`.
 */
class DialogForms : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)

public:
    explicit DialogForms(QObject* parent = nullptr);

    MainCtx* ctx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);

    /**
     * `text`: one location per line (URLs or local paths). `name` (optional) is
     * the title of the new queue entries ("name" for a single location,
     * "name (n)" for several). Returns the number of locations queued.
     */
    Q_INVOKABLE int openLocations(const QString& text, const QString& name, bool enqueue);

    /** number of valid locations in `text` (to enable the primary button) */
    Q_INVOKABLE int countLocations(const QString& text) const;

    /** text of the clipboard when it holds one or more URLs, else "" */
    Q_INVOKABLE QString clipboardLocations() const;

signals:
    void ctxChanged();

private:
    MainCtx* m_ctx = nullptr;
};

#endif
