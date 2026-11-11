import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

import "../../theme"
import "../models"

// Seletor de tema: popup colado na parte de baixo da tela, com os prints dos wallpapers
// (themes/screenshots/<id>.*) num carrossel. O tema atual fica no centro, maior; os outros
// vão ficando menores e mais para trás, um sobrepondo o outro.
//
//   Super+T (qs ipc call theme toggle)   abre/fecha
//   h / l  (ou ← →, roda do mouse)       passa para o anterior / próximo: já troca o tema e o wallpaper
//   Esc, Enter ou q                      fecha (o tema escolhido fica)
PopupModel {
  id: root

  edge: "bottom"

  // ================= CONFIGURAÇÕES (valores vêm do Bar.qml) =================
  property real cardWidth: bar ? bar.themeCardWidth : 480            // largura do print do meio
  property real cardRatio: bar ? bar.themeCardRatio : 16 / 9
  property int sideCount: bar ? bar.themeSideCount : 3               // quantos aparecem de cada lado
  property real scaleStep: bar ? bar.themeScaleStep : 0.18           // quanto cada posição para trás encolhe
  property real fadeStep: bar ? bar.themeFadeStep : 0.12             // quanto cada posição para trás apaga
  property real spread: bar ? bar.themeSpread : 0.55                 // distância do 1º vizinho (em larguras do print do meio)
  property real spreadStep: bar ? bar.themeSpreadStep : 0.30         // distância extra de cada vizinho seguinte
  property real cardRadius: bar ? bar.themeCardRadius : 16
  property color selectedBorderColor: bar ? bar.accentColor : "#12b76a"
  property real selectedBorderWidth: 3
  // =========================================================================

  readonly property real cardHeight: cardWidth / cardRatio

  function scaleAt(ad) { return Math.max(0.3, 1 - scaleStep * ad) }
  function offsetAt(ad) { return ad === 0 ? 0 : cardWidth * (spread + spreadStep * (ad - 1)) }

  readonly property real extent: offsetAt(sideCount) + scaleAt(sideCount) * cardWidth / 2

  padding: 14
  popupHeight: Math.round(cardHeight + 2 * padding)
  popupWidth: Math.round(Math.min(2 * extent + 2 * padding, bar.width - bar.leftSize - bar.rightSize))
  pos: bar.leftSize + (bar.width - bar.leftSize - bar.rightSize - popupWidth) / 2

  // ---------- lista de wallpapers ----------
  property var entries: []         // [{ id, path }]
  property int current: 0
  property bool pendingSync: true  // alinhar o carrossel com o tema atual quando a lista chegar

  function syncCurrent() {
    const i = entries.findIndex(e => e.id === Theme.currentId)
    current = i >= 0 ? i : 0
  }

  function refresh() { lister.running = true }

  Process {
    id: lister
    running: true
    command: ["sh", "-c",
      'for f in "$1"/*; do [ -f "$f" ] || continue; b="${f##*/}"; case "$b" in .*) continue;; esac; printf "%s\\t%s\\n" "${b%.*}" "$f"; done | sort',
      "sh", Quickshell.shellPath("themes/screenshots")]
    stdout: StdioCollector {
      onStreamFinished: {
        root.entries = text.split("\n")
          .filter(l => l.indexOf("\t") > 0)
          .map(l => ({ id: l.split("\t")[0], path: l.split("\t").slice(1).join("\t") }))
        if (root.pendingSync) { root.syncCurrent(); root.pendingSync = false }
      }
    }
  }

  // ---------- abrir / fechar / passar ----------
  function toggle() { open ? close() : show() }
  function show() {
    pendingSync = true
    refresh()
    syncCurrent()
    open = true
  }
  function close() { open = false }

  function go(delta) {
    if (entries.length === 0) return
    const n = Math.max(0, Math.min(entries.length - 1, current + delta))
    if (n === current) return
    current = n
    Theme.select(entries[n].id)
  }

  IpcHandler {
    target: "theme"
    function toggle(): void { root.toggle() }
    function open(): void { root.show() }
    function close(): void { root.close() }
  }

  // o teclado precisa do foco da janela (o Bar.qml dá foco exclusivo enquanto estiver aberto)
  onOpenChanged: if (open) Qt.callLater(() => keys.forceActiveFocus())
  onShownChanged: if (shown && open) Qt.callLater(() => keys.forceActiveFocus())

  Item {
    id: keys
    focus: root.open

    Keys.onPressed: (event) => {
      if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
      if (event.key === Qt.Key_H || event.key === Qt.Key_Left)       { root.go(-1); event.accepted = true }
      else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) { root.go(1); event.accepted = true }
      else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return
               || event.key === Qt.Key_Enter || event.key === Qt.Key_Q) { root.close(); event.accepted = true }
    }
  }

  // ---------- carrossel ----------
  readonly property real areaWidth: width - 2 * padding

  WheelHandler {
    onWheel: (wheel) => root.go(wheel.angleDelta.y > 0 ? -1 : 1)
  }

  Repeater {
    model: root.entries

    delegate: Item {
      id: card
      required property var modelData
      required property int index

      readonly property int d: index - root.current
      readonly property int ad: Math.abs(d)
      readonly property bool inRange: ad <= root.sideCount
      readonly property int place: Math.min(ad, root.sideCount + 1)    // quem está fora do alcance espera na ponta

      width: root.cardWidth
      height: root.cardHeight
      x: root.areaWidth / 2 - width / 2 + (d < 0 ? -1 : 1) * root.offsetAt(place)
      y: 0
      scale: root.scaleAt(place)
      z: 100 - ad
      opacity: inRange ? Math.max(0, 1 - root.fadeStep * ad) : 0
      visible: opacity > 0.01

      Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

      ClippingRectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: "transparent"

        Image {
          anchors.fill: parent
          source: card.inRange
            ? "file://" + card.modelData.path.split("/").map(encodeURIComponent).join("/")
            : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          sourceSize.width: Math.round(root.cardWidth * 2)
        }
      }

      // moldura do tema selecionado
      Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: "transparent"
        border.width: card.d === 0 ? root.selectedBorderWidth : 0
        border.color: root.selectedBorderColor
      }

      MouseArea {
        anchors.fill: parent
        enabled: card.d !== 0 && card.inRange
        cursorShape: Qt.PointingHandCursor
        onClicked: root.go(card.d)
      }
    }
  }
}
