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
#include "player/player_controller.hpp"
#include "playlist/media.hpp"
#include "medialibrary/medialib.hpp"
#include "medialibrary/mlplaylistlistmodel.hpp"
#include "dialogs/dialogs_provider.hpp"
#include "playlist/playlist_controller.hpp"
#include "qt.hpp"

#include <QClipboard>
#include <QGuiApplication>
#include <QRegularExpression>
#include <QTimer>
#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QStandardPaths>
#include <QCollator>

#include <vlc_url.h>
#include <vlc_playlist.h>
#include <vlc_input_item.h>
#include <vlc_interface.h>

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

QStringList DialogForms::pickMediaFiles(const QString& title)
{
    return THEDP->showSimpleOpen(title, EXT_FILTER_MEDIA | EXT_FILTER_VIDEO | EXT_FILTER_AUDIO);
}

bool DialogForms::createPlaylist(const QString& name, const QStringList& urls)
{
    if (!mediaLibraryAvailable() || name.trimmed().isEmpty())
        return false;

    auto model = new MLPlaylistListModel(this);
    model->setMl(m_ctx->getMediaLibrary());

    // create() appends the items in a second transaction once the playlist exists,
    // the model can go once both are done
    connect(model, &MLPlaylistListModel::transactionPendingChanged, model, [model](bool pending) {
        if (pending)
            return;
        QTimer::singleShot(0, model, [model]() {
            if (!model->transactionPending())
                model->deleteLater();
        });
    });

    QVariantList items;
    for (const QString& url : urls)
        items.push_back(url);
    model->create(name.trimmed(), items);
    return true;
}

// --- Add Subtitles

namespace
{

QStringList subtitleNameFilters()
{
    return QString::fromLatin1(EXTENSIONS_SUBTITLE).split(QLatin1Char(';'), Qt::SkipEmptyParts);
}

QFileInfoList subtitleFileInfos(const QUrl& folder)
{
    if (!folder.isLocalFile())
        return {};
    QDir dir(folder.toLocalFile());
    QFileInfoList list = dir.entryInfoList(subtitleNameFilters(), QDir::Files | QDir::Readable, QDir::NoSort);
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(list.begin(), list.end(), [&collator](const QFileInfo& a, const QFileInfo& b) {
        return collator.compare(a.fileName(), b.fileName()) < 0;
    });
    return list;
}

/** true when the subtitle \`sub\` goes with the video \`video\` (base names) */
bool subtitleMatches(const QString& videoBase, const QString& subBase, bool* exact)
{
    *exact = subBase.compare(videoBase, Qt::CaseInsensitive) == 0;
    if (*exact)
        return true;
    if (subBase.size() <= videoBase.size() || !subBase.startsWith(videoBase, Qt::CaseInsensitive))
        return false;
    return !subBase.at(videoBase.size()).isLetterOrNumber();
}

}

bool DialogForms::hasCurrentMedia() const
{
    if (!m_ctx)
        return false;
    qt_intf_t* p_intf = m_ctx->getIntf();
    return !THEMIM->getUrl().isEmpty();
}

QString DialogForms::currentMediaName() const
{
    if (!m_ctx)
        return {};
    qt_intf_t* p_intf = m_ctx->getIntf();
    return THEMIM->getName();
}

QUrl DialogForms::defaultSubtitleFolder() const
{
    if (m_ctx)
    {
        qt_intf_t* p_intf = m_ctx->getIntf();
        const QUrl url = THEMIM->getUrl();
        if (url.isLocalFile())
            return QUrl::fromLocalFile(QFileInfo(url.toLocalFile()).absolutePath());
    }

    QString dir = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
    if (dir.isEmpty())
        dir = QDir::homePath();
    return QUrl::fromLocalFile(dir);
}

QUrl DialogForms::pickFolder(const QUrl& start)
{
    const QUrl url = QFileDialog::getExistingDirectoryUrl(nullptr, qtr("Choose a folder with subtitles"),
            start, QFileDialog::ShowDirsOnly, QStringList(QStringLiteral("file")));
    return url.isEmpty() ? start : url;
}

QString DialogForms::folderText(const QUrl& folder) const
{
    QString path = folder.isLocalFile() ? folder.toLocalFile() : folder.toString();
    const QString home = QDir::homePath();
    if (path == home || path.startsWith(home + QLatin1Char('/')))
        path = QLatin1Char('~') + path.mid(home.size());
    return path.split(QLatin1Char('/'), Qt::SkipEmptyParts).join(QStringLiteral(" / "));
}

QVariantList DialogForms::subtitleFiles(const QUrl& folder) const
{
    QVariantList ret;
    for (const QFileInfo& info : subtitleFileInfos(folder))
        ret.push_back(QVariantMap{
            { QStringLiteral("name"), info.fileName() },
            { QStringLiteral("url"), QUrl::fromLocalFile(info.absoluteFilePath()) }
        });
    return ret;
}

QVariantList DialogForms::queueMatches(const QUrl& folder) const
{
    QVariantList ret;
    if (!m_ctx || !folder.isLocalFile())
        return ret;

    const QFileInfoList subs = subtitleFileInfos(folder);
    const QString folderPath = QDir(folder.toLocalFile()).absolutePath();

    qt_intf_t* p_intf = m_ctx->getIntf();
    vlc_playlist_t* playlist = THEMPL->getPlaylist().m_playlist;
    if (!playlist)
        return ret;

    vlc_playlist_Lock(playlist);
    const size_t count = vlc_playlist_Count(playlist);
    for (size_t i = 0; i < count; ++i)
    {
        input_item_t* media = vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, i));
        if (!media || !media->psz_uri)
            continue;
        const QUrl url = QUrl::fromEncoded(media->psz_uri);
        if (!url.isLocalFile())
            continue;
        const QFileInfo video(url.toLocalFile());
        if (video.absolutePath() != folderPath)
            continue;

        QString subName;
        QUrl subUrl;
        bool bestExact = false;
        for (const QFileInfo& sub : subs)
        {
            bool exact;
            if (!subtitleMatches(video.completeBaseName(), sub.completeBaseName(), &exact))
                continue;
            // exact name first, else the closest (shortest) one
            if (subName.isEmpty() || (exact && !bestExact)
                    || (!bestExact && sub.fileName().size() < subName.size()))
            {
                subName = sub.fileName();
                subUrl = QUrl::fromLocalFile(sub.absoluteFilePath());
                bestExact = exact;
            }
        }

        ret.push_back(QVariantMap{
            { QStringLiteral("index"), int(i) },
            { QStringLiteral("name"), video.fileName() },
            { QStringLiteral("subName"), subName },
            { QStringLiteral("subUrl"), subUrl }
        });
    }
    vlc_playlist_Unlock(playlist);
    return ret;
}

int DialogForms::attachSubtitles(const QStringList& urls)
{
    if (!m_ctx)
        return 0;
    qt_intf_t* p_intf = m_ctx->getIntf();

    int added = 0;
    for (const QString& url : urls)
    {
        // the first file is selected, the others only added to the track list
        if (THEMIM->AddAssociatedMedia(SPU_ES, url, added == 0, true, false) == VLC_SUCCESS)
            ++added;
        else
            msg_Warn(p_intf, "unable to load subtitle '%s'", qtu(url));
    }
    return added;
}

int DialogForms::assignToQueue(const QVariantList& pairs)
{
    if (!m_ctx)
        return 0;
    qt_intf_t* p_intf = m_ctx->getIntf();
    vlc_playlist_t* playlist = THEMPL->getPlaylist().m_playlist;
    if (!playlist)
        return 0;

    int updated = 0;
    QStringList attachNow;

    vlc_playlist_Lock(playlist);
    const size_t count = vlc_playlist_Count(playlist);
    const ssize_t current = vlc_playlist_GetCurrentIndex(playlist);
    for (const QVariant& pair : pairs)
    {
        const QVariantMap map = pair.toMap();
        const int index = map.value(QStringLiteral("index"), -1).toInt();
        const QUrl sub = map.value(QStringLiteral("subUrl")).toUrl();
        if (index < 0 || size_t(index) >= count || !sub.isLocalFile())
            continue;

        input_item_t* media = vlc_playlist_item_GetMedia(vlc_playlist_Get(playlist, index));
        if (!media)
            continue;

        const QString option = QStringLiteral(":sub-file=") + QDir::toNativeSeparators(sub.toLocalFile());
        if (input_item_AddOption(media, qtu(option), VLC_INPUT_OPTION_TRUSTED) != VLC_SUCCESS)
            continue;
        ++updated;
        if (index == current)
            attachNow << sub.toString();
    }
    vlc_playlist_Unlock(playlist);

    // the playing item has already been opened, add the subtitle to it directly
    for (const QString& url : attachNow)
        THEMIM->AddAssociatedMedia(SPU_ES, url, true, true, false);

    return updated;
}

// --- Go to Time

qint64 DialogForms::currentTimeMs() const
{
    if (!m_ctx)
        return 0;
    qt_intf_t* p_intf = m_ctx->getIntf();
    return THEMIM->getTime().toMilliseconds();
}

qint64 DialogForms::lengthMs() const
{
    if (!m_ctx)
        return 0;
    qt_intf_t* p_intf = m_ctx->getIntf();
    return THEMIM->getLength().toMilliseconds();
}

void DialogForms::seekToMs(qint64 ms)
{
    if (!m_ctx)
        return;
    qt_intf_t* p_intf = m_ctx->getIntf();
    THEMIM->setTime(VLCTime(VLC_TICK_FROM_MS(ms)));
}

// --- Add to Playlist

QObject* DialogForms::playlistModel()
{
    if (!m_playlistModel && m_ctx && m_ctx->hasMediaLibrary())
    {
        m_playlistModel = new MLPlaylistListModel(this);
        m_playlistModel->setMl(m_ctx->getMediaLibrary());
        connect(m_playlistModel, &MLPlaylistListModel::transactionPendingChanged,
                this, &DialogForms::playlistBusyChanged);
    }
    return m_playlistModel;
}

bool DialogForms::playlistBusy() const
{
    return m_playlistModel && m_playlistModel->transactionPending();
}

int DialogForms::takePlaylistMedias()
{
    m_playlistMedias = DialogsProvider::getInstance()->takePlaylistMedias();
    return m_playlistMedias.count();
}

void DialogForms::addToPlaylist(int row)
{
    if (!playlistModel() || m_playlistMedias.isEmpty())
        return;
    m_playlistModel->append(m_playlistModel->getItemId(row), m_playlistMedias);
}

void DialogForms::addToNewPlaylist(const QString& name)
{
    if (!playlistModel() || m_playlistMedias.isEmpty() || name.trimmed().isEmpty())
        return;
    m_playlistModel->create(name.trimmed(), m_playlistMedias);
}
