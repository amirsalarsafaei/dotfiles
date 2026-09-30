import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

ClippingRectangle {
    id: frost

    property Item backdrop: null
    property real sync: 0
    property real tint: 0.34
    readonly property int pad: 40

    radius: height / 2
    color: Theme.ink
    border.color: Theme.alpha(Theme.fgBright, 0.1)
    border.width: 1

    ShaderEffectSource {
        id: region

        visible: false
        live: true
        sourceItem: frost.backdrop
        sourceRect: {
            frost.sync;
            frost.x;
            frost.y;
            if (!frost.backdrop)
                return Qt.rect(0, 0, 0, 0);
            const at = frost.mapToItem(frost.backdrop, -frost.pad, -frost.pad);
            return Qt.rect(at.x, at.y, frost.width + 2 * frost.pad, frost.height + 2 * frost.pad);
        }
    }

    MultiEffect {
        x: -frost.pad
        y: -frost.pad
        width: frost.width + 2 * frost.pad
        height: frost.height + 2 * frost.pad
        visible: frost.backdrop !== null
        source: region
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 48
        saturation: 0.15
    }

    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.alpha(Theme.ink, frost.tint * 0.6)
            }

            GradientStop {
                position: 1
                color: Theme.alpha(Theme.ink, frost.tint)
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.round(parent.width * 0.62)
        height: 1

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: Theme.alpha(Theme.fgBright, 0)
            }

            GradientStop {
                position: 0.5
                color: Theme.alpha(Theme.fgBright, 0.2)
            }

            GradientStop {
                position: 1
                color: Theme.alpha(Theme.fgBright, 0)
            }
        }
    }
}
