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
#ifndef OPEN_ADVANCED_HPP
#define OPEN_ADVANCED_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include "maininterface/mainctx.hpp"

/**
 * Backend of the QML "Open Media (advanced)" dialog (OpenAdvanced.qml), the replacement of the
 * OpenDialog widget (File / Disc / Network / Capture Device + "Show more options").
 * It builds the same MRLs and input options as the widget panels (open_panels.cpp) and runs the
 * same actions as OpenDialog (play, enqueue, stream, convert).
 * Instantiate it from QML with `ctx: MainCtx`.
 */
class OpenAdvanced : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    /// capture modes of this platform: [{ id: "camera"|"audio"|"screen", label }]
    Q_PROPERTY(QVariantList captureModes READ captureModes NOTIFY ctxChanged FINAL)

public:
    // actions of submit()
    enum Action { Play = 0, Enqueue = 1, Stream = 2, Convert = 3 };
    Q_ENUM(Action)

    explicit OpenAdvanced(QObject* parent = nullptr);

    MainCtx* ctx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);
    QVariantList captureModes() const;

    /// the QML dialog can handle this tab (0 file, 1 disc, 2 network, 3 capture) on this platform
    static bool supportsTab(int tab);

    // --- File

    /// native multi-file chooser, URLs (empty if cancelled)
    Q_INVOKABLE QStringList pickFiles();
    /// native chooser for one subtitle file / one media file (slave), "" if cancelled
    Q_INVOKABLE QString pickSubtitle();
    Q_INVOKABLE QString pickMedia();
    /// "/Users/me/Movies/a.mkv" for a file URL
    Q_INVOKABLE QString displayPath(const QString& url) const;
    /// the subtitle option (:sub-file=...) of a subtitle URL
    Q_INVOKABLE QString subtitleOption(const QString& url) const;

    // --- Disc

    /// disc types: 0 DVD, 1 Blu-ray, 2 Audio CD, 3 VCD, 4 DVD-Audio
    /// [{ path, label }]: /dev entries and the mounted discs
    Q_INVOKABLE QVariantList discDevices() const;
    /// default device of the preferences for the disc type
    Q_INVOKABLE QString defaultDiscDevice(int type) const;
    Q_INVOKABLE bool blurayMenuDefault() const;
    Q_INVOKABLE QString pickDiscFolder();
    Q_INVOKABLE void eject(const QString& device);
    /// { items: [mrl], options: [opt], caching: "disc-caching" }
    Q_INVOKABLE QVariantMap discMrl(int type, const QString& device, int title, int chapter,
                                    int audioTrack, int subtitleTrack, bool noMenus) const;

    // --- Network

    /// { items, caching: "network-caching" } for the lines of the text (same normalisation as the Network form)
    Q_INVOKABLE QStringList networkItems(const QString& text) const;

    // --- Capture

    /// [{ id, label }] of the video / audio capture devices (AVFoundation on macOS)
    Q_INVOKABLE QVariantList captureDevices(const QString& kind) const;
    /// { items, options, caching: "live-caching" }
    Q_INVOKABLE QVariantMap captureMrl(const QString& mode, const QString& videoDevice,
                                       const QString& audioDevice, double fps) const;

    // --- Common

    /// default caching (ms) of the preference named `method` (file-caching, disc-caching, ...)
    Q_INVOKABLE int cachingDefault(const QString& method) const;
    /// parses 1:23:45 / 83 / 1h2m3s, seconds or -1 when invalid, 0 when empty
    Q_INVOKABLE double parseTime(const QString& text) const;
    /// the "more options" as input options: caching, start/stop time (seconds, <= 0 unset), slave, free text
    Q_INVOKABLE QStringList commonOptions(const QString& method, int caching, double start, double stop,
                                          const QString& slave, const QString& extra) const;
    /**
     * Runs the action for `items` (MRLs) with `options` (list of "name=value").
     * `names`: optional title per item. Returns the number of items handled.
     */
    Q_INVOKABLE int submit(int action, const QStringList& items, const QStringList& names,
                           const QStringList& options);

signals:
    void ctxChanged();

private:
    MainCtx* m_ctx = nullptr;
};

#endif
