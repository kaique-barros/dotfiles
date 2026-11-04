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

  required property var canva
  property color frameColor: canva.frameColor
  property bool dockActive: false 
  property int dockSize: dockActive ? canva.dockSize : 0
  property int animationTime: canva.animationTime
  property url splatterSource: canva.splatterSource
  property real splatterOpacity: canva.splatterOpacity

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

  Image {
    anchors.fill: parent
    source: barDrawer.splatterSource
    fillMode: Image.Tile
    opacity: barDrawer.splatterOpacity
    smooth: true
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
