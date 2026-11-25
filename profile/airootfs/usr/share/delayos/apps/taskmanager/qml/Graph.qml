import QtQuick
import DelayUI

// History graph (60 samples): accent line with a soft accent fill; optional grid.
Canvas {
    id: g
    property var values: []
    property real maxValue: 100          // 0 = auto
    property bool grid: false
    property color lineColor: Theme.accent
    renderStrategy: Canvas.Cooperative
    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const w = width, h = height
        if (grid) {
            ctx.strokeStyle = Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)
            ctx.lineWidth = 1
            for (let i = 1; i < 10; ++i) { const x = Math.round(w * i / 10) + 0.5; ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke() }
            for (let j = 1; j < 10; ++j) { const y = Math.round(h * j / 10) + 0.5; ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke() }
        }
        const v = values || []
        if (v.length < 2) return
        let mx = maxValue
        if (mx <= 0) { mx = 1; for (const x of v) mx = Math.max(mx, x * 1.15) }
        const step = w / (v.length - 1)
        ctx.beginPath()
        ctx.moveTo(0, h)
        for (let i = 0; i < v.length; ++i) ctx.lineTo(i * step, h - Math.min(1, v[i] / mx) * (h - 2) - 1)
        ctx.lineTo(w, h)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.22)
        ctx.fill()
        ctx.beginPath()
        for (let i = 0; i < v.length; ++i) {
            const y = h - Math.min(1, v[i] / mx) * (h - 2) - 1
            if (i === 0) ctx.moveTo(0, y); else ctx.lineTo(i * step, y)
        }
        ctx.strokeStyle = lineColor
        ctx.lineWidth = 1.5
        ctx.stroke()
    }
}
