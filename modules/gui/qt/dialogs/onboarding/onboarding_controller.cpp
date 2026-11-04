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

#include "onboarding_controller.hpp"

#include "maininterface/mainctx.hpp"
#include "util/color_scheme_model.hpp"
#include "medialibrary/medialib.hpp"
#include "qt.hpp"

#include <QFileDialog>
#include <QDir>
#include <QStandardPaths>

#include <vlc_media_library.h>

static const char* const ML_FOLDER_ADD_QUEUE = "ML_FOLDER_ADD_QUEUE";

OnboardingController::OnboardingController(QObject* parent)
    : QObject(parent)
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
    if (dir.isEmpty())
        dir = QDir::homePath();
    m_folder = QUrl::fromLocalFile(dir);
}

void OnboardingController::setCtx(MainCtx* ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    if (m_ctx)
        connect(m_ctx->getColorScheme(), &ColorSchemeModel::currentChanged,
                this, &OnboardingController::colorSchemeIndexChanged);
    emit ctxChanged();
    emit colorSchemeIndexChanged();
}

int OnboardingController::colorSchemeIndex() const
{
    return m_ctx ? m_ctx->getColorScheme()->currentIndex() : 0;
}

void OnboardingController::setColorSchemeIndex(int index)
{
    if (m_ctx)
        m_ctx->getColorScheme()->setCurrentIndex(index);
}

QString OnboardingController::folderText() const
{
    QString path = QDir::toNativeSeparators(m_folder.toLocalFile());
    const QString home = QDir::toNativeSeparators(QDir::homePath());
    if (path.startsWith(home))
        path = QStringLiteral("~") + path.mid(home.size());
    return path;
}

bool OnboardingController::mediaLibraryAvailable() const
{
    return m_ctx && m_ctx->getMediaLibrary();
}

bool OnboardingController::browse()
{
    const QUrl url = QFileDialog::getExistingDirectoryUrl(nullptr,
            qtr("Choose a folder to add to the Media Library"), m_folder,
            QFileDialog::ShowDirsOnly, QStringList(QStringLiteral("file")));
    if (url.isEmpty())
        return false;
    m_folder = url;
    emit folderChanged();
    return true;
}

void OnboardingController::setFolderText(const QString& text)
{
    QString path = text.trimmed();
    if (path.startsWith(QLatin1Char('~')))
        path = QDir::homePath() + path.mid(1);
    const QUrl url = QUrl::fromLocalFile(path);
    if (path.isEmpty() || url == m_folder)
        return;
    m_folder = url;
    emit folderChanged();
}

void OnboardingController::skip()
{
    if (!m_ctx)
        return;
    config_PutInt("qt-privacy-ask", 0);
    m_ctx->reloadPrefs();
    config_SaveConfigFile(m_ctx->getIntf());
}

void OnboardingController::finish(bool metadataAccess)
{
    if (!m_ctx)
        return;
    qt_intf_t* p_intf = m_ctx->getIntf();

    config_PutInt("metadata-network-access", metadataAccess);
    config_PutInt("qt-privacy-ask", 0);

    /* Add the chosen folder to the Media Library and reload the indexing service */
    if (MediaLib* ml = m_ctx->getMediaLibrary())
    {
        const QUrl folder = m_folder;
        if (QDir(folder.toLocalFile()).exists())
        {
            // the main context outlives this window, so the task isn't cancelled with it
            ml->runOnMLThread(m_ctx,
                [folder](vlc_medialibrary_t* ml) {
                    vlc_ml_add_folder(ml, qtu(folder.toString(QUrl::FullyEncoded)));
                },
                ML_FOLDER_ADD_QUEUE);
        }
        ml->reload();
    }

    m_ctx->reloadPrefs();
    config_SaveConfigFile(p_intf);
}
