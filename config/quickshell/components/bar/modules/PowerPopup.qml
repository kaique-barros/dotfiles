import QtQuick
import Quickshell.Services.UPower

import "../models"

PopupModel {
  id: root

  // ================= CONFIGURAÇÕES =================
  property real rowHeight: 32
  property real headerHeight: 28
  property color hoverColor: "#e8ebf0"
  property color selectedColor: "#12b76a"
  property color textColor: "#1d2939"
  // =================================================

  readonly property var options: {
    const l = [
      { label: "Economia", profile: PowerProfile.PowerSaver },
      { label: "Equilibrado", profile: PowerProfile.Balanced }
    ]
    if (PowerProfiles.hasPerformanceProfile)
      l.push({ label: "Desempenho", profile: PowerProfile.Performance })
    return l
  }

  edge: "left"
  padding: 8
  popupWidth: 200
  popupHeight: 2 * padding + headerHeight + 30 + options.length * rowHeight

  Column {
    width: parent.width
    spacing: 6

    Text {
      width: parent.width
      height: root.headerHeight
      verticalAlignment: Text.AlignVCenter
      text: "Perfil de energia"
      font.bold: true
      font.pixelSize: 13
      color: root.textColor
    }

    Repeater {
      model: root.options

      delegate: Rectangle {
        id: row
        required property var modelData
        readonly property bool selected: PowerProfiles.profile === modelData.profile

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
          color: row.selected ? root.selectedColor : "transparent"
        }

        Text {
          anchors.left: dot.right
          anchors.leftMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: row.modelData.label
          font.pixelSize: 12
          font.bold: row.selected
          color: root.textColor
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: PowerProfiles.profile = row.modelData.profile
        }
      }
    }
  }
}
