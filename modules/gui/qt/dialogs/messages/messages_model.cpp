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

#include "messages_model.hpp"

#include "qt.hpp"

#include <QClipboard>
#include <QGuiApplication>
#include <QFileDialog>
#include <QFile>
#include <QTextStream>

#include <vlc_common.h>
#include <vlc_interface.h>
#include <vlc_threads.h>

namespace
{
constexpr size_t MaxEntries = 20000;

QString severityName(int s)
{
    switch (s)
    {
    case 1: return QStringLiteral("error");
    case 2: return QStringLiteral("warning");
    case 3: return QStringLiteral("debug");
    default: return QStringLiteral("info");
    }
}
}

MessagesModel::MessagesModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

MessagesModel::~MessagesModel()
{
    m_alive = false;
    detach();
}

void MessagesModel::setCtx(MainCtx* ctx)
{
    if (m_ctx == ctx)
        return;
    detach();
    m_ctx = ctx;
    attach();
    emit ctxChanged();
}

void MessagesModel::attach()
{
    if (!m_ctx)
        return;
    static const struct vlc_logger_operations ops = { MessagesModel::logCallback, nullptr };
    m_vlc = vlc_object_instance(m_ctx->getIntf());
    vlc_LogSet(m_vlc, &ops, this);
}

void MessagesModel::detach()
{
    if (m_vlc)
        vlc_LogSet(m_vlc, nullptr, nullptr);
    m_vlc = nullptr;
}

void MessagesModel::logCallback(void* data, int type, const vlc_log_t* item, const char* format, va_list ap)
{
    auto self = static_cast<MessagesModel*>(data);
    if (!self->m_alive)
        return;

    char* str = nullptr;
    if (vasprintf(&str, format, ap) == -1)
        return;

    Entry e;
    e.time = QDateTime::currentDateTime();
    e.severity = type == VLC_MSG_ERR ? 1 : type == VLC_MSG_WARN ? 2 : type == VLC_MSG_DBG ? 3 : 0;
    e.module = qfu(item->psz_module);
    e.text = qfu(str);
    free(str);

    {
        QMutexLocker locker(&self->m_pendingLock);
        self->m_pending.push_back(std::move(e));
    }
    if (!self->m_flushQueued.exchange(true))
    {
        const int canc = vlc_savecancel();
        QMetaObject::invokeMethod(self, [self] { self->flush(); }, Qt::QueuedConnection);
        vlc_restorecancel(canc);
    }
}

bool MessagesModel::accepts(const Entry& e) const
{
    // level 0: errors (and notices), 1: + warnings, 2: + debug
    if (e.severity > m_level + 1 && e.severity != 0)
        return false;
    if (!m_filter.isEmpty()
        && !e.text.contains(m_filter, Qt::CaseInsensitive)
        && !e.module.contains(m_filter, Qt::CaseInsensitive))
        return false;
    return true;
}

void MessagesModel::flush()
{
    std::vector<Entry> batch;
    {
        QMutexLocker locker(&m_pendingLock);
        batch.swap(m_pending);
        m_flushQueued = false;
    }
    if (batch.empty())
        return;

    if (m_all.size() + batch.size() > MaxEntries)
    {
        // drop the oldest tenth
        beginResetModel();
        m_all.erase(m_all.begin(), m_all.begin() + MaxEntries / 10);
        for (auto& e : batch)
            m_all.push_back(std::move(e));
        rebuild();
        endResetModel();
        emit totalChanged();
        return;
    }

    std::vector<int> added;
    for (auto& e : batch)
    {
        m_all.push_back(std::move(e));
        if (accepts(m_all.back()))
            added.push_back(int(m_all.size()) - 1);
    }
    if (!added.empty())
    {
        beginInsertRows({}, int(m_rows.size()), int(m_rows.size() + added.size()) - 1);
        m_rows.insert(m_rows.end(), added.begin(), added.end());
        endInsertRows();
    }
    emit totalChanged();
}

void MessagesModel::rebuild()
{
    m_rows.clear();
    for (size_t i = 0; i < m_all.size(); ++i)
        if (accepts(m_all[i]))
            m_rows.push_back(int(i));
}

int MessagesModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : int(m_rows.size());
}

QVariant MessagesModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= int(m_rows.size()))
        return {};
    const Entry& e = m_all[m_rows[index.row()]];
    switch (role)
    {
    case TimeRole: return e.time.toString(QStringLiteral("HH:mm:ss.zzz"));
    case SeverityRole: return e.severity;
    case ModuleRole: return e.module;
    case TextRole: return e.text;
    default: return {};
    }
}

QHash<int, QByteArray> MessagesModel::roleNames() const
{
    return {
        { TimeRole, "time" },
        { SeverityRole, "severity" },
        { ModuleRole, "module" },
        { TextRole, "text" },
    };
}

void MessagesModel::setLevel(int level)
{
    level = qBound(0, level, 2);
    if (level == m_level)
        return;
    m_level = level;
    beginResetModel();
    rebuild();
    endResetModel();
    emit levelChanged();
}

void MessagesModel::setFilter(const QString& filter)
{
    if (filter == m_filter)
        return;
    m_filter = filter;
    beginResetModel();
    rebuild();
    endResetModel();
    emit filterChanged();
}

void MessagesModel::clear()
{
    beginResetModel();
    m_all.clear();
    m_rows.clear();
    endResetModel();
    emit totalChanged();
}

QString MessagesModel::text() const
{
    QString out;
    for (int row : m_rows)
    {
        const Entry& e = m_all[row];
        out += e.time.toString(QStringLiteral("HH:mm:ss.zzz")) + QLatin1Char(' ') + e.module
               + QLatin1Char(' ') + severityName(e.severity) + QStringLiteral(": ") + e.text + QLatin1Char('\n');
    }
    return out;
}

void MessagesModel::copyAll() const
{
    QGuiApplication::clipboard()->setText(text());
}

QString MessagesModel::save()
{
    const QString name = QFileDialog::getSaveFileName(nullptr, qtr("Save log file as..."), QString(),
                                                      qtr("Texts/Logs (*.log *.txt);; All (*.*)"));
    if (name.isEmpty())
        return {};
    QFile file(name);
    if (!file.open(QFile::WriteOnly | QFile::Text))
        return {};
    QTextStream out(&file);
    out << text();
    return name;
}
