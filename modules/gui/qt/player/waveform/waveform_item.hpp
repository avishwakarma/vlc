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
#ifndef VLC_QT_WAVEFORM_ITEM_HPP
#define VLC_QT_WAVEFORM_ITEM_HPP

#include <QColor>
#include <QQuickItem>
#include <QUrl>
#include <QVariantAnimation>

#include <tuple>
#include <vector>

#include "waveform_service.hpp"

class MainCtx;
Q_MOC_INCLUDE("maininterface/mainctx.hpp")

/**
 * Waveform seek track (Figma 2139:8124 / 4767:23726): vertical bars on a
 * fixed grid, height = peak level, played bars in one colour and the rest in
 * another, a playhead at the position. Drawn with one scene graph geometry
 * node for the bars and one for the playhead (anti-aliased rounded bars).
 *
 * Input handling stays in SliderBar; this item only draws.
 */
class WaveformItem : public QQuickItem
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ ctx WRITE setCtx NOTIFY ctxChanged FINAL)
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged FINAL)

    // 0..1, same mapping as the SliderBar thumb
    Q_PROPERTY(qreal position READ position WRITE setPosition NOTIFY positionChanged FINAL)
    // x of the pointer while hovered or dragged (seek preview), < 0 otherwise
    Q_PROPERTY(qreal hoverX READ hoverX WRITE setHoverX NOTIFY hoverXChanged FINAL)

    Q_PROPERTY(QColor playedColor MEMBER m_playedColor WRITE setPlayedColor NOTIFY styleChanged FINAL)
    Q_PROPERTY(QColor remainingColor MEMBER m_remainingColor WRITE setRemainingColor NOTIFY styleChanged FINAL)
    Q_PROPERTY(QColor playheadColor MEMBER m_playheadColor WRITE setPlayheadColor NOTIFY styleChanged FINAL)

    // geometry (logical px, scaled by the caller)
    Q_PROPERTY(qreal barWidth MEMBER m_barWidth WRITE setBarWidth NOTIFY styleChanged FINAL)
    Q_PROPERTY(qreal barSpacing MEMBER m_barSpacing WRITE setBarSpacing NOTIFY styleChanged FINAL)
    Q_PROPERTY(qreal barMinHeight MEMBER m_barMinHeight WRITE setBarMinHeight NOTIFY styleChanged FINAL)
    Q_PROPERTY(qreal barMaxHeight MEMBER m_barMaxHeight WRITE setBarMaxHeight NOTIFY styleChanged FINAL)
    Q_PROPERTY(qreal leftPadding MEMBER m_leftPadding WRITE setLeftPadding NOTIFY styleChanged FINAL)
    Q_PROPERTY(qreal rightPadding MEMBER m_rightPadding WRITE setRightPadding NOTIFY styleChanged FINAL)
    Q_PROPERTY(qreal playheadWidth MEMBER m_playheadWidth WRITE setPlayheadWidth NOTIFY styleChanged FINAL)
    Q_PROPERTY(qreal playheadInset MEMBER m_playheadInset WRITE setPlayheadInset NOTIFY styleChanged FINAL)
    Q_PROPERTY(qreal playheadGap MEMBER m_playheadGap WRITE setPlayheadGap NOTIFY styleChanged FINAL)

    // duration of the bar growth when peaks arrive
    Q_PROPERTY(int animationDuration MEMBER m_animationDuration NOTIFY styleChanged FINAL)

    // a waveform exists or is being computed for the source
    Q_PROPERTY(bool available READ available NOTIFY availableChanged FINAL)
    // analysis complete
    Q_PROPERTY(bool ready READ ready NOTIFY availableChanged FINAL)
    Q_PROPERTY(qreal progress READ progress NOTIFY progressChanged FINAL)

public:
    explicit WaveformItem(QQuickItem* parent = nullptr);
    ~WaveformItem() override;

    MainCtx* ctx() const { return m_ctx; }
    void setCtx(MainCtx* ctx);

    QUrl source() const { return m_source; }
    void setSource(const QUrl& source);

    qreal position() const { return m_position; }
    void setPosition(qreal position);

    qreal hoverX() const { return m_hoverX; }
    void setHoverX(qreal x);

    void setPlayedColor(const QColor&);
    void setRemainingColor(const QColor&);
    void setPlayheadColor(const QColor&);
    void setBarWidth(qreal);
    void setBarSpacing(qreal);
    void setBarMinHeight(qreal);
    void setBarMaxHeight(qreal);
    void setLeftPadding(qreal);
    void setRightPadding(qreal);
    void setPlayheadWidth(qreal);
    void setPlayheadInset(qreal);
    void setPlayheadGap(qreal);

    /** position for a x coordinate, inverse of the playhead placement */
    Q_INVOKABLE qreal positionAt(qreal x) const;

    bool available() const { return m_available; }
    bool ready() const { return m_ready; }
    qreal progress() const { return m_progress; }

signals:
    void ctxChanged();
    void sourceChanged();
    void positionChanged();
    void hoverXChanged();
    void styleChanged();
    void availableChanged();
    void progressChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData& value) override;

private:
    void requestData();
    void onDataChanged();
    void updateTargets(bool animate);
    void markBarsDirty();
    qreal playheadX(qreal position) const;
    std::tuple<int, int, int> barSignature(qreal position) const;
    qreal phCentreMin() const;
    qreal phCentreMax() const;
    int barCount() const;

    MainCtx* m_ctx = nullptr;
    QUrl m_source;
    WaveformDataPtr m_data;

    qreal m_position = 0.;
    qreal m_hoverX = -1.;

    QColor m_playedColor { 0xAB, 0x63, 0x14 };
    QColor m_remainingColor { 0x40, 0x40, 0x40 };
    QColor m_playheadColor { 0xD3, 0x79, 0x18 };

    qreal m_barWidth = 2.;
    qreal m_barSpacing = 3.;
    qreal m_barMinHeight = 2.;
    qreal m_barMaxHeight = 14.;
    qreal m_leftPadding = 6.;
    qreal m_rightPadding = 6.;
    qreal m_playheadWidth = 4.;
    qreal m_playheadInset = 2.;
    qreal m_playheadGap = 3.;
    int m_animationDuration = 250;

    bool m_available = false;
    bool m_ready = false;
    qreal m_progress = 0.;

    // per bar levels 0..1 (< 0: not analysed yet), animated from -> to
    std::vector<float> m_from;
    std::vector<float> m_to;
    qreal m_animT = 1.;
    QVariantAnimation m_animation;

    bool m_barsDirty = true;
    bool m_playheadDirty = true;
};

#endif
