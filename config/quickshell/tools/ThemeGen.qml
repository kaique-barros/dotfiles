import QtQuick
import Quickshell
import Quickshell.Io

// Roda o ColorQuantizer nos prints e chama o make_theme.py para escrever themes/<id>.json.
// Não é aberto direto: use tools/gen-themes.sh, que prepara as variáveis de ambiente.
ShellRoot {
  id: root

  readonly property string themesDir: Quickshell.env("THEMES_DIR") || ""
  readonly property string workshopDir: Quickshell.env("WORKSHOP_DIR") || ""
  readonly property string maker: Quickshell.env("MAKE_THEME") || ""
  readonly property bool force: Quickshell.env("FORCE") === "1"
  readonly property int depth: parseInt(Quickshell.env("QUANT_DEPTH") || "3")   // 2^depth cores
  readonly property int rescale: 128                                              // reduz o print antes de quantizar

  // "id<TAB>caminho" por linha
  readonly property var jobs: (Quickshell.env("TODO") || "").split("\n")
    .filter(l => l.indexOf("\t") > 0)
    .map(l => ({ id: l.split("\t")[0], path: l.split("\t").slice(1).join("\t") }))

  property int pending: jobs.length
  property var failedIds: []

  function hex(c) {
    const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2)
    return "#" + h(c.r) + h(c.g) + h(c.b)
  }

  function jobDone(id, ok) {
    if (!ok) failedIds = failedIds.concat([id])
    pending--
    if (pending <= 0) finish()
  }

  function finish() {
    if (failedIds.length > 0) console.log("[theme] falhou:", failedIds.join(", "))
    console.log("[theme] pronto")
    Qt.quit()
  }

  Component.onCompleted: if (jobs.length === 0) finish()

  // se algum print não carregar, não fica esperando para sempre
  Timer {
    interval: 120000
    running: root.jobs.length > 0
    onTriggered: {
      console.log("[theme] tempo esgotado; sem resposta de", root.pending, "print(s)")
      root.finish()
    }
  }

  Instantiator {
    model: root.jobs

    delegate: Scope {
      id: job
      required property var modelData
      property bool started: false

      function check() {
        if (started || quant.colors.length === 0) return
        started = true
        const hexes = []
        for (let i = 0; i < quant.colors.length; i++) hexes.push(root.hex(quant.colors[i]))
        gen.command = [
          "python3", root.maker,
          "--id", job.modelData.id,
          "--shot", job.modelData.path,
          "--themes", root.themesDir,
          "--workshop", root.workshopDir,
          "--colors", hexes.join(",")
        ].concat(root.force ? ["--force"] : [])
        gen.running = true
      }

      ColorQuantizer {
        id: quant
        source: "file://" + job.modelData.path.split("/").map(encodeURIComponent).join("/")
        depth: root.depth
        rescaleSize: root.rescale
        onColorsChanged: job.check()
      }

      Process {
        id: gen
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log(text.trim()) }
        onExited: (exitCode, exitStatus) => root.jobDone(job.modelData.id, exitCode === 0)
      }

      Component.onCompleted: job.check()
    }
  }
}
