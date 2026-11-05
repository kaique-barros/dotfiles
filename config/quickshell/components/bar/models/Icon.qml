// models/Icon.qml
import Quickshell
import QtQuick
import QtQuick.Effects

Item {
  id: root
  property url source
  property color color: "white"
  property real size: 24

  implicitWidth: size
  implicitHeight: size

  Image {
    id: img
    anchors.fill: parent
    source: root.source
    fillMode: Image.PreserveAspectFit
    // renderiza o SVG no tamanho real (2x para telas HiDPI), senão fica borrado
    sourceSize: Qt.size(root.width * 2, root.height * 2)
    smooth: true
    visible: false            // quem aparece é o MultiEffect
    layer.enabled: true       // necessário para o efeito usar o item
  }

  MultiEffect {
    anchors.fill: img
    source: img
    brightness: 1.0           // clareia tudo para branco puro
    colorization: 1.0         // aplica a cor por cima
    colorizationColor: root.color
  }
}
