pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// XP e nível por tarefas concluídas no quadro Kanban do Obsidian.
//
// Fonte de verdade: o arquivo do Kanban (tasksFile). Uma tarefa conta como concluída quando está marcada
// ([x]) ou numa coluna de doneLanes. A cada mudança do arquivo comparamos com o que já foi premiado e
// gravamos um evento em ~/.local/state/quickshell/xp.jsonl; XP, nível e contadores são recalculados desse log
// (append-only: dá para corrigir à mão apagando/editando linhas).
//
// Eventos (uma linha JSON cada):
//   {"type":"init","ts":...}                      primeiro uso
//   {"type":"baseline","ids":[...]}               tarefas já concluídas antes de começar: não rendem XP
//   {"type":"done","id","title","due","tag","day","ts","xp","late"}
//   {"type":"gone","id"}                          a tarefa saiu do arquivo (arquivada/apagada): o id volta a poder render XP
Singleton {
  id: root

  // ================= CONFIGURAÇÕES =================
  property string tasksFile: "~/Obsidian Vault/Tarefas.md"    // o DockContent copia o do CalendarBox
  property int baseXp: 10
  property real lateFactor: 0.3                               // tarefa concluída depois do dia dela rende 30%
  property var tagXp: ({})                                    // peso por tag, ex.: ({ "estudo": 15, "rotina": 8 })
  property var doneLanes: ["Concluído", "Concluido", "Complete", "Completo", "Done"]  // colunas que contam como concluídas
  property var ignoreLanes: ["Archive"]
  property int dayStartHour: 4                                // o dia vira às 04:00
  property real levelBase: 50                                 // XP total do nível n = levelBase * n ^ levelExp
  property real levelExp: 1.5
  // =================================================

  // ---------- estado (vem do log) ----------
  property real xp: 0
  property int totalDone: 0
  property var dailyCount: ({})            // "aaaa-mm-dd" -> tarefas concluídas
  property var dailyXp: ({})

  readonly property string today: dayKey(clock.date)
  readonly property int todayCount: dailyCount[today] || 0
  readonly property real todayXp: dailyXp[today] || 0

  function xpFor(n) { return Math.round(levelBase * Math.pow(n, levelExp)) }

  readonly property int level: {
    let n = 0
    while (xpFor(n + 1) <= xp) n++
    return n
  }
  readonly property real levelStartXp: xpFor(level)
  readonly property real nextLevelXp: xpFor(level + 1)
  readonly property real levelProgress: Math.max(0, Math.min(1, (xp - levelStartXp) / Math.max(1, nextLevelXp - levelStartXp)))

  // emitido a cada tarefa premiada (para notificações/animações futuras)
  signal taskCompleted(var event)
  signal levelUp(int newLevel)

  // ---------- internos ----------
  readonly property string logPath:
    (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/xp.jsonl"

  property var known: ({})                 // ids já premiados e ainda presentes no arquivo
  property bool initialized: false
  property bool logReady: false
  property var pendingList: null
  property bool tryMd: false

  function pad(n) { return n < 10 ? "0" + n : "" + n }

  function dayKey(d) {
    const s = new Date(d.getTime() - dayStartHour * 3600000)
    return s.getFullYear() + "-" + pad(s.getMonth() + 1) + "-" + pad(s.getDate())
  }

  function expand(p) {
    const home = Quickshell.env("HOME") || ""
    if (p === "~") return home
    if (p.startsWith("~/")) return home + p.slice(1)
    return p
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // ---------- log ----------
  function reset() {
    xp = 0; totalDone = 0; dailyCount = ({}); dailyXp = ({}); known = ({}); initialized = false
  }

  function applyEvent(e, live) {
    if (e.type === "init") {
      initialized = true
    } else if (e.type === "baseline") {
      (e.ids || []).forEach(id => { known[id] = true })
    } else if (e.type === "done") {
      known[e.id] = true
      const before = level
      xp += e.xp || 0
      totalDone += 1
      const c = Object.assign({}, dailyCount); c[e.day] = (c[e.day] || 0) + 1; dailyCount = c
      const x = Object.assign({}, dailyXp);   x[e.day] = (x[e.day] || 0) + (e.xp || 0); dailyXp = x
      if (live) {
        taskCompleted(e)
        if (level > before) levelUp(level)
      }
    } else if (e.type === "gone") {
      delete known[e.id]
    }
  }

  function append(e) {
    applyEvent(e, true)
    Quickshell.execDetached(["sh", "-c",
      'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" >> "$1"',
      "sh", logPath, JSON.stringify(e)])
  }

  function replay(text) {
    reset()
    const lines = text.split("\n")
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].trim() === "") continue
      try { applyEvent(JSON.parse(lines[i]), false) } catch (err) { console.warn("Progress: linha inválida no log:", lines[i]) }
    }
  }

  FileView {
    id: logView
    path: root.logPath
    printErrors: false
    onLoaded: root.logLoaded(text())
    onLoadFailed: root.logLoaded("")
  }

  function logLoaded(text) {
    replay(text)
    logReady = true
    if (pendingList) { const l = pendingList; pendingList = null; sync(l) }
  }

  // ---------- tarefas ----------
  function normalize(s) { return s.toLowerCase().replace(/\s+/g, " ").trim() }

  function parse(text) {
    const out = []
    const seen = {}
    let lane = ""
    const lines = text.split("\n")
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const h = /^##\s+(.*?)\s*$/.exec(line)
      if (h) { lane = h[1]; continue }
      if (/^\*\*\*\s*$/.test(line)) break                    // o Kanban separa o Archive com ***
      if (ignoreLanes.indexOf(lane) >= 0) continue

      const m = /^\s*-\s\[([ xX])\]\s+(.*)$/.exec(line)
      if (!m) continue

      let body = m[2]
      let due = ""
      const dm = /@\{(\d{1,2})\/(\d{1,2})\/(\d{2,4})\}/.exec(body)
      const dm2 = /@\{(\d{4})-(\d{2})-(\d{2})\}/.exec(body)
      if (dm) {
        let y = parseInt(dm[3]); if (y < 100) y += 2000
        due = y + "-" + pad(parseInt(dm[2])) + "-" + pad(parseInt(dm[1]))
        body = body.replace(dm[0], "")
      } else if (dm2) {
        due = dm2[1] + "-" + dm2[2] + "-" + dm2[3]
        body = body.replace(dm2[0], "")
      }
      const tags = []
      body = body.replace(/#(\S+)/g, (s, t) => { tags.push(t); return "" })
      const title = body.replace(/\s+/g, " ").trim().replace(/\s*[-–]$/, "")

      // id = título + data (+ nº da ocorrência, se houver títulos repetidos)
      const base = normalize(title) + "|" + due
      seen[base] = (seen[base] || 0) + 1

      out.push({
        id: base + "#" + seen[base],
        title: title,
        due: due,
        tag: tags[0] || "",
        done: m[1] !== " " || doneLanes.indexOf(lane) >= 0
      })
    }
    return out
  }

  function sync(list) {
    if (!logReady) { pendingList = list; return }
    // leitura vazia (arquivo sendo salvo): ignora, para não marcar tudo como "gone"
    if (list.length === 0 && Object.keys(known).length > 0) return

    const now = new Date()
    const ts = now.toISOString()

    if (!initialized) {
      append({ type: "init", ts: ts })
      append({ type: "baseline", ids: list.filter(t => t.done).map(t => t.id) })
      return
    }

    const present = {}
    for (let i = 0; i < list.length; i++) present[list[i].id] = true

    const day = dayKey(now)
    for (let i = 0; i < list.length; i++) {
      const t = list[i]
      if (!t.done || known[t.id]) continue
      const late = t.due !== "" && t.due < day
      const w = t.tag !== "" && tagXp[t.tag.toLowerCase()] !== undefined ? tagXp[t.tag.toLowerCase()] : baseXp
      append({
        type: "done", ts: ts, day: day, id: t.id, title: t.title, due: t.due, tag: t.tag,
        late: late, xp: Math.round(w * (late ? lateFactor : 1))
      })
    }

    for (const id of Object.keys(known)) {
      if (!present[id]) append({ type: "gone", id: id })
    }
  }

  FileView {
    id: tasksView
    path: root.expand(root.tasksFile) + (root.tryMd ? ".md" : "")
    watchChanges: true
    printErrors: false
    onFileChanged: reloadTimer.restart()
    onLoaded: root.sync(root.parse(text()))
    onLoadFailed: if (!root.tryMd && !root.tasksFile.endsWith(".md")) root.tryMd = true
  }

  Timer {
    id: reloadTimer
    interval: 400                            // o Obsidian salva em rajadas
    onTriggered: tasksView.reload()
  }
}
