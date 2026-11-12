import QtQuick

import "../../progress"

// Badge do nível com o anel de progresso até o próximo nível.
// A forma do badge muda a cada 5 níveis; a cor vem do accent do tema.
Box {
  id: root

  // ================= CONFIGURAÇÕES =================
  property color accentColor: "#12b76a"
  property color textColor: "white"
  property color mutedColor: "#99ffffff"
  property color trackColor: "#33ffffff"
  property real ringWidth: 7
  property real ringGap: 8                 // espaço entre o anel e o badge
  property int levelsPerTier: 5
  // n = lados (0 = círculo); inner = raio interno relativo (estrela quando < 1)
  property var shapes: [
    { n: 0,  inner: 1 },
    { n: 6,  inner: 1 },
    { n: 8,  inner: 1 },
    { n: 5,  inner: 0.55 },
    { n: 8,  inner: 0.62 },
    { n: 12, inner: 0.78 }
  ]
  // =================================================

  readonly property int tier: Math.min(shapes.length - 1, Math.floor(Progress.level / levelsPerTier))
  readonly property real luma: 0.299 * accentColor.r + 0.587 * accentColor.g + 0.114 * accentColor.b
  readonly property color badgeTextColor: luma > 0.6 ? "#111111" : "white"

  Column {
    anchors.fill: parent
    spacing: 6

    Item {
      id: ringBox
      width: parent.width
      height: parent.height - label.height - parent.spacing

      Canvas {
        id: canvas
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        antialiasing: true

        Connections {
          target: Progress
          function onLevelChanged() { canvas.requestPaint() }
          function onLevelProgressChanged() { canvas.requestPaint() }
        }
        Connections {
          target: root
          function onAccentColorChanged() { canvas.requestPaint() }
          function onTrackColorChanged() { canvas.requestPaint() }
          function onTierChanged() { canvas.requestPaint() }
        }
        onWidthChanged: requestPaint()

        onPaint: {
          const ctx = getContext("2d")
          ctx.reset()
          const cx = width / 2, cy = height / 2
          const R = width / 2 - 2
          const rr = R - root.ringWidth / 2

          ctx.lineWidth = root.ringWidth
          ctx.lineCap = "round"
          ctx.strokeStyle = root.trackColor
          ctx.beginPath(); ctx.arc(cx, cy, rr, 0, Math.PI * 2); ctx.stroke()

          if (Progress.levelProgress > 0.002) {
            ctx.strokeStyle = root.accentColor
            ctx.beginPath()
            ctx.arc(cx, cy, rr, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Progress.levelProgress)
            ctx.stroke()
          }

          // badge
          const br = rr - root.ringWidth / 2 - root.ringGap
          const s = root.shapes[root.tier]
          ctx.fillStyle = root.accentColor
          ctx.beginPath()
          if (s.n === 0) {
            ctx.arc(cx, cy, br, 0, Math.PI * 2)
          } else {
            const pts = s.inner < 1 ? s.n * 2 : s.n
            for (let i = 0; i < pts; i++) {
              const a = -Math.PI / 2 + i * Math.PI * 2 / pts
              const r = (s.inner < 1 && i % 2 === 1) ? br * s.inner : br
              const x = cx + r * Math.cos(a), y = cy + r * Math.sin(a)
              if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.closePath()
          }
          ctx.fill()
        }
      }

      Text {
        anchors.centerIn: canvas
        text: Progress.level
        font.pixelSize: canvas.width * 0.3
        font.bold: true
        color: root.badgeTextColor
      }
    }

    Text {
      id: label
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: "nível " + Progress.level + " · " + Math.round(Progress.xp - Progress.levelStartXp) + " / "
            + Math.round(Progress.nextLevelXp - Progress.levelStartXp) + " xp"
      font.pixelSize: 12
      color: root.mutedColor
      elide: Text.ElideRight
    }
  }
}
