/*****************************************************************************
 * waveform_analyzer.h: audio peak extraction for the waveform seek bar
 *****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
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
#ifndef VLC_QT_WAVEFORM_ANALYZER_H
#define VLC_QT_WAVEFORM_ANALYZER_H

#include <vlc_common.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Peak extraction of the first audio track of a media.
 *
 * The media is demuxed and decoded without any clock (as fast as the CPU
 * allows) in the thread calling vlc_waveform_analyzer_Run(). Nothing is
 * rendered: no audio output, no stream output, no player involved.
 *
 * The result is a fixed number of bins covering [0, length] (same time base
 * as the player position), each holding the maximum absolute sample value
 * (0.0 .. 1.0) of all channels in that interval. Bins not analysed yet are
 * reported as a negative value.
 */
typedef struct vlc_waveform_analyzer vlc_waveform_analyzer;

enum vlc_waveform_status
{
    VLC_WAVEFORM_DONE = 0,
    VLC_WAVEFORM_CANCELLED,     /**< vlc_waveform_analyzer_Cancel() was called */
    VLC_WAVEFORM_ERROR,         /**< cannot open/demux, no decodable audio */
    VLC_WAVEFORM_UNSUPPORTED,   /**< has video, unknown length or too long */
};

struct vlc_waveform_analyzer_cbs
{
    /**
     * Called from the analysis thread, at most every ~100 ms and once at the
     * end (with progress = 1.0 when done).
     *
     * \param bins bin_count values, negative = not analysed yet; only valid
     *             during the call
     * \param progress 0.0 .. 1.0
     */
    void (*on_progress)(void *opaque, const float *bins, unsigned bin_count,
                        double progress);
};

/**
 * Create an analyzer (no thread is started).
 *
 * \param parent parent object (the interface)
 * \param mrl media to analyse
 * \param bin_count number of output bins (> 0)
 * \param max_length media longer than this are rejected (UNSUPPORTED)
 */
vlc_waveform_analyzer *
vlc_waveform_analyzer_New(vlc_object_t *parent, const char *mrl,
                          unsigned bin_count, vlc_tick_t max_length,
                          const struct vlc_waveform_analyzer_cbs *cbs,
                          void *opaque);

/**
 * Run the analysis synchronously. Blocks until done, failed or cancelled.
 * Must be called once.
 *
 * \return a vlc_waveform_status
 */
int vlc_waveform_analyzer_Run(vlc_waveform_analyzer *);

/**
 * Request the cancellation of a running (or not yet started) analysis.
 * Thread-safe, never blocks. Interrupts blocking I/O of the analysis thread.
 */
void vlc_waveform_analyzer_Cancel(vlc_waveform_analyzer *);

/**
 * Destroy the analyzer. Run() must have returned (or never been called).
 */
void vlc_waveform_analyzer_Delete(vlc_waveform_analyzer *);

#ifdef __cplusplus
}
#endif

#endif
