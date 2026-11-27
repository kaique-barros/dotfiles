import QtQuick

import "../../progress"

// Uma tarefa: faixa(s) colorida(s) à esquerda (uma por matéria; a segunda marca entrega com prazo),
// título, subtítulo e, na aba "Hoje", os botões iniciar/pausar, concluir e reprogramar.
Item {
  id: row

  required property var task
  property bool actions: false                    // só na aba Hoje
  property bool done: false
  property bool showDate: false                   // semana / 15 dias: mostra o dia

  property color textColor: "white"
  property color mutedColor: "#99ffffff"
  property color accentColor: "#12b76a"

  property bool picking: false

  readonly property color tone: StudyAgent.courseColor(task.course_idx)
  readonly property bool canMove: actions && !done && (task.options || []).length > 0

  width: parent ? parent.width : 0
  height: 40 + (picking ? pickBox.height + 6 : 0)

  // ---------- fitas ----------
  Rectangle {                                    // fita da matéria
    x: 0; y: 2
    width: 4; height: 36; radius: 2
    color: row.tone
    opacity: row.done ? 0.4 : 1
  }
  Rectangle {                                    // segunda fita: tarefa com entrega marcada
    visible: row.task.delivery === true
    x: 7; y: 2
    width: 4; height: 36; radius: 2
    color: row.tone
    opacity: row.done ? 0.4 : 1
  }

  readonly property real textX: (task.delivery === true ? 11 : 4) + 9

  Column {
    x: row.textX
    y: 3
    width: row.width - row.textX - (row.actions && !row.done ? 112 : 0) - (row.showDate ? 44 : 0)
    spacing: 2

    Text {
      width: parent.width
      text: row.task.title
      font.pixelSize: 12
      font.bold: !row.done
      font.strikeout: row.done
      color: row.textColor
      opacity: row.done ? 0.5 : 1
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      text: {
        const p = []
        if (row.task.running) p.push("▶ " + StudyAgent.fmtTime(clock.secs))
        else if (row.task.spent_seconds > 0) p.push(StudyAgent.fmtTime(row.task.spent_seconds))
        if (row.task.late) p.push("atrasada")
        if (row.task.course) p.push(row.task.course)
        if (row.task.due) p.push("prazo " + StudyAgent.shortDate(row.task.due))
        return p.join(" · ")
      }
      font.pixelSize: 10
      color: row.task.late ? "#f97066" : (row.task.running ? row.accentColor : row.mutedColor)
      elide: Text.ElideRight
    }
  }

  // cronômetro (andando entre consultas)
  SystemClock { id: tick; precision: SystemClock.Seconds }
  QtObject {
    id: clock
    readonly property int secs: { tick.date; return StudyAgent.spent(row.task) }
  }

  // data (semana / 15 dias)
  Text {
    visible: row.showDate
    anchors.right: parent.right
    y: 6
    width: 40
    horizontalAlignment: Text.AlignRight
    text: StudyAgent.weekdayOf(row.task.day) + "\n" + StudyAgent.shortDate(row.task.day)
    font.pixelSize: 10
    color: row.mutedColor
  }

  // ---------- botões ----------
  Row {
    visible: row.actions && !row.done
    anchors.right: parent.right
    y: 6
    spacing: 6

    Repeater {
      model: [
        { id: "play", glyph: row.task.running ? "⏸" : "▶" },
        { id: "done", glyph: "✓" },
        { id: "move", glyph: "↻" }
      ]
      delegate: Rectangle {
        required property var modelData
        width: 28; height: 28; radius: 14
        readonly property bool enabled: modelData.id !== "move" || row.canMove
        color: modelData.id === "done" ? Qt.rgba(row.accentColor.r, row.accentColor.g, row.accentColor.b, 0.35)
             : (modelData.id === "move" && row.picking) ? "#44ffffff" : "#22ffffff"
        opacity: enabled ? 1 : 0.3
        Text {
          anchors.centerIn: parent
          text: modelData.glyph
          font.pixelSize: 13
          color: row.textColor
        }
        MouseArea {
          anchors.fill: parent
          enabled: parent.enabled
          onClicked: {
            if (modelData.id === "play") row.task.running ? StudyAgent.pause(row.task.id) : StudyAgent.start(row.task.id)
            else if (modelData.id === "done") StudyAgent.done(row.task.id)
            else row.picking = !row.picking
          }
        }
      }
    }
  }

  // ---------- seletor de dia (↻): só dias depois de hoje e até o prazo, que é fixo ----------
  Flow {
    id: pickBox
    visible: row.picking
    x: row.textX
    y: 42
    width: row.width - row.textX
    spacing: 4

    Repeater {
      model: row.picking ? row.task.options : []
      delegate: Rectangle {
        required property var modelData
        height: 22
        width: optText.implicitWidth + 14
        radius: 11
        color: modelData.dayoff ? "#33fdb022" : "#22ffffff"
        Text {
          id: optText
          anchors.centerIn: parent
          text: StudyAgent.weekdayOf(modelData.day) + " " + StudyAgent.shortDate(modelData.day)
                + (modelData.dayoff ? " · folga" : "") + (modelData.count > 0 ? " · " + modelData.count : "")
          font.pixelSize: 10
          color: row.textColor
        }
        MouseArea {
          anchors.fill: parent
          onClicked: { row.picking = false; StudyAgent.plan(row.task.id, modelData.day) }
        }
      }
    }
  }
}
