import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

import "../theme"

// Fundo do overview do niri (Mod+Tab): o screenshot do wallpaper do tema atual, desfocado.
// É uma janela layer-shell na camada Background; o niri a coloca só no "backdrop" do overview por causa do
// layer-rule `place-within-backdrop` no config.kdl (namespace "quickshell-overview-backdrop"). No dia a dia
// ela não aparece: quem fica atrás das janelas continua sendo o linux-wallpaperengine.
Scope {
  id: root

  // ================= CONFIGURAÇÕES =================
  property real blurAmount: 1.0        // 0 a 1 (intensidade do desfoque)
  property int blurMax: 64             // raio máximo do desfoque, em px
  property real dim: 0.35              // 0 a 1: escurece por cima, para os cartões das workspaces se destacarem
  // =================================================

  readonly property string source: {
    const p = Theme.expand(Theme.screenshot)
    return p !== "" ? "file://" + p.split("/").map(encodeURIComponent).join("/") : ""
  }

  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      required property var modelData
      screen: modelData

      anchors { top: true; bottom: true; left: true; right: true }
      color: "black"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.namespace: "quickshell-overview-backdrop"

      Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        visible: false
      }

      MultiEffect {
        anchors.fill: parent
        // um pouco maior que a tela, para o desfoque não clarear nas bordas
        anchors.margins: -root.blurMax
        source: img
        blurEnabled: true
        blur: root.blurAmount
        blurMax: root.blurMax
        autoPaddingEnabled: false
      }

      Rectangle { anchors.fill: parent; color: "black"; opacity: root.dim }
    }
  }
}
