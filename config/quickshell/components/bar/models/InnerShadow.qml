import QtQuick
import QtQuick.Effects

Item {
  id: root
  property real radius: 2
  property real size: 1                // espessura da sombra
  property color color: "black"
  property real strength: 0.3

  readonly property real m: size * 3 + 2   // folga para o blur não desbotar a borda

  // 2) recorta tudo pela forma arredondada
  layer.enabled: true
  layer.effect: MultiEffect {
    maskEnabled: true
    maskSource: clipMask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1
  }

  Item {
    id: clipMask
    anchors.fill: parent
    layer.enabled: true
    visible: false
    Rectangle { anchors.fill: parent; radius: root.radius }
  }

  // 1) anel escuro maior que o item, desfocado
  Item {
    anchors.fill: parent
    anchors.margins: -root.m
    layer.enabled: true
    layer.effect: MultiEffect {
      blurEnabled: true
      blurMax: 16
      blur: Math.min(1, root.size / 8)
    }

    Rectangle {
      anchors.fill: parent
      color: "transparent"
      radius: root.radius + root.m
      border.width: root.m + root.size
      border.color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.strength)
    }
  }
}
