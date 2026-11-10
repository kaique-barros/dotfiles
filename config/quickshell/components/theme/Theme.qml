pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tema atual, lido de themes/<id>.json (o id é o mesmo do Wallpaper Engine).
//
//   Theme.currentId            id do tema ("" = tudo padrão); definido no shell.qml
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

  property string currentId: ""

  readonly property string themesDir: Quickshell.shellPath("themes")
  readonly property string themeFile: currentId !== "" ? themesDir + "/" + currentId + ".json" : ""

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

  FileView {
    id: file
    path: root.themeFile
    watchChanges: true                       // editar o json aplica na hora
    printErrors: false
    property bool loadedOnce: false

    onLoaded: { loadedOnce = true; root.apply(text()) }
    onLoadFailed: {
      loadedOnce = false
      if (root.themeFile !== "") console.warn("Theme: não achei", root.themeFile, "- usando o padrão")
      root.reset()
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
