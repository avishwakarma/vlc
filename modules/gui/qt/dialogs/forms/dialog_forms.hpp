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
    Q_PROPERTY(bool mediaLibraryAvailable READ mediaLibraryAvailable NOTIFY ctxChanged FINAL)

public:
    explicit DialogForms(QObject* parent = nullptr);

    MainCtx* ctx() const { return m_ctx; }
    bool mediaLibraryAvailable() const { return m_ctx && m_ctx->hasMediaLibrary(); }
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

    /** native file chooser for media files, returns the selected URLs (empty if cancelled) */
    Q_INVOKABLE QStringList pickMediaFiles(const QString& title);

    /**
     * Creates a media library playlist and appends \`urls\` to it. Needs the media library
     * (mediaLibraryAvailable), returns false without it.
     */
    Q_INVOKABLE bool createPlaylist(const QString& name, const QStringList& urls);

    // --- Add Subtitles

    /** the playing media has a name/URL */
    Q_INVOKABLE bool hasCurrentMedia() const;
    Q_INVOKABLE QString currentMediaName() const;
    /** folder of the playing media when it is a local file, else the folder of the last open dialog */
    Q_INVOKABLE QUrl defaultSubtitleFolder() const;
    /** native folder chooser, returns \`start\` if cancelled */
    Q_INVOKABLE QUrl pickFolder(const QUrl& start);
    /** "~/Movies/Show" display text of a folder URL */
    Q_INVOKABLE QString folderText(const QUrl& folder) const;
    /** subtitle files of a local folder: [{ name, url }] sorted by name */
    Q_INVOKABLE QVariantList subtitleFiles(const QUrl& folder) const;
    /**
     * Items of the play queue that are files of \`folder\`, each with the subtitle file of the
     * folder that goes with it (same name, followed by a separator or the extension):
     * [{ index, name, subName, subUrl }]
     */
    Q_INVOKABLE QVariantList queueMatches(const QUrl& folder) const;
    /** adds subtitle files to the playing media (the first one is selected), returns how many were added */
    Q_INVOKABLE int attachSubtitles(const QStringList& urls);
    /**
     * pairs: [{ index, subUrl }] of queue items. The subtitle is added to the item as a
     * \`sub-file\` option so it is loaded whenever the item plays (not stored beyond the
     * queue), and attached right away to the playing item. Returns the number of items updated.
     */
    Q_INVOKABLE int assignToQueue(const QVariantList& pairs);

    // --- Go to Time

    /** playing time / length in ms (length 0 when unknown), and the jump */
    Q_INVOKABLE qint64 currentTimeMs() const;
    Q_INVOKABLE qint64 lengthMs() const;
    Q_INVOKABLE void seekToMs(qint64 ms);

    // --- Add to Playlist

    /** the media library playlists (MLPlaylistListModel; roles id, name, count, thumbnail...) */
    Q_PROPERTY(QObject* playlistModel READ playlistModel NOTIFY ctxChanged FINAL)
    Q_PROPERTY(bool playlistBusy READ playlistBusy NOTIFY playlistBusyChanged FINAL)
    QObject* playlistModel();
    bool playlistBusy() const;
    /** takes the media ids of the pending Add to Playlist request (DialogsProvider) */
    Q_INVOKABLE int takePlaylistMedias();
    /** appends the pending media to the playlist at `row` of playlistModel */
    Q_INVOKABLE void addToPlaylist(int row);
    /** creates a playlist with the pending media */
    Q_INVOKABLE void addToNewPlaylist(const QString& name);

signals:
    void ctxChanged();
    void playlistBusyChanged();

private:
    MainCtx* m_ctx = nullptr;
    class MLPlaylistListModel* m_playlistModel = nullptr;
    QVariantList m_playlistMedias;
};

#endif
