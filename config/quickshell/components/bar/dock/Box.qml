import QtQuick

// Caixa arredondada posicionada pela grade (BoxGrid).
Rectangle {
  id: box

  // ================= POSIÇÃO NA GRADE =================
  property int col: 0
  property int row: 0
  property int colSpan: 1
  property int rowSpan: 1
  // ====================================================

  property real padding: 12                // folga interna

  readonly property var grid: parent ? parent.grid : null

  default property alias content: inner.data

  x: grid ? grid.cellX(col) : 0
  y: grid ? grid.cellY(row) : 0
  width: grid ? grid.spanW(colSpan) : 0
  height: grid ? grid.spanH(rowSpan) : 0

  radius: grid ? grid.boxRadius : 16
  color: grid ? grid.boxColor : "gray"

  Item {
    id: inner
    anchors.fill: parent
    anchors.margins: box.padding
    clip: true
  }
}
