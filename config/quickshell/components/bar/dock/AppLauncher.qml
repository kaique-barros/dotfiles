import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Launcher em grade com páginas, busca (/) e ordenação por uso.
// Normal: h j k l / setas movem, Enter lança, o = próxima página, O = anterior,
//         letras das caixinhas lançam direto, / abre a busca.
// Busca:  digite para filtrar (nome, nome genérico, keywords, comentário, comando),
//         setas / Tab movem, Enter lança, Esc sai da busca.
Item {
  id: root

  // ================= CONFIGURAÇÕES =================
  // ordenação: "usage" = mais usados primeiro (lançamentos feitos aqui; importe o cache antigo do rofi com tools/import-rofi-cache.sh)
  //            "alpha" = ordem alfabética
  property string sortMode: "usage"

  property bool active: false              // ligado pela dock quando esta página está visível
  property bool closeOnLaunch: true        // fecha a dock depois de lançar

  // "all"  = todos os apps  | "user" = só ~/.local/share/applications
  property string source: "all"

  // histórico de uso (formato "contagem id" por linha)
  property string usageFile: "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-launcher.usage"

  // grade
  property int columns: 6
  property int rows: 8
  property real iconSize: 56               // tamanho igual para todos os ícones

  // margens da área onde a grade fica centralizada (individuais)
  property real marginTop: 60
  property real marginBottom: 60
  property real marginLeft: 20
  property real marginRight: 20

  // células
  property real cellPadding: 12            // folga em volta do ícone (a seleção usa isso)
  property real spacingX: 12
  property real spacingY: 12

  // caixinha de atalho
  property real hintHeight: 18
  property real hintSpacing: 6
  property var hintKeys: ["q", "w", "e", "r", "t", "a", "s", "d", "z", "x", "c", "v"]

  // caixa de busca
  property real searchHeight: 34
  property real searchMarginBottom: 14

  // cores
  property color selectedColor: "#e8ebf0"
  property color hintColor: "#1e1e2e"
  property color hintTextColor: "white"
  property color textColor: "#344054"
  property color searchColor: "#e8ebf0"
  // =================================================

  signal launched()
  signal closeRequested()

  property int selected: 0                 // índice dentro da página atual
  property int page: 0
  property var typed: []                   // letras já digitadas no modo de atalho
  property var fileIds: []                 // ids dos .desktop da pasta do usuário (source "user")
  property var usage: ({})                 // id normalizado -> contagem

  property bool searching: false
  property string query: ""

  readonly property int perPage: columns * rows
  readonly property var alphabet: hintKeys.filter((k, i, a) => a.indexOf(k) === i)

  // ---------- lista de apps ----------
  function normId(s) {
    return String(s || "").trim().split("/").pop().replace(/\.desktop$/, "").toLowerCase()
  }

  function joinList(l) {
    if (!l) return ""
    let s = ""
    for (let i = 0; i < l.length; i++) s += " " + l[i]
    return s
  }

  readonly property var entries: {
    const list = []
    if (source === "user") {
      for (let i = 0; i < fileIds.length; i++) {
        const e = DesktopEntries.byId(fileIds[i])
        if (e && !e.noDisplay) list.push(e)
      }
    } else {
      const all = DesktopEntries.applications.values
      for (let i = 0; i < all.length; i++) {
        if (!all[i].noDisplay) list.push(all[i])
      }
    }
    return list
  }

  // entradas com os textos já em minúsculas, para a ordenação e a busca
  readonly property var indexed: entries.map(e => {
    const main = ((e.name || "") + " " + (e.genericName || "") + joinList(e.keywords)
                  + " " + (e.id || "")).toLowerCase()
    return {
      e: e,
      key: normId(e.id),
      name: (e.name || "").toLowerCase(),
      main: main,
      all: main + " " + (e.comment || "").toLowerCase() + " " + (e.execString || "").toLowerCase()
    }
  })

  readonly property var sortedIdx: {
    const list = indexed.slice()
    const byName = (a, b) => a.name.localeCompare(b.name)
    if (sortMode === "usage")
      list.sort((a, b) => ((usage[b.key] || 0) - (usage[a.key] || 0)) || byName(a, b))
    else
      list.sort(byName)
    return list
  }

  readonly property var apps: {
    const q = query.toLowerCase().trim()
    if (!searching || q === "") return sortedIdx.map(o => o.e)

    const tokens = q.split(/\s+/)
    const hits = []
    for (let i = 0; i < sortedIdx.length; i++) {
      const o = sortedIdx[i]
      if (!tokens.every(t => o.all.indexOf(t) >= 0)) continue
      let tier = 3                                          // só no comentário / comando
      if (o.name.startsWith(q)) tier = 0                    // nome começa com a busca
      else if (tokens.every(t => o.name.indexOf(t) >= 0)) tier = 1   // nome contém
      else if (tokens.every(t => o.main.indexOf(t) >= 0)) tier = 2   // alias / keywords / id
      hits.push({ o: o, tier: tier, pos: i })
    }
    hits.sort((a, b) => (a.tier - b.tier) || (a.pos - b.pos))
    return hits.map(h => h.o.e)
  }

  readonly property int pageCount: Math.max(1, Math.ceil(apps.length / perPage))
  onPageCountChanged: if (page >= pageCount) page = pageCount - 1

  readonly property var pageApps: apps.slice(page * perPage, (page + 1) * perPage)
  readonly property var codes: makeCodes(alphabet, pageApps.length)

  onQueryChanged: { page = 0; selected = 0 }

  // ---------- histórico de uso ----------
  function parseUsage(text) {
    const u = {}
    const lines = text.split("\n")
    for (let i = 0; i < lines.length; i++) {
      const m = lines[i].match(/^\s*(\d+)\s+(.+?)\s*$/)
      if (!m) continue
      const key = normId(m[2])
      u[key] = (u[key] || 0) + parseInt(m[1])
    }
    usage = u
  }

  function recordUse(e) {
    if (!e) return
    const key = normId(e.id)
    const u = Object.assign({}, usage)
    u[key] = (u[key] || 0) + 1
    usage = u

    // grava no arquivo próprio 
    const script = 'f="' + usageFile + '"; touch "$f"; ' +
      "awk -v id=\"$1\" 'BEGIN{d=0} $2==id{print $1+1, $2; d=1; next} {print} END{if(!d) print 1, id}' " +
      '"$f" > "$f.tmp" && mv "$f.tmp" "$f"'
    Quickshell.execDetached(["sh", "-c", script, "sh", key])
  }

  // ---------- códigos de atalho ----------
  function binom(n, k) {
    let r = 1
    for (let i = 1; i <= k; i++) r = r * (n - k + i) / i
    return Math.round(r)
  }

  // todos os códigos têm o mesmo tamanho L: o menor L em que as combinações cobrem os apps
  function makeCodes(alpha, count) {
    const n = alpha.length
    if (count <= 0 || n === 0) return []
    let L = 1
    while (binom(n, L) < count && L < n) L++
    const out = []
    const idx = []
    function rec(start, depth) {
      if (depth === L) { out.push(idx.map(i => alpha[i])); return }
      for (let i = start; i < n; i++) {
        idx.push(i)
        rec(i + 1, depth + 1)
        idx.pop()
        if (out.length >= count) return
      }
    }
    rec(0, 0)
    return out.slice(0, count)
  }

  function matches(code) {
    return typed.every(t => code.indexOf(t) >= 0)
  }

  // ---------- ações ----------
  function iconFor(e) {
    if (!e || !e.icon) return ""
    if (e.icon.startsWith("/")) return "file://" + e.icon
    const p = Quickshell.iconPath(e.icon, true)
    return p ? p : ""
  }

  function move(dc, dr) {
    const n = pageApps.length
    if (n === 0) return
    const col = selected % columns
    const row = Math.floor(selected / columns)

    if (dc !== 0) {
      const nc = col + dc
      if (nc < 0 || nc >= columns) return
      const ni = row * columns + nc
      if (ni < n) selected = ni
      return
    }

    const nr = row + dr
    if (nr < 0) {                                   // topo: página anterior
      if (page > 0) { page--; selected = (rows - 1) * columns + col }
      return
    }
    if (nr >= rows) {                               // fim: próxima página
      if (page < pageCount - 1) { page++; selected = Math.min(col, pageApps.length - 1) }
      return
    }
    const ni = nr * columns + col
    if (ni < n) selected = ni
  }

  // anda de item em item atravessando as páginas (Tab / Shift+Tab)
  function step(delta) {
    const total = apps.length
    if (total === 0) return
    const gi = Math.max(0, Math.min(total - 1, page * perPage + selected + delta))
    page = Math.floor(gi / perPage)
    selected = gi % perPage
  }

  // troca de página com volta ao início/fim
  function goPage(delta) {
    page = (page + delta + pageCount) % pageCount
    selected = Math.min(selected, Math.max(0, pageApps.length - 1))
  }

  function startSearch() {
    searching = true
    query = ""
    typed = []
    selected = 0
    page = 0
  }

  function endSearch() {
    searching = false
    query = ""
    selected = 0
    page = 0
  }

  function launch(i) {
    if (i < 0 || i >= pageApps.length) return
    typed = []
    const e = pageApps[i]
    recordUse(e)
    e.execute()
    launched()
    if (searching) endSearch()
  }

  function typeLetter(ch) {
    const next = typed.concat([ch])
    let found = -1
    let count = 0
    for (let i = 0; i < codes.length; i++) {
      if (next.every(t => codes[i].indexOf(t) >= 0)) {
        count++
        if (codes[i].length === next.length) found = i      // não sobrou letra: é esse
      }
    }
    if (count === 0) return                                  // nenhum app tem essa letra: ignora
    typed = next
    if (found >= 0) launch(found)
  }

  function handleKey(event) {
    if (!active) return
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return

    const k = event.key
    if (k === Qt.Key_Return || k === Qt.Key_Enter) {
      if (!event.isAutoRepeat) launch(selected)
    } else if (k === Qt.Key_Escape) {
      if (searching) endSearch()
      else if (typed.length > 0) typed = []
      else closeRequested()
    } else if (k === Qt.Key_Backspace) {
      if (searching) {
        if (query.length > 0) query = query.slice(0, -1)
        else endSearch()
      } else {
        typed = typed.slice(0, -1)
      }
    } else if (k === Qt.Key_Left) move(-1, 0)
    else if (k === Qt.Key_Right) move(1, 0)
    else if (k === Qt.Key_Up) move(0, -1)
    else if (k === Qt.Key_Down) move(0, 1)
    else if (k === Qt.Key_Tab) step(1)
    else if (k === Qt.Key_Backtab) step(-1)
    else if (searching) {
      const t = event.text
      if (t.length === 1 && t.charCodeAt(0) >= 32) query += t
      else return
    } else {
      const raw = event.text
      const ch = raw.toLowerCase()
      if (raw === "/") startSearch()
      else if (raw === "o") goPage(1)
      else if (raw === "O") goPage(-1)
      else if (ch === "h") move(-1, 0)
      else if (ch === "l") move(1, 0)
      else if (ch === "j") move(0, 1)
      else if (ch === "k") move(0, -1)
      else if (!event.isAutoRepeat && alphabet.indexOf(ch) >= 0) typeLetter(ch)
      else return
    }
    event.accepted = true
  }

  function grabFocus() {
    if (active && visible) keys.forceActiveFocus()
  }

  onActiveChanged: {
    if (active) {
      selected = 0
      page = 0
      typed = []
      lister.running = true                // relê a pasta (pega atalhos novos)
      usageReader.running = true           // relê o histórico de uso
      Qt.callLater(grabFocus)
    } else {
      searching = false
      query = ""
    }
  }
  onVisibleChanged: if (visible) Qt.callLater(grabFocus)

  // lista os arquivos .desktop da pasta do usuário (usado só com source "user")
  Process {
    id: lister
    command: ["sh", "-c", "ls -1 \"$HOME/.local/share/applications\" 2>/dev/null"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        root.fileIds = text.split("\n")
          .filter(f => f.endsWith(".desktop"))
          .map(f => f.slice(0, -8))
      }
    }
  }

  // histórico de uso
  Process {
    id: usageReader
    command: ["sh", "-c", 'cat "' + root.usageFile + '" 2>/dev/null']
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.parseUsage(text)
    }
  }

  Item {
    id: keys
    focus: true
    Keys.onPressed: (event) => root.handleKey(event)
  }

  // clicar no fundo também recupera o foco
  MouseArea {
    anchors.fill: parent
    z: -1
    onPressed: (mouse) => { root.grabFocus(); mouse.accepted = false }
  }

  // ---------- visual ----------
  Item {
    id: gridBox
    anchors.fill: parent
    anchors.topMargin: root.marginTop
    anchors.bottomMargin: root.marginBottom
    anchors.leftMargin: root.marginLeft
    anchors.rightMargin: root.marginRight

    readonly property real cellW: root.iconSize + 2 * root.cellPadding
    readonly property real cellH: root.iconSize + root.hintSpacing + root.hintHeight + 2 * root.cellPadding

    Item {
      id: grid
      anchors.centerIn: parent
      width: root.columns * gridBox.cellW + (root.columns - 1) * root.spacingX
      height: root.rows * gridBox.cellH + (root.rows - 1) * root.spacingY

      Repeater {
        model: root.pageApps

        delegate: Item {
          id: cell
          required property var modelData
          required property int index

          readonly property var code: root.codes[index] || []
          readonly property bool hintShown: !root.searching && root.matches(code)
          readonly property var remaining: code.filter(c => root.typed.indexOf(c) < 0)

          x: (index % root.columns) * (gridBox.cellW + root.spacingX)
          y: Math.floor(index / root.columns) * (gridBox.cellH + root.spacingY)
          width: gridBox.cellW
          height: gridBox.cellH

          Rectangle {
            anchors.fill: parent
            radius: 12
            color: root.selectedColor
            visible: cell.index === root.selected
          }

          Column {
            anchors.centerIn: parent
            spacing: root.hintSpacing

            // ícone (ou a inicial do app, se o ícone não for encontrado)
            Item {
              width: root.iconSize
              height: root.iconSize
              anchors.horizontalCenter: parent.horizontalCenter

              IconImage {
                id: img
                anchors.fill: parent
                source: root.iconFor(cell.modelData)
                visible: status === Image.Ready
              }

              Rectangle {
                anchors.fill: parent
                visible: !img.visible
                radius: width / 4
                color: "#d0d5dd"

                Text {
                  anchors.centerIn: parent
                  text: (cell.modelData.name || "?").charAt(0).toUpperCase()
                  font.pixelSize: root.iconSize * 0.45
                  font.bold: true
                  color: root.textColor
                }
              }
            }

            // caixinha de atalho: ocupa sempre o espaço, para o ícone não "pular" quando ela some
            Item {
              width: root.iconSize
              height: root.hintHeight
              anchors.horizontalCenter: parent.horizontalCenter

              Rectangle {
                anchors.centerIn: parent
                visible: cell.hintShown
                width: Math.max(root.hintHeight, hintText.implicitWidth + 12)
                height: root.hintHeight
                radius: 4
                color: root.hintColor

                Text {
                  id: hintText
                  anchors.centerIn: parent
                  text: cell.remaining.join("").toUpperCase()
                  font.family: "monospace"
                  font.pixelSize: 10
                  font.bold: true
                  color: root.hintTextColor
                }
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launch(cell.index)
          }
        }
      }
    }

    // indicador de página
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: grid.bottom
      anchors.topMargin: 8
      visible: root.pageCount > 1
      text: (root.page + 1) + " / " + root.pageCount
      font.pixelSize: 11
      font.bold: true
      color: root.textColor
    }
  }

  // sem resultados
  Text {
    anchors.centerIn: parent
    visible: root.searching && root.query.trim() !== "" && root.apps.length === 0
    text: "Nenhum app encontrado"
    font.pixelSize: 12
    font.italic: true
    color: "#98a2b3"
  }

  // ---------- caixa de busca (no fim da dock) ----------
  Rectangle {
    id: searchBox
    visible: root.searching
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.searchMarginBottom
    width: parent.width - root.marginLeft - root.marginRight
    height: root.searchHeight
    radius: 10
    color: root.searchColor

    Text {
      id: slash
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: "/"
      font.family: "monospace"
      font.pixelSize: 14
      font.bold: true
      color: "#667085"
    }

    Text {
      id: queryText
      anchors.left: slash.right
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: root.query
      font.pixelSize: 13
      color: root.textColor
    }

    // cursor piscando
    Rectangle {
      anchors.left: queryText.right
      anchors.leftMargin: 1
      anchors.verticalCenter: parent.verticalCenter
      width: 2
      height: 16
      color: root.textColor
      visible: root.searching

      SequentialAnimation on opacity {
        running: root.searching
        loops: Animation.Infinite
        NumberAnimation { to: 0; duration: 500 }
        NumberAnimation { to: 1; duration: 500 }
      }
    }

    Text {
      anchors.left: slash.right
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      visible: root.query === ""
      text: "buscar app..."
      font.pixelSize: 13
      color: "#98a2b3"
    }

    Text {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: root.apps.length
      font.pixelSize: 11
      font.bold: true
      color: "#667085"
    }
  }
}
