import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Dialog {
    id: overwritePage
    title: qsTr('Overwrite')
    modal: true

    property variant overwrites: []

    ColumnLayout {
        spacing: 10

        Label {
            id: label
            ColumnLayout.minimumWidth: mainWin.width * 0.33
        }

        Component {
            id: overwriteOptionComponent
            GridLayout {
                columns: 2

                Label {
                    text: tr('Source:')
                }
                Label {
                    text: modelData.sourceFile
                }

                Label {
                    text: tr('Destination:')
                }
                Label {
                    text: modelData.destinationFile
                }


            }
        }
    }
}
