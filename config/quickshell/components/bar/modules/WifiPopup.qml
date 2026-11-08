import QtQuick
import Quickshell
import Quickshell.Io

import "../models"

PopupModel {
  id: root

  // ================= CONFIGURAÇÕES =================
  property int maxRows: 7
  property real rowHeight: 30
  property real headerHeight: 28
  property color hoverColor: "#e8ebf0"
  property color textColor: "#1d2939"
  property color mutedColor: "#667085"
  property color activeColor: "#12b76a"
  // =================================================

  property bool wifiOn: true
  property var networks: []
  readonly property int shownRows: Math.min(maxRows, networks.length)

  edge: "left"
  padding: 8
  popupWidth: 230
  popupHeight: 2 * padding + headerHeight + 6 + Math.max(1, shownRows) * rowHeight

  function refresh() {
    radioProc.running = true
    scanProc.running = true
  }

  onOpenChanged: if (open) refresh()

  function setWifi(on) {
    wifiOn = on
    Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"])
    refreshTimer.interval = 1500
    refreshTimer.restart()
  }

  function connectTo(ssid) {
    Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid])
    refreshTimer.interval = 3000
    refreshTimer.restart()
  }

  function parse(text) {
    const best = {}
    const lines = text.split("\n")
    for (let i = 0; i < lines.length; i++) {
      if (!lines[i]) continue
      // formato -t: IN-USE:SSID:SIGNAL:SECURITY, com ":" escapado como "\:"
      const f = lines[i].replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":"))
      if (f.length < 4 || !f[1]) continue
      const n = { ssid: f[1], signal: parseInt(f[2]) || 0, active: f[0] === "*" }
      const old = best[n.ssid]
      if (!old || n.active || (!old.active && n.signal > old.signal)) best[n.ssid] = n
    }
    const list = Object.keys(best).map(k => best[k])
    list.sort((a, b) => (Number(b.active) - Number(a.active)) || (b.signal - a.signal))
    networks = list
  }

  Timer { id: refreshTimer; onTriggered: root.refresh() }

  Process {
    id: radioProc
    command: ["nmcli", "radio", "wifi"]
    stdout: StdioCollector { onStreamFinished: root.wifiOn = text.trim() === "enabled" }
  }

  Process {
    id: scanProc
    command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
    stdout: StdioCollector { onStreamFinished: root.parse(text) }
  }

  Column {
    width: parent.width
    spacing: 6

    Item {
      width: parent.width
      height: root.headerHeight

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "Wi-Fi"
        font.bold: true
        font.pixelSize: 13
        color: root.textColor
      }
      ToggleSwitch {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: root.wifiOn
        onToggled: root.setWifi(!root.wifiOn)
      }
    }

    Text {
      visible: root.networks.length === 0
      width: parent.width
      height: root.rowHeight
      verticalAlignment: Text.AlignVCenter
      text: root.wifiOn ? "Nenhuma rede encontrada" : "Wi-Fi desligado"
      font.pixelSize: 11
      font.italic: true
      color: root.mutedColor
    }

    Repeater {
      model: root.networks.slice(0, root.maxRows)

      delegate: Rectangle {
        id: row
        required property var modelData

        width: parent.width
        height: root.rowHeight
        radius: 8
        color: area.containsMouse ? root.hoverColor : "transparent"

        Rectangle {
          id: dot
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          width: 8
          height: 8
          radius: 4
          color: row.modelData.active ? root.activeColor : "transparent"
        }

        Text {
          anchors.left: dot.right
          anchors.leftMargin: 8
          anchors.right: sig.left
          anchors.rightMargin: 6
          anchors.verticalCenter: parent.verticalCenter
          text: row.modelData.ssid
          font.pixelSize: 12
          font.bold: row.modelData.active
          color: root.textColor
          elide: Text.ElideRight
        }

        Text {
          id: sig
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: row.modelData.signal + "%"
          font.pixelSize: 11
          color: root.mutedColor
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.connectTo(row.modelData.ssid)
        }
      }
    }
  }
}
