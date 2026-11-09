import QtQuick
import Quickshell.Bluetooth

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

  // Separadores
  property real headerDividerRatio: 0.9
  property real itemDividerRatio: 0.8
  property real dividerThickness: 1.5
  property color dividerColor: "#c7cdd6"
  // =================================================

  readonly property var adapter: Bluetooth.defaultAdapter

  // dispositivos pareados, os conectados primeiro
  readonly property var paired: {
    const out = []
    const all = Bluetooth.devices.values
    for (let i = 0; i < all.length; i++) {
      if (all[i].paired || all[i].bonded) out.push(all[i])
    }
    out.sort((a, b) => Number(b.connected) - Number(a.connected))
    return out
  }

  readonly property int shownRows: Math.min(maxRows, paired.length)

  edge: "left"
  padding: 8
  popupWidth: 230
  popupHeight: 2 * padding + headerHeight + 13 + Math.max(1, shownRows) * rowHeight

  Column {
    width: parent.width
    spacing: 6

    Item {
      width: parent.width
      height: root.headerHeight

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "Bluetooth"
        font.bold: true
        font.pixelSize: 13
        color: root.textColor
      }

      ToggleSwitch {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !!root.adapter
        checked: !!root.adapter && root.adapter.enabled
        onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
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
      visible: root.paired.length === 0
      width: parent.width
      height: root.rowHeight
      verticalAlignment: Text.AlignVCenter
      text: !root.adapter ? "Sem adaptador" : "Nenhum dispositivo pareado"
      font.pixelSize: 11
      font.italic: true
      color: root.mutedColor
    }

    Repeater {
      model: root.paired.slice(0, root.maxRows)

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
          color: row.modelData.connected ? root.activeColor : "transparent"
        }

        Text {
          anchors.left: dot.right
          anchors.leftMargin: 8
          anchors.right: st.left
          anchors.rightMargin: 6
          anchors.verticalCenter: parent.verticalCenter
          text: row.modelData.name || row.modelData.deviceName || row.modelData.address
          font.pixelSize: 12
          font.bold: row.modelData.connected
          color: root.textColor
          elide: Text.ElideRight
        }

        Text {
          id: st
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: row.modelData.connected ? "Conectado" : ""
          font.pixelSize: 10
          color: root.mutedColor
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (row.modelData.connected) row.modelData.disconnect()
            else row.modelData.connect()
          }
        }

        // Separador entre dispositivos
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
