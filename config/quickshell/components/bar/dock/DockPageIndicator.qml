import QtQuick

Item {
  id: root

  property int pageCount: 3
  property int currentPage: 0
  signal pageSelected(int index)

  width: 24
  implicitHeight: col.implicitHeight

  Column {
    id: col
    anchors.centerIn: parent
    spacing: 8

    Repeater {
      model: root.pageCount

      delegate: Item {
        id: dotItem
        required property int index
        readonly property bool isCurrent: index === root.currentPage

        width: 24
        height: isCurrent ? 28 : 10
        Behavior on height {
          NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Rectangle {
          id: dot
          anchors.centerIn: parent
          width: dotItem.isCurrent ? 8 : 8
          height: dotItem.isCurrent ? 26 : 8
          radius: 4
          color: dotItem.isCurrent ? "#11111b" : "#98a2b3"

          Behavior on height {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
          }
          Behavior on color {
            ColorAnimation { duration: 150 }
          }
        }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          cursorShape: Qt.PointingHandCursor
          onClicked: root.pageSelected(dotItem.index)
        }
      }
    }
  }

  // Roda do mouse no indicador alterna as páginas
  WheelHandler {
    onWheel: (wheel) => {
      if (wheel.angleDelta.y < 0) {
        root.pageSelected(Math.min(root.pageCount - 1, root.currentPage + 1))
      } else {
        root.pageSelected(Math.max(0, root.currentPage - 1))
      }
    }
  }
}
