import Quickshell 
import QtQuick 

PanelWindow {
	width: 700; height: 300;
	color: "transparent"

	mask: Region {
        // Região principal (o que será visível)
        // Posicionada exatamente onde o retângulo vermelho está
        x: rect.x
        y: rect.y
        width: rect.width
        height: rect.height

        // A região de subtração deve ser FILHA da região acima
        Region {
            x: 40; y: 40
            width: 40; height: 40
            intersection: Intersection.Xor
        }
    }
	
	Rectangle {
		id: rect
		color: 'red'
		width: 500; height: 200;
		anchors.centerIn: parent
	}
}
