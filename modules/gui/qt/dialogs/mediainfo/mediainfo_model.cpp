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

#include "mediainfo_model.hpp"

#include "qt.hpp"
#include "player/player_controller.hpp"
#include "dialogs/dialogs_provider.hpp"

#include <QClipboard>
#include <QGuiApplication>
#include <QFileInfo>
#include <QDir>
#include <QDesktopServices>
#include <QProcess>
#include <QLocale>

#include <vlc_url.h>
#include <vlc_input_item.h>
#include <vlc_meta.h>
#include <vlc_list.hpp>
#include <vlc_interface.h>

namespace
{

QString takeString(char* str)
{
    const QString s = (str && *str) ? qfu(str) : QString();
    free(str);
    return s;
}

QString streamKind(const info_category_t& cat)
{
    /* the "Type" row of a stream holds the localized "Video" / "Audio" / "Subtitle" */
    const QString video = qfu(vlc_gettext("Video"));
    const QString audio = qfu(vlc_gettext("Audio"));
    const QString sub = qfu(vlc_gettext("Subtitle"));
    const QString type = qfu(vlc_gettext("Type"));
    for (auto& info : vlc::from(cat.infos, &info_t::node))
    {
        if (qfu(info.psz_name) != type)
            continue;
        const QString v = qfu(info.psz_value);
        if (v == video)
            return QStringLiteral("video");
        if (v == audio)
            return QStringLiteral("audio");
        if (v == sub)
            return QStringLiteral("subtitle");
    }
    return QStringLiteral("other");
}

}

MediaInfoModel::MediaInfoModel(QObject* parent)
    : QObject(parent)
{
}

MediaInfoModel::~MediaInfoModel() = default;

void MediaInfoModel::setCtx(MainCtx* ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
}

void MediaInfoModel::connectPlayer()
{
    if (m_connected || !m_ctx)
        return;
    qt_intf_t* p_intf = m_ctx->getIntf();
    PlayerController* player = THEMIM;
    if (!player)
        return;
    m_connected = true;

    connect(player, &PlayerController::inputChanged, this, [this](bool) {
        if (!m_following)
            return;
        qt_intf_t* p_intf = m_ctx->getIntf();
        setItem(SharedInputItem{THEMIM->getInput()}, true);
    });
    connect(player, &PlayerController::infoChanged, this, [this](input_item_t*) {
        if (m_following)
            refreshStreams();
    });
    connect(player, &PlayerController::currentMetaChanged, this, [this](input_item_t*) {
        if (m_following && !m_editing)
            refreshMeta();
    });
    connect(player, &PlayerController::statisticsUpdated, this, [this](const input_stats_t& s) {
        if (m_following)
            onStats(s);
    });
}

void MediaInfoModel::loadRequest()
{
    if (!m_ctx)
        return;
    qt_intf_t* p_intf = m_ctx->getIntf();
    connectPlayer();

    m_editing = false;
    SharedInputItem item = DialogsProvider::getInstance()->takeMediaInfoItem();
    if (item.get())
        setItem(item, false);
    else
        setItem(SharedInputItem{THEMIM->getInput()}, true);
}

void MediaInfoModel::setItem(const SharedInputItem& item, bool following)
{
    m_item = item;
    m_following = following;
    m_history.clear();
    m_stats.clear();
    m_editing = false;

    m_uri.clear();
    m_location.clear();
    m_isLocal = false;
    m_duration = 0;

    input_item_t* p_item = m_item.get();
    if (p_item)
    {
        m_uri = takeString(input_item_GetURI(p_item));
        if (char* path = vlc_uri2path(qtu(m_uri)))
        {
            m_location = qfu(path);
            m_isLocal = true;
            free(path);
        }
        else
            m_location = m_uri;
        m_duration = MS_FROM_VLC_TICK(input_item_GetDuration(p_item));
        if (following && p_item->p_stats)
            onStats(*p_item->p_stats);
    }

    refreshMeta();
    refreshStreams();
    emit itemChanged();
    emit statsChanged();
}

void MediaInfoModel::refreshMeta()
{
    m_meta.clear();
    m_extra.clear();
    m_artwork = QUrl();

    input_item_t* p_item = m_item.get();
    if (p_item)
    {
        m_meta[QStringLiteral("title")] = takeString(input_item_GetTitleFbName(p_item));
        m_meta[QStringLiteral("artist")] = takeString(input_item_GetArtist(p_item));
        m_meta[QStringLiteral("album")] = takeString(input_item_GetAlbum(p_item));
        m_meta[QStringLiteral("genre")] = takeString(input_item_GetGenre(p_item));
        m_meta[QStringLiteral("date")] = takeString(input_item_GetDate(p_item));
        m_meta[QStringLiteral("trackNumber")] = takeString(input_item_GetTrackNum(p_item));
        m_meta[QStringLiteral("trackTotal")] = takeString(input_item_GetTrackTotal(p_item));
        m_meta[QStringLiteral("description")] = takeString(input_item_GetDescription(p_item));
        m_meta[QStringLiteral("language")] = takeString(input_item_GetLanguage(p_item));
        m_meta[QStringLiteral("publisher")] = takeString(input_item_GetPublisher(p_item));
        m_meta[QStringLiteral("copyright")] = takeString(input_item_GetCopyright(p_item));
        m_meta[QStringLiteral("encodedBy")] = takeString(input_item_GetEncodedBy(p_item));
        m_meta[QStringLiteral("nowPlaying")] = takeString(input_item_GetNowPlayingFb(p_item));

        const QString art = takeString(input_item_GetArtURL(p_item));
        if (!art.isEmpty())
            m_artwork = QUrl(art);

        vlc_mutex_locker lock(&p_item->lock);
        vlc_meta_t* meta = p_item->p_meta;
        if (meta)
        {
            auto add = [this](const QString& key, const QString& value) {
                QVariantMap row;
                row[QStringLiteral("key")] = key;
                row[QStringLiteral("value")] = value;
                m_extra.push_back(row);
            };
            if (const char* disc = vlc_meta_Get(meta, vlc_meta_DiscNumber))
                add(qfu(VLC_META_DISCNUMBER), qfu(disc));
            if (const char* url = vlc_meta_Get(meta, vlc_meta_URL))
                add(qfu(VLC_META_URL), qfu(url));
            if (char** keys = vlc_meta_CopyExtraNames(meta))
            {
                for (int i = 0; keys[i]; ++i)
                {
                    const char* v = vlc_meta_GetExtra(meta, keys[i]);
                    add(qfu(keys[i]), v ? qfu(v) : QString());
                    free(keys[i]);
                }
                free(keys);
            }
        }
    }
    emit metaChanged();
}

void MediaInfoModel::refreshStreams()
{
    m_streams.clear();
    input_item_t* p_item = m_item.get();
    if (p_item)
    {
        vlc_mutex_locker locker(&p_item->lock);
        for (auto& cat : vlc::from(p_item->categories, &info_category_t::node))
        {
            if (info_category_IsHidden(&cat))
                continue;
            QVariantList infos;
            for (auto& info : vlc::from(cat.infos, &info_t::node))
            {
                QVariantMap row;
                row[QStringLiteral("name")] = qfu(info.psz_name);
                row[QStringLiteral("value")] = qfu(info.psz_value);
                infos.push_back(row);
            }
            QVariantMap stream;
            stream[QStringLiteral("name")] = qfu(cat.psz_name);
            stream[QStringLiteral("kind")] = streamKind(cat);
            stream[QStringLiteral("infos")] = infos;
            m_streams.push_back(stream);
        }
    }
    emit streamsChanged();
}

void MediaInfoModel::onStats(const input_stats_t& s)
{
    m_stats[QStringLiteral("inputBytes")] = qulonglong(s.i_read_bytes);
    m_stats[QStringLiteral("inputBitrate")] = double(s.f_input_bitrate * 8000);
    m_stats[QStringLiteral("demuxBytes")] = qulonglong(s.i_demux_read_bytes);
    m_stats[QStringLiteral("contentBitrate")] = double(s.f_demux_bitrate * 8000);
    m_stats[QStringLiteral("corrupted")] = qulonglong(s.i_demux_corrupted);
    m_stats[QStringLiteral("discontinuity")] = qulonglong(s.i_demux_discontinuity);
    m_stats[QStringLiteral("vDecoded")] = qulonglong(s.i_decoded_video);
    m_stats[QStringLiteral("vDisplayed")] = qulonglong(s.i_displayed_pictures);
    m_stats[QStringLiteral("vLate")] = qulonglong(s.i_late_pictures);
    m_stats[QStringLiteral("vLost")] = qulonglong(s.i_lost_pictures);
    m_stats[QStringLiteral("aDecoded")] = qulonglong(s.i_decoded_audio);
    m_stats[QStringLiteral("aPlayed")] = qulonglong(s.i_played_abuffers);
    m_stats[QStringLiteral("aLost")] = qulonglong(s.i_lost_abuffers);

    m_history.push_back(double(s.f_input_bitrate * 8000));
    while (m_history.size() > 60)
        m_history.removeFirst();
    emit statsChanged();
}

bool MediaInfoModel::save(const QVariantMap& f)
{
    input_item_t* input = m_item.get();
    if (!input || !m_ctx)
    {
        emit saved(false);
        return false;
    }
    qt_intf_t* p_intf = m_ctx->getIntf();

    auto s = [&f](const char* key) { return f.value(QLatin1String(key)).toString().toUtf8(); };
    input_item_SetTitle(input, s("title").constData());
    input_item_SetArtist(input, s("artist").constData());
    input_item_SetAlbum(input, s("album").constData());
    input_item_SetGenre(input, s("genre").constData());
    input_item_SetTrackNum(input, s("trackNumber").constData());
    input_item_SetTrackTotal(input, s("trackTotal").constData());
    input_item_SetDate(input, s("date").constData());
    input_item_SetLanguage(input, s("language").constData());
    input_item_SetCopyright(input, s("copyright").constData());
    input_item_SetPublisher(input, s("publisher").constData());
    input_item_SetDescription(input, s("description").constData());

    m_editing = false;
    const int ret = input_item_WriteMeta(VLC_OBJECT(p_intf), input);
    /* the player controller caches the metadata of the playing item */
    THEMIM->refreshMediaMeta(input);
    refreshMeta();
    emit saved(ret == VLC_SUCCESS);
    return ret == VLC_SUCCESS;
}

void MediaInfoModel::reveal()
{
    if (!m_isLocal)
        return;
    const QFileInfo info(m_location);
#ifdef Q_OS_MACOS
    QProcess::startDetached(QStringLiteral("/usr/bin/open"), {QStringLiteral("-R"), info.absoluteFilePath()});
#else
    QDesktopServices::openUrl(QUrl::fromLocalFile(info.absolutePath()));
#endif
}

void MediaInfoModel::copyText(const QString& text) const
{
    QGuiApplication::clipboard()->setText(text);
}

QString MediaInfoModel::formatBytes(double bytes) const
{
    static const char* units[] = {"B", "KiB", "MiB", "GiB", "TiB"};
    int u = 0;
    while (bytes >= 1024 && u < 4)
    {
        bytes /= 1024;
        ++u;
    }
    return QStringLiteral("%1 %2").arg(QLocale().toString(bytes, 'f', u == 0 ? 0 : 1)).arg(QLatin1String(units[u]));
}
