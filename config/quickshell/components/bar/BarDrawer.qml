import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Item {
  id: barDrawer
  anchors.fill: parent

  FileView {
    id: dockStateFile
    path: "/tmp/quickshell_dock_active"
    watchChanges: true
    onFileChanged: dockActive = !dockActive
  }

  property color frameColor: "white"
  required property var canva
  property bool dockActive: false 
  property int dockSize: dockActive ? 650 : 0
  property int animationTime: 250

  Behavior on dockSize {
    NumberAnimation {
      duration: animationTime
      easing.type: barDrawer.dockActive ? Easing.OutCubic : Easing.InCubic
    }
  }

  layer.enabled: true
  layer.effect: MultiEffect {
    maskEnabled: true
    maskInverted: true
    maskSource: holeMask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1
  }

  // a moldura em si (faltava isso)
  Rectangle {
    anchors.fill: parent
    color: barDrawer.frameColor
  }

  Item {
    id: holeMask
    anchors.fill: parent
    layer.enabled: true
    visible: false

    Rectangle {
      color: "white"
      x: canva.leftSize + dockSize
      y: canva.topSize
      width: canva.width - canva.leftSize - canva.rightSize - dockSize
      height: canva.height - canva.topSize - canva.bottomSize
      topLeftRadius: (canva.topSize > 0 || canva.leftSize > 0) ? canva.internalRadius : 0
      topRightRadius: (canva.topSize > 0 || canva.rightSize > 0) ? canva.internalRadius : 0
      bottomLeftRadius: (canva.bottomSize > 0 || canva.leftSize > 0) ? canva.internalRadius : 0
      bottomRightRadius: (canva.bottomSize > 0 || canva.rightSize > 0) ? canva.internalRadius : 0
    }
  }
}
