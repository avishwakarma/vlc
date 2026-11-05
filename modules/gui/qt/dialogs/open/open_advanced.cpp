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

#include "open_advanced.hpp"

#include "qt.hpp"
#include "dialogs/dialogs_provider.hpp"
#include "playlist/media.hpp"
#include "playlist/playlist_controller.hpp"
#include "util/qt_dirs.hpp"

#include <vlc_intf_strings.h>
#include <vlc_modules.h>
#include <vlc_plugin.h>
#include <vlc_url.h>

#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QRegularExpression>
#include <QStorageInfo>
#include <QUrl>

#ifdef __APPLE__
# include "avcapture_devices.h"
#endif

#define I_DEVICE_TOOLTIP \
    I_DIR_OR_FOLDER( N_("Select a device or a VIDEO_TS directory"), \
                     N_("Select a device or a VIDEO_TS folder") )

/* intf_Eject(), shared with the widget panel */
#include "../../../eject.c"

using namespace vlc::playlist;

namespace
{

enum DiscType { DiscDvd = 0, DiscBluray, DiscCdda, DiscVcd, DiscDvda };

/* same as the widget panels: the entries of /dev/ that look like the given patterns */
QStringList devEntries(const QStringList& patterns)
{
    return QDir(QStringLiteral("/dev/")).entryList(patterns, QDir::System)
            .replaceInStrings(QRegularExpression(QStringLiteral("^")), QStringLiteral("/dev/"));
}

QString fixupLocation(const QString& location)
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

#ifdef __APPLE__
void collectDevice(void* opaque, const char* uid, const char* name)
{
    QVariantMap entry;
    entry[QStringLiteral("id")] = qfu(uid);
    entry[QStringLiteral("label")] = qfu(name);
    static_cast<QVariantList*>(opaque)->append(entry);
}
#endif

}

OpenAdvanced::OpenAdvanced(QObject* parent)
    : QObject(parent)
{
}

void OpenAdvanced::setCtx(MainCtx* ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
}

bool OpenAdvanced::supportsTab(int tab)
{
#ifdef _WIN32
    /* DirectShow devices and the drive probing of the widget panels are not ported */
    return tab != 1 && tab != 3;
#else
    Q_UNUSED(tab);
    return true;
#endif
}

QVariantList OpenAdvanced::captureModes() const
{
    QVariantList modes;
    auto add = [&modes](const char* id, const QString& label) {
        QVariantMap m;
        m[QStringLiteral("id")] = QString::fromLatin1(id);
        m[QStringLiteral("label")] = label;
        modes.append(m);
    };
#ifdef __APPLE__
    if (module_exists("avcapture"))
        add("camera", qtr("Video camera"));
    if (module_exists("avaudiocapture"))
        add("audio", qtr("Audio input"));
#elif !defined(_WIN32)
    if (module_exists("v4l2"))
        add("camera", qtr("Video camera"));
#endif
    add("screen", qtr("Desktop"));
    return modes;
}

// --- File

QStringList OpenAdvanced::pickFiles()
{
    return THEDP->showSimpleOpen(qtr("Select one or multiple files"));
}

QString OpenAdvanced::pickSubtitle()
{
    const QStringList urls = THEDP->showSimpleOpen(qtr("Open subtitle file"), EXT_FILTER_SUBTITLE,
                                                   m_ctx ? m_ctx->getDialogFilePath() : QUrl());
    return urls.isEmpty() ? QString() : urls.first();
}

QString OpenAdvanced::pickMedia()
{
    const QStringList urls = THEDP->showSimpleOpen(qtr("Select a media file"));
    return urls.isEmpty() ? QString() : urls.first();
}

QString OpenAdvanced::displayPath(const QString& url) const
{
    return toNativeSeparators(QUrl(url).toDisplayString(
        QUrl::RemovePassword | QUrl::PreferLocalFile | QUrl::NormalizePathSegments));
}

QString OpenAdvanced::subtitleOption(const QString& url) const
{
    return QStringLiteral("sub-file=") + colon_escape(toNativeSeparators(QUrl(url).toLocalFile()));
}

// --- Disc

QVariantList OpenAdvanced::discDevices() const
{
    QVariantList list;
    QStringList seen;
    auto add = [&](const QString& path, const QString& label) {
        if (path.isEmpty() || seen.contains(path))
            return;
        seen << path;
        QVariantMap m;
        m[QStringLiteral("path")] = path;
        m[QStringLiteral("label")] = label.isEmpty() ? path : label;
        list.append(m);
    };

#ifndef _WIN32
    const QStringList devs = devEntries({ "sr*", "sg*", "scd*", "dvd*", "cd*" });
    for (const QString& dev : devs)
        add(dev, QString());
#endif

    /* the mounted discs: audio CDs, DVD (VIDEO_TS), Blu-ray (BDMV), optical file systems */
    for (const QStorageInfo& vol : QStorageInfo::mountedVolumes())
    {
        if (!vol.isValid() || !vol.isReady() || vol.isRoot())
            continue;
        const QString fs = QString::fromLatin1(vol.fileSystemType());
        const QDir root(vol.rootPath());
        const bool optical = fs == QLatin1String("cddafs") || fs == QLatin1String("udf")
                          || fs == QLatin1String("cd9660")
                          || root.exists(QStringLiteral("VIDEO_TS")) || root.exists(QStringLiteral("BDMV"));
        if (!optical)
            continue;
#ifdef __APPLE__
        /* the audio CD module and libdvdnav want the BSD device, the others the mount point */
        const QString dev = (fs == QLatin1String("cddafs")) ? QString::fromLatin1(vol.device()) : vol.rootPath();
        add(dev, vol.displayName() + QStringLiteral(" (") + vol.rootPath() + QLatin1Char(')'));
#else
        add(vol.rootPath(), vol.displayName());
#endif
    }

    /* the devices configured in the preferences */
    for (int type : { DiscDvd, DiscCdda, DiscVcd })
        add(defaultDiscDevice(type), QString());

    return list;
}

QString OpenAdvanced::defaultDiscDevice(int type) const
{
    if (!m_ctx)
        return {};
    qt_intf_t* p_intf = m_ctx->getIntf();
    const char* name = nullptr;
    switch (type)
    {
        case DiscVcd: name = "vcd"; break;
        case DiscCdda: name = config_GetType("cd-audio") ? "cd-audio" : nullptr; break;
        default: name = "dvd"; break;
    }
    if (!name)
        return {};
    char* psz = var_InheritString(p_intf, name);
    const QString ret = psz ? qfu(psz) : QString();
    free(psz);
    return ret;
}

bool OpenAdvanced::blurayMenuDefault() const
{
    return m_ctx ? var_InheritBool(m_ctx->getIntf(), "bluray-menu") : true;
}

QString OpenAdvanced::pickDiscFolder()
{
    QString dir = QFileDialog::getExistingDirectoryUrl(nullptr, qfut(I_DEVICE_TOOLTIP),
            m_ctx ? m_ctx->getDialogFilePath() : QUrl(), QFileDialog::ShowDirsOnly,
            QStringList(QStringLiteral("file"))).toLocalFile();
    return dir.isEmpty() ? QString() : toNativeSepNoSlash(std::move(dir));
}

void OpenAdvanced::eject(const QString& device)
{
    if (!m_ctx || device.isEmpty())
        return;
    intf_Eject(VLC_OBJECT(m_ctx->getIntf()), qtu(device));
}

QVariantMap OpenAdvanced::discMrl(int type, const QString& device, int title, int chapter,
                                  int audioTrack, int subtitleTrack, bool noMenus) const
{
    /* DiscOpenPanel::updateMRL() */
    const char* scheme;
    switch (type)
    {
        case DiscDvd: scheme = noMenus ? "dvdsimple" : "dvd"; break;
        case DiscDvda: scheme = "dvda"; break;
        case DiscBluray: scheme = "bluray"; break;
        case DiscVcd: scheme = "vcd"; break;
        default: scheme = "cdda"; break;
    }

    QVariantMap ret;
    ret[QStringLiteral("caching")] = QStringLiteral("disc-caching");

    char* mrl = vlc_path2uri(qtu(device), scheme);
    if (unlikely(mrl == nullptr))
    {
        ret[QStringLiteral("items")] = QStringList();
        ret[QStringLiteral("options")] = QStringList();
        return ret;
    }

    QString anchor;
    if (title > 0)
    {
        if (type == DiscDvd || type == DiscBluray || type == DiscDvda)
        {
            anchor = QStringLiteral("#%1").arg(title);
            if (chapter > 0)
                anchor += QStringLiteral(":%1").arg(chapter);
        }
        else if (type == DiscVcd)
            anchor = QStringLiteral("#%1").arg(title);
    }

    QStringList opts;
    if (type == DiscDvd || type == DiscVcd)
    {
        if (audioTrack >= 0)
            opts << QStringLiteral("audio-track=%1").arg(audioTrack);
        if (subtitleTrack >= 0)
            opts << QStringLiteral("sub-track=%1").arg(subtitleTrack);
    }
    else if (type == DiscCdda)
    {
        if (title > 0)
            opts << QStringLiteral("cdda-track=%1").arg(title);
    }
    else if (type == DiscBluray)
    {
        if (noMenus)
            opts << QStringLiteral("no-bluray-menu");
    }

    ret[QStringLiteral("items")] = QStringList(qfu(mrl) + anchor);
    ret[QStringLiteral("options")] = opts;
    free(mrl);
    return ret;
}

// --- Network

QStringList OpenAdvanced::networkItems(const QString& text) const
{
    QStringList ret;
    const QStringList lines = text.split(QRegularExpression(QStringLiteral("[\\r\\n]+")), Qt::SkipEmptyParts);
    for (const QString& line : lines)
    {
        const QString uri = fixupLocation(line);
        if (!uri.isEmpty())
            ret << uri;
    }
    return ret;
}

// --- Capture

QVariantList OpenAdvanced::captureDevices(const QString& kind) const
{
    QVariantList list;
#ifdef __APPLE__
    vlc_qt_avcapture_devices(kind == QLatin1String("audio") ? 1 : 0, collectDevice, &list);
#elif !defined(_WIN32)
    if (kind == QLatin1String("audio"))
    {
        /* CaptureOpenPanel: ALSA capture nodes */
        QStringList names = QDir(QStringLiteral("/dev/snd")).entryList({ "pcmC*D*c" }, QDir::System)
                .replaceInStrings(QRegularExpression(QStringLiteral("^pcmC")), QStringLiteral("hw:"))
                .replaceInStrings(QRegularExpression(QStringLiteral("c$")), QString())
                .replaceInStrings(QRegularExpression(QStringLiteral("D")), QStringLiteral(","));
        for (const QString& n : names)
        {
            QVariantMap m;
            m[QStringLiteral("id")] = n;
            m[QStringLiteral("label")] = n;
            list.append(m);
        }
    }
    else
    {
        for (const QString& dev : devEntries({ "video*" }))
        {
            QVariantMap m;
            m[QStringLiteral("id")] = dev;
            m[QStringLiteral("label")] = dev;
            list.append(m);
        }
    }
#else
    Q_UNUSED(kind);
#endif
    return list;
}

QVariantMap OpenAdvanced::captureMrl(const QString& mode, const QString& videoDevice,
                                     const QString& audioDevice, double fps) const
{
    QStringList items, opts;
    if (mode == QLatin1String("screen"))
    {
        items << QStringLiteral("screen://");
        opts << QStringLiteral("screen-fps=") + QString::number(fps, 'f');
    }
    else if (mode == QLatin1String("audio"))
    {
        items << QStringLiteral("qtsound://") + audioDevice;
    }
    else /* camera */
    {
#ifdef __APPLE__
        items << QStringLiteral("avcapture://") + videoDevice;
        if (!audioDevice.isEmpty())
            opts << QStringLiteral("input-slave=qtsound://") + audioDevice;
#else
        items << QStringLiteral("v4l2://") + videoDevice;
        if (!audioDevice.isEmpty())
            opts << QStringLiteral("input-slave=alsa://") + audioDevice;
#endif
    }

    QVariantMap ret;
    ret[QStringLiteral("items")] = items;
    ret[QStringLiteral("options")] = opts;
    ret[QStringLiteral("caching")] = QStringLiteral("live-caching");
    return ret;
}

// --- Common

int OpenAdvanced::cachingDefault(const QString& method) const
{
    return m_ctx ? var_InheritInteger(m_ctx->getIntf(), qtu(method)) : 0;
}

double OpenAdvanced::parseTime(const QString& text) const
{
    const QString t = text.trimmed();
    if (t.isEmpty())
        return 0;

    static const QRegularExpression hms(QStringLiteral("^(?:(\\d+)[hH]\\s*)?(?:(\\d+)[mM]\\s*)?(?:(\\d+(?:\\.\\d+)?)[sS]?)?$"));
    static const QRegularExpression colon(QStringLiteral("^\\d+(:\\d{1,2}){0,2}(\\.\\d+)?$"));

    if (colon.match(t).hasMatch())
    {
        const QStringList parts = t.split(QLatin1Char(':'));
        double s = 0;
        for (int i = 0; i < parts.size(); ++i)
        {
            const double v = parts.at(i).toDouble();
            if (i > 0 && v >= 60)
                return -1;
            s = s * 60 + v;
        }
        return s;
    }

    const auto m = hms.match(t);
    if (m.hasMatch() && (!m.captured(1).isEmpty() || !m.captured(2).isEmpty() || t.endsWith(QLatin1Char('s'), Qt::CaseInsensitive)))
        return m.captured(1).toDouble() * 3600 + m.captured(2).toDouble() * 60 + m.captured(3).toDouble();

    return -1;
}

QStringList OpenAdvanced::commonOptions(const QString& method, int caching, double start, double stop,
                                        const QString& slave, const QString& extra) const
{
    /* OpenDialog::updateMRL() */
    QStringList opts;
    if (!slave.isEmpty())
        opts << QStringLiteral("input-slave=") + slave;
    if (!method.isEmpty())
        opts << QStringLiteral("%1=%2").arg(method).arg(caching);
    if (start > 0)
        opts << QStringLiteral("start-time=") + QString::number(start, 'f', 3);
    if (stop > start && stop > 0)
        opts << QStringLiteral("stop-time=") + QString::number(stop, 'f', 3);

    /* free text: ":a=b :c" or "a=b :c" */
    const QStringList free = extra.trimmed().split(QRegularExpression(QStringLiteral("(^|\\s+):")), Qt::SkipEmptyParts);
    for (const QString& f : free)
    {
        const QString o = f.trimmed();
        if (!o.isEmpty())
            opts << o;
    }
    return opts;
}

int OpenAdvanced::submit(int action, const QStringList& itemsIn, const QStringList& names,
                         const QStringList& options)
{
    if (!m_ctx || itemsIn.isEmpty())
        return 0;

    qt_intf_t* p_intf = m_ctx->getIntf();

    if (action == Stream || action == Convert)
    {
        /* OpenDialog::stream(): the legacy sout wizard gets " :a :b" split on " :" */
        const QString joined = options.isEmpty() ? QString() : (QStringLiteral(" :") + options.join(QStringLiteral(" :")));
        msg_Dbg(p_intf, "MRL(s) passed to the Sout: %zu", static_cast<size_t>(itemsIn.size()));
        THEDP->streamingDialog(nullptr, itemsIn, action == Convert, joined.split(QStringLiteral(" :")));
        return itemsIn.size();
    }

    QVector<Media> medias;
    medias.reserve(itemsIn.size());
    for (int i = 0; i < itemsIn.size(); ++i)
    {
        const QString name = i < names.size() ? names.at(i) : QString();
        medias.push_back(Media{itemsIn.at(i), name, options});
    }
    THEMPL->append(medias, action == Play);
    return itemsIn.size();
}
