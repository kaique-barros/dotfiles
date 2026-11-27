import QtQuick

import "../../progress"

// XP, nível, streak, freezes e tarefas concluídas (tudo calculado pelo daemon; aqui só se desenha).
Box {
  id: root

  property color accentColor: "#12b76a"
  property color textColor: "white"
  property color mutedColor: "#99ffffff"
  property color trackColor: "#33ffffff"
  property real ringWidth: 6

  readonly property var today: StudyAgent.todayInfo
  readonly property real luma: 0.299 * accentColor.r + 0.587 * accentColor.g + 0.114 * accentColor.b

  Row {
    anchors.fill: parent
    spacing: 14

    // ---------- anel do nível ----------
    Item {
      id: ringBox
      width: height
      height: parent.height

      Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        Connections {
          target: StudyAgent
          function onLevelProgressChanged() { canvas.requestPaint() }
          function onLevelChanged() { canvas.requestPaint() }
        }
        Connections {
          target: root
          function onAccentColorChanged() { canvas.requestPaint() }
          function onTrackColorChanged() { canvas.requestPaint() }
        }
        onWidthChanged: requestPaint()

        onPaint: {
          const ctx = getContext("2d")
          ctx.reset()
          const cx = width / 2, cy = height / 2
          const rr = Math.min(width, height) / 2 - root.ringWidth / 2 - 1
          ctx.lineWidth = root.ringWidth
          ctx.lineCap = "round"
          ctx.strokeStyle = root.trackColor
          ctx.beginPath(); ctx.arc(cx, cy, rr, 0, Math.PI * 2); ctx.stroke()
          if (StudyAgent.levelProgress > 0.002) {
            ctx.strokeStyle = root.accentColor
            ctx.beginPath()
            ctx.arc(cx, cy, rr, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * StudyAgent.levelProgress)
            ctx.stroke()
          }
        }
      }

      Column {
        anchors.centerIn: parent
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: StudyAgent.level
          font.pixelSize: ringBox.height * 0.34
          font.bold: true
          color: root.textColor
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "nível"
          font.pixelSize: 10
          color: root.mutedColor
        }
      }
    }

    // ---------- números ----------
    Column {
      width: parent.width - ringBox.width - parent.spacing
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8

      Item {
        width: parent.width
        height: 16
        Text {
          anchors.left: parent.left
          text: Math.round(StudyAgent.xp - StudyAgent.levelStartXp) + " / " + Math.round(StudyAgent.nextLevelXp - StudyAgent.levelStartXp) + " xp"
          font.pixelSize: 13
          font.bold: true
          color: root.textColor
        }
        Text {
          anchors.right: parent.right
          text: StudyAgent.error !== "" ? "daemon offline" : (StudyAgent.multiplier > 1.0001 ? "bônus ×" + StudyAgent.multiplier.toFixed(2) : "")
          font.pixelSize: 11
          color: StudyAgent.error !== "" ? "#f97066" : root.mutedColor
        }
      }

      Row {
        width: parent.width
        Repeater {
          model: [
            { v: String(StudyAgent.streak), l: StudyAgent.streak === 1 ? "dia seguido" : "dias seguidos", hi: StudyAgent.streak > 0 },
            { v: StudyAgent.freezes + "/" + StudyAgent.freezeCap, l: "freezes", hi: false },
            { v: String(StudyAgent.weekDone), l: "na semana", hi: false },
            { v: (root.today.done || 0) + "/" + (root.today.need || 0), l: "hoje", hi: root.today.on_track === true }
          ]
          delegate: Column {
            required property var modelData
            width: parent.width / 4
            Text {
              text: modelData.v
              font.pixelSize: 17
              font.bold: true
              color: modelData.hi ? root.accentColor : root.textColor
            }
            Text {
              text: modelData.l
              font.pixelSize: 10
              color: root.mutedColor
              elide: Text.ElideRight
              width: parent.width - 4
            }
          }
        }
      }
    }
  }
}
