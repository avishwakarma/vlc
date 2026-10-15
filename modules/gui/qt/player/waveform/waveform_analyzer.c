/*****************************************************************************
 * waveform_analyzer.c: audio peak extraction for the waveform seek bar
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

/*
 * Pipeline: vlc_stream_NewURL (access + automatic stream filters such as
 * skiptags) -> demux_New("any") with a private es_out -> packetizer ->
 * audio decoder. The decoded blocks are reduced to peaks right away and
 * released. There is no clock, so it runs as fast as decoding allows.
 *
 * Only the first audio ES is selected (ES_OUT_GET_ES_STATE returns false
 * for the others, so demuxers can skip their data). A media with a video
 * ES is rejected: the waveform is for audio files.
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <math.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

#include <vlc_common.h>
#include <vlc_aout.h>
#include <vlc_block.h>
#include <vlc_codec.h>
#include <vlc_demux.h>
#include <vlc_es.h>
#include <vlc_es_out.h>
#include <vlc_interrupt.h>
#include <vlc_stream.h>

#include "waveform_analyzer.h"

/* fine bins per output bin: the fine array is time based and is re-binned
 * to the output bins with the latest known length */
#define FINE_FACTOR 16
#define REPORT_INTERVAL VLC_TICK_FROM_MS(100)

struct es_out_id_t
{
    struct es_out_id_t *next;
    es_format_t fmt;
};

struct wf_decoder
{
    decoder_t dec;
    es_format_t fmt_in;
    vlc_waveform_analyzer *owner;
};

struct vlc_waveform_analyzer
{
    es_out_t out;

    vlc_object_t *obj;
    char *mrl;
    unsigned bin_count;
    vlc_tick_t max_length;

    const struct vlc_waveform_analyzer_cbs *cbs;
    void *opaque;

    vlc_interrupt_t *interrupt;
    atomic_bool cancelled;

    /* es_out state (analysis thread only) */
    struct es_out_id_t *es_list;
    struct es_out_id_t *audio;
    bool has_video;
    struct wf_decoder *packetizer;
    struct wf_decoder *decoder;

    /* peaks (analysis thread only) */
    vlc_tick_t origin;
    vlc_tick_t length;
    vlc_tick_t next_pts;
    vlc_tick_t reached;     /* end of the analysed range, relative to origin */
    double *fine;           /* sum of the frame powers per fine bin */
    uint32_t *fine_n;       /* frames per fine bin */
    size_t fine_count;
    double fine_dt;         /* ticks per fine bin */
    uint64_t frames;
    bool overflow;
    float *out_bins;
    vlc_tick_t last_report;
};

static bool IsCancelled(vlc_waveform_analyzer *a)
{
    return atomic_load_explicit(&a->cancelled, memory_order_relaxed);
}

/*****************************************************************************
 * Peaks
 *****************************************************************************/

/* Mean power (mean of the squared samples over all channels) of one frame */
static double FramePower(const audio_format_t *fmt, const uint8_t *p,
                         unsigned channels)
{
    double sum = 0.;

    switch (fmt->i_format)
    {
        case VLC_CODEC_FL32:
        {
            const float *s = (const float *)p;
            for (unsigned c = 0; c < channels; c++)
                if (isfinite(s[c]))
                    sum += (double)s[c] * s[c];
            break;
        }
        case VLC_CODEC_FL64:
        {
            const double *s = (const double *)p;
            for (unsigned c = 0; c < channels; c++)
                if (isfinite(s[c]))
                    sum += s[c] * s[c];
            break;
        }
        case VLC_CODEC_S16N:
        {
            const int16_t *s = (const int16_t *)p;
            for (unsigned c = 0; c < channels; c++)
            {
                const double v = s[c] / 32768.;
                sum += v * v;
            }
            break;
        }
        case VLC_CODEC_S32N:
        {
            const int32_t *s = (const int32_t *)p;
            for (unsigned c = 0; c < channels; c++)
            {
                const double v = s[c] / 2147483648.;
                sum += v * v;
            }
            break;
        }
        case VLC_CODEC_U8:
            for (unsigned c = 0; c < channels; c++)
            {
                const double v = (p[c] - 128) / 128.;
                sum += v * v;
            }
            break;
    }
    return sum / channels;
}

static bool IsSupportedFormat(vlc_fourcc_t fourcc)
{
    switch (fourcc)
    {
        case VLC_CODEC_FL32:
        case VLC_CODEC_FL64:
        case VLC_CODEC_S16N:
        case VLC_CODEC_S32N:
        case VLC_CODEC_U8:
            return true;
        default:
            return false;
    }
}

/* Double the time span of the fine array (merge pairs of bins) */
static void GrowFine(vlc_waveform_analyzer *a)
{
    const size_t half = a->fine_count / 2;
    for (size_t i = 0; i < half; i++)
    {
        a->fine[i] = a->fine[2 * i] + a->fine[2 * i + 1];
        a->fine_n[i] = a->fine_n[2 * i] + a->fine_n[2 * i + 1];
    }
    memset(&a->fine[half], 0, (a->fine_count - half) * sizeof (*a->fine));
    memset(&a->fine_n[half], 0, (a->fine_count - half) * sizeof (*a->fine_n));
    a->fine_dt *= 2.;
}

static void Accumulate(vlc_waveform_analyzer *a, const audio_format_t *fmt,
                       const block_t *block)
{
    const unsigned channels = fmt->i_channels;
    const unsigned rate = fmt->i_rate;
    const size_t frames = block->i_nb_samples;

    if (channels == 0 || rate == 0 || frames == 0
     || !IsSupportedFormat(fmt->i_format))
        return;

    const size_t frame_size = channels * (aout_BitsPerSample(fmt->i_format) / 8);
    if (frame_size == 0 || block->i_buffer < frames * frame_size)
        return;

    vlc_tick_t pts = block->i_pts;
    if (pts == VLC_TICK_INVALID)
        pts = a->next_pts != VLC_TICK_INVALID ? a->next_pts : a->origin;
    a->next_pts = pts + vlc_tick_from_samples(frames, rate);

    const double t0 = (double)(pts - a->origin);
    const double tick_per_frame = (double)CLOCK_FREQ / rate;
    const double t_end = t0 + frames * tick_per_frame;

    if (t_end <= 0.)
        return; /* preroll before the start */

    if (t_end > (double)a->max_length)
    {
        a->overflow = true;
        return;
    }

    /* the media is longer than announced: widen the fine array */
    while (t_end >= a->fine_dt * a->fine_count)
        GrowFine(a);

    const double inv_dt = 1. / a->fine_dt;
    const uint8_t *p = block->p_buffer;

    for (size_t i = 0; i < frames; i++, p += frame_size)
    {
        const double t = t0 + i * tick_per_frame;
        if (t < 0.)
            continue;
        size_t idx = (size_t)(t * inv_dt);
        if (idx >= a->fine_count)
            idx = a->fine_count - 1;

        a->fine[idx] += FramePower(fmt, p, channels);
        a->fine_n[idx]++;
    }

    a->frames += frames;
    if ((vlc_tick_t)t_end > a->reached)
        a->reached = (vlc_tick_t)t_end;
}

/* Re-bin the fine array into the output bins over [0, length] */
static double ComputeBins(vlc_waveform_analyzer *a, bool final)
{
    vlc_tick_t length = a->length;
    if (length <= 0)
        length = a->reached;
    if (length <= 0)
        length = 1;

    const double bin_dt = (double)length / a->bin_count;

    for (unsigned i = 0; i < a->bin_count; i++)
    {
        const double start = i * bin_dt;
        const double end = start + bin_dt;

        if (!final && end > (double)a->reached)
        {
            a->out_bins[i] = -1.f; /* not analysed yet */
            continue;
        }

        size_t f0 = (size_t)(start / a->fine_dt);
        const double f1_ceil = ceil(end / a->fine_dt);
        size_t f1 = (size_t)f1_ceil;
        if (f1 <= f0)
            f1 = f0 + 1;
        if (f1 > a->fine_count)
            f1 = a->fine_count;

        /* RMS of the bin: loud masters hit full scale in every bin, so
         * peaks would draw a flat waveform */
        double sum = 0.;
        uint64_t n = 0;
        for (size_t f = f0; f < f1; f++)
        {
            sum += a->fine[f];
            n += a->fine_n[f];
        }
        float rms = n > 0 ? (float)sqrt(sum / n) : 0.f;
        a->out_bins[i] = rms > 1.f ? 1.f : rms;
    }

    double progress = (double)a->reached / length;
    if (final || progress > 1.)
        progress = 1.;
    return progress;
}

static void Report(vlc_waveform_analyzer *a, bool final)
{
    const double progress = ComputeBins(a, final);
    if (a->cbs != NULL && a->cbs->on_progress != NULL)
        a->cbs->on_progress(a->opaque, a->out_bins, a->bin_count, progress);
    a->last_report = vlc_tick_now();
}

/*****************************************************************************
 * Decoder
 *****************************************************************************/

/* Same as the input decoder does for an audio output: complete the output
 * format (frame size/length) that decoder_NewAudioBuffer() relies on */
static int DecoderFormatUpdate(decoder_t *dec)
{
    audio_format_t *fmt = &dec->fmt_out.audio;

    fmt->i_format = dec->fmt_out.i_codec;
    if (fmt->i_physical_channels == 0 || fmt->i_rate == 0
     || aout_BitsPerSample(fmt->i_format) == 0)
        return VLC_EGENERIC;

    aout_FormatPrepare(fmt);
    if (fmt->i_bytes_per_frame == 0 || fmt->i_frame_length == 0)
        return VLC_EGENERIC;
    return VLC_SUCCESS;
}

static void DecoderQueueAudio(decoder_t *dec, block_t *block)
{
    struct wf_decoder *wd = container_of(dec, struct wf_decoder, dec);

    Accumulate(wd->owner, &dec->fmt_out.audio, block);
    block_Release(block);
}

static const struct decoder_owner_callbacks dec_audio_cbs =
{
    .audio = {
        .format_update = DecoderFormatUpdate,
        .queue = DecoderQueueAudio,
    },
};

static void DecoderUnload(struct wf_decoder *wd)
{
    if (wd->dec.p_module != NULL)
        decoder_Clean(&wd->dec);
    es_format_Clean(&wd->fmt_in);
}

static void DecoderDelete(struct wf_decoder *wd)
{
    if (wd == NULL)
        return;
    DecoderUnload(wd);
    vlc_object_delete(&wd->dec);
}

static int DecoderLoad(struct wf_decoder *wd, bool packetizer,
                       const es_format_t *fmt)
{
    decoder_Init(&wd->dec, &wd->fmt_in, fmt);
    wd->dec.cbs = &dec_audio_cbs;

    decoder_LoadModule(&wd->dec, packetizer, false);
    if (wd->dec.p_module == NULL)
    {
        decoder_Clean(&wd->dec);
        es_format_Clean(&wd->fmt_in);
        return VLC_EGENERIC;
    }
    return VLC_SUCCESS;
}

static struct wf_decoder *DecoderNew(vlc_waveform_analyzer *a, bool packetizer,
                                     const es_format_t *fmt)
{
    struct wf_decoder *wd = vlc_object_create(a->obj, sizeof (*wd));
    if (unlikely(wd == NULL))
        return NULL;
    wd->owner = a;
    es_format_Init(&wd->fmt_in, UNKNOWN_ES, 0);

    if (DecoderLoad(wd, packetizer, fmt) != VLC_SUCCESS)
    {
        vlc_object_delete(&wd->dec);
        return NULL;
    }
    return wd;
}

static void DecodersDestroy(vlc_waveform_analyzer *a)
{
    DecoderDelete(a->decoder);
    DecoderDelete(a->packetizer);
    a->decoder = a->packetizer = NULL;
}

static int DecodersCreate(vlc_waveform_analyzer *a, const es_format_t *fmt)
{
    /* like the input decoder: only packetize when the demuxer did not */
    if (!fmt->b_packetized)
    {
        a->packetizer = DecoderNew(a, true, fmt);
        if (a->packetizer == NULL)
            return VLC_EGENERIC;
        a->packetizer->dec.fmt_out.b_packetized = true;
        fmt = &a->packetizer->dec.fmt_out;
    }

    a->decoder = DecoderNew(a, false, fmt);
    if (a->decoder == NULL)
    {
        msg_Dbg(a->obj, "no audio decoder for %4.4s", (const char *)&fmt->i_codec);
        DecodersDestroy(a);
        return VLC_EGENERIC;
    }
    return VLC_SUCCESS;
}

/* Decode one packetized block (or NULL to drain) */
static bool DecoderDecode(vlc_waveform_analyzer *a, block_t *block)
{
    decoder_t *decoder = &a->decoder->dec;

    if (decoder->pf_decode(decoder, block) == VLCDEC_ECRITICAL)
    {
        DecoderUnload(a->decoder);
        return false;
    }
    return true;
}

/* Feed one block (or NULL to drain) through the packetizer and decoder */
static void DecodersProcess(vlc_waveform_analyzer *a, block_t *block)
{
    if (a->decoder == NULL || a->decoder->dec.p_module == NULL)
    {
        if (block != NULL)
            block_Release(block);
        return;
    }

    if (a->packetizer == NULL)
    {
        DecoderDecode(a, block);
        return;
    }

    decoder_t *packetizer = &a->packetizer->dec;
    decoder_t *decoder = &a->decoder->dec;
    block_t **pp_block = block != NULL ? &block : NULL;
    block_t *packetized;

    while ((packetized = packetizer->pf_packetize(packetizer, pp_block)) != NULL)
    {
        if (!es_format_IsSimilar(decoder->fmt_in, &packetizer->fmt_out))
        {
            /* drain and reload the decoder for the new input format */
            decoder->pf_decode(decoder, NULL);
            DecoderUnload(a->decoder);
            if (DecoderLoad(a->decoder, false, &packetizer->fmt_out) != VLC_SUCCESS)
            {
                block_ChainRelease(packetized);
                if (block != NULL)
                    block_Release(block);
                return;
            }
        }

        while (packetized != NULL)
        {
            block_t *next = packetized->p_next;
            packetized->p_next = NULL;

            if (!DecoderDecode(a, packetized))
            {
                block_ChainRelease(next);
                if (block != NULL)
                    block_Release(block);
                return;
            }
            packetized = next;
        }

        if (IsCancelled(a))
            break;
    }

    if (block != NULL)
        block_Release(block);
    if (pp_block == NULL)
        DecoderDecode(a, NULL); /* drain */
}

/*****************************************************************************
 * es_out
 *****************************************************************************/

static es_out_id_t *EsOutAdd(es_out_t *out, input_source_t *in,
                             const es_format_t *fmt)
{
    (void) in;
    vlc_waveform_analyzer *a = container_of(out, vlc_waveform_analyzer, out);

    es_out_id_t *id = malloc(sizeof (*id));
    if (unlikely(id == NULL))
        return NULL;

    es_format_Copy(&id->fmt, fmt);
    id->next = a->es_list;
    a->es_list = id;

    if (fmt->i_cat == VIDEO_ES)
        a->has_video = true;
    else if (fmt->i_cat == AUDIO_ES && a->audio == NULL)
    {
        if (DecodersCreate(a, &id->fmt) == VLC_SUCCESS)
            a->audio = id;
    }
    return id;
}

static int EsOutSend(es_out_t *out, es_out_id_t *id, block_t *block)
{
    vlc_waveform_analyzer *a = container_of(out, vlc_waveform_analyzer, out);

    if (id == a->audio && !a->has_video)
        DecodersProcess(a, block);
    else
        block_Release(block);
    return VLC_SUCCESS;
}

static void EsOutDel(es_out_t *out, es_out_id_t *id)
{
    vlc_waveform_analyzer *a = container_of(out, vlc_waveform_analyzer, out);

    if (id == a->audio)
    {
        if (!IsCancelled(a))
            DecodersProcess(a, NULL);
        DecodersDestroy(a);
        a->audio = NULL;
    }

    for (es_out_id_t **pp = &a->es_list; *pp != NULL; pp = &(*pp)->next)
        if (*pp == id)
        {
            *pp = id->next;
            break;
        }
    es_format_Clean(&id->fmt);
    free(id);
}

static int EsOutControl(es_out_t *out, input_source_t *in, int query,
                        va_list args)
{
    (void) in;
    vlc_waveform_analyzer *a = container_of(out, vlc_waveform_analyzer, out);

    switch (query)
    {
        case ES_OUT_GET_ES_STATE:
        {
            es_out_id_t *id = va_arg(args, es_out_id_t *);
            *va_arg(args, bool *) = (id == a->audio);
            return VLC_SUCCESS;
        }
        case ES_OUT_SET_ES_FMT:
        {
            es_out_id_t *id = va_arg(args, es_out_id_t *);
            const es_format_t *fmt = va_arg(args, const es_format_t *);
            es_format_Clean(&id->fmt);
            es_format_Copy(&id->fmt, fmt);
            if (id == a->audio)
            {
                DecodersProcess(a, NULL);
                DecodersDestroy(a);
                if (DecodersCreate(a, &id->fmt) != VLC_SUCCESS)
                    a->audio = NULL;
            }
            return VLC_SUCCESS;
        }
        case ES_OUT_RESTART_ES:
        {
            es_out_id_t *id = va_arg(args, es_out_id_t *);
            if (id == a->audio)
            {
                DecodersDestroy(a);
                if (DecodersCreate(a, &id->fmt) != VLC_SUCCESS)
                    a->audio = NULL;
            }
            return VLC_SUCCESS;
        }
        case ES_OUT_IS_EMPTY:
            *va_arg(args, bool *) = true;
            return VLC_SUCCESS;
        case ES_OUT_SET_ES:
        case ES_OUT_UNSET_ES:
        case ES_OUT_SET_ES_DEFAULT:
        case ES_OUT_SET_ES_STATE:
        case ES_OUT_SET_ES_CAT_POLICY:
        case ES_OUT_SET_GROUP:
        case ES_OUT_SET_PCR:
        case ES_OUT_SET_GROUP_PCR:
        case ES_OUT_RESET_PCR:
        case ES_OUT_SET_NEXT_DISPLAY_TIME:
        case ES_OUT_SET_GROUP_META:
        case ES_OUT_SET_GROUP_EPG:
        case ES_OUT_SET_GROUP_EPG_EVENT:
        case ES_OUT_SET_EPG_TIME:
        case ES_OUT_DEL_GROUP:
        case ES_OUT_SET_ES_SCRAMBLED_STATE:
        case ES_OUT_DRAIN:
        case ES_OUT_SET_META:
            return VLC_SUCCESS;
        default:
            /* ES_OUT_POST_SUBNODE (playlists), vout/spu controls, ... */
            return VLC_EGENERIC;
    }
}

static void EsOutDestroy(es_out_t *out)
{
    (void) out; /* owned by the analyzer */
}

static const struct es_out_callbacks es_out_cbs =
{
    .add = EsOutAdd,
    .send = EsOutSend,
    .del = EsOutDel,
    .control = EsOutControl,
    .destroy = EsOutDestroy,
};

/*****************************************************************************
 * API
 *****************************************************************************/

vlc_waveform_analyzer *
vlc_waveform_analyzer_New(vlc_object_t *parent, const char *mrl,
                          unsigned bin_count, vlc_tick_t max_length,
                          const struct vlc_waveform_analyzer_cbs *cbs,
                          void *opaque)
{
    assert(parent != NULL && mrl != NULL && bin_count > 0);

    vlc_waveform_analyzer *a = calloc(1, sizeof (*a));
    if (unlikely(a == NULL))
        return NULL;

    a->out.cbs = &es_out_cbs;
    a->bin_count = bin_count;
    a->max_length = max_length;
    a->cbs = cbs;
    a->opaque = opaque;
    a->origin = VLC_TICK_0;
    a->next_pts = VLC_TICK_INVALID;
    atomic_init(&a->cancelled, false);

    a->mrl = strdup(mrl);
    a->fine_count = (size_t)bin_count * FINE_FACTOR;
    a->fine = calloc(a->fine_count, sizeof (*a->fine));
    a->fine_n = calloc(a->fine_count, sizeof (*a->fine_n));
    a->out_bins = calloc(bin_count, sizeof (*a->out_bins));
    a->interrupt = vlc_interrupt_create();
    a->obj = vlc_object_create(parent, sizeof (*a->obj));

    if (a->mrl == NULL || a->fine == NULL || a->fine_n == NULL || a->out_bins == NULL
     || a->interrupt == NULL || a->obj == NULL)
    {
        vlc_waveform_analyzer_Delete(a);
        return NULL;
    }

    /* never pop up dialogs (credentials, certificates...) for this */
    a->obj->no_interact = true;
    return a;
}

void vlc_waveform_analyzer_Cancel(vlc_waveform_analyzer *a)
{
    atomic_store(&a->cancelled, true);
    vlc_interrupt_kill(a->interrupt);
}

int vlc_waveform_analyzer_Run(vlc_waveform_analyzer *a)
{
    vlc_interrupt_t *previous = vlc_interrupt_set(a->interrupt);
    int status = VLC_WAVEFORM_ERROR;
    demux_t *demux = NULL;

    if (IsCancelled(a))
    {
        status = VLC_WAVEFORM_CANCELLED;
        goto out;
    }

    stream_t *stream = vlc_stream_NewURL(a->obj, a->mrl);
    if (stream == NULL)
        goto out;

    demux = demux_New(a->obj, "any", a->mrl, stream, &a->out);
    if (demux == NULL)
    {
        vlc_stream_Delete(stream);
        goto out;
    }

    vlc_tick_t length;
    if (demux_Control(demux, DEMUX_GET_LENGTH, &length) != VLC_SUCCESS
     || length <= 0)
    {
        msg_Dbg(a->obj, "waveform: unknown length");
        status = VLC_WAVEFORM_UNSUPPORTED;
        goto out;
    }
    if (length > a->max_length)
    {
        msg_Dbg(a->obj, "waveform: media too long");
        status = VLC_WAVEFORM_UNSUPPORTED;
        goto out;
    }
    a->length = length;

    vlc_tick_t normal_time;
    if (demux_Control(demux, DEMUX_GET_NORMAL_TIME, &normal_time) == VLC_SUCCESS
     && normal_time != VLC_TICK_INVALID)
        a->origin = normal_time;

    /* leave some room: estimated lengths (VBR without index) are rough */
    a->fine_dt = (double)length * 1.25 / a->fine_count;
    if (a->fine_dt < 1.)
        a->fine_dt = 1.;

    a->last_report = vlc_tick_now();

    while (!IsCancelled(a) && !a->has_video
        && demux_Demux(demux) == VLC_DEMUXER_SUCCESS)
    {
        if (a->overflow)
        {
            status = VLC_WAVEFORM_UNSUPPORTED;
            goto out;
        }

        if (vlc_tick_now() - a->last_report >= REPORT_INTERVAL)
        {
            /* the length estimation of some demuxers improves over time */
            if (demux_Control(demux, DEMUX_GET_LENGTH, &length) == VLC_SUCCESS
             && length > 0 && length <= a->max_length)
                a->length = length;
            Report(a, false);
        }
    }

    if (IsCancelled(a))
    {
        status = VLC_WAVEFORM_CANCELLED;
        goto out;
    }

    /* drain the pending samples */
    if (a->audio != NULL && !a->has_video)
        DecodersProcess(a, NULL);

    if (a->has_video)
    {
        msg_Dbg(a->obj, "waveform: media has video, skipped");
        status = VLC_WAVEFORM_UNSUPPORTED;
    }
    else if (a->frames == 0)
        status = VLC_WAVEFORM_ERROR;
    else
    {
        if (demux_Control(demux, DEMUX_GET_LENGTH, &length) == VLC_SUCCESS
         && length > 0 && length <= a->max_length)
            a->length = length;
        Report(a, true);
        status = VLC_WAVEFORM_DONE;
    }

out:
    /* an interrupted open/read fails: report it as a cancellation */
    if (status != VLC_WAVEFORM_DONE && IsCancelled(a))
        status = VLC_WAVEFORM_CANCELLED;

    if (demux != NULL)
        demux_Delete(demux); /* deletes the ES (EsOutDel) and the stream */
    DecodersDestroy(a);

    while (a->es_list != NULL)
    {
        es_out_id_t *id = a->es_list;
        a->es_list = id->next;
        es_format_Clean(&id->fmt);
        free(id);
    }
    a->audio = NULL;

    vlc_interrupt_set(previous);
    return status;
}

void vlc_waveform_analyzer_Delete(vlc_waveform_analyzer *a)
{
    if (a->obj != NULL)
        vlc_object_delete(a->obj);
    if (a->interrupt != NULL)
        vlc_interrupt_destroy(a->interrupt);
    free(a->out_bins);
    free(a->fine);
    free(a->fine_n);
    free(a->mrl);
    free(a);
}
