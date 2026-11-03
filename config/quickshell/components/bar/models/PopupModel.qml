import QtQuick

Item {
  id: root

  // ---------- API ----------
  required property var bar              // a PanelWindow (canva): topSize, bottomSize, leftSize, rightSize, internalRadius
  required property string edge          // "left" | "right" | "top" | "bottom"
  required property color frameColor

  property real pos: 0                   // início ao longo da barra, em coords da janela (y se left/right, x se top/bottom)
  property int popupWidth: 300
  property int popupHeight: 180
  property bool open: false
  property int padding: 12
  property int cornerRadius: canva.internalRadius          // cantos externos (convexos)
  property int filletRadius: bar.internalRadius   // junções (côncavas)

  property var peerStart: null           // popup vizinho ANTES deste na mesma barra
  property var peerEnd: null             // popup vizinho DEPOIS deste na mesma barra

  property int offset: 0
  property int animationTime: 250

  readonly property bool hovered: hoverHandler.hovered
  HoverHandler { id: hoverHandler }
  default property alias content: contentArea.data

  // ---------- geometria base ----------
  readonly property bool vertical: edge === "left" || edge === "right"
  readonly property real r: filletRadius
  readonly property real rr: cornerRadius

  readonly property real startBar: vertical ? bar.topSize : bar.leftSize
  readonly property real endBar: vertical ? bar.bottomSize : bar.rightSize
  readonly property real aMin: startBar
  readonly property real aMax: (vertical ? bar.height : bar.width) - endBar
  readonly property real maxDepth: vertical ? bar.width - bar.leftSize - bar.rightSize
                                            : bar.height - bar.topSize - bar.bottomSize

  readonly property real targetDepth: Math.max(0, Math.min(vertical ? popupWidth : popupHeight, maxDepth))
  readonly property real span0: Math.max(0, Math.min(vertical ? popupHeight : popupWidth, aMax - aMin))

  property real depth: open ? targetDepth : 0
  Behavior on depth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  readonly property bool shown: depth > 0.5

  // ---------- 1) posição: peer + clamp + snap ----------
  // empurra para baixo do vizinho anterior; se o vão for < 2r, cola nele (fusão)
  readonly property real wantedStart: {
    if (!!peerStart && peerStart.shown && pos < peerStart.alongEnd + 2 * r)
      return peerStart.alongEnd
    return pos
  }
  readonly property real rawStart: Math.max(aMin, Math.min(aMax - span0, wantedStart))

  // sobra menos que r até uma barra: não cabe fillet, então cola
  readonly property bool nearStart: rawStart - aMin < r
  readonly property bool nearEnd: aMax - (rawStart + span0) < r
  readonly property bool fill: nearStart && nearEnd

  readonly property real span: Math.round(fill ? aMax - aMin : span0)
  readonly property real alongStart: Math.round(fill ? aMin
                                    : nearStart ? aMin
                                    : nearEnd ? aMax - span
                                    : rawStart)
  readonly property real alongEnd: alongStart + span

  // ---------- 2) o que tem em cada ponta ----------
  readonly property bool fusedStart: !!peerStart && peerStart.shown && Math.abs(alongStart - peerStart.alongEnd) < 1
  readonly property bool fusedEnd: !!peerEnd && peerEnd.shown && Math.abs(alongEnd - peerEnd.alongStart) < 1

  // "free" | "bar" (encostou numa barra) | "screen" (encostou na borda sem barra) | "peer" (fundido)
  readonly property string startKind: fusedStart ? "peer"
        : alongStart - aMin < 1 ? (startBar > 0 ? "bar" : "screen") : "free"
  readonly property string endKind: fusedEnd ? "peer"
        : aMax - alongEnd < 1 ? (endBar > 0 ? "bar" : "screen") : "free"

  readonly property real diffStart: fusedStart ? targetDepth - peerStart.targetDepth : 0
  readonly property real diffEnd: fusedEnd ? targetDepth - peerEnd.targetDepth : 0

  // canto externo: raio convexo e/ou fillet côncavo
  function outerCorner(kind, diff) {
    const maxR = Math.min(depth, span) / 2
    if (kind === "free")
      return { radius: Math.min(rr, maxR), fillet: 0 }
    if (kind === "bar")
      return { radius: 0, fillet: Math.round(Math.min(r, depth)) }
    if (kind === "peer") {
      if (diff > 1)  return { radius: Math.min(rr, diff, maxR), fillet: 0 }          // mais fundo: arredonda
      if (diff < -1) return { radius: 0, fillet: Math.round(Math.min(r, -diff)) }    // mais raso: fillet no degrau
      return { radius: 0, fillet: 0 }                                                // mesma profundidade: reto
    }
    return { radius: 0, fillet: 0 }                                                  // screen
  }
  readonly property var outerStart: outerCorner(startKind, diffStart)
  readonly property var outerEnd: outerCorner(endKind, diffEnd)

  // junção com a parede da barra: só existe quando a ponta está livre
  readonly property real wallStartFillet: startKind === "free" ? Math.round(Math.min(r, depth)) : 0
  readonly property real wallEndFillet: endKind === "free" ? Math.round(Math.min(r, depth)) : 0

  // ---------- mapeamento para os cantos da tela ----------
  readonly property var slots: ({
    left:   { os: "tr", oe: "br" },
    right:  { os: "tl", oe: "bl" },
    top:    { os: "bl", oe: "br" },
    bottom: { os: "tl", oe: "tr" }
  })[edge]

  function radiusAt(c) {
    return slots.os === c ? outerStart.radius : slots.oe === c ? outerEnd.radius : 0
  }

  // posição e canto sólido de cada fillet (coords locais; ficam FORA do corpo)
  function place(slot, f) {
    const w = width, h = height
    if (vertical) {
      const left = edge === "left"
      switch (slot) {
        case "ws": return left ? { x: 0,   y: -f,  c: "bl" } : { x: w - f, y: -f,  c: "br" }
        case "we": return left ? { x: 0,   y: h,   c: "tl" } : { x: w - f, y: h,   c: "tr" }
        case "os": return left ? { x: w,   y: 0,   c: "tl" } : { x: -f,    y: 0,   c: "tr" }
        default:   return left ? { x: w,   y: h-f, c: "bl" } : { x: -f,    y: h-f, c: "br" }
      }
    }
    const top = edge === "top"
    switch (slot) {
      case "ws": return top ? { x: -f,  y: 0,   c: "tr" } : { x: -f,  y: h - f, c: "br" }
      case "we": return top ? { x: w,   y: 0,   c: "tl" } : { x: w,   y: h - f, c: "bl" }
      case "os": return top ? { x: 0,   y: h,   c: "tl" } : { x: 0,   y: -f,    c: "bl" }
      default:   return top ? { x: w-f, y: h,   c: "tr" } : { x: w-f, y: -f,    c: "br" }
    }
  }
  readonly property var pWS: place("ws", wallStartFillet)
  readonly property var pWE: place("we", wallEndFillet)
  readonly property var pOS: place("os", outerStart.fillet)
  readonly property var pOE: place("oe", outerEnd.fillet)

  // ---------- posição final do corpo na janela ----------
  readonly property int d: Math.round(depth)

  // Se edge for "left", soma o offset (move para a direita). Se for "right", subtrai (move para a esquerda).
  x: edge === "left" ? bar.leftSize + offset
   : edge === "right" ? bar.width - bar.rightSize - d - offset
   : alongStart

  // Se edge for "top", soma o offset (move para baixo). Se for "bottom", subtrai (move para cima).
  y: edge === "top" ? bar.topSize + offset
   : edge === "bottom" ? bar.height - bar.bottomSize - d - offset
   : alongStart

  width: vertical ? d : span
  height: vertical ? span : d
  visible: shown

  // ---------- visual ----------
  Rectangle {
    anchors.fill: parent
    color: root.frameColor
    topLeftRadius: root.radiusAt("tl")
    topRightRadius: root.radiusAt("tr")
    bottomLeftRadius: root.radiusAt("bl")
    bottomRightRadius: root.radiusAt("br")
  }

  Fillet { visible: root.wallStartFillet > 0.5; color: root.frameColor; r: root.wallStartFillet
           x: root.pWS.x; y: root.pWS.y; corner: root.pWS.c }
  Fillet { visible: root.wallEndFillet > 0.5;   color: root.frameColor; r: root.wallEndFillet
           x: root.pWE.x; y: root.pWE.y; corner: root.pWE.c }
  Fillet { visible: root.outerStart.fillet > 0.5; color: root.frameColor; r: root.outerStart.fillet
           x: root.pOS.x; y: root.pOS.y; corner: root.pOS.c }
  Fillet { visible: root.outerEnd.fillet > 0.5;   color: root.frameColor; r: root.outerEnd.fillet
           x: root.pOE.x; y: root.pOE.y; corner: root.pOE.c }

  // conteúdo (pode ficar vazio por enquanto)
  Item {
    id: contentArea
    anchors.fill: parent
    anchors.margins: root.padding
    clip: true
  }

  Behavior on x {
    NumberAnimation { duration: animationTime; easing.type: barDrawer.dockActive ? Easing.OutCubic : Easing.InCubic }
  }
  Behavior on y {
    NumberAnimation { duration: animationTime; easing.type: barDrawer.dockActive ? Easing.OutCubic : Easing.InCubic }
  }
}
