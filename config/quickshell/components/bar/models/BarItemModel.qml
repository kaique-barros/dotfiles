import QtQuick

Slot {
  id: root

  // ---- moldura ----
  property bool framed: false
  property real inset: 6                  // folga entre a barra e a "pílula"
  property real frameRadius: 100
  property real frameSize: 2
  property color frameColor: "black"
  property color fillColor: "transparent"
  property real padding: 4

  // ---- popup ----
  property var popup: null                // o BarPopup (mesmo edge do item)
  property string trigger: "click"        // "click" | "hover"
  property string popupAlign: "center"    // "start" | "center" | "end"
  property int hoverCloseDelay: 150

  default property alias content: contentArea.data

  // ---- medidas derivadas (seguem o tamanho da barra) ----
  readonly property real innerThickness: Math.max(0, thickness - 2 * inset)
  readonly property real innerLength: Math.max(0, length - 2 * inset)
  readonly property real contentThickness: Math.max(0, innerThickness - 2 * padding)
  readonly property real contentLength: Math.max(0, innerLength - 2 * padding)
  readonly property real effectiveRadius:
      Math.min(frameRadius, innerThickness / 2, innerLength / 2)

  // ---- controle do popup ----
  readonly property bool popupOpen: popup !== null && popup.open

  function openPopup()   { if (popup) popup.open = true }
  function closePopup()  { if (popup) popup.open = false }
  function togglePopup() { if (popup) popup.open = !popup.open }

  signal clicked()

  // posição do popup, alinhada a este item (ao longo da barra)
  readonly property real popupSpan:
      popup === null ? 0 : (vertical ? popup.popupHeight : popup.popupWidth)
  readonly property real popupPos:
      popupAlign === "start" ? along
    : popupAlign === "end"   ? along + length - popupSpan
    :                          along + (length - popupSpan) / 2

  Binding {
    target: root.popup
    property: "pos"
    value: root.popupPos
    when: root.popup !== null
    restoreMode: Binding.RestoreNone
  }

  Component.onCompleted: {
    if (popup && popup.edge !== edge)
      console.warn("BarItem: popup está em '" + popup.edge + "' mas o item está em '" + edge + "'")
  }

  // ---- gatilhos ----
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true // Permite capturar o hover se precisar

    onClicked: {
      root.clicked()
      root.togglePopup()
      console.log("MouseArea clicada com sucesso!", Date.now())
    }

    onEntered: {
      if (root.trigger === "hover") {
        closeTimer.stop()
        openPopup()
      }
    }

    onExited: {
      if (root.trigger === "hover") {
        closeTimer.restart()
      }
    }
  }

  Timer {
    id: closeTimer
    interval: root.hoverCloseDelay
    onTriggered: root.closePopup()
  }

  // ---- visual ----
  Item {
    id: pill
    anchors.fill: parent
    anchors.margins: root.inset

    Rectangle {
      anchors.fill: parent
      radius: root.effectiveRadius
      color: root.fillColor
    }

    InnerShadow {
      anchors.fill: parent
      visible: root.framed
      radius: root.effectiveRadius
      size: root.frameSize
      color: root.frameColor
    }

    Item {
      id: contentArea
      anchors.fill: parent
      anchors.margins: root.padding
      clip: true
    }
  }
}
