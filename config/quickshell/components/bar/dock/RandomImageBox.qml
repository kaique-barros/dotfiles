import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Mostra uma imagem aleatória (ou GIF) das pastas indicadas, sorteada a cada abertura da dock.
// A busca é recursiva. O tamanho é o da caixa (colSpan / rowSpan).
Box {
  id: root

  // ================= CONFIGURAÇÕES =================
  property var directories: ["~/Downloads/cassie_pack/"]                  // pastas (aceita ~), subpastas incluídas
  property var extensions: ["png", "jpg", "jpeg", "webp", "gif", "bmp"]

  property bool active: false                               // ligue na dock: sorteia quando vira true
  property bool rescanOnOpen: true                          // relê as pastas a cada abertura (acha arquivos novos)

  property real quality: 2                                  // resolução carregada = tamanho * este valor
  property bool animateGifs: true
  // =================================================

  padding: 0

  property var files: []
  property string currentFile: ""
  property bool pendingPick: false
  property int errorCount: 0

  function expand(p) {
    const home = Quickshell.env("HOME") || ""
    if (p === "~") return home
    if (p.startsWith("~/")) return home + p.slice(1)
    return p
  }

  // caminho -> URL (escapa espaços, # e outros caracteres)
  function toUrl(path) {
    return "file://" + path.split("/").map(encodeURIComponent).join("/")
  }

  function scan() { scanner.running = true }

  function pick() {
    if (files.length === 0) return
    let f = files[Math.floor(Math.random() * files.length)]
    // evita repetir a mesma imagem duas vezes seguidas
    let guard = 0
    while (files.length > 1 && f === currentFile && guard++ < 10)
      f = files[Math.floor(Math.random() * files.length)]
    currentFile = f
  }

  readonly property string findScript:
    'find -L "$@" -type f \\( '
    + extensions.map(e => "-iname '*." + e + "'").join(" -o ")
    + ' \\) 2>/dev/null'

  Process {
    id: scanner
    command: ["sh", "-c", root.findScript, "sh"].concat(root.directories.map(d => root.expand(d)))

    stdout: StdioCollector {
      onStreamFinished: {
        root.files = text.split("\n").filter(l => l !== "")
        if (root.pendingPick || root.currentFile === "") {
          root.pendingPick = false
          root.pick()
        }
      }
    }
  }

  onActiveChanged: {
    if (!active) return
    if (files.length > 0) {
      pick()                          // já tem a lista: sorteia na hora
      if (rescanOnOpen) scan()        // e atualiza a lista para a próxima
    } else {
      pendingPick = true
      scan()
    }
  }

  Component.onCompleted: scan()

  // ---------- visual ----------
  ClippingRectangle {
    anchors.fill: parent
    radius: root.radius
    color: "transparent"
    antialiasing: true

    AnimatedImage {
      id: img
      anchors.fill: parent
      source: root.currentFile !== "" ? root.toUrl(root.currentFile) : ""
      fillMode: root.fillMode
      asynchronous: true
      cache: false
      smooth: true
      mipmap: true
      playing: root.animateGifs && root.visible
      sourceSize: Qt.size(width * root.quality, height * root.quality)

      onStatusChanged: {
        if (status === Image.Ready) {
          root.errorCount = 0
        } else if (status === Image.Error && root.files.length > 1 && root.errorCount < 5) {
          root.errorCount++
          Qt.callLater(root.pick)     // arquivo quebrado ou removido: sorteia outro
        }
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: root.files.length === 0 && !scanner.running
    width: parent.width - 24
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: "Nenhuma imagem encontrada"
    font.pixelSize: 12
    font.italic: true
    color: "#333333"
  }
}
