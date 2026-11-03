import QtQuick

Item {
  id: slot

  required property var bar            // a janela (canva)
  required property string edge        // "left" | "right" | "top" | "bottom"

  property real pos: 0                 // deslocamento a partir do alinhamento
  property string align: "start"       // "start" | "center" | "end"
  property real length: 40             // tamanho ao longo da barra

  property int offset: 0
  property int animationTime: 250

  readonly property bool vertical: edge === "left" || edge === "right"
  readonly property real thickness: ({
    left: bar.leftSize, right: bar.rightSize,
    top: bar.topSize, bottom: bar.bottomSize
  })[edge]

  // trecho útil: entre as barras perpendiculares (mesma regra dos popups)
  readonly property real aMin: vertical ? bar.topSize : bar.leftSize
  readonly property real aMax: vertical ? bar.height - bar.bottomSize
                                        : bar.width - bar.rightSize

  readonly property real along: Math.round(
      align === "center" ? (aMin + aMax - length) / 2 + pos
    : align === "end"    ? aMax - length - pos
    :                      aMin + pos)

  // 1. Definimos o valor alvo base para x e y
  readonly property real targetX: vertical ? (edge === "left" ? 0 + offset : bar.width - thickness - offset) : along
  readonly property real targetY: vertical ? along : (edge === "top" ? 0 + offset : bar.height - thickness - offset)

  // 2. Atribuímos x e y com animação suave de transição (Behavior on)
  x: targetX
  Behavior on x {
    NumberAnimation { duration: animationTime; easing.type: barDrawer.dockActive ? Easing.OutCubic : Easing.InCubic }
  }

  y: targetY
  Behavior on y {
    NumberAnimation { duration: animationTime; easing.type: barDrawer.dockActive ? Easing.OutCubic : Easing.InCubic }
  }

  width: vertical ? thickness : length
  height: vertical ? length : thickness
  visible: thickness > 0
}
