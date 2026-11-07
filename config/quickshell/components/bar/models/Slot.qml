import QtQuick

Item {
  id: slot

  required property var bar            // a janela (canva)
  required property string edge        // "left" | "right" | "top" | "bottom"

  property real pos: 0                 // deslocamento a partir do alinhamento
  property string align: "start"       // "start" | "center" | "end"
  property real length: 40             // tamanho ao longo da barra

  // O offset vem de barDrawer.dockSize, que já é o valor animado.
  // Por isso aqui não há Behavior: animar de novo faria o item ficar para trás.
  property int offset: 0
  property int animationTime: 250      // não é mais usado aqui

  readonly property bool vertical: edge === "left" || edge === "right"
  readonly property real thickness: ({
    left: bar.leftSize, right: bar.rightSize,
    top: bar.topSize, bottom: bar.bottomSize
  })[edge]

  readonly property real aMin: vertical ? bar.topSize : bar.leftSize
  readonly property real aMax: vertical ? bar.height - bar.bottomSize
                                        : bar.width - bar.rightSize

  readonly property real along: Math.round(
      align === "center" ? (aMin + aMax - length) / 2 + pos
    : align === "end"    ? aMax - length - pos
    :                      aMin + pos)

  x: vertical ? (edge === "left" ? 0 + offset : bar.width - thickness - offset) : along
  y: vertical ? along : (edge === "top" ? 0 + offset : bar.height - thickness - offset)

  width: vertical ? thickness : length
  height: vertical ? length : thickness
  visible: thickness > 0
}
