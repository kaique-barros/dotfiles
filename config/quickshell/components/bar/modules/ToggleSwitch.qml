import QtQuick

Rectangle {
  id: root
  property bool checked: false
  signal toggled()

  implicitWidth: 34
  implicitHeight: 18
  radius: height / 2
  color: checked ? "#12b76a" : "#d0d5dd"
  Behavior on color { ColorAnimation { duration: 120 } }

  Rectangle {
    width: root.height - 4
    height: width
    radius: width / 2
    y: 2
    x: root.checked ? root.width - width - 2 : 2
    color: "white"
    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
