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
#include "waveform_service.hpp"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QStandardPaths>
#include <QThread>

#include <algorithm>
#include <cstring>
#include <mutex>

#include <vlc_common.h>
#include <vlc_tick.h>

#include "waveform_analyzer.h"

namespace {

// media longer than this are not analysed (CPU/battery), see W11 report
constexpr vlc_tick_t MAX_LENGTH = VLC_TICK_FROM_SEC(3 * 3600);

// cache: one small file per media, oldest dropped beyond these limits
constexpr int CACHE_MAX_ENTRIES = 2000;
constexpr qint64 CACHE_MAX_BYTES = 8 * 1024 * 1024;
constexpr char CACHE_MAGIC[4] = { 'V', 'L', 'W', 'F' };
constexpr quint8 CACHE_VERSION = 2;
constexpr quint8 CACHE_STATUS_OK = 0;
constexpr quint8 CACHE_STATUS_UNAVAILABLE = 1;

QPointer<WaveformService> s_instance;

} // namespace

/*****************************************************************************
 * Task: shared by the UI thread (cancel) and the pool thread (run)
 *****************************************************************************/

class WaveformTask : public std::enable_shared_from_this<WaveformTask>
{
public:
    QString mrl;
    QString cachePath;
    QString cacheDir;
    qt_intf_t* intf = nullptr;
    WaveformService* service = nullptr;  // outlives the pool thread

    // UI thread only
    QPointer<WaveformData> data;

    void cancel()
    {
        std::lock_guard<std::mutex> guard(m_lock);
        m_cancelled = true;
        if (m_analyzer)
            vlc_waveform_analyzer_Cancel(m_analyzer);
    }

    void run();

private:
    void post(WaveformData::State state, QVector<float> bins, double progress);
    bool readCache(QVector<float>& bins, bool& available);
    void writeCache(const QVector<float>& bins, bool available);
    void pruneCache();

    static void onProgress(void* opaque, const float* bins, unsigned count, double progress)
    {
        auto self = static_cast<WaveformTask*>(opaque);
        QVector<float> copy(bins, bins + count);
        self->m_last = copy;
        if (progress < 1.)
            self->post(WaveformData::State::Loading, std::move(copy), progress);
    }

    std::mutex m_lock;
    bool m_cancelled = false;
    vlc_waveform_analyzer* m_analyzer = nullptr;
    QVector<float> m_last;
};

void WaveformTask::post(WaveformData::State state, QVector<float> bins, double progress)
{
    std::shared_ptr<WaveformTask> self = shared_from_this();
    WaveformService* svc = service;
    QMetaObject::invokeMethod(svc, [svc, self, state, bins = std::move(bins), progress]() mutable {
        svc->onTaskUpdate(self, static_cast<int>(state), std::move(bins), progress);
    }, Qt::QueuedConnection);
}

void WaveformTask::run()
{
    {
        std::lock_guard<std::mutex> guard(m_lock);
        if (m_cancelled)
            return;
    }

    // analyses are background work: don't compete with playback
    QThread::currentThread()->setPriority(QThread::LowPriority);

    QVector<float> bins;
    bool available = false;
    if (readCache(bins, available))
    {
        msg_Dbg(intf, "waveform: %s from cache (%s)", qtu(mrl), available ? "peaks" : "unavailable");
        if (available)
            post(WaveformData::State::Ready, std::move(bins), 1.);
        else
            post(WaveformData::State::Unavailable, {}, 0.);
        return;
    }

    static const vlc_waveform_analyzer_cbs cbs = { &WaveformTask::onProgress };

    {
        std::lock_guard<std::mutex> guard(m_lock);
        if (m_cancelled)
            return;
        const QByteArray url = mrl.toUtf8();
        m_analyzer = vlc_waveform_analyzer_New(&intf->obj, url.constData(),
                                               WaveformService::BIN_COUNT, MAX_LENGTH,
                                               &cbs, this);
        if (!m_analyzer)
        {
            post(WaveformData::State::Unavailable, {}, 0.);
            return;
        }
    }

    const qint64 start = QDateTime::currentMSecsSinceEpoch();
    const int status = vlc_waveform_analyzer_Run(m_analyzer);

    {
        std::lock_guard<std::mutex> guard(m_lock);
        vlc_waveform_analyzer_Delete(m_analyzer);
        m_analyzer = nullptr;
    }

    msg_Dbg(intf, "waveform: %s status %d in %lld ms", qtu(mrl), status,
            static_cast<long long>(QDateTime::currentMSecsSinceEpoch() - start));

    switch (status)
    {
        case VLC_WAVEFORM_DONE:
            writeCache(m_last, true);
            post(WaveformData::State::Ready, m_last, 1.);
            break;
        case VLC_WAVEFORM_CANCELLED:
            return; // nobody is waiting for it, nothing cached
        case VLC_WAVEFORM_UNSUPPORTED:
        case VLC_WAVEFORM_ERROR:
        default:
            // remembered, so the same file isn't decoded again next time
            writeCache({}, false);
            post(WaveformData::State::Unavailable, {}, 0.);
            break;
    }
    pruneCache();
}

bool WaveformTask::readCache(QVector<float>& bins, bool& available)
{
    QFile file(cachePath);
    if (!file.open(QIODevice::ReadWrite))
        return false;

    const QByteArray content = file.readAll();
    if (content.size() < 8 || memcmp(content.constData(), CACHE_MAGIC, 4) != 0
        || static_cast<quint8>(content[4]) != CACHE_VERSION)
        return false;

    const quint8 status = static_cast<quint8>(content[5]);
    const quint16 count = static_cast<quint8>(content[6]) | (static_cast<quint8>(content[7]) << 8);

    if (status == CACHE_STATUS_UNAVAILABLE)
        available = false;
    else
    {
        if (count != WaveformService::BIN_COUNT || content.size() != 8 + count * 2)
            return false;
        bins.resize(count);
        const auto* p = reinterpret_cast<const uchar*>(content.constData()) + 8;
        for (int i = 0; i < count; i++)
            bins[i] = (p[2 * i] | (p[2 * i + 1] << 8)) / 65535.f;
        available = true;
    }

    // LRU: the modification time is the last use
    file.setFileTime(QDateTime::currentDateTime(), QFileDevice::FileModificationTime);
    return true;
}

void WaveformTask::writeCache(const QVector<float>& bins, bool available)
{
    if (!QDir().mkpath(cacheDir))
        return;

    QByteArray content;
    content.reserve(8 + bins.size() * 2);
    content.append(CACHE_MAGIC, 4);
    content.append(static_cast<char>(CACHE_VERSION));
    content.append(static_cast<char>(available ? CACHE_STATUS_OK : CACHE_STATUS_UNAVAILABLE));
    const quint16 count = available ? bins.size() : 0;
    content.append(static_cast<char>(count & 0xff));
    content.append(static_cast<char>(count >> 8));
    for (int i = 0; available && i < bins.size(); i++)
    {
        const quint16 v = static_cast<quint16>(std::clamp(bins[i], 0.f, 1.f) * 65535.f + .5f);
        content.append(static_cast<char>(v & 0xff));
        content.append(static_cast<char>(v >> 8));
    }

    QSaveFile file(cachePath);
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(content);
    file.commit();
}

void WaveformTask::pruneCache()
{
    QDir dir(cacheDir);
    const QFileInfoList entries = dir.entryInfoList({ QStringLiteral("*.wf") }, QDir::Files,
                                                    QDir::Time); // newest first
    qint64 total = 0;
    for (int i = 0; i < entries.size(); i++)
    {
        total += entries[i].size();
        if (i >= CACHE_MAX_ENTRIES || total > CACHE_MAX_BYTES)
            QFile::remove(entries[i].absoluteFilePath());
    }
}

/*****************************************************************************
 * WaveformData
 *****************************************************************************/

void WaveformData::update(State state, QVector<float> bins, double progress)
{
    m_state = state;
    m_progress = progress;
    if (state == State::Unavailable)
        m_bins.clear();
    else if (!bins.isEmpty())
        m_bins = std::move(bins);
    if (state != State::Loading)
        m_task.reset();
    emit changed();
}

/*****************************************************************************
 * WaveformService
 *****************************************************************************/

WaveformService::WaveformService(qt_intf_t* intf, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
{
    // one analysis at a time: a newer request cancels the older one anyway
    m_pool.setMaxThreadCount(1);
    m_pool.setExpiryTimeout(10000);
    m_pool.setObjectName(QStringLiteral("waveform"));

    m_cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                 + QStringLiteral("/waveforms");
}

WaveformService::~WaveformService()
{
    // VLC may quit in the middle of an analysis: cancel (interrupts the I/O
    // and the decoding loop), then wait for the pool thread, which returns
    // within a few milliseconds. Nothing else may use m_intf after that.
    for (const QWeakPointer<WaveformData>& weak : std::as_const(m_active))
    {
        if (WaveformDataPtr data = weak.toStrongRef())
            if (data->m_task)
                data->m_task->cancel();
    }
    m_pool.clear();
    m_pool.waitForDone();
}

WaveformService* WaveformService::instance(qt_intf_t* intf, QObject* owner)
{
    if (!s_instance && intf && owner)
        s_instance = new WaveformService(intf, owner);
    return s_instance;
}

WaveformService* WaveformService::existingInstance()
{
    return s_instance;
}

WaveformDataPtr WaveformService::request(const QUrl& mrl)
{
    // last reference gone: stop the analysis (never blocks)
    const auto deleter = [](WaveformData* data) {
        if (data->m_task)
            data->m_task->cancel();
        data->deleteLater();
    };

    const auto unavailable = [&deleter]() {
        WaveformDataPtr data(new WaveformData, deleter);
        data->m_state = WaveformData::State::Unavailable;
        return data;
    };

    // scope: local regular files only (no network, no discs, no directories)
    if (!mrl.isValid() || !mrl.isLocalFile())
        return unavailable();

    const QFileInfo info(mrl.toLocalFile());
    if (!info.isFile() || info.size() <= 0)
        return unavailable();

    const QString mrlString = mrl.toString(QUrl::FullyEncoded);
    const QString key = QString::fromLatin1(QCryptographicHash::hash(
        QStringLiteral("%1|%2|%3|%4|v%5").arg(mrlString)
                                      .arg(info.size())
                                      .arg(info.lastModified().toMSecsSinceEpoch())
                                      .arg(BIN_COUNT).arg(CACHE_VERSION).toUtf8(),
        QCryptographicHash::Sha1).toHex());

    for (auto it = m_active.begin(); it != m_active.end();)
    {
        if (it.value().isNull())
            it = m_active.erase(it);
        else
            ++it;
    }

    if (WaveformDataPtr existing = m_active.value(key).toStrongRef())
        return existing;

    WaveformDataPtr data(new WaveformData, deleter);

    auto task = std::make_shared<WaveformTask>();
    task->mrl = mrlString;
    task->cacheDir = m_cacheDir;
    task->cachePath = m_cacheDir + QLatin1Char('/') + key + QStringLiteral(".wf");
    task->intf = m_intf;
    task->service = this;
    task->data = data.get();
    data->m_task = task;

    m_active.insert(key, data);

    m_pool.start([task]() { task->run(); });
    return data;
}

void WaveformService::onTaskUpdate(const std::shared_ptr<WaveformTask>& task, int state,
                                   QVector<float> bins, double progress)
{
    WaveformData* data = task->data;
    if (!data)
        return;
    data->update(static_cast<WaveformData::State>(state), std::move(bins), progress);
}
