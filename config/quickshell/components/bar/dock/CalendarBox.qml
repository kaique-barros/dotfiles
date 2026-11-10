import QtQuick
import Quickshell
import Quickshell.Io

// Calendário integrado ao Full Calendar do Obsidian.
// O calendário é sempre um quadrado; a área das tarefas fica à direita, depois do separador.
Box {
  id: root

  // ================= CONFIGURAÇÕES =================
  property string directory: "~/Obsidian Vault/Calendar"   // pasta dos eventos (subpastas incluídas)
  property bool active: false                              // ligue na dock: relê os eventos e volta ao mês atual
  property int weekStart: 0                                // 0 = domingo, 1 = segunda

  // calendário
  property bool showWeekdays: true
  property bool showOtherMonthDays: true                   // dias do mês anterior/seguinte, esmaecidos
  property real dayFontSize: 0                             // 0 = automático
  property real dayRatio: 0.86                             // tamanho do círculo/quadrado do dia, relativo à célula
  property color textColor: "#ffffff"
  property color mutedColor: "#66000000"
  property color eventColor: "#33000000"                   // círculo dos dias com evento (mais escuro que a caixa)
  property color todayColor: "black"                       // quadrado do dia atual
  property color todayTextColor: "white"
  property real todayRadius: 5

  // separador e área das tarefas
  property real separatorGap: 12
  property real separatorThickness: 1.5
  property real separatorRatio: 0.9                        // altura do separador em relação à caixa
  property color separatorColor: "#55000000"
  property real tasksMinWidth: 120                         // largura mínima reservada às tarefas
  property bool showTasksPlaceholder: true                 // contorno para você ver o espaço reservado
  // =================================================

  property var monthNames: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
                            "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
  property var weekdayLetters: ["D", "S", "T", "Q", "Q", "S", "S"]    // começando no domingo

  // mês exibido
  property int viewYear: 2026
  property int viewMonth: 0

  // eventos: { "2026-10-10": ["Prova 2 - Fund Mec", ...] }
  property var eventsByKey: ({})

  function pad(n) { return n < 10 ? "0" + n : "" + n }
  function keyOf(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }

  function expand(p) {
    const home = Quickshell.env("HOME") || ""
    if (p === "~") return home
    if (p.startsWith("~/")) return home + p.slice(1)
    return p
  }

  function goToday() {
    const n = new Date()
    viewYear = n.getFullYear()
    viewMonth = n.getMonth()
  }

  function shift(n) {
    let m = viewMonth + n
    let y = viewYear
    while (m < 0) { m += 12; y-- }
    while (m > 11) { m -= 12; y++ }
    viewMonth = m
    viewYear = y
  }

  Component.onCompleted: { goToday(); scan() }

  onActiveChanged: {
    if (!active) return
    goToday()
    scan()
  }

  // ---------- leitura dos eventos ----------
  // imprime "data|dataFinal|titulo" para cada nota que tem frontmatter
  readonly property string scanScript: `
find -L "$1" -type f -name '*.md' -print0 | xargs -0 -r awk '
FNR==1 { fm=0; done=0; t=""; d=""; ed="" }
done { next }
/^---[ ]*$/ {
  if (fm == 0) { if (FNR == 1) fm = 1; else done = 1 }
  else {
    if (d == "" && match(FILENAME, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) d = substr(FILENAME, RSTART, RLENGTH)
    print d "|" ed "|" t
    done = 1
  }
  next
}
fm {
  if ($0 ~ /^title:/) { t = $0; sub(/^title:[ ]*/, "", t); gsub(/^["]|["]$/, "", t) }
  else if ($0 ~ /^(date|startDate):/) { d = $0; sub(/^[a-zA-Z]+:[ ]*/, "", d); gsub(/["]/, "", d) }
  else if ($0 ~ /^endDate:/) { ed = $0; sub(/^endDate:[ ]*/, "", ed); gsub(/["]/, "", ed) }
}' 2>/dev/null
`

  function scan() { scanner.running = true }

  function parseKey(s) {
    const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s)
    return m ? new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3])) : null
  }

  function parse(text) {
    const map = {}
    const lines = text.split("\n")
    for (let i = 0; i < lines.length; i++) {
      if (!lines[i]) continue
      const p = lines[i].split("|")
      const start = parseKey(p[0])
      if (!start) continue
      const title = p.slice(2).join("|") || "(sem título)"
      const endParsed = parseKey(p[1] || "")
      const end = (endParsed && endParsed >= start) ? endParsed : start

      // eventos de vários dias aparecem em todos os dias do intervalo
      const cur = new Date(start.getTime())
      let guard = 0
      while (cur <= end && guard++ < 366) {
        const k = keyOf(cur)
        if (!map[k]) map[k] = []
        map[k].push(title)
        cur.setDate(cur.getDate() + 1)
      }
    }
    eventsByKey = map
  }

  Process {
    id: scanner
    command: ["sh", "-c", root.scanScript, "sh", root.expand(root.directory)]
    stdout: StdioCollector { onStreamFinished: root.parse(text) }
  }

  // ---------- data de hoje ----------
  SystemClock {
    id: clock
    enabled: root.visible
    precision: SystemClock.Minutes
  }
  readonly property string todayKey: keyOf(clock.date)

  // ---------- as 42 células do mês exibido ----------
  readonly property var cells: {
    const out = []
    const first = new Date(viewYear, viewMonth, 1)
    const offset = (first.getDay() - weekStart + 7) % 7
    for (let i = 0; i < 42; i++) {
      const d = new Date(viewYear, viewMonth, i - offset + 1)
      const k = keyOf(d)
      out.push({
        day: d.getDate(),
        inMonth: d.getMonth() === viewMonth,
        hasEvent: !!eventsByKey[k],
        today: k === todayKey
      })
    }
    return out
  }

  // ---------- geometria ----------
  readonly property real innerW: width - 2 * padding
  readonly property real innerH: height - 2 * padding

  // o calendário é sempre um quadrado: limitado pela altura e pelo espaço que sobra para as tarefas
  readonly property real calSize: Math.max(0,
    Math.min(innerH, innerW - tasksMinWidth - 2 * separatorGap - separatorThickness))

  Item {
    id: content
    anchors.fill: parent

    // ================= CALENDÁRIO (quadrado) =================
    Item {
      id: calendar
      x: 0
      y: 0
      width: root.calSize
      height: root.calSize

      readonly property real headerH: Math.max(22, width * 0.13)
      readonly property real weekdaysH: root.showWeekdays ? Math.max(14, width * 0.07) : 0
      readonly property real gridH: height - headerH - weekdaysH
      readonly property real cellW: width / 7
      readonly property real cellH: gridH / 6
      readonly property real dayBox: Math.min(cellW, cellH) * root.dayRatio

      // roda do mouse troca o mês
      WheelHandler {
        onWheel: (wheel) => root.shift(wheel.angleDelta.y > 0 ? -1 : 1)
      }

      // cabeçalho: [‹]  Mês Ano  [›]
      Item {
        id: header
        width: parent.width
        height: calendar.headerH

        Item {
          anchors.left: parent.left
          width: parent.height
          height: parent.height

          Text {
            anchors.centerIn: parent
            text: "‹"
            font.pixelSize: parent.height * 0.95
            font.bold: true
            color: root.textColor
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.shift(-1)
          }
        }

        Text {
          anchors.centerIn: parent
          text: root.monthNames[root.viewMonth] + " " + root.viewYear
          font.pixelSize: parent.height * 0.55
          font.bold: true
          color: root.textColor

          // clicar no título volta para o mês atual
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.goToday()
          }
        }

        Item {
          anchors.right: parent.right
          width: parent.height
          height: parent.height

          Text {
            anchors.centerIn: parent
            text: "›"
            font.pixelSize: parent.height * 0.95
            font.bold: true
            color: root.textColor
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.shift(1)
          }
        }
      }

      // dias da semana
      Row {
        visible: root.showWeekdays
        y: calendar.headerH
        width: parent.width
        height: calendar.weekdaysH

        Repeater {
          model: 7

          delegate: Text {
            required property int index
            width: calendar.cellW
            height: calendar.weekdaysH
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.weekdayLetters[(index + root.weekStart) % 7]
            font.pixelSize: calendar.weekdaysH * 0.75
            font.bold: true
            color: root.mutedColor
          }
        }
      }

      // dias
      Item {
        y: calendar.headerH + calendar.weekdaysH
        width: parent.width
        height: calendar.gridH

        Repeater {
          model: root.cells

          delegate: Item {
            id: cell
            required property var modelData
            required property int index

            x: (index % 7) * calendar.cellW
            y: Math.floor(index / 7) * calendar.cellH
            width: calendar.cellW
            height: calendar.cellH
            visible: modelData.inMonth || root.showOtherMonthDays
            opacity: modelData.inMonth ? 1 : 0.35

            // dia com evento: círculo mais escuro em volta
            Rectangle {
              anchors.centerIn: parent
              visible: cell.modelData.hasEvent
              width: calendar.dayBox
              height: width
              radius: width / 2
              color: root.eventColor
            }

            // dia atual: quadrado
            Rectangle {
              anchors.centerIn: parent
              visible: cell.modelData.today
              width: calendar.dayBox
              height: width
              radius: root.todayRadius
              color: root.todayColor
            }

            Text {
              anchors.centerIn: parent
              text: cell.modelData.day
              font.pixelSize: root.dayFontSize > 0 ? root.dayFontSize : calendar.dayBox * 0.45
              font.bold: cell.modelData.today || cell.modelData.hasEvent
              color: cell.modelData.today ? root.todayTextColor : root.textColor
            }
          }
        }
      }
    }

    // ================= SEPARADOR =================
    Rectangle {
      x: root.calSize + root.separatorGap
      y: (content.height - height) / 2
      width: root.separatorThickness
      height: content.height * root.separatorRatio
      radius: width / 2
      color: root.separatorColor
    }

    // ================= ÁREA DAS TAREFAS (reservada) =================
    Item {
      id: tasksArea
      x: root.calSize + 2 * root.separatorGap + root.separatorThickness
      y: 0
      width: Math.max(0, content.width - x)
      height: content.height

      // contorno só para visualizar o espaço; desligue com showTasksPlaceholder: false
      Rectangle {
        anchors.fill: parent
        visible: root.showTasksPlaceholder
        color: "transparent"
        radius: 8
        border.color: root.separatorColor
        border.width: 1
      }
    }
  }
}
