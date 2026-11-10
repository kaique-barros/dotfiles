import QtQuick
import Quickshell
import Quickshell.Io

import "../models"

PopupModel {
  id: root

  // ================= CONFIGURAÇÕES =================
  property int maxRows: bar ? bar.popupMaxRows : 7
  property real rowHeight: bar ? bar.popupRowHeight : 30
  property real headerHeight: bar ? bar.popupHeaderHeight : 28
  property color hoverColor: bar ? bar.popupHoverColor : "#e8ebf0"
  property color titleColor: bar ? bar.popupTitleColor : "#1d2939"
  property color textColor: bar ? bar.popupTextColor : "#1d2939"
  property color mutedColor: bar ? bar.popupMutedColor : "#667085"
  property color activeColor: bar ? bar.accentColor : "#12b76a"

  // Separadores
  property real headerDividerRatio: bar ? bar.popupHeaderDividerRatio : 0.9
  property real itemDividerRatio: bar ? bar.popupItemDividerRatio : 0.8
  property real dividerThickness: bar ? bar.popupDividerThickness : 1.5
  property color dividerColor: bar ? bar.popupDividerColor : "#c7cdd6"
  property string fontFamily: bar ? bar.fontFamily : ""
  readonly property string family: fontFamily !== "" ? fontFamily : Qt.application.font.family
  property real titleFontSize: bar ? bar.popupTitleFontSize : 13
  property real rowFontSize: bar ? bar.popupRowFontSize : 12
  property real subFontSize: bar ? bar.popupSubFontSize : 11
  // =================================================

  property bool wifiOn: true
  property var networks: []
  readonly property int shownRows: Math.min(maxRows, networks.length)

  edge: "left"
  padding: bar ? bar.popupPadding : 8
  popupWidth: bar ? bar.wifiPopupWidth : 230
  popupHeight: 2 * padding + headerHeight + 13 + Math.max(1, shownRows) * rowHeight

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
        font.family: root.family
        font.pixelSize: root.titleFontSize
        color: root.titleColor
      }

      ToggleSwitch {
        onColor: root.activeColor
        offColor: bar ? bar.toggleOffColor : "#d0d5dd"
        knobColor: bar ? bar.toggleKnobColor : "white"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: root.wifiOn
        onToggled: root.setWifi(!root.wifiOn)
      }
    }

    // Separador principal
    Rectangle {
      width: parent.width * root.headerDividerRatio
      height: root.dividerThickness
      anchors.horizontalCenter: parent.horizontalCenter
      color: root.dividerColor
    }

    Text {
      visible: root.networks.length === 0
      width: parent.width
      height: root.rowHeight
      verticalAlignment: Text.AlignVCenter
      text: root.wifiOn ? "Nenhuma rede encontrada" : "Wi-Fi desligado"
      font.family: root.family
      font.pixelSize: root.subFontSize
      font.italic: true
      color: root.mutedColor
    }

    Repeater {
      model: root.networks.slice(0, root.maxRows)

      delegate: Rectangle {
        id: row
        required property var modelData
        required property int index

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
          font.family: root.family
          font.pixelSize: root.rowFontSize
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
          font.family: root.family
          font.pixelSize: root.subFontSize
          color: root.mutedColor
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.connectTo(row.modelData.ssid)
        }

        // Separador entre redes
        Rectangle {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width * root.itemDividerRatio
          height: root.dividerThickness
          color: root.dividerColor
          visible: row.index < root.shownRows - 1
        }
      }
    }
  }
}
