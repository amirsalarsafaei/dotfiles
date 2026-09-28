import QtQuick

ShaderEffect {
    id: aurora

    property bool running: true
    property real time: 0
    property real intensity: 1
    property vector2d resolution: Qt.vector2d(width, height)
    property color base: Theme.ink
    property color accentA: Theme.primary
    property color accentB: Theme.secondary

    fragmentShader: Qt.resolvedUrl("shaders/aurora.frag.qsb")

    FrameAnimation {
        running: aurora.running && aurora.visible
        onTriggered: aurora.time += frameTime
    }
}
