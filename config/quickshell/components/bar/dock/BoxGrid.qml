import QtQuick

// Grade de controle da página: as caixas (Box) dizem em quais células ficam.
Item {
  id: root

  // ================= CONFIGURAÇÕES =================
  property int columns: 6
  property int rows: 11
  property real spacing: 10                // espaço entre as caixas

  // margens individuais da grade
  property real marginTop: 0
  property real marginBottom: 0
  property real marginLeft: 0
  property real marginRight: 0

  property color boxColor: "gray"          // cor das caixas (passe canva.itemFillColor)
  property real boxRadius: 16

  // guia visual da grade (só para organizar)
  property bool showGrid: false
  property color gridColor: "#55000000"
  property color gridLabelColor: "#88000000"
  // =================================================

  readonly property real cellW: (width - marginLeft - marginRight - (columns - 1) * spacing) / columns
  readonly property real cellH: (height - marginTop - marginBottom - (rows - 1) * spacing) / rows

  function cellX(c) { return marginLeft + c * (cellW + spacing) }
  function cellY(r) { return marginTop + r * (cellH + spacing) }
  function spanW(n) { return n * cellW + (n - 1) * spacing }
  function spanH(n) { return n * cellH + (n - 1) * spacing }

  default property alias content: area.data

  // guia: uma célula por quadrado, com "col,row"
  Item {
    anchors.fill: parent
    visible: root.showGrid

    Repeater {
      model: root.columns * root.rows

      delegate: Rectangle {
        required property int index
        readonly property int c: index % root.columns
        readonly property int r: Math.floor(index / root.columns)

        x: root.cellX(c)
        y: root.cellY(r)
        width: root.cellW
        height: root.cellH
        color: "transparent"
        radius: 6
        border.color: root.gridColor
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: parent.c + "," + parent.r
          font.pixelSize: 10
          color: root.gridLabelColor
        }
      }
    }
  }

  // as caixas ficam aqui
  Item {
    id: area
    anchors.fill: parent
    readonly property var grid: root
  }
}
