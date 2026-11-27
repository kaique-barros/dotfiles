import QtQuick
import Quickshell

import "../../progress"

// Controle do studyagent: nova tarefa, escanear matérias, planejar agora (e o que mais vier).
// O resultado não aparece aqui (pouco espaço, alguns comandos demoram): vai por notificação,
// uma quando o comando é recebido e outra quando termina.
//
// Nova tarefa: "Título @27/11 #CPP"  (@ = prazo: 27/11, +3, hoje, amanha, aaaa-mm-dd; # = matéria; ambos opcionais)
Box {
  id: root

  property color textColor: "white"
  property color mutedColor: "#99ffffff"
  property color accentColor: "#12b76a"

  // token do leitor de cronogramas (o escopo `schedule`; ver README do studyagent)
  property string scheduleToken: (Quickshell.env("HOME") || "") + "/.config/studyagent/schedule.token"

  function addTask() {
    let text = input.text.trim()
    if (text === "") return
    let due = "", course = "", bad = ""
    text = text.replace(/(^|\s)@(\S+)/, (m, sp, v) => { due = StudyAgent.parseDue(v.toLowerCase()); if (due === "") bad = v; return " " })
    text = text.replace(/(^|\s)#(\S+)/, (m, sp, v) => { course = v.toUpperCase(); return " " })
    text = text.replace(/\s+/g, " ").trim()
    if (bad !== "") { StudyAgent.notify("Nova tarefa ✗", "prazo inválido: @" + bad + " (use 27/11, +3, hoje, amanha ou aaaa-mm-dd)"); return }
    if (text === "") { StudyAgent.notify("Nova tarefa ✗", "falta o título"); return }
    const args = ["task", "add"]
    if (due !== "") args.push("--due", due)
    if (course !== "") args.push("--course", course)
    args.push("--", text)
    StudyAgent.job("Nova tarefa", args, {
      summarize: (out) => "criada: " + text + (due !== "" ? " (prazo " + StudyAgent.shortDate(due) + ")" : "")
    })
    input.text = ""
    input.focus = false
  }

  function scan() {
    StudyAgent.job("Escanear matérias", ["schedule", "scan"], {
      env: { STUDYAGENT_TOKEN_FILE: root.scheduleToken },
      summarize: (out) => {
        const lines = out.split("\n")
        const ok = lines.filter(l => l.indexOf("✓") === 0).length
        const bad = lines.filter(l => l.indexOf("✗") === 0).length
        if (ok === 0 && bad === 0) return "nenhum Cronograma novo ou alterado"
        return ok + (ok === 1 ? " proposta criada" : " propostas criadas") + (bad > 0 ? ", " + bad + " com erro" : "")
              + " — aprove com `studyagent proposal approve`"
      }
    })
  }

  function planNow() {
    StudyAgent.job("Planejar agora", ["plan", "run"], {})
  }

  Column {
    anchors.fill: parent
    spacing: 8

    Text {
      text: "Controle"
      font.pixelSize: 13
      font.bold: true
      color: root.textColor
    }

    // nova tarefa
    Rectangle {
      width: parent.width
      height: 30
      radius: 15
      color: "#22ffffff"
      border.color: input.activeFocus ? root.accentColor : "transparent"
      border.width: 1

      TextInput {
        id: input
        anchors.left: parent.left
        anchors.right: addBtn.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 6
        clip: true
        font.pixelSize: 12
        color: root.textColor
        selectionColor: root.accentColor
        onAccepted: root.addTask()
        Keys.onEscapePressed: input.focus = false

        Text {
          visible: input.text === "" && !input.activeFocus
          text: "nova tarefa…  @27/11  #CPP"
          font.pixelSize: 12
          color: root.mutedColor
        }
      }
      MouseArea {
        anchors.fill: parent
        anchors.rightMargin: 34
        onClicked: input.forceActiveFocus()
      }
      Rectangle {
        id: addBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 3
        width: 24; height: 24; radius: 12
        color: root.accentColor
        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; font.bold: true; color: "#111" }
        MouseArea { anchors.fill: parent; onClicked: root.addTask() }
      }
    }

    // ações
    Flow {
      width: parent.width
      spacing: 6

      Repeater {
        model: [
          { id: "scan", text: "Escanear matérias" },
          { id: "plan", text: "Planejar agora" }
        ]
        delegate: Rectangle {
          required property var modelData
          height: 26
          width: btnText.implicitWidth + 22
          radius: 13
          color: btnArea.containsMouse ? "#44ffffff" : "#22ffffff"
          Text {
            id: btnText
            anchors.centerIn: parent
            text: modelData.text
            font.pixelSize: 11
            color: root.textColor
          }
          MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: modelData.id === "scan" ? root.scan() : root.planNow()
          }
        }
      }
    }
  }
}
