import QtQuick
import Quickshell
import Quickshell.Io

// Calendário integrado ao Full Calendar + tarefas do Kanban (Obsidian).
Box {
  id: root

  // ================= CONFIGURAÇÕES =================
  property string directory: "~/Obsidian Vault/Calendar"   // eventos (subpastas incluídas)
  property string tasksFile: "~/Obsidian Vault/Tarefas.md" // quadro do plugin Kanban
  property bool active: false                              // dockActive: relê tudo e volta ao mês atual
  property bool keysEnabled: false                         // dockActive && página 1: liga os atalhos
  property int weekStart: 0                                // 0 = domingo, 1 = segunda

  // calendário
  property real calScale: 0.8                              // 1 = maior quadrado possível; diminua para encolher
  property bool showWeekdays: true
  property bool showOtherMonthDays: true
  property real dayFontSize: 0                             // 0 = automático
  property real dayRatio: 0.86
  property color textColor: "white"
  property color mutedColor: "#99ffffff"
  property color eventColor: "#55000000"                   // círculo dos dias com evento
  property color todayColor: "#000000"                     // quadrado do dia atual
  property color todayTextColor: "white"
  property color selectColor: "white"                      // contorno do dia selecionado
  property real selectWidth: 2
  property real todayRadius: 5

  // separadores
  property real separatorGap: 12
  property real separatorThickness: 1.5
  property real separatorRatio: 0.9                        // separador vertical (calendário | tarefas)
  property color separatorColor: "#55ffffff"
  property real tasksMinWidth: 120

  // painel da direita
  property real tasksFontSize: 12
  property var taskIgnoreSections: ["Concluído", "Archive"] // colunas do Kanban que não aparecem
  property bool includeOverdue: false                      // true: inclui tarefas de dias anteriores ao dia mostrado
  property bool showUndated: false                         // true: inclui tarefas sem data
  // =================================================

  property var monthNames: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
                            "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
  property var weekdayLetters: ["D", "S", "T", "Q", "Q", "S", "S"]
  property var weekdayShort: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
  property var monthShort: ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]

  property int viewYear: 2026
  property int viewMonth: 0

  property var eventsByKey: ({})
  property var tasks: []

  // seleção por teclado
  property bool selecting: false
  property string selectedKey: ""
  property bool chordC: false

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

  // ---------- seleção e atalhos ----------
  function parseKey(s) {
    const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s)
    return m ? new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3])) : null
  }

  function startSelect() {
    const now = new Date()
    selectedKey = (viewYear === now.getFullYear() && viewMonth === now.getMonth())
      ? keyOf(now)
      : keyOf(new Date(viewYear, viewMonth, 1))
    selecting = true
  }

  function moveSelection(days) {
    const d = parseKey(selectedKey)
    if (!d) return
    d.setDate(d.getDate() + days)
    selectedKey = keyOf(d)
    viewYear = d.getFullYear()
    viewMonth = d.getMonth()
  }

  function handleKey(e) {
    if (!keysEnabled) return
    if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return

    if (selecting) {
      if (e.key === Qt.Key_Escape) { selecting = false; e.accepted = true }
      else if (e.key === Qt.Key_H || e.key === Qt.Key_Left)  { moveSelection(-1); e.accepted = true }
      else if (e.key === Qt.Key_L || e.key === Qt.Key_Right) { moveSelection(1);  e.accepted = true }
      else if (e.key === Qt.Key_J || e.key === Qt.Key_Down)  { moveSelection(7);  e.accepted = true }
      else if (e.key === Qt.Key_K || e.key === Qt.Key_Up)    { moveSelection(-7); e.accepted = true }
      return
    }

    // atalho c + a: seleciona o calendário
    if (e.key === Qt.Key_C) {
      chordC = true
      chordTimer.restart()
      e.accepted = true
    } else if (e.key === Qt.Key_A && chordC) {
      chordC = false
      startSelect()
      e.accepted = true
    }
  }

  Timer { id: chordTimer; interval: 900; onTriggered: root.chordC = false }

  Item {
    id: keyCatcher
    width: 0
    height: 0
    Keys.onPressed: (event) => root.handleKey(event)
  }

  onKeysEnabledChanged: {
    if (keysEnabled) Qt.callLater(() => keyCatcher.forceActiveFocus())
    else { selecting = false; chordC = false }
  }

  Component.onCompleted: { goToday(); scan() }

  onActiveChanged: {
    if (!active) { selecting = false; return }
    goToday()
    scan()
  }

  // ---------- leitura dos eventos ----------
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

  function scan() {
    scanner.running = true
    tasksReader.running = true
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

  // ---------- leitura das tarefas (Kanban) ----------
  // "- [ ] Título @{dd/mm/aa} #Tag" dentro de "## Coluna"

  property var tagColors: ({})

  // aceita "#rrggbb", nomes e "rgba(r, g, b, a)" do Obsidian
  function toColor(s) {
    if (!s) return ""
    const m = /^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$/.exec(s.trim())
    if (m) return Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, m[4] === undefined ? 1 : parseFloat(m[4]))
    return s
  }

  // cores do plugin Kanban: global (data.json) e do quadro (bloco kanban:settings)
  function readTagColors(text) {
    const map = {}
    function add(list) {
      if (!list) return
      for (const e of list) {
        const k = (e.tagKey || "").replace(/^#/, "").toLowerCase()
        if (k) map[k] = { fg: toColor(e.color), bg: toColor(e.backgroundColor) }
      }
    }

    const parts = text.split("@@KANBAN_GLOBAL@@")
    const board = parts[0]
    const global = parts.length > 1 ? parts[1] : ""

    const gi = global.indexOf("{")
    if (gi >= 0) {
      try { add(JSON.parse(global.slice(gi))["tag-colors"]) } catch (e) {}
    }

    const m = /%%\s*kanban:settings\s*```\s*(\{[\s\S]*?\})\s*```\s*%%/.exec(board)
    if (m) {
      try { add(JSON.parse(m[1])["tag-colors"]) } catch (e) {}
    }
    return map
  }

  function parseTasks(text) {
    const colors = readTagColors(text)
    tagColors = colors

    const out = []
    let section = ""
    const lines = text.split("@@KANBAN_GLOBAL@@")[0].split("\n")
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const h = /^##\s+(.*?)\s*$/.exec(line)
      if (h) { section = h[1]; continue }

      const m = /^\s*-\s\[ \]\s+(.*)$/.exec(line)
      if (!m) continue
      if (taskIgnoreSections.indexOf(section) >= 0) continue

      let body = m[1]
      let key = ""
      // @{dd/mm/aa}, @{dd/mm/aaaa} ou @{aaaa-mm-dd}
      const dm = /@\{(\d{1,2})\/(\d{1,2})\/(\d{2,4})\}/.exec(body)
      const dm2 = /@\{(\d{4})-(\d{2})-(\d{2})\}/.exec(body)
      if (dm) {
        let y = parseInt(dm[3])
        if (y < 100) y += 2000
        key = y + "-" + pad(parseInt(dm[2])) + "-" + pad(parseInt(dm[1]))
        body = body.replace(dm[0], "")
      } else if (dm2) {
        key = dm2[1] + "-" + dm2[2] + "-" + dm2[3]
        body = body.replace(dm2[0], "")
      }

      const tags = []
      body = body.replace(/#(\S+)/g, (s, t) => { tags.push(t); return "" })
      body = body.replace(/\s+/g, " ").trim().replace(/\s*[-–]$/, "")

      const tag = tags[0] || ""
      const c = colors[tag.toLowerCase()]
      out.push({
        title: body,
        key: key,
        tag: tag,
        tagFg: c ? c.fg : "",
        tagBg: c ? c.bg : "",
        section: section
      })
    }
    tasks = out
  }

  Process {
    id: tasksReader
    command: ["sh", "-c",
      'f="$1"; [ -f "$f" ] || f="$1.md"; cat "$f" 2>/dev/null; printf "\\n@@KANBAN_GLOBAL@@\\n"; cat "$(dirname "$1")/.obsidian/plugins/obsidian-kanban/data.json" 2>/dev/null',
      "sh", root.expand(root.tasksFile)]
    stdout: StdioCollector { onStreamFinished: root.parseTasks(text) }
  }

  // ---------- data de hoje ----------
  SystemClock {
    id: clock
    enabled: root.visible
    precision: SystemClock.Minutes
  }
  readonly property string todayKey: keyOf(clock.date)

  // dia que o painel da direita mostra: o selecionado, ou hoje
  readonly property string shownKey: selecting ? selectedKey : todayKey
  readonly property string shownLabel: {
    const d = parseKey(shownKey)
    return d ? weekdayShort[d.getDay()] + ", " + d.getDate() + " " + monthShort[d.getMonth()] : ""
  }

  readonly property var dayEvents: {
    const list = eventsByKey[shownKey] || []
    return list.map(t => ({ title: t, tag: "" }))
  }

  readonly property var dayTasks: tasks.filter(t => {
    if (t.key === "") return showUndated
    return t.key === shownKey || (includeOverdue && t.key < shownKey)
  })

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
        today: k === todayKey,
        selected: selecting && k === selectedKey
      })
    }
    return out
  }

  // ---------- geometria ----------
  readonly property real innerW: width - 2 * padding
  readonly property real innerH: height - 2 * padding

  // sempre quadrado
  readonly property real calSize: Math.max(0,
    Math.min(innerH, innerW - tasksMinWidth - 2 * separatorGap - separatorThickness) * calScale)

  // seção reutilizável (título + lista com rolagem)
  component SectionList: Item {
    id: sec
    property string title: ""
    property string emptyText: ""
    property var items: []
    property bool showTag: false
    property real fontSize: 12
    property color textColor: "white"
    property color mutedColor: "#99ffffff"

    Text {
      id: head
      width: parent.width
      text: sec.title
      font.pixelSize: sec.fontSize
      font.bold: true
      color: sec.textColor
      elide: Text.ElideRight
    }

    Text {
      visible: sec.items.length === 0
      anchors.top: head.bottom
      anchors.topMargin: 4
      text: sec.emptyText
      font.pixelSize: sec.fontSize
      color: sec.mutedColor
    }

    ListView {
      anchors.top: head.bottom
      anchors.topMargin: 4
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: sec.items

      delegate: Item {
        id: row
        required property var modelData
        width: ListView.view.width
        height: sec.fontSize * 1.8

        Rectangle {
          id: tagPill
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          visible: sec.showTag && row.modelData.tag !== ""
          width: tagText.implicitWidth + 12
          height: tagText.implicitHeight + 4
          radius: height / 2
          color: row.modelData.tagBg ? row.modelData.tagBg : "transparent"

          Text {
            id: tagText
            anchors.centerIn: parent
            text: "#" + row.modelData.tag
            font.pixelSize: sec.fontSize * 0.85
            color: row.modelData.tagFg ? row.modelData.tagFg : sec.mutedColor
          }
        }

        Text {
          anchors.left: parent.left
          anchors.right: tagPill.visible ? tagPill.left : parent.right
          anchors.rightMargin: tagPill.visible ? 6 : 0
          anchors.verticalCenter: parent.verticalCenter
          text: "•  " + row.modelData.title
          font.pixelSize: sec.fontSize
          color: sec.textColor
          elide: Text.ElideRight
        }

        Text {
          anchors.left: parent.left
          anchors.right: tagText.visible ? tagText.left : parent.right
          anchors.rightMargin: tagText.visible ? 6 : 0
          anchors.verticalCenter: parent.verticalCenter
          text: "•  " + row.modelData.title
          font.pixelSize: sec.fontSize
          color: sec.textColor
          elide: Text.ElideRight
        }
      }
    }
  }

  Item {
    id: content
    anchors.fill: parent

    // ================= CALENDÁRIO (quadrado) =================
    Item {
      id: calendar
      x: 0
      y: (content.height - height) / 2
      width: root.calSize
      height: root.calSize

      readonly property real headerH: Math.max(22, width * 0.13)
      readonly property real weekdaysH: root.showWeekdays ? Math.max(14, width * 0.07) : 0
      readonly property real gridH: height - headerH - weekdaysH
      readonly property real cellW: width / 7
      readonly property real cellH: gridH / 6
      readonly property real dayBox: Math.min(cellW, cellH) * root.dayRatio

      WheelHandler {
        onWheel: (wheel) => root.shift(wheel.angleDelta.y > 0 ? -1 : 1)
      }

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

            // evento: círculo mais escuro em volta
            Rectangle {
              anchors.centerIn: parent
              visible: cell.modelData.hasEvent
              width: calendar.dayBox
              height: width
              radius: width / 2
              color: root.eventColor
            }

            // hoje: quadrado
            Rectangle {
              anchors.centerIn: parent
              visible: cell.modelData.today
              width: calendar.dayBox
              height: width
              radius: root.todayRadius
              color: root.todayColor
            }

            // selecionado (teclado): contorno
            Rectangle {
              anchors.centerIn: parent
              visible: cell.modelData.selected
              width: calendar.dayBox + 4
              height: width
              radius: root.todayRadius + 2
              color: "transparent"
              border.color: root.selectColor
              border.width: root.selectWidth
            }

            Text {
              anchors.centerIn: parent
              text: cell.modelData.day
              font.pixelSize: root.dayFontSize > 0 ? root.dayFontSize : calendar.dayBox * 0.45
              font.bold: cell.modelData.today || cell.modelData.hasEvent || cell.modelData.selected
              color: cell.modelData.today ? root.todayTextColor : root.textColor
            }
          }
        }
      }
    }

    // ================= SEPARADOR VERTICAL =================
    Rectangle {
      x: root.calSize + root.separatorGap
      y: (content.height - height) / 2
      width: root.separatorThickness
      height: content.height * root.separatorRatio
      radius: width / 2
      color: root.separatorColor
    }

    // ================= EVENTOS | TAREFAS =================
    Item {
      id: tasksArea
      x: root.calSize + 2 * root.separatorGap + root.separatorThickness
      y: 0
      width: Math.max(0, content.width - x)
      height: content.height

      readonly property real sectionH: (height - 2 * root.separatorGap - root.separatorThickness) / 2

      SectionList {
        id: eventsSection
        y: 0
        width: parent.width
        height: tasksArea.sectionH
        title: "Eventos · " + root.shownLabel
        emptyText: "Sem eventos"
        items: root.dayEvents
        fontSize: root.tasksFontSize
        textColor: root.textColor
        mutedColor: root.mutedColor
      }

      // separador entre as seções
      Rectangle {
        y: tasksArea.sectionH + root.separatorGap
        width: parent.width
        height: root.separatorThickness
        radius: height / 2
        color: root.separatorColor
      }

      SectionList {
        id: tasksSection
        y: tasksArea.sectionH + 2 * root.separatorGap + root.separatorThickness
        width: parent.width
        height: tasksArea.sectionH
        title: "Tarefas"
        emptyText: "Sem tarefas"
        items: root.dayTasks
        showTag: true
        fontSize: root.tasksFontSize
        textColor: root.textColor
        mutedColor: root.mutedColor
      }
    }
  }
}
