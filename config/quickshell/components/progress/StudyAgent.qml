pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Ponte com o daemon studyagent. Toda a lógica (XP, streak, planejamento, tarefas) fica no daemon;
// aqui só se chama o comando `studyagent` (sem HTTP/curl) e se mostra o JSON.
//
//   studyagent ui snapshot        -> tudo que a página de produtividade desenha (StudyAgent.snap)
//   studyagent events -f          -> uma linha por evento: dispara a atualização na hora
//   studyagent task done|start|pause|plan <id> [dia]   -> ações (botões)
//
// Pré-requisitos: comando `studyagent` no PATH e token em ~/.config/studyagent/token (ver README do studyagent).
Singleton {
  id: root

  // ================= CONFIGURAÇÕES =================
  property string command: "studyagent"
  property int pollSeconds: 60                 // atualização de segurança enquanto a dock está aberta
  property bool active: false                  // a dock liga isto (DockContent): só consulta com ela aberta
  // =================================================

  // ---------- dados ----------
  property var snap: ({})
  property bool ready: false
  property string error: ""                    // última falha ("" = ok): daemon fora do ar, token ausente...
  property double snapAt: 0                    // quando o snapshot chegou (para o cronômetro andar entre consultas)

  readonly property var progress: snap.progress || ({})
  readonly property var tasks: snap.tasks || ({ today: [], tomorrow: [], week: [], fifteen: [] })
  readonly property var doneToday: snap.done_today || []
  readonly property var calendar: snap.calendar || []
  readonly property var taskDots: snap.task_dots || ({})
  readonly property var courses: snap.courses || []
  readonly property var dayoffs: snap.dayoffs || []
  readonly property string today: snap.today || ""

  // atalhos do progresso (nomes antigos do Progress.qml)
  readonly property int level: progress.level || 0
  readonly property real xp: progress.xp || 0
  readonly property real levelStartXp: progress.level_start_xp || 0
  readonly property real nextLevelXp: progress.next_level_xp || 1
  readonly property real levelProgress: progress.level_progress || 0
  readonly property int streak: progress.streak || 0
  readonly property int bestStreak: progress.best_streak || 0
  readonly property int freezes: progress.freezes || 0
  readonly property int freezeCap: progress.freeze_cap || 3
  readonly property real multiplier: progress.multiplier || 1
  readonly property int totalDone: progress.total_done || 0
  readonly property int weekDone: progress.week_done || 0
  readonly property var todayInfo: progress.today || ({})

  // ---------- cores por matéria (uma por sigla) ----------
  function courseColor(idx) {
    if (idx === undefined || idx === null || idx < 0) return Qt.hsla(0, 0, 0.7, 1)
    return Qt.hsla((0.58 + idx * 0.137) % 1, 0.55, 0.64, 1)
  }

  // ---------- datas ("aaaa-mm-dd") ----------
  function parseDay(s) {
    const p = String(s).split("-")
    return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
  }
  function dayKey(d) {
    return d.getFullYear() + "-" + (d.getMonth() < 9 ? "0" : "") + (d.getMonth() + 1) + "-" + (d.getDate() < 10 ? "0" : "") + d.getDate()
  }
  function shortDate(s) {                      // "27/11"
    const p = String(s).split("-")
    return p.length === 3 ? p[2] + "/" + p[1] : ""
  }
  readonly property var weekdayNames: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
  function weekdayOf(s) { return weekdayNames[parseDay(s).getDay()] }

  // sessões (aulas, provas, feriados...) de um dia, e o que é "destaque" no calendário
  function sessionsOn(day) { return calendar.filter(s => s.date === day) }
  function hasHighlight(day) { return calendar.some(s => s.date === day && s.highlight) }
  function dotsOn(day) { return taskDots[day] || [] }
  function isDayoff(day) { return dayoffs.indexOf(day) >= 0 }

  // tempo gasto numa tarefa, andando entre uma consulta e outra
  function spent(t) {
    if (!t) return 0
    return (t.spent_seconds || 0) + (t.running ? Math.max(0, Math.floor((Date.now() - snapAt) / 1000)) : 0)
  }
  function fmtTime(sec) {
    const m = Math.floor(sec / 60), s = sec % 60
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
  }

  // ---------- ações (botões) ----------
  function done(id)        { act(["task", "done", String(id)]) }
  function start(id)       { act(["task", "start", String(id)]) }
  function pause(id)       { act(["task", "pause", String(id)]) }
  function plan(id, day)   { act(["task", "plan", String(id), day]) }

  // ---------- comandos do widget de controle: avisam por notificação (recebido -> concluído/falhou) ----------
  // opts: { env: {VAR: valor}, summarize: function(texto) -> string }
  function notify(title, body) {
    Quickshell.execDetached(["notify-send", "-a", "studyagent", title, body])
  }
  function job(label, args, opts) {
    const o = opts || {}
    notify(label, "comando recebido, em andamento…")
    jobComp.createObject(root, {
      command: [root.command].concat(args),
      environment: o.env || ({}),
      label: label,
      summarize: o.summarize || null,
      running: true
    })
  }
  function finishJob(j, code, out, err) {
    const lastLine = (t) => { const l = t.trim().split("\n").filter(x => x.trim() !== ""); return l.length ? l[l.length - 1] : "" }
    if (code === 0) {
      let body = j.summarize ? j.summarize(out) : lastLine(out)
      notify(j.label + " ✓", (body || "concluído").slice(0, 240))
    } else {
      notify(j.label + " ✗", ("falhou: " + (lastLine(err) || lastLine(out) || ("código " + code))).slice(0, 240))
    }
    refresh()
    j.destroy()
  }
  Component {
    id: jobComp
    Process {
      id: j
      property string label: ""
      property var summarize: null
      stdout: StdioCollector { id: jout }
      stderr: StdioCollector { id: jerr }
      onExited: (code) => root.finishJob(j, code, jout.text, jerr.text)
    }
  }

  // "@27/11", "@+3", "@hoje", "@amanha", "@2026-12-04", "@27/11/2026" -> "aaaa-mm-dd" ("" se inválido)
  function parseDue(s) {
    const base = today !== "" ? parseDay(today) : new Date()
    const fmt = (d) => dayKey(d)
    let m
    if (s === "hoje") return fmt(base)
    if (s === "amanha" || s === "amanhã") return fmt(new Date(base.getFullYear(), base.getMonth(), base.getDate() + 1))
    if ((m = /^\+(\d{1,3})$/.exec(s))) return fmt(new Date(base.getFullYear(), base.getMonth(), base.getDate() + parseInt(m[1])))
    if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s
    if ((m = /^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?$/.exec(s))) {
      let y = m[3] ? parseInt(m[3]) : base.getFullYear()
      if (y < 100) y += 2000
      let d = new Date(y, parseInt(m[2]) - 1, parseInt(m[1]))
      if (!m[3] && d < base) d = new Date(y + 1, parseInt(m[2]) - 1, parseInt(m[1]))   // sem ano e já passou: ano que vem
      return fmt(d)
    }
    return ""
  }

  function refresh() {
    if (snapProc.running) { pending = true; return }
    snapProc.running = true
  }

  // ---------- internos ----------
  property bool pending: false
  property var queue: []

  function act(args) {
    queue.push(args)
    if (!actionProc.running) next()
  }
  function next() {
    if (queue.length === 0) return
    actionProc.command = [root.command].concat(queue.shift())
    actionProc.running = true
  }
  function parse(text) {
    try {
      const o = JSON.parse(text)
      snap = o
      if (streamAfter < 0) streamAfter = o.last_event || 0
      snapAt = Date.now()
      ready = true
      error = ""
    } catch (e) {
      error = text.trim() !== "" ? "resposta inválida do studyagent" : (error || "sem resposta do studyagent")
    }
  }

  Process {
    id: snapProc
    command: [root.command, "ui", "snapshot"]
    stdout: StdioCollector { onStreamFinished: root.parse(text) }
    stderr: StdioCollector { id: snapErr }
    onExited: (code) => {
      if (code !== 0) root.error = snapErr.text.trim().split("\n").pop() || ("studyagent saiu com código " + code)
      if (root.pending) { root.pending = false; root.refresh() }
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector { id: actErr }
    onExited: (code) => {
      if (code !== 0) root.error = actErr.text.trim().split("\n").pop() || ("falhou: " + code)
      root.refresh()
      root.next()
    }
  }

  // acompanha os eventos do daemon: cada linha = algo mudou -> atualiza (várias linhas juntas viram uma consulta)
  Timer { id: debounce; interval: 400; onTriggered: root.refresh() }
  Process {
    id: stream
    command: [root.command, "events", "-f", "--after", String(root.streamAfter)]
    running: root.active && root.streamAfter >= 0
    stdout: SplitParser {
      onRead: (line) => {
        if (root.ready) debounce.restart()
      }
    }
    onExited: if (root.active && root.streamAfter >= 0) restart.start()
  }
  property int streamAfter: -1                   // só eventos novos: o id vem do primeiro snapshot (não reprocessa o histórico)
  Timer { id: restart; interval: 5000; onTriggered: if (root.active) stream.running = true }

  Timer {
    interval: root.pollSeconds * 1000
    running: root.active
    repeat: true
    onTriggered: root.refresh()
  }

  onActiveChanged: if (active) refresh()
  Component.onCompleted: refresh()
}
