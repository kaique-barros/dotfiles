import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower

import "../models"

// Pílula com Wi-Fi, Bluetooth e perfil de energia.
// Cada ícone muda conforme o estado. Passar o mouse num ícone aumenta ele e abre o popup.
BarItemModel {
  id: root

  // ================= CONFIGURAÇÕES =================
  property real pillThickness: bar ? bar.pillThickness : 40
  property real endPadding: 10                 // folga nas pontas, ao longo da barra
  property real iconSize: bar ? bar.connIconSize : 20
  property real iconSpacing: bar ? bar.connIconSpacing : 10                // espaço entre os ícones
  property real hoverScale: bar ? bar.connHoverScale : 1.3                // quanto o ícone cresce no hover
  property color iconColor: bar ? bar.connIconColor : "black"
  property int scaleDuration: 120
  property int closeDelay: 200                 // espera antes de fechar o popup

  // ícones (nomes dos arquivos em assets/)
  property string wifiConnectedIcon: "wifi_connected.svg"
  property string wifiDisconnectedIcon: "wifi_disconected.svg"
  property string wifiOffIcon: "wifi_off.svg"

  property string btConnectedIcon: "bluetooth.svg"
  property string btDisconnectedIcon: "bluetooth_disconected.svg"
  property string btOffIcon: "bluetooth_off.svg"

  property string powerEconomyIcon: "power_economy.svg"
  property string powerBalanceIcon: "power_balance.svg"
  property string powerPerformanceIcon: "power_performance.svg"
  // =================================================

  // [wifiPopup, bluetoothPopup, powerPopup], na mesma ordem dos ícones
  property var popupList: []

  property int openIndex: -1                   // popup que deve estar aberto (-1 = nenhum)
  property int hoverIndex: -1

  readonly property bool popupHovered: popupList.some(p => !!p && p.hovered)

  // centro da pílula, em coordenadas da janela: os popups se centralizam nele
  readonly property real popupCenter: along + length / 2

  framed: false
  fillColor: bar ? bar.itemFillColor : "gray"            // a mesma cor das workspaces
  frameRadius: 100
  inset: Math.max(0, (thickness - pillThickness) / 2)
  padding: 0
  length: col.implicitHeight + 2 * inset + 2 * endPadding

  // ---------- estado: Wi-Fi ("connected" | "disconnected" | "off") ----------
  property string wifiState: "disconnected"

  function refreshWifi() { wifiProc.running = true }

  Process {
    id: wifiProc
    command: ["sh", "-c", "nmcli radio wifi; nmcli -t -f TYPE,STATE device"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n")
        if (lines[0].trim() !== "enabled") { root.wifiState = "off"; return }
        let ok = false
        for (let i = 1; i < lines.length; i++)
          if (lines[i].trim() === "wifi:connected") ok = true
        root.wifiState = ok ? "connected" : "disconnected"
      }
    }
  }

  // o nmcli avisa quando algo muda; o timer é só uma garantia
  Process {
    command: ["nmcli", "monitor"]
    running: true
    stdout: SplitParser { onRead: debounce.restart() }
  }
  Timer { id: debounce; interval: 400; onTriggered: root.refreshWifi() }
  Timer { interval: 20000; running: true; repeat: true; onTriggered: root.refreshWifi() }
  Component.onCompleted: refreshWifi()

  // ---------- estado: Bluetooth ----------
  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property string btState: {
    if (!btAdapter || !btAdapter.enabled) return "off"
    const all = Bluetooth.devices.values
    for (let i = 0; i < all.length; i++)
      if (all[i].connected) return "connected"
    return "disconnected"
  }

  // ---------- ícone de cada item ----------
  readonly property string wifiFile:
      wifiState === "connected" ? wifiConnectedIcon
    : wifiState === "off"       ? wifiOffIcon
    :                             wifiDisconnectedIcon

  readonly property string btFile:
      btState === "connected" ? btConnectedIcon
    : btState === "off"       ? btOffIcon
    :                           btDisconnectedIcon

  readonly property string powerFile:
      PowerProfiles.profile === PowerProfile.PowerSaver   ? powerEconomyIcon
    : PowerProfiles.profile === PowerProfile.Performance  ? powerPerformanceIcon
    :                                                       powerBalanceIcon

  readonly property var icons: [wifiFile, btFile, powerFile]

  // ---------- abrir / fechar popups ----------
  Timer {
    id: closeTimer
    interval: root.closeDelay
    onTriggered: {
      if (root.hoverIndex === -1 && !root.popupHovered) root.openIndex = -1
    }
  }

  onPopupHoveredChanged: {
    if (popupHovered) closeTimer.stop()
    else closeTimer.restart()
  }

  Column {
    id: col
    anchors.centerIn: parent

    Repeater {
      model: 3          // fixo: os ícones trocam sem recriar os itens (o hover não se perde)

      delegate: Item {
        id: cell
        required property int index

        width: root.pillThickness
        height: root.iconSize + root.iconSpacing

        HoverHandler {
          id: hh
          onHoveredChanged: {
            if (hovered) {
              root.hoverIndex = cell.index
              root.openIndex = cell.index
              closeTimer.stop()
            } else {
              if (root.hoverIndex === cell.index) root.hoverIndex = -1
              closeTimer.restart()
            }
          }
        }

        Item {
          anchors.centerIn: parent
          width: root.iconSize
          height: root.iconSize
          scale: hh.hovered ? root.hoverScale : 1
          Behavior on scale { NumberAnimation { duration: root.scaleDuration; easing.type: Easing.OutCubic } }

          Icon {
            anchors.centerIn: parent
            size: root.iconSize
            color: root.iconColor
            source: "file://" + Quickshell.shellPath("assets/" + root.icons[cell.index])
          }
        }
      }
    }
  }
}
