import QtQuick
import QtQuick.Shapes

// quadrado r×r com a curva côncava; "corner" é o canto SÓLIDO (tl, tr, bl, br)
Shape {
  id: f
  property color color: "white"
  property real r: 20
  property string corner: "tl"

  readonly property bool fx: corner === "tr" || corner === "br"
  readonly property bool fy: corner === "bl" || corner === "br"

  width: r
  height: r
  preferredRendererType: Shape.CurveRenderer

  ShapePath {
    fillColor: f.color
    strokeColor: "transparent"

    startX: f.fx ? f.r : 0
    startY: f.fy ? f.r : 0
    PathLine { x: f.fx ? 0 : f.r; y: f.fy ? f.r : 0 }
    PathArc {
      x: f.fx ? f.r : 0
      y: f.fy ? 0 : f.r
      radiusX: f.r; radiusY: f.r
      direction: f.fx !== f.fy ? PathArc.Clockwise : PathArc.Counterclockwise
    }
    PathLine { x: f.fx ? f.r : 0; y: f.fy ? f.r : 0 }
  }
}
