/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
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
#ifndef VLC_QT_WAVEFORM_SERVICE_HPP
#define VLC_QT_WAVEFORM_SERVICE_HPP

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QSharedPointer>
#include <QThreadPool>
#include <QUrl>
#include <QVector>

#include <memory>

#include "qt.hpp"

class WaveformTask;

/**
 * Peaks of one media, shared by every view showing it. Lives on the UI
 * thread; dropping the last reference cancels a running analysis.
 */
class WaveformData : public QObject
{
    Q_OBJECT

public:
    enum class State
    {
        Loading,     // in the queue or being analysed (bins fill in)
        Ready,       // complete
        Unavailable, // out of scope (stream, video, too long) or failed
    };

    State state() const { return m_state; }
    bool available() const { return m_state != State::Unavailable; }

    /** peaks 0..1 (max abs sample), negative = not analysed yet */
    const QVector<float>& bins() const { return m_bins; }
    double progress() const { return m_progress; }

signals:
    void changed();

private:
    friend class WaveformService;
    explicit WaveformData(QObject* parent = nullptr) : QObject(parent) {}

    void update(State state, QVector<float> bins, double progress);

    State m_state = State::Loading;
    QVector<float> m_bins;
    double m_progress = 0.;
    std::shared_ptr<WaveformTask> m_task;
};

using WaveformDataPtr = QSharedPointer<WaveformData>;

/**
 * Runs the analyses (one at a time, low priority, off the UI thread),
 * deduplicates requests and keeps the disk cache.
 */
class WaveformService : public QObject
{
    Q_OBJECT

public:
    static constexpr unsigned BIN_COUNT = 1024;

    explicit WaveformService(qt_intf_t* intf, QObject* parent = nullptr);
    ~WaveformService() override;

    /** service of the interface (created on first use), may be null */
    static WaveformService* instance(qt_intf_t* intf, QObject* owner);
    static WaveformService* existingInstance();

    /** peaks for a media; Unavailable right away when out of scope */
    WaveformDataPtr request(const QUrl& mrl);

private:
    friend class WaveformTask;

    void onTaskUpdate(const std::shared_ptr<WaveformTask>& task, int state,
                      QVector<float> bins, double progress);

    qt_intf_t* m_intf;
    QThreadPool m_pool;
    QString m_cacheDir;
    QHash<QString, QWeakPointer<WaveformData>> m_active;
};

#endif
