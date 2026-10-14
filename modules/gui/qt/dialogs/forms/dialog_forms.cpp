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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "dialog_forms.hpp"

#include "maininterface/mainctx.hpp"
#include "playlist/media.hpp"
#include "playlist/playlist_controller.hpp"
#include "qt.hpp"

#include <QClipboard>
#include <QGuiApplication>
#include <QRegularExpression>

#include <vlc_url.h>

using namespace vlc::playlist;

namespace
{

/** same normalisation as DialogsProvider::openUrlDialog() */
QString normalizeLocation(const QString& location)
{
    const QString trimmed = location.trimmed();
    if (trimmed.isEmpty())
        return {};

    char* uri;
    if (!trimmed.contains(QStringLiteral("://")))
        uri = vlc_path2uri(qtu(trimmed), nullptr);
    else
        uri = vlc_uri_fixup(qtu(trimmed));
    if (!uri)
        return {};

    const QString ret = qfu(uri);
    free(uri);
    return ret;
}

QStringList normalizedLocations(const QString& text)
{
    QStringList ret;
    const QStringList lines = text.split(QRegularExpression(QStringLiteral("[\\r\\n]+")), Qt::SkipEmptyParts);
    for (const QString& line : lines)
    {
        const QString uri = normalizeLocation(line);
        if (!uri.isEmpty())
            ret << uri;
    }
    return ret;
}

}

DialogForms::DialogForms(QObject* parent)
    : QObject(parent)
{
}

void DialogForms::setCtx(MainCtx* ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
}

int DialogForms::countLocations(const QString& text) const
{
    return normalizedLocations(text).size();
}

QString DialogForms::clipboardLocations() const
{
    const QString text = QGuiApplication::clipboard()->text().trimmed();
    if (text.isEmpty() || text.size() > 4096)
        return {};

    const QStringList lines = text.split(QRegularExpression(QStringLiteral("[\\r\\n]+")), Qt::SkipEmptyParts);
    for (const QString& line : lines)
        if (!line.trimmed().contains(QStringLiteral("://")))
            return {};
    return lines.join(QLatin1Char('\n'));
}

int DialogForms::openLocations(const QString& text, const QString& name, bool enqueue)
{
    if (!m_ctx)
        return 0;

    const QStringList uris = normalizedLocations(text);
    if (uris.isEmpty())
        return 0;

    const QString title = name.trimmed();
    QVector<Media> medias;
    medias.reserve(uris.size());
    for (int i = 0; i < uris.size(); ++i)
    {
        QString mediaName;
        if (!title.isEmpty())
            mediaName = (uris.size() == 1) ? title : QStringLiteral("%1 (%2)").arg(title).arg(i + 1);
        medias.push_back(Media{uris.at(i), mediaName});
    }

    qt_intf_t* p_intf = m_ctx->getIntf();
    THEMPL->append(medias, !enqueue);
    return uris.size();
}
