import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Window 2.15

Dialog {
    id: reviewPage
    title: qsTr('Confirm Options')
    modal: true

    onAboutToShow: {
        const opts = Object.keys(modConfigWindow.m_selections);
        choicesRepeater.model = opts;
    }

    footer: DialogButtonBox {
        Button {
            text: qsTr("Back")
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
        Button {
            text: qsTr("Install")
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
        }
    }

    Column {
        Label {
            text: qsTr('Are you satisfied with your choices?')
        }

        MenuSeparator {}

        Repeater {
            id: choicesRepeater
            delegate: Label {
                text: modConfigWindow.m_selections[ modelData ]
            }
        }
    }
}
