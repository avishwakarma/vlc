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
#ifndef MESSAGES_MODEL_HPP
#define MESSAGES_MODEL_HPP

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <QAbstractListModel>
#include <QMutex>
#include <QDateTime>
#include <vector>
#include <atomic>

#include "maininterface/mainctx.hpp"

/**
 * Log messages for the QML Messages viewer (dialogs/forms/qml/Messages.qml).
 * Hooks the libvlc logger while it lives (like the widget dialog) and keeps the
 * last messages; severity level and text filters are applied by the model.
 */
class MessagesModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    /// 0 errors, 1 warnings + errors, 2 everything (debug)
    Q_PROPERTY(int level READ level WRITE setLevel NOTIFY levelChanged FINAL)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged FINAL)
    Q_PROPERTY(int total READ total NOTIFY totalChanged FINAL)

public:
    enum Roles {
        TimeRole = Qt::UserRole + 1,
        SeverityRole, // 0 info, 1 error, 2 warning, 3 debug
        ModuleRole,
        TextRole,
    };

    explicit MessagesModel(QObject* parent = nullptr);
    ~MessagesModel() override;

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    MainCtx* ctx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);
    int level() const { return m_level; }
    void setLevel(int level);
    QString filter() const { return m_filter; }
    void setFilter(const QString& filter);
    int total() const { return int(m_all.size()); }

    Q_INVOKABLE void clear();
    /// all displayed rows as text
    Q_INVOKABLE QString text() const;
    Q_INVOKABLE void copyAll() const;
    /// asks for a file and saves the displayed rows, returns the file name or ""
    Q_INVOKABLE QString save();

signals:
    void ctxChanged();
    void levelChanged();
    void filterChanged();
    void totalChanged();

private:
    struct Entry
    {
        QDateTime time;
        int severity;
        QString module;
        QString text;
    };

    static void logCallback(void* data, int type, const vlc_log_t* item, const char* format, va_list ap);
    void flush();
    bool accepts(const Entry& e) const;
    void rebuild();
    void attach();
    void detach();

    MainCtx* m_ctx = nullptr;
    libvlc_int_t* m_vlc = nullptr;
    int m_level = 1;
    QString m_filter;

    std::vector<Entry> m_all;
    std::vector<int> m_rows;

    QMutex m_pendingLock;
    std::vector<Entry> m_pending;
    std::atomic_bool m_flushQueued { false };
    std::atomic_bool m_alive { true };
};

#endif
