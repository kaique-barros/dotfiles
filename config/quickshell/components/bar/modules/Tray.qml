import QtQuick
import Quickshell.Widgets
import Quickshell.Services.SystemTray

import "../models"

// Quadrado da bandeja. Fechado: grade columns x rows com os primeiros apps.
// Com o mouse em cima: estica para cima e os ícones sobem até a posição na coluna.
BarItemModel {
  id: root

  // ================= CONFIGURAÇÕES =================
  property real boxSize: bar ? bar.pillThickness : 40     // lado do quadrado fechado
  property real radius: bar ? bar.trayRadius : 10                                // cantos arredondados

  // fechado
  property int columns: bar ? bar.trayColumns : 2
  property int rows: bar ? bar.trayRows : 2
  property real gap: bar ? bar.trayGap : 4

  // aberto
  property real expandedIconSize: bar ? bar.trayIconSize : 26
  property real expandedSpacing: bar ? bar.traySpacing : 10
  property real maxLength: 360                            // comprimento máximo aberto, ao longo da barra
  property real scrollStep: 0.25                          // rolagem da lista com a roda do mouse
  property real marginTop: 8
  property real marginBottom: 8

  // animação
  property int expandDuration: 220
  property real stagger: 0.05                             // atraso entre ícones ao subir (0 = todos juntos)
  property int closeDelay: 200                            // espera antes de fechar ao tirar o mouse
  // =================================================

  readonly property int maxShown: columns * rows
  readonly property int count: SystemTray.items.values.length

  framed: false
  fillColor: bar ? bar.itemFillColor : "gray"            // a mesma cor das workspaces
  frameRadius: radius
  padding: 4

  inset: Math.max(0, (thickness - boxSize) / 2)

  // ---------- abre / fecha ----------
  property bool expanded: false
  readonly property bool open: expanded && count > 0

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (hovered) { closeTimer.stop(); root.expanded = true }
      else closeTimer.restart()
    }
  }
  Timer {
    id: closeTimer
    interval: root.closeDelay
    onTriggered: root.expanded = false
  }

  // progresso da animação: 0 = fechado, 1 = aberto
  property real t: open ? 1 : 0
  Behavior on t {
    NumberAnimation { duration: root.expandDuration; easing.type: Easing.OutCubic }
  }

  // ---------- tamanho (cresce para cima porque o item está alinhado ao fim) ----------
  readonly property real collapsedLength: boxSize + 2 * inset
  readonly property real iconBox: Math.min(expandedIconSize, contentThickness)
  readonly property real step: iconBox + expandedSpacing
  readonly property real listHeight: count * iconBox + Math.max(0, count - 1) * expandedSpacing
  readonly property real expandedLength:
      Math.min(maxLength, Math.max(collapsedLength,
        listHeight + marginTop + marginBottom + 2 * (inset + padding)))

  // altura útil (dentro do padding) quando aberto
  readonly property real expandedContent: expandedLength - 2 * (inset + padding)
  readonly property real overflow: Math.max(0, listHeight + marginTop + marginBottom - expandedContent)

  length: open ? expandedLength : collapsedLength
  Behavior on length {
    NumberAnimation { duration: root.expandDuration; easing.type: Easing.OutCubic }
  }

  // grade do estado fechado
  readonly property real cell: Math.floor(
    (boxSize - 2 * padding - (columns - 1) * gap) / columns)
  readonly property real gridW: columns * cell + (columns - 1) * gap
  readonly property real gridH: rows * cell + (rows - 1) * gap

  // rolagem da lista aberta
  property real scroll: 0
  onOpenChanged: if (!open) scroll = 0
  onOverflowChanged: scroll = Math.min(scroll, overflow)

  // ---------- ícones (um só por app; ele se move entre as duas posições) ----------
  Item {
    id: stage
    anchors.fill: parent

    WheelHandler {
      enabled: root.open && root.overflow > 0
      onWheel: (wheel) => {
        root.scroll = Math.max(0, Math.min(root.overflow, root.scroll - wheel.angleDelta.y * root.scrollStep))
      }
    }

    Repeater {
      model: SystemTray.items

      delegate: Item {
        id: ic
        required property var modelData
        required property int index

        readonly property bool inGrid: index < root.maxShown

        // progresso individual (com atraso entre os ícones)
        readonly property real ti: Math.max(0, Math.min(1,
          (root.t - index * root.stagger) / Math.max(0.3, 1 - (root.count - 1) * root.stagger)))

        // posições fechada e aberta (a vertical é medida a partir do fim da barra,
        // que não se move, então o ícone "sobe" em relação à tela)
        readonly property real xClosed: (stage.width - root.gridW) / 2
                                        + (index % root.columns) * (root.cell + root.gap)
        readonly property real dyClosed: inGrid
            ? Math.floor(index / root.columns) * (root.cell + root.gap) - root.gridH
            : -root.cell
        readonly property real xOpen: (stage.width - root.iconBox) / 2
        readonly property real dyOpen: root.marginTop + index * root.step - root.scroll - root.expandedContent

        width: root.cell + (root.iconBox - root.cell) * ti
        height: width
        x: xClosed + (xOpen - xClosed) * ti
        y: stage.height + dyClosed + (dyOpen - dyClosed) * ti
        opacity: inGrid ? 1 : ti

        IconImage {
          anchors.fill: parent
          source: ic.modelData.icon
        }

        MouseArea {
          id: area
          anchors.fill: parent
          enabled: ic.opacity > 0.5
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          cursorShape: Qt.PointingHandCursor

          onClicked: (mouse) => {
            const it = ic.modelData
            if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && it.onlyMenu)) {
              if (it.hasMenu) {
                const p = area.mapToItem(null, mouse.x, mouse.y)
                it.display(root.bar, p.x, p.y)
              }
            } else if (mouse.button === Qt.MiddleButton) {
              it.secondaryActivate()
            } else {
              it.activate()
            }
          }
        }
      }
    }
  }
}
