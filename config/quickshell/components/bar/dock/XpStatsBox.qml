import QtQuick

import "../../progress"

// Números do progresso: tarefas de hoje, total concluído e XP.
// (streak e freezes entram na fase 2)
Box {
  id: root

  property color textColor: "white"
  property color mutedColor: "#99ffffff"
  property real fontSize: 14

  readonly property var rows: [
    { label: "Hoje",             value: Progress.todayCount + (Progress.todayCount === 1 ? " tarefa" : " tarefas") },
    { label: "Total concluídas", value: String(Progress.totalDone) },
    { label: "XP total",         value: String(Math.round(Progress.xp)) }
  ]

  Column {
    anchors.fill: parent
    spacing: 0

    Repeater {
      model: root.rows

      delegate: Item {
        required property var modelData
        width: parent.width
        height: parent.height / root.rows.length

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.label
          font.pixelSize: root.fontSize - 1
          color: root.mutedColor
        }
        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.value
          font.pixelSize: root.fontSize
          font.bold: true
          color: root.textColor
        }
      }
    }
  }
}
