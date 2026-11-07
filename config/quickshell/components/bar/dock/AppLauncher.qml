import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Launcher em grade com páginas.
// Seleção: h j k l + Enter, ou combinações de letras na caixinha embaixo de cada ícone.
Item {
  id: root

  // ================= CONFIGURAÇÕES =================
  property bool active: false              // ligado pela dock quando esta página está visível
  property bool closeOnLaunch: true        // fecha a dock depois de lançar

  // "all"  = todos os apps (como o rofi)
  // "user" = só ~/.local/share/applications
  property string source: "all"

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

  // cores
  property color selectedColor: "#e8ebf0"
  property color hintColor: "#1e1e2e"
  property color hintTextColor: "white"
  property color textColor: "#344054"
  // =================================================

  signal launched()
  signal closeRequested()

  property int selected: 0                 // índice dentro da página atual
  property int page: 0
  property var typed: []                   // letras já digitadas no modo de atalho
  property var fileIds: []                 // ids dos .desktop da pasta do usuário (source "user")

  readonly property int perPage: columns * rows
  readonly property var alphabet: hintKeys.filter((k, i, a) => a.indexOf(k) === i)

  readonly property var apps: {
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
    list.sort((a, b) => (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase()))
    return list
  }

  readonly property int pageCount: Math.max(1, Math.ceil(apps.length / perPage))
  onPageCountChanged: if (page >= pageCount) page = pageCount - 1

  readonly property var pageApps: apps.slice(page * perPage, (page + 1) * perPage)
  readonly property var codes: makeCodes(alphabet, pageApps.length)

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

  function launch(i) {
    if (i < 0 || i >= pageApps.length) return
    typed = []
    pageApps[i].execute()
    launched()
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
      if (typed.length > 0) typed = []
      else closeRequested()
    } else if (k === Qt.Key_Backspace) {
      typed = typed.slice(0, -1)
    } else {
      const ch = (event.text || "").toLowerCase()
      if (ch === "h") move(-1, 0)
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
      typed = []
      lister.running = true
      Qt.callLater(grabFocus)              // espera a página ficar visível
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

  Item {
    id: keys
    focus: true
    Keys.onPressed: (event) => {
      console.log("LAUNCHER key:", event.key, JSON.stringify(event.text))
      root.handleKey(event)
    }
    onActiveFocusChanged: console.log("LAUNCHER activeFocus:", activeFocus)
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
          readonly property bool hintShown: root.matches(code)
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
}
