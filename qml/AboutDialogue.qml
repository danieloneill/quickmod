import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Dialog {
    id: aboutPage
    title: qsTr('About Quickmod')
    modal: true

    footer: DialogButtonBox {
        Button {
            text: qsTr("Close")
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
    }

    Item {
        implicitHeight: aboutText.implicitHeight + 20
        implicitWidth: aboutText.implicitWidth + 20
        TextArea {
            id: aboutText
            anchors.fill: parent
            readOnly: true
            textFormat: Text.RichText
            onLinkActivated: function(url) {
                Qt.openUrlExternally(url);
            }

            ToolTip.visible: hoveredLink && hoveredLink.length > 0
            ToolTip.text: qsTr("Open URL in browser...")
        }
    }

    Component.onCompleted: aboutText.text = File.read("../about.html");
}
