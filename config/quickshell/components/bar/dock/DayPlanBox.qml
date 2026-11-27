import QtQuick
import Quickshell

import "../../progress"

// Cronograma do dia: eventos sem hora em "chips" no topo (somem se não houver) e, abaixo, a linha do tempo
// com aulas e eventos que têm horário, em blocos nos horários marcados.
Box {
  id: root

  property string day: ""                        // "aaaa-mm-dd" (o DockContent liga ao dia selecionado do calendário)
  property color textColor: "white"
  property color mutedColor: "#99ffffff"
  property color lineColor: "#22ffffff"
  property color accentColor: "#12b76a"
  property real hourH: 34                        // altura de uma hora na linha do tempo

  readonly property string theDay: day !== "" ? day : StudyAgent.today
  readonly property var sessions: StudyAgent.sessionsOn(theDay)
  readonly property var chips: sessions.filter(s => !s.start)
  readonly property var timed: sessions.filter(s => s.start)

  function minutes(hhmm) {
    const p = String(hhmm).split(":")
    return p.length >= 2 ? parseInt(p[0]) * 60 + parseInt(p[1]) : 0
  }
  // faixa de horas mostrada: ao menos 8h–18h, ampliada para caber tudo
  readonly property int firstHour: {
    let m = 8
    for (const s of timed) m = Math.min(m, Math.floor(minutes(s.start) / 60))
    return Math.max(0, m)
  }
  readonly property int lastHour: {
    let m = 18
    for (const s of timed) m = Math.max(m, Math.ceil(minutes(s.end || s.start) / 60) + 1)
    return Math.min(24, m)
  }

  function tone(s) {                              // cor de destaque do bloco
    if (s.kind === "exam") return Qt.color("#f97066")
    if (s.kind === "holiday" || s.kind === "no_class") return Qt.color("#fdb022")
    if (s.flag) return Qt.color("#7a5af8")
    return StudyAgent.courseColor(root.courseIdx(s.course))
  }
  function courseIdx(key) {
    for (const c of StudyAgent.courses) if (c.key === key) return c.idx
    return -1
  }

  Column {
    anchors.fill: parent
    spacing: 6

    // cabeçalho: dia
    Text {
      text: (root.theDay === StudyAgent.today ? "Hoje" : StudyAgent.weekdayOf(root.theDay)) + " · " + StudyAgent.shortDate(root.theDay)
            + (StudyAgent.isDayoff(root.theDay) ? " · folga" : "")
      font.pixelSize: 13
      font.bold: true
      color: root.textColor
    }

    // eventos sem hora
    Flow {
      visible: root.chips.length > 0
      width: parent.width
      spacing: 4
      Repeater {
        model: root.chips
        delegate: Rectangle {
          required property var modelData
          height: 20
          width: Math.min(chipText.implicitWidth + 14, parent.width)
          radius: 10
          color: Qt.rgba(root.tone(modelData).r, root.tone(modelData).g, root.tone(modelData).b, modelData.highlight ? 0.35 : 0.2)
          border.color: root.tone(modelData)
          border.width: modelData.highlight ? 1 : 0
          Text {
            id: chipText
            anchors.centerIn: parent
            width: parent.width - 14
            horizontalAlignment: Text.AlignHCenter
            text: modelData.label
            font.pixelSize: 11
            color: root.textColor
            elide: Text.ElideRight
          }
        }
      }
    }

    // linha do tempo
    Flickable {
      id: flick
      width: parent.width
      height: parent.height - y
      contentWidth: width
      contentHeight: (root.lastHour - root.firstHour) * root.hourH
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      // abre já mostrando o primeiro compromisso (ou a hora atual, se for hoje)
      function focusStart() {
        let target = root.firstHour * 60
        if (root.timed.length > 0) target = Math.min.apply(null, root.timed.map(s => root.minutes(s.start)))
        else if (root.theDay === StudyAgent.today) target = new Date().getHours() * 60
        contentY = Math.max(0, Math.min(contentHeight - height, (target / 60 - root.firstHour - 0.3) * root.hourH))
      }
      Component.onCompleted: focusStart()
      Connections { target: root; function onTheDayChanged() { flick.focusStart() } }
      onHeightChanged: focusStart()

      Repeater {
        model: root.lastHour - root.firstHour
        delegate: Item {
          required property int index
          y: index * root.hourH
          width: flick.width
          height: root.hourH
          Rectangle { x: 34; width: parent.width - 34; height: 1; color: root.lineColor }
          Text {
            y: -6
            text: (root.firstHour + index) + "h"
            font.pixelSize: 10
            color: root.mutedColor
          }
        }
      }

      Repeater {
        model: root.timed
        delegate: Rectangle {
          required property var modelData
          readonly property real t0: root.minutes(modelData.start)
          readonly property real t1: Math.max(t0 + 30, root.minutes(modelData.end || modelData.start))
          x: 38
          y: (t0 / 60 - root.firstHour) * root.hourH + 1
          width: flick.width - 40
          height: Math.max(18, (t1 - t0) / 60 * root.hourH - 2)
          radius: 6
          color: Qt.rgba(root.tone(modelData).r, root.tone(modelData).g, root.tone(modelData).b, 0.3)
          Rectangle { width: 3; height: parent.height; radius: 2; color: root.tone(modelData) }
          Text {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.topMargin: 2
            text: modelData.label + (height > 30 ? "\n" + modelData.start + (modelData.end ? " – " + modelData.end : "") : "")
            font.pixelSize: 11
            color: root.textColor
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
          }
        }
      }

      // agora (só no dia de hoje)
      Rectangle {
        visible: root.theDay === StudyAgent.today
        x: 34; width: flick.width - 34; height: 1.5
        color: "#f97066"
        y: ((nowTick.date.getHours() * 60 + nowTick.date.getMinutes()) / 60 - root.firstHour) * root.hourH
        SystemClock { id: nowTick; precision: SystemClock.Minutes }
      }
    }
  }
}
