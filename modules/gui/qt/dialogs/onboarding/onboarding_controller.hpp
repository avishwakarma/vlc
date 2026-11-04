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
#ifndef ONBOARDING_CONTROLLER_HPP
#define ONBOARDING_CONTROLLER_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QObject>
#include <QUrl>
#include <QString>

#include "maininterface/mainctx.hpp"

/**
 * Backend of the QML onboarding (first run) window. Port of
 * FirstRunWizard::finish() plus the theme/folder helpers the QML needs.
 */
class OnboardingController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    // index in ColorSchemeModel (0 System, 1 Day, 2 Night, 3 Auto)
    Q_PROPERTY(int colorSchemeIndex READ colorSchemeIndex WRITE setColorSchemeIndex NOTIFY colorSchemeIndexChanged FINAL)
    // folder displayed in the media folder field, ~ abbreviated
    Q_PROPERTY(QString folderText READ folderText NOTIFY folderChanged FINAL)
    // debug aid: VLC_QT_ONBOARDING_STEP=N starts on step N (used for design comparison screenshots)
    Q_PROPERTY(int initialStep READ initialStep CONSTANT FINAL)
    Q_PROPERTY(bool mediaLibraryAvailable READ mediaLibraryAvailable NOTIFY ctxChanged FINAL)

public:
    explicit OnboardingController(QObject* parent = nullptr);

    MainCtx* ctx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);

    int colorSchemeIndex() const;
    void setColorSchemeIndex(int index);

    QString folderText() const;
    bool mediaLibraryAvailable() const;
    int initialStep() const { return qEnvironmentVariableIntValue("VLC_QT_ONBOARDING_STEP"); }

    /** opens a native directory chooser, updates the folder on accept */
    Q_INVOKABLE bool browse();
    /** user typed a path in the field */
    Q_INVOKABLE void setFolderText(const QString& text);

    /** metadataAccess: allow network access for metadata (cover art, track names...) */
    Q_INVOKABLE void finish(bool metadataAccess);

    /** "Skip": the wizard is not shown again, no folder is added and the metadata access stays off */
    Q_INVOKABLE void skip();

signals:
    void ctxChanged();
    void colorSchemeIndexChanged();
    void folderChanged();

private:
    MainCtx* m_ctx = nullptr;
    QUrl m_folder;
};

#endif
