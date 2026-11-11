import QtQuick
import Quickshell
import Quickshell.Io

import "../../theme"
import "../models"

// Bolinhas das workspaces: as que existem (têm janelas) + a atual.
// Clicar numa bolinha vai para a workspace correspondente.
// A workspace ativa fica maior e mostra um ícone.
BarItemModel {
  id: root

  // ================= CONFIGURAÇÕES =================
  // --- fundo (sólido, com cor e opacidade) ---
  property color backgroundColor: bar ? bar.itemBackgroundColor : "gray"
  property real backgroundOpacity: bar ? bar.itemBackgroundOpacity : 0.9      // 0 a 1 (só o fundo; as bolinhas não são afetadas)

  // --- sombra interna (só aparece com framed: true) ---
  frameSize: 4
  frameStrength: 0.5
  frameColor: "black"

  // --- pílula (o fundo) ---
  property real pillThickness: bar ? bar.pillThickness : 40    // largura da pílula atravessando a barra
  property real endPadding: 10        // folga extra nas pontas, ao longo da barra
  frameRadius: 100

  // --- bolinhas ---
  property bool horizontalDots: false  // false = coluna (vertical), true = linha
  property real dotSize: bar ? bar.wsDotSize : 12
  property real dotSpacing: bar ? bar.wsDotSpacing : 6
  property color inactiveColor: bar ? bar.wsInactiveColor : "#b4b4b4"
  property int colorAnimation: 150

  // --- workspace ativa ---
  property real activeSize: bar ? bar.wsActiveSize : 28                 // limitado à largura da pílula
  property color activeColor: bar ? bar.wsActiveColor : "black"
  property string iconPath: ""                 // vazio = fire.svg do tema (ou o padrão); ou um caminho absoluto
  property color iconColor: bar ? bar.wsIconColor : "white"
  property real iconSize: bar ? bar.wsIconSize : 16
  property int sizeAnimation: 150
  // ==================================================

  framed: false
  fillColor: bar ? bar.itemFillColor : Qt.rgba(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundOpacity)

  readonly property real activeBox: Math.min(activeSize, pillThickness)

  inset: Math.max(0, (thickness - pillThickness) / 2)
  padding: Math.max(0, (pillThickness - activeBox) / 2)

  // ---- niri: workspaces via `niri msg --json` (o Quickshell não tem módulo nativo) ----
  property int currentId: -1
  property var wsIds: []

  function refresh() { if (!wsReader.running) wsReader.running = true }

  Process {
    id: wsReader
    command: ["niri", "msg", "--json", "workspaces"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        let list = []
        try { list = JSON.parse(text) } catch (e) { return }
        // só do monitor focado; mostra as que têm janela + a focada
        const focused = list.find(w => w.is_focused)
        const out = focused ? focused.output : null
        const ids = []
        let cur = -1
        for (const w of list) {
          if (out && w.output !== out) continue
          if (w.is_focused) cur = w.idx
          if (w.is_focused || w.active_window_id !== null) ids.push(w.idx)
        }
        ids.sort((x, y) => x - y)
        root.currentId = cur
        root.wsIds = ids
      }
    }
  }

  // eventos do niri: qualquer evento de workspace/janela dispara uma releitura
  Process {
    id: events
    command: ["niri", "msg", "--json", "event-stream"]
    running: true
    stdout: SplitParser {
      onRead: line => {
        if (line.indexOf("Workspace") >= 0 || line.indexOf("Window") >= 0) root.refresh()
      }
    }
    onRunningChanged: if (!running) restart.start()
  }
  Timer { id: restart; interval: 2000; onTriggered: events.running = true }

  length: (vertical ? grid.implicitHeight : grid.implicitWidth)
          + 2 * (inset + padding) + 2 * endPadding

  Grid {
    id: grid
    anchors.centerIn: parent
    spacing: root.dotSpacing

    columns: root.horizontalDots
      ? (root.vertical
          ? Math.max(1, Math.floor((root.contentThickness + root.dotSpacing)
                                   / (root.activeBox + root.dotSpacing)))
          : Math.max(1, root.wsIds.length))
      : 1

    Repeater {
      model: root.wsIds

      delegate: Item {
        id: cell
        required property int modelData
        readonly property bool current: modelData === root.currentId

        implicitWidth: root.horizontalDots ? dot.width : root.activeBox
        implicitHeight: root.horizontalDots ? root.activeBox : dot.height

        Rectangle {
          id: dot
          anchors.centerIn: parent
          width: cell.current ? root.activeBox : root.dotSize
          height: width
          radius: width / 2
          color: cell.current ? root.activeColor : root.inactiveColor

          Behavior on width { NumberAnimation { duration: root.sizeAnimation; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: root.colorAnimation } }

          Icon {
            anchors.centerIn: parent
            source: root.iconPath !== "" ? "file://" + root.iconPath : Theme.asset("fire.svg")
            color: root.iconColor
            size: Math.min(root.iconSize, dot.width - 4)
            opacity: cell.current ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: root.sizeAnimation } }
          }
        }

        MouseArea {
          anchors.centerIn: parent
          width: parent.width + root.dotSpacing
          height: parent.height + root.dotSpacing
          cursorShape: Qt.PointingHandCursor
          onClicked: Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(cell.modelData)])
        }
      }
    }
  }
}
