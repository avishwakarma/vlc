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
#include "waveform_item.hpp"

#include <QQuickWindow>
#include <QSGGeometryNode>
#include <QSGVertexColorMaterial>

#include <algorithm>
#include <cmath>

#include "maininterface/mainctx.hpp"

namespace {

// level of a bar: peak relative to the loudest peak of the media (linear, so
// quiet passages read as dots and the dynamics stay visible, as in Figma)

// segments per rounded corner
constexpr int CORNER_SEGMENTS = 3;

struct Vertex { float x, y; uchar r, g, b, a; };
static_assert(sizeof(Vertex) == sizeof(QSGGeometry::ColoredPoint2D));

struct Rgba { uchar r, g, b, a; };

Rgba premultiplied(const QColor& c, float opacity = 1.f)
{
    const float a = c.alphaF() * opacity;
    return { uchar(std::lround(c.redF() * a * 255)), uchar(std::lround(c.greenF() * a * 255)),
             uchar(std::lround(c.blueF() * a * 255)), uchar(std::lround(a * 255)) };
}

QColor mix(const QColor& a, const QColor& b, float t)
{
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t,
                            a.greenF() + (b.greenF() - a.greenF()) * t,
                            a.blueF() + (b.blueF() - a.blueF()) * t,
                            a.alphaF() + (b.alphaF() - a.alphaF()) * t);
}

/*
 * Anti-aliased rounded rectangle: a fan over the inner outline (opaque) and a
 * one device pixel fringe whose outer edge is transparent, which is what the
 * Qt Quick rectangle node does. Works with the stock vertex colour material,
 * so no custom shader is needed.
 */
class Mesh
{
public:
    std::vector<Vertex> vertices;
    std::vector<quint32> indices;

    void clear() { vertices.clear(); indices.clear(); }

    void addRoundedRect(const QRectF& rect, qreal radius, Rgba color, qreal aa)
    {
        if (rect.width() <= 0 || rect.height() <= 0 || color.a == 0)
            return;

        radius = std::clamp(radius, 0., std::min(rect.width(), rect.height()) / 2);
        const qreal half = aa / 2;

        const quint32 base = quint32(vertices.size());
        const QPointF center = rect.center();
        vertices.push_back({ float(center.x()), float(center.y()), color.r, color.g, color.b, color.a });

        // corner arc centres, clockwise from top-right (y down)
        const QPointF centres[4] = {
            { rect.right() - radius, rect.top() + radius },
            { rect.right() - radius, rect.bottom() - radius },
            { rect.left() + radius, rect.bottom() - radius },
            { rect.left() + radius, rect.top() + radius },
        };
        const qreal startAngle[4] = { -M_PI / 2, 0, M_PI / 2, M_PI };

        quint32 ring = 0;
        for (int c = 0; c < 4; c++)
        {
            for (int s = 0; s <= CORNER_SEGMENTS; s++)
            {
                const qreal angle = startAngle[c] + (M_PI / 2) * s / CORNER_SEGMENTS;
                const qreal nx = std::cos(angle), ny = std::sin(angle);
                const qreal px = centres[c].x() + nx * radius;
                const qreal py = centres[c].y() + ny * radius;

                // inner (opaque), clamped so tiny rects keep a core
                qreal ix = px - nx * half, iy = py - ny * half;
                ix = std::clamp(ix, std::min(center.x(), px), std::max(center.x(), px));
                iy = std::clamp(iy, std::min(center.y(), py), std::max(center.y(), py));
                vertices.push_back({ float(ix), float(iy), color.r, color.g, color.b, color.a });
                // outer (transparent)
                vertices.push_back({ float(px + nx * half), float(py + ny * half), 0, 0, 0, 0 });
                ring++;
            }
        }

        for (quint32 i = 0; i < ring; i++)
        {
            const quint32 j = (i + 1) % ring;
            const quint32 inI = base + 1 + 2 * i, outI = inI + 1;
            const quint32 inJ = base + 1 + 2 * j, outJ = inJ + 1;
            indices.insert(indices.end(), { base, inI, inJ });
            indices.insert(indices.end(), { inI, outI, outJ, inI, outJ, inJ });
        }
    }

    void upload(QSGGeometryNode* node) const
    {
        QSGGeometry* geometry = node->geometry();
        geometry->allocate(int(vertices.size()), int(indices.size()));
        if (!vertices.empty())
            memcpy(geometry->vertexData(), vertices.data(), vertices.size() * sizeof(Vertex));
        if (!indices.empty())
            memcpy(geometry->indexData(), indices.data(), indices.size() * sizeof(quint32));
        node->markDirty(QSGNode::DirtyGeometry);
    }
};

QSGGeometryNode* newMeshNode()
{
    auto node = new QSGGeometryNode;
    auto geometry = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), 0, 0,
                                    QSGGeometry::UnsignedIntType);
    geometry->setDrawingMode(QSGGeometry::DrawTriangles);
    node->setGeometry(geometry);
    node->setMaterial(new QSGVertexColorMaterial);
    node->setFlags(QSGNode::OwnsGeometry | QSGNode::OwnsMaterial);
    return node;
}

} // namespace

WaveformItem::WaveformItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents);

    m_animation.setStartValue(0.);
    m_animation.setEndValue(1.);
    m_animation.setEasingCurve(QEasingCurve::OutCubic);
    connect(&m_animation, &QVariantAnimation::valueChanged, this, [this](const QVariant& value) {
        m_animT = value.toReal();
        markBarsDirty();
    });
}

WaveformItem::~WaveformItem() = default;

void WaveformItem::setCtx(MainCtx* ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
    requestData();
}

void WaveformItem::setSource(const QUrl& source)
{
    if (m_source == source)
        return;
    m_source = source;
    emit sourceChanged();
    requestData();
}

void WaveformItem::requestData()
{
    if (m_data)
        disconnect(m_data.get(), nullptr, this, nullptr);
    m_data.reset(); // cancels the previous analysis if nobody else shows it

    if (m_ctx && !m_source.isEmpty())
    {
        if (WaveformService* service = WaveformService::instance(m_ctx->getIntf(), m_ctx))
        {
            m_data = service->request(m_source);
            connect(m_data.get(), &WaveformData::changed, this, &WaveformItem::onDataChanged);
        }
    }

    // the bars of the previous media shrink, the new ones grow when their
    // peaks arrive
    onDataChanged();
}

void WaveformItem::onDataChanged()
{
    // While an analysis has not produced anything yet, keep the current mode:
    // switching media keeps the waveform without a flash of the plain bar,
    // and a media that turns out unsupported never shows it.
    bool available = m_available;
    if (!m_data || !m_data->available())
        available = false;
    else if (m_data->state() == WaveformData::State::Ready || !m_data->bins().isEmpty())
        available = true;

    const bool ready = m_data && m_data->state() == WaveformData::State::Ready;
    const qreal progress = m_data ? m_data->progress() : 0.;

    if (available != m_available || ready != m_ready)
    {
        m_available = available;
        m_ready = ready;
        emit availableChanged();
    }
    if (progress != m_progress)
    {
        m_progress = progress;
        emit progressChanged();
    }
    updateTargets(true);
}

int WaveformItem::barCount() const
{
    const qreal pitch = m_barWidth + m_barSpacing;
    if (pitch <= 0)
        return 0;
    const qreal usable = width() - m_leftPadding - m_rightPadding + m_barSpacing;
    return std::max(0, int(std::floor(usable / pitch)));
}

qreal WaveformItem::playheadX(qreal position) const
{
    const qreal span = std::max(0., width() - 2 * m_playheadInset - m_playheadWidth);
    return m_playheadInset + std::clamp(position, 0., 1.) * span;
}

/* which bars are played / hidden by the playhead, to skip useless rebuilds */
std::tuple<int, int, int> WaveformItem::barSignature(qreal position) const
{
    const qreal pitch = m_barWidth + m_barSpacing;
    if (pitch <= 0)
        return {};
    const qreal x = playheadX(position);
    const auto index = [&](qreal edge) { return int(std::floor((edge - m_leftPadding) / pitch)); };
    return { index(x + m_playheadWidth / 2 - m_barWidth / 2),
             index(x - m_playheadGap - m_barWidth),
             index(x + m_playheadWidth + m_playheadGap) };
}

qreal WaveformItem::phCentreMin() const { return playheadX(0.) + m_playheadWidth / 2; }
qreal WaveformItem::phCentreMax() const { return playheadX(1.) + m_playheadWidth / 2; }

qreal WaveformItem::positionAt(qreal x) const
{
    const qreal span = width() - 2 * m_playheadInset - m_playheadWidth;
    if (span <= 0)
        return 0.;
    return (x - m_playheadInset - m_playheadWidth / 2) / span;
}

void WaveformItem::updateTargets(bool animate)
{
    const int count = barCount();
    std::vector<float> targets(count, -1.f);

    if (m_data && m_data->available() && !m_data->bins().isEmpty())
    {
        const QVector<float>& bins = m_data->bins();
        const int binCount = bins.size();

        // bins are RMS levels, mapped in dB on a fixed scale (not relative to
        // the track), so that bars never change when more data arrives and the
        // dynamics of loud, compressed masters stay visible. A plain
        // peak/max ratio makes them look flat.
        constexpr float silence = 1e-4f;
        constexpr float dbFloor = -19.f, dbCeil = -9.f;
        const qreal pitch = m_barWidth + m_barSpacing;
        for (int k = 0; k < count; k++)
        {
            // positions covered by this bar, as the playhead maps them
            const qreal centre = m_leftPadding + k * pitch + m_barWidth / 2;
            const qreal p0 = std::clamp(positionAt(centre - pitch / 2), 0., 1.);
            const qreal p1 = std::clamp(positionAt(centre + pitch / 2), 0., 1.);
            int b0 = int(std::floor(p0 * binCount));
            int b1 = int(std::ceil(p1 * binCount));
            b0 = std::clamp(b0, 0, binCount - 1);
            b1 = std::clamp(b1, b0 + 1, binCount);

            float peak = 0.f;
            bool pending = false;
            for (int b = b0; b < b1; b++)
            {
                if (bins[b] < 0.f)
                    pending = true;
                else
                    peak += bins[b] * bins[b];
            }
            peak = std::sqrt(peak / (b1 - b0)); // RMS of the span covered by the bar
            if (pending)
                continue; // not (fully) analysed yet: the bar appears once final

            float level = 0.f;
            if (peak > silence)
                level = std::clamp((20.f * std::log10(peak) - dbFloor) / (dbCeil - dbFloor), 0.f, 1.f);
            targets[k] = level;
        }
    }

    // current (interpolated) levels become the start of the new animation
    std::vector<float> from(count, -1.f);
    if (animate && int(m_to.size()) == count)
    {
        const float t = float(m_animT);
        for (int k = 0; k < count; k++)
        {
            const float a = std::max(m_from[k], 0.f), b = std::max(m_to[k], 0.f);
            from[k] = (m_to[k] < 0.f && m_from[k] < 0.f) ? -1.f : a + (b - a) * t;
        }
    }
    else
        from = targets;

    m_from = std::move(from);
    m_to = std::move(targets);

    if (animate && m_from != m_to && m_animationDuration > 0 && isVisible())
    {
        m_animation.stop();
        m_animation.setDuration(m_animationDuration);
        m_animT = 0.;
        m_animation.start();
    }
    else
    {
        m_animation.stop();
        m_animT = 1.;
        m_from = m_to;
    }
    markBarsDirty();
}

void WaveformItem::markBarsDirty()
{
    m_barsDirty = true;
    update();
}

void WaveformItem::setPosition(qreal position)
{
    if (qFuzzyCompare(m_position, position))
        return;

    // the bars are static: only the played/remaining split moves with the playhead
    const bool barsChange = barSignature(position) != barSignature(m_position);

    m_position = position;
    emit positionChanged();

    m_playheadDirty = true;
    if (barsChange)
        m_barsDirty = true;
    update();
}

void WaveformItem::setHoverX(qreal x)
{
    if (x < 0)
        x = -1.;
    if (qFuzzyCompare(m_hoverX, x))
        return;
    m_hoverX = x;
    emit hoverXChanged();
    markBarsDirty();
}

#define STYLE_SETTER(Name, member, Type) \
    void WaveformItem::set##Name(Type value) \
    { \
        if (member == value) \
            return; \
        member = value; \
        emit styleChanged(); \
        m_playheadDirty = true; \
        updateTargets(false); \
    }

STYLE_SETTER(PlayedColor, m_playedColor, const QColor&)
STYLE_SETTER(RemainingColor, m_remainingColor, const QColor&)
STYLE_SETTER(PlayheadColor, m_playheadColor, const QColor&)
STYLE_SETTER(BarWidth, m_barWidth, qreal)
STYLE_SETTER(BarSpacing, m_barSpacing, qreal)
STYLE_SETTER(BarMinHeight, m_barMinHeight, qreal)
STYLE_SETTER(BarMaxHeight, m_barMaxHeight, qreal)
STYLE_SETTER(LeftPadding, m_leftPadding, qreal)
STYLE_SETTER(RightPadding, m_rightPadding, qreal)
STYLE_SETTER(PlayheadWidth, m_playheadWidth, qreal)
STYLE_SETTER(PlayheadInset, m_playheadInset, qreal)
STYLE_SETTER(PlayheadGap, m_playheadGap, qreal)

#undef STYLE_SETTER

void WaveformItem::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size())
    {
        m_playheadDirty = true;
        updateTargets(false); // the number of bars depends on the width
    }
}

void WaveformItem::itemChange(ItemChange change, const ItemChangeData& value)
{
    if (change == ItemDevicePixelRatioHasChanged)
    {
        m_playheadDirty = true;
        markBarsDirty();
    }
    QQuickItem::itemChange(change, value);
}

QSGNode* WaveformItem::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*)
{
    QSGNode* root = oldNode;
    if (!root)
    {
        root = new QSGNode;
        root->appendChildNode(newMeshNode()); // bars
        root->appendChildNode(newMeshNode()); // playhead
        m_barsDirty = m_playheadDirty = true;
    }
    auto barsNode = static_cast<QSGGeometryNode*>(root->firstChild());
    auto playheadNode = static_cast<QSGGeometryNode*>(barsNode->nextSibling());

    const qreal dpr = window() ? window()->effectiveDevicePixelRatio() : 1.;
    const qreal aa = 1. / dpr; // one device pixel
    const auto snap = [dpr](qreal v) { return std::round(v * dpr) / dpr; };

    const qreal phX = snap(playheadX(m_position));
    const qreal phH = std::max(0., height() - 2 * m_playheadInset);

    if (m_barsDirty)
    {
        m_barsDirty = false;

        Mesh mesh;
        const int count = int(m_to.size());
        mesh.vertices.reserve(size_t(count) * (1 + 8 * (CORNER_SEGMENTS + 1)));
        mesh.indices.reserve(size_t(count) * 12 * (CORNER_SEGMENTS + 1));

        const qreal pitch = m_barWidth + m_barSpacing;
        const qreal centreY = height() / 2;
        const qreal phCentre = phX + m_playheadWidth / 2;
        // the pointer seeks to positionAt(x), whose playhead centre is x itself
        const qreal hoverX = m_hoverX >= 0 ? std::clamp(m_hoverX, phCentreMin(), phCentreMax()) : -1.;

        // seek preview between the playhead and the pointer
        const Rgba played = premultiplied(m_playedColor);
        const Rgba remaining = premultiplied(m_remainingColor);
        const Rgba aheadPreview = premultiplied(mix(m_remainingColor, m_playedColor, .5f));
        const Rgba behindPreview = premultiplied(mix(m_playedColor, m_remainingColor, .5f));

        const float t = float(m_animT);

        // bars sit on a fixed grid and never move or hide: the playhead is
        // drawn on top of them
        for (int k = 0; k < count; k++)
        {
            const qreal x = snap(m_leftPadding + k * pitch);

            const float a = std::max(m_from[k], 0.f), b = std::max(m_to[k], 0.f);
            const float level = a + (b - a) * t;

            // even height in device pixels keeps the bar centred on the grid
            qreal h = m_barMinHeight + (m_barMaxHeight - m_barMinHeight) * level;
            h = std::max(2., std::round(h * dpr / 2) * 2) / dpr;
            const qreal y = snap(centreY - h / 2);

            const qreal centre = x + m_barWidth / 2;
            Rgba color = centre < phCentre ? played : remaining;
            if (hoverX >= 0)
            {
                if (centre > phCentre && centre <= hoverX)
                    color = aheadPreview;
                else if (centre < phCentre && centre >= hoverX)
                    color = behindPreview;
            }

            mesh.addRoundedRect(QRectF(x, y, m_barWidth, h), m_barWidth / 2, color, aa);
        }
        mesh.upload(barsNode);
    }

    if (m_playheadDirty)
    {
        m_playheadDirty = false;
        Mesh mesh;
        mesh.addRoundedRect(QRectF(phX, snap(m_playheadInset), m_playheadWidth, phH),
                            m_playheadWidth / 2, premultiplied(m_playheadColor), aa);
        mesh.upload(playheadNode);
    }

    return root;
}
