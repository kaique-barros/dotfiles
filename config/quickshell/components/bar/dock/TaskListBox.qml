import QtQuick

import "../../progress"

// Tarefas em abas: Hoje, Amanhã, Semana (até +7 dias) e 15 dias. Uma cor por matéria.
Box {
  id: root

  property color textColor: "white"
  property color mutedColor: "#99ffffff"
  property color accentColor: "#12b76a"

  property int tab: 0
  readonly property var tabs: [
    { name: "Hoje",   key: "today" },
    { name: "Amanhã", key: "tomorrow" },
    { name: "Semana", key: "week" },
    { name: "15 dias", key: "fifteen" }
  ]
  readonly property string tabKey: tabs[tab].key
  readonly property var list: StudyAgent.tasks[tabKey] || []

  function sorted(a) {
    return a.slice().sort((x, y) => (x.running === y.running ? 0 : x.running ? -1 : 1)
                                 || String(x.day).localeCompare(String(y.day)) || x.id - y.id)
  }

  Column {
    anchors.fill: parent
    spacing: 8

    Row {
      id: tabBar
      spacing: 6
      Repeater {
        model: root.tabs
        delegate: Rectangle {
          required property var modelData
          required property int index
          height: 24
          width: label.implicitWidth + 18
          radius: 12
          color: root.tab === index ? root.accentColor : "#22ffffff"
          Text {
            id: label
            anchors.centerIn: parent
            readonly property int n: (StudyAgent.tasks[modelData.key] || []).length
            text: modelData.name + (n > 0 ? "  " + n : "")
            font.pixelSize: 11
            font.bold: root.tab === index
            color: root.tab === index && (0.299 * root.accentColor.r + 0.587 * root.accentColor.g + 0.114 * root.accentColor.b) > 0.6 ? "#111" : root.textColor
          }
          MouseArea { anchors.fill: parent; onClicked: root.tab = index }
        }
      }
    }

    ListView {
      id: view
      width: parent.width
      height: parent.height - tabBar.height - parent.spacing - (StudyAgent.error !== "" ? 16 : 0)
      clip: true
      spacing: 6
      boundsBehavior: Flickable.StopAtBounds
      model: root.tab === 0 ? root.sorted(root.list).concat(StudyAgent.doneToday.map(t => Object.assign({}, t, { _done: true }))) : root.sorted(root.list)

      delegate: TaskRow {
        required property var modelData
        task: modelData
        done: modelData._done === true
        actions: root.tab === 0
        showDate: root.tab >= 2
        textColor: root.textColor
        mutedColor: root.mutedColor
        accentColor: root.accentColor
      }

      Text {
        visible: view.count === 0
        anchors.centerIn: parent
        text: StudyAgent.ready ? "nada por aqui" : "carregando…"
        font.pixelSize: 12
        color: root.mutedColor
      }
    }

    Text {
      visible: StudyAgent.error !== ""
      width: parent.width
      text: StudyAgent.error
      font.pixelSize: 10
      color: "#f97066"
      elide: Text.ElideRight
    }
  }
}
