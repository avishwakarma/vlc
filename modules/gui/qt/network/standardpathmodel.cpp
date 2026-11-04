/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * Authors: Benjamin Arnaud <bunjee@omega.gg>
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

#include "standardpathmodel.hpp"
#include "qt.hpp"
#include "networkdevicemodel.hpp"
#include "networkmediamodel.hpp"

#include "util/locallistbasemodel.hpp"

// VLC includes
#include <vlc_media_source.h>
#include <vlc_configuration.h>

#include <QAbstractListModel>
#include <QStandardPaths>
#include <QUrl>

#include "vlcmediasourcewrapper.hpp"

struct StandardPathItem : public NetworkBaseItem
{
    SharedInputItem inputItem;
    MediaTreePtr tree;
};

using StandardPathItemPtr =  std::shared_ptr<StandardPathItem>;
using StandardPathLoader = LocalListCacheLoader<StandardPathItemPtr>;

template<>
bool ListCache<StandardPathItemPtr>::compareItems(const StandardPathItemPtr& a, const StandardPathItemPtr& b)
{
    //just compare the pointers here
    return a == b;
}

namespace {

bool itemMatchPattern(const StandardPathItemPtr& a, const QString& pattern)
{
    return a->name.contains(pattern, Qt::CaseInsensitive);
}

bool ascendingName(const StandardPathItemPtr& a,
                   const StandardPathItemPtr& b)
{
    return (QString::compare(a->name, b->name, Qt::CaseInsensitive) <= 0);
}

bool ascendingMrl(const StandardPathItemPtr& a,
                   const StandardPathItemPtr& b)
{
    return (QString::compare(a->mainMrl.toString(), b->mainMrl.toString(), Qt::CaseInsensitive) <= 0);
}

bool descendingName(const StandardPathItemPtr& a,
                   const StandardPathItemPtr& b)
{
    return (QString::compare(a->name, b->name, Qt::CaseInsensitive) >= 0);
}

bool descendingMrl(const StandardPathItemPtr& a,
                   const StandardPathItemPtr& b)
{
    return (QString::compare(a->mainMrl.toString(), b->mainMrl.toString(), Qt::CaseInsensitive) >= 0);
}

}


class StandardPathModelPrivate
    : public LocalListBaseModelPrivate<StandardPathItemPtr>
{
    Q_DECLARE_PUBLIC(StandardPathModel)
public:

    StandardPathModelPrivate(StandardPathModel* pub)
        : LocalListBaseModelPrivate<StandardPathItemPtr>(pub)
    {}

    StandardPathLoader::ItemCompare getSortFunction() const override
    {
        if (m_sortCriteria == "mrl")
        {
            if (m_sortOrder == Qt::AscendingOrder)
                return ascendingMrl;
            else
                return descendingMrl;
        }
        else
        {
            if (m_sortOrder == Qt::AscendingOrder)
                return ascendingName;
            else
                return descendingName;
        }
    }

    bool initializeModel() override
    {
        Q_Q(StandardPathModel);

        using UserPath = std::pair<QString, QString>;
        std::list<UserPath> paths;

        assert(m_qmlInitializing == false);

        if (m_serversMode)
        {
            for (const QVariant& entry : m_servers)
            {
                const QVariantMap map = entry.toMap();
                const QUrl url(map.value(QStringLiteral("url")).toString());
                if (!url.isValid() || url.scheme().isEmpty())
                    continue;
                QString name = map.value(QStringLiteral("name")).toString();
                if (name.isEmpty())
                    name = url.host().isEmpty() ? url.toString() : url.host();
                addItem(url, name, {}, ITEM_NET);
            }

            ++m_revision;
            m_loading = false;
            emit q->loadingChanged();
            return true;
        }

        QString homePath = QVLCUserDir(VLC_HOME_DIR);
        //QVLCUserDir defaults to HomePath, make sure we only add it once
        bool homeAdded = false;
        auto addFilterHome = [&](const QString& path, const QString& label) {
            if (path == homePath ) {
                if (homeAdded) {
                    return;
                } else {
                    addItem(homePath, qtr("Home"), {});
                    homeAdded = true;
                }
            } else {
                addItem(path, label, {});
            }

        };

#ifdef Q_OS_UNIX
        addItem(homePath, qtr("Home"), {});
        homeAdded = true;
#endif
        addFilterHome(QVLCUserDir(VLC_DESKTOP_DIR), qtr("Desktop"));
        addFilterHome(QVLCUserDir(VLC_DOCUMENTS_DIR), qtr("Documents"));
        addFilterHome(QVLCUserDir(VLC_MUSIC_DIR), qtr("Music"));
        addFilterHome(QVLCUserDir(VLC_VIDEOS_DIR), qtr("Videos"));
        addFilterHome(QVLCUserDir(VLC_DOWNLOAD_DIR), qtr("Download"));

        //model is never updated, but this is still needed to fit the LocalListBaseModelPrivate requirements
        ++m_revision;
        m_loading = false;
        emit q->loadingChanged();
        return true;
    }

    const StandardPathItem* getItemForRow(int row) const
    {
        const StandardPathItemPtr* ref = item(row);
        if (ref)
            return ref->get();
        return nullptr;
    }

    void addItem(const QString & path, const QString & name, const QString& artwork)
    {
        addItem(QUrl::fromLocalFile(path), name, artwork, ITEM_LOCAL);
    }

    void addItem(const QUrl& url, const QString & name, const QString& artwork, input_item_net_type itemType)
    {

        auto item = std::make_shared<StandardPathItem>();

        item->name = name;
        item->mainMrl  = url;
        item->protocol = url.scheme();
        item->type = NetworkDeviceModel::TYPE_DIRECTORY;

        input_item_t * inputItem = input_item_NewDirectory(qtu(url.toString()), qtu(name), itemType);
        item->inputItem = SharedInputItem(inputItem, false);

        item->tree = MediaTreePtr(vlc_media_tree_New(), false);
        {
            MediaTreeLocker lock{item->tree};
            vlc_media_tree_Add(item->tree.get(), &(item->tree->root), inputItem);
        }

        item->artwork = artwork;

        m_items.emplace_back(std::move(item));
    }

public: //LocalListCacheLoader::ModelSource implementation
    std::vector<StandardPathItemPtr> getModelData(const QString& pattern) const override
    {
        if (pattern.isEmpty())
            return m_items;

        std::vector<StandardPathItemPtr> items;
        std::copy_if(
            m_items.cbegin(), m_items.cend(),
            std::back_inserter(items),
            [&pattern](const StandardPathItemPtr& item){
                return itemMatchPattern(item, pattern);
            });
        return items;
    }

    void reload()
    {
        Q_Q(StandardPathModel);
        if (m_qmlInitializing)
            return;
        m_items.clear();
        initializeModel();
        invalidateCache();
        Q_UNUSED(q);
    }

public:
    std::vector<StandardPathItemPtr> m_items;
    bool m_serversMode = false;
    QVariantList m_servers;
};

// Ctor / dtor

StandardPathModel::StandardPathModel(QObject * parent)
    : NetworkBaseModel(new StandardPathModelPrivate(this), parent)
{
}

bool StandardPathModel::serversMode() const
{
    Q_D(const StandardPathModel);
    return d->m_serversMode;
}

void StandardPathModel::setServersMode(bool enabled)
{
    Q_D(StandardPathModel);
    if (d->m_serversMode == enabled)
        return;
    d->m_serversMode = enabled;
    d->reload();
    emit serversModeChanged();
}

QVariantList StandardPathModel::servers() const
{
    Q_D(const StandardPathModel);
    return d->m_servers;
}

void StandardPathModel::setServers(const QVariantList& servers)
{
    Q_D(StandardPathModel);
    if (d->m_servers == servers)
        return;
    d->m_servers = servers;
    if (d->m_serversMode)
        d->reload();
    emit serversChanged();
}

// QAbstractItemModel implementation

QHash<int, QByteArray> StandardPathModel::roleNames() const /* override */
{
    auto roles = NetworkBaseModel::roleNames();
    roles[PATH_SOURCE] = QByteArrayLiteral("source");
    roles[PATH_TREE] = QByteArrayLiteral("tree");
    return roles;
}

QVariant StandardPathModel::data(const QModelIndex & index, int role) const /* override */
{
    Q_D(const StandardPathModel);

    const StandardPathItem* item = d->getItemForRow(index.row());
    if (!item)
        return {};

    switch (role)
    {
        case PATH_TREE:
            return QVariant::fromValue(NetworkTreeItem(item->tree, item->inputItem));
        default:
            return NetworkBaseModel::basedata(*item, role);
    }
}
