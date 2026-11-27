import QtQuick

import "../../progress"

// Mês com as datas importantes. Só eventos (prova, feriado, aula de dúvidas/revisão...) destacam o dia;
// tarefas aparecem como pontinhos na cor da matéria. Clique no dia para ver o cronograma dele.
Box {
  id: root

  property color textColor: "white"
  property color mutedColor: "#99ffffff"
  property color eventColor: "#55ffffff"         // círculo dos dias com evento
  property color todayColor: "#000000"
  property color selectColor: "white"
  property color accentColor: "#12b76a"

  property string selectedDay: ""                // "" = hoje
  readonly property string effectiveDay: selectedDay !== "" ? selectedDay : StudyAgent.today

  // mês exibido
  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()  // 0-11
  readonly property var monthNames: ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
  readonly property var weekLetters: ["D", "S", "T", "Q", "Q", "S", "S"]

  function shiftMonth(n) {
    const d = new Date(viewYear, viewMonth + n, 1)
    viewYear = d.getFullYear(); viewMonth = d.getMonth()
  }
  function goToday() {
    const d = StudyAgent.today !== "" ? StudyAgent.parseDay(StudyAgent.today) : new Date()
    viewYear = d.getFullYear(); viewMonth = d.getMonth(); selectedDay = ""
  }
  Connections {
    target: StudyAgent
    function onTodayChanged() { root.goToday() }
  }

  // 6 semanas × 7 dias a partir do domingo anterior ao dia 1
  readonly property var cells: {
    StudyAgent.calendar; StudyAgent.taskDots; StudyAgent.today      // refaz quando os dados mudam
    const first = new Date(viewYear, viewMonth, 1)
    const start = new Date(viewYear, viewMonth, 1 - first.getDay())
    const out = []
    for (let i = 0; i < 42; i++) {
      const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
      const k = StudyAgent.dayKey(d)
      out.push({
        day: k, num: d.getDate(), inMonth: d.getMonth() === viewMonth,
        today: k === StudyAgent.today, event: StudyAgent.hasHighlight(k),
        dayoff: StudyAgent.isDayoff(k), dots: StudyAgent.dotsOn(k).slice(0, 3)
      })
    }
    return out
  }

  Column {
    anchors.fill: parent
    spacing: 4

    // cabeçalho
    Item {
      width: parent.width
      height: 22
      Text {
        id: prev
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "‹"
        font.pixelSize: 20
        color: root.mutedColor
        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.shiftMonth(-1) }
      }
      Text {
        anchors.centerIn: parent
        text: root.monthNames[root.viewMonth] + " " + root.viewYear
        font.pixelSize: 13
        font.bold: true
        color: root.textColor
        MouseArea { anchors.fill: parent; onClicked: root.goToday() }
      }
      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "›"
        font.pixelSize: 20
        color: root.mutedColor
        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.shiftMonth(1) }
      }
    }

    Row {
      width: parent.width
      Repeater {
        model: root.weekLetters
        delegate: Text {
          required property string modelData
          width: parent.width / 7
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          font.pixelSize: 10
          font.bold: true
          color: root.mutedColor
        }
      }
    }

    Grid {
      id: grid
      width: parent.width
      columns: 7
      readonly property real cw: width / 7
      readonly property real ch: (root.height - root.padding * 2 - 22 - 14 - 12) / 6

      Repeater {
        model: root.cells
        delegate: Item {
          id: cell
          required property var modelData
          width: grid.cw
          height: grid.ch

          readonly property real d: Math.min(width, height - 4) * 0.82

          // dia com evento: círculo destacado
          Rectangle {
            visible: cell.modelData.event
            anchors.centerIn: num
            width: cell.d; height: cell.d; radius: width / 2
            color: root.eventColor
          }
          // hoje: quadrado arredondado
          Rectangle {
            visible: cell.modelData.today
            anchors.centerIn: num
            width: cell.d; height: cell.d; radius: 6
            color: root.todayColor
          }
          // selecionado: contorno
          Rectangle {
            visible: cell.modelData.day === root.effectiveDay
            anchors.centerIn: num
            width: cell.d; height: cell.d; radius: cell.modelData.today ? 6 : width / 2
            color: "transparent"
            border.color: root.selectColor
            border.width: 1.5
          }

          Text {
            id: num
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            text: cell.modelData.num
            font.pixelSize: Math.min(cell.d * 0.5, 13)
            font.bold: cell.modelData.today || cell.modelData.event
            font.italic: cell.modelData.dayoff
            color: cell.modelData.inMonth ? root.textColor : root.mutedColor
            opacity: cell.modelData.inMonth ? 1 : 0.45
          }

          // pontinhos das tarefas
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            spacing: 2
            Repeater {
              model: cell.modelData.dots
              delegate: Rectangle {
                required property var modelData
                width: 4; height: 4; radius: 2
                color: StudyAgent.courseColor(modelData.course_idx)
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            onClicked: root.selectedDay = (cell.modelData.day === StudyAgent.today ? "" : cell.modelData.day)
          }
        }
      }
    }
  }
}
