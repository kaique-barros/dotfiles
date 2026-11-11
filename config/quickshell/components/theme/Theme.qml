pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tema atual, lido de themes/<id>.json (o id é o mesmo do Wallpaper Engine).
//
//   Theme.currentId            id do tema em uso ("" = tudo padrão)
//   Theme.select("1845706469") troca de tema: aplica na hora, salva e troca o wallpaper (tools/wallpaper.sh)
//   Theme.defaultId            tema usado enquanto não houver um salvo; definido no shell.qml
//   Theme.color("cor1", "#fff") cor do tema, ou o valor padrão quando o tema não define
//   Theme.asset("battery.svg")  ícone/imagem do tema, ou o de assets/ quando o tema não tem
//
// Formato do arquivo (todos os campos são opcionais; vazio = usar o padrão):
//   {
//     "id": "1845706469",
//     "name": "Título do wallpaper",
//     "screenshot": "/caminho/para/o/print.png",
//     "assets": "~/caminho/da/pasta",          // absoluto, com ~, ou relativo à pasta themes/
//     "colors": { "cor1": "#ffffff", "cor2": "#555555", "cor3": "#000000",
//                 "accent": "", "danger": "" },
//     "quantized": [ ... ]                      // cores brutas do ColorQuantizer, só de consulta
//   }
Singleton {
  id: root

  // Quem manda: o que foi escolhido (QS_THEME, o arquivo salvo ou o seletor) > defaultId do shell.qml
  property string defaultId: ""
  property string chosenId: Quickshell.env("QS_THEME") || ""
  readonly property string currentId: chosenId !== "" ? chosenId : defaultId

  readonly property string themesDir: Quickshell.shellPath("themes")
  readonly property string wallpaperScript: Quickshell.shellPath("tools/wallpaper.sh")
  // o mesmo arquivo que o tools/wallpaper.sh grava, para o tema sobreviver ao reinício
  readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/theme"
  readonly property string themeFile: currentId !== "" ? themesDir + "/" + currentId + ".json" : ""
  readonly property string niriThemeScript:
    Quickshell.shellPath("tools/theme-sync-niri.sh")

  // ---------- dados do tema carregado ----------
  property string name: ""
  property string screenshot: ""
  property var colors: ({})
  property var quantized: []
  property string assetsDir: ""          // já resolvido (caminho absoluto) ou ""
  property var assetFiles: []            // arquivos que existem na pasta de assets do tema

  readonly property bool loaded: themeFile !== "" && file.loadedOnce

  // ---------- API ----------
  function color(key, fallback) {
    const v = colors[key]
    return v ? v : fallback
  }

  // devolve "file://..." do arquivo do tema se ele existir; senão, o padrão em assets/
  function asset(name) {
    if (assetsDir !== "" && assetFiles.indexOf(name) >= 0)
      return "file://" + assetsDir.split("/").map(encodeURIComponent).join("/") + "/" + encodeURIComponent(name)
    return "file://" + Quickshell.shellPath("assets/" + name)
  }

  // ---------- internos ----------
  function expand(p) {
    if (!p) return ""
    const home = Quickshell.env("HOME") || ""
    if (p === "~") return home
    if (p.startsWith("~/")) return home + p.slice(1)
    if (p.startsWith("/")) return p
    return themesDir + "/" + p                      // relativo à pasta themes/
  }

  function isColor(v) {
    return typeof v === "string" && /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(v.trim())
  }

  function syncNiriTheme() {
    Quickshell.execDetached([
        root.niriThemeScript,
        root.currentId
    ])
  }

  // troca de tema: as cores mudam na hora; o wallpaper troca quando você para de passar (evita reiniciar o engine a cada tecla)
  function select(id) {
    if (!id || id === currentId) return
    chosenId = id
    wallpaperTimer.restart()
  }

  function reset() {
    name = ""
    screenshot = ""
    colors = ({})
    quantized = []
    assetsDir = ""
    assetFiles = []
  }

  function apply(text) {
    let data
    try {
      data = JSON.parse(text)
    } catch (e) {
      console.warn("Theme: JSON inválido em", themeFile, "-", e)
      reset()
      return
    }

    name = data.name || ""
    screenshot = data.screenshot || ""
    quantized = Array.isArray(data.quantized) ? data.quantized : []

    const c = {}
    const src = data.colors || {}
    for (const k in src) {
      if (isColor(src[k])) c[k] = src[k].trim()      // cor vazia ou inválida = padrão
    }
    colors = c

    assetFiles = []
    assetsDir = expand(data.assets)
    if (assetsDir !== "") lister.running = true
  }

  Timer {
    id: wallpaperTimer
    interval: 350
    onTriggered: Quickshell.execDetached([root.wallpaperScript, "set", root.currentId])
  }

  // tema salvo da última vez (só vale se nada foi escolhido ainda)
  FileView {
    id: stateView
    path: root.stateFile
    printErrors: false
    onLoaded: {
      const id = text().trim()
      if (id !== "" && root.chosenId === "") root.chosenId = id
    }
  }

  FileView {
    id: file
    path: root.themeFile
    watchChanges: true                       // editar o json aplica na hora
    printErrors: false
    property bool loadedOnce: false

    onLoaded: {
      loadedOnce = true
      root.apply(text())
      root.syncNiriTheme()
    }

    onLoadFailed: {
      loadedOnce = false
      if (root.themeFile !== "")
          console.warn("Theme: não achei", root.themeFile, "- usando o padrão")

      root.reset()
      root.syncNiriTheme()
    }
    onFileChanged: reload()
  }

  onThemeFileChanged: if (themeFile === "") reset()

  // lista os arquivos da pasta de assets do tema (pasta inexistente = lista vazia)
  Process {
    id: lister
    command: ["sh", "-c", '[ -d "$1" ] && find -L "$1" -maxdepth 1 -type f -printf "%f\\n"', "sh", root.assetsDir]
    stdout: StdioCollector {
      onStreamFinished: root.assetFiles = text.split("\n").filter(s => s.length > 0)
    }
  }
}
