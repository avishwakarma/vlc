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
#ifndef MEDIAINFO_MODEL_HPP
#define MEDIAINFO_MODEL_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

#include "util/shared_input_item.hpp"
#include "maininterface/mainctx.hpp"

/**
 * Backend of the QML Media Information inspector (dialogs/forms/qml/MediaInfo.qml).
 * It shows either the item the DialogsProvider asked for (a library / queue entry), or
 * follows the playing media (then the live statistics are available).
 */
class MediaInfoModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    /// follows the playing media (statistics available)
    Q_PROPERTY(bool following READ following NOTIFY itemChanged FINAL)
    Q_PROPERTY(bool hasItem READ hasItem NOTIFY itemChanged FINAL)
    /// title, artist, album, genre, date, trackNumber, trackTotal, description, language,
    /// publisher, copyright, encodedBy, nowPlaying (strings)
    Q_PROPERTY(QVariantMap meta READ meta NOTIFY metaChanged FINAL)
    /// [{ key, value }] extra metadata (disc number, URL, custom tags)
    Q_PROPERTY(QVariantList extraMeta READ extraMeta NOTIFY metaChanged FINAL)
    /// [{ name, kind ("video"|"audio"|"subtitle"|"other"), infos: [{ name, value }] }]
    Q_PROPERTY(QVariantList streams READ streams NOTIFY streamsChanged FINAL)
    Q_PROPERTY(QUrl artwork READ artwork NOTIFY metaChanged FINAL)
    Q_PROPERTY(QString uri READ uri NOTIFY itemChanged FINAL)
    /// local path of a file, else the uri
    Q_PROPERTY(QString location READ location NOTIFY itemChanged FINAL)
    Q_PROPERTY(bool isLocalFile READ isLocalFile NOTIFY itemChanged FINAL)
    /// duration in ms (0 when unknown)
    Q_PROPERTY(qint64 duration READ duration NOTIFY itemChanged FINAL)
    /// live numbers: inputBytes, inputBitrate (kb/s), demuxBytes, contentBitrate (kb/s), corrupted,
    /// discontinuity, vDecoded, vDisplayed, vLate, vLost, aDecoded, aPlayed, aLost
    Q_PROPERTY(QVariantMap stats READ stats NOTIFY statsChanged FINAL)
    /// the last 60 values of the input bitrate (kb/s), for the graph
    Q_PROPERTY(QVariantList bitrateHistory READ bitrateHistory NOTIFY statsChanged FINAL)

public:
    explicit MediaInfoModel(QObject* parent = nullptr);
    ~MediaInfoModel() override;

    MainCtx* ctx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);

    bool following() const { return m_following; }
    bool hasItem() const { return m_item.get() != nullptr; }
    QVariantMap meta() const { return m_meta; }
    QVariantList extraMeta() const { return m_extra; }
    QVariantList streams() const { return m_streams; }
    QUrl artwork() const { return m_artwork; }
    QString uri() const { return m_uri; }
    QString location() const { return m_location; }
    bool isLocalFile() const { return m_isLocal; }
    qint64 duration() const { return m_duration; }
    QVariantMap stats() const { return m_stats; }
    QVariantList bitrateHistory() const { return m_history; }

    /// takes the pending request of the DialogsProvider (item, or follow the player)
    Q_INVOKABLE void loadRequest();
    /// writes the given fields (same keys as `meta`) to the item and to the file when possible
    Q_INVOKABLE bool save(const QVariantMap& fields);
    /// the user is typing: do not overwrite the fields on metadata updates
    Q_INVOKABLE void setEditing(bool editing) { m_editing = editing; }
    /// selects the file in Finder (Explorer / file manager elsewhere)
    Q_INVOKABLE void reveal();
    Q_INVOKABLE void copyText(const QString& text) const;
    /// "1 920 x 1 080 pixels" style helpers
    Q_INVOKABLE QString formatBytes(double bytes) const;

signals:
    void ctxChanged();
    void itemChanged();
    void metaChanged();
    void streamsChanged();
    void statsChanged();
    void saved(bool success);

private:
    void setItem(const SharedInputItem& item, bool following);
    void refreshMeta();
    void refreshStreams();
    void connectPlayer();
    void onStats(const input_stats_t& stats);

    MainCtx* m_ctx = nullptr;
    SharedInputItem m_item;
    bool m_following = false;
    bool m_editing = false;
    bool m_connected = false;

    QVariantMap m_meta;
    QVariantList m_extra;
    QVariantList m_streams;
    QUrl m_artwork;
    QString m_uri;
    QString m_location;
    bool m_isLocal = false;
    qint64 m_duration = 0;
    QVariantMap m_stats;
    QVariantList m_history;
};

#endif
