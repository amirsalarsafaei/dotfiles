import QtQuick

Item {
    id: cover

    property string wanted: Media.art
    property real mix: 0
    readonly property Image image: texture
    readonly property string shown: texture.source.toString()

    onWantedChanged: {
        reveal.stop();
        swap.restart();
    }

    SequentialAnimation {
        id: swap

        NumberAnimation {
            target: cover
            property: "mix"
            to: 0
            duration: 900
            easing.type: Easing.InOutSine
        }

        ScriptAction {
            script: {
                texture.source = cover.wanted;
                if (cover.wanted !== "" && texture.status === Image.Ready)
                    reveal.restart();
            }
        }
    }

    NumberAnimation {
        id: reveal

        target: cover
        property: "mix"
        to: 1
        duration: 2600
        easing.type: Easing.InOutSine
    }

    Image {
        id: texture

        visible: false
        asynchronous: true
        mipmap: true
        smooth: true
        sourceSize: Qt.size(512, 512)
        onStatusChanged: {
            if (status === Image.Ready && cover.wanted !== "" && !swap.running)
                reveal.restart();
        }
    }
}
