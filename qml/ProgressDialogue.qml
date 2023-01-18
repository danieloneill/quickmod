import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Dialog {
    id: progressPage
    title: qsTr('Downloading...')
    modal: true

    property alias text: label.text
    property int to: 0
    property int value: 0
    property bool showCancel: true
    property variant queue: []

    signal cancel()
    signal cancelAll()

    ColumnLayout {
        spacing: 10

        Label {
            id: label
            ColumnLayout.minimumWidth: mainWin.width * 0.33
        }

        ProgressBar {
            id: progress
            ColumnLayout.fillWidth: true
            indeterminate: progressPage.value === progressPage.to
            from: 0.0
            to: 1.0
            value: progressPage.to <= 0 ? 0 : progressPage.value / progressPage.to;
        }

        Label {
            visible: !progress.indeterminate
            ColumnLayout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: parseInt(progressPage.value) + " / " + parseInt(progressPage.to)
        }

        MenuSeparator {
            ColumnLayout.fillWidth: true
            visible: progressPage.queue.length > 0
        }

        Label {
            visible: progressPage.queue.length > 0
            ColumnLayout.fillWidth: true
            leftPadding: 10
            horizontalAlignment: Text.AlignLeft
            text: qsTr("%1 additional %2 in queue...").arg(progressPage.queue.length).arg(progressPage.queue.length === 1 ? 'download' : 'downloads')

            MouseArea {
                hoverEnabled: true
                anchors.fill: parent

                ToolTip.visible: containsMouse
                ToolTip.text: qsTr('%1 %2 in queue:\n%3').arg(progressPage.queue.length).arg(progressPage.queue.length === 1 ? 'download' : 'downloads').arg(progressPage.queue.map(e => e.length > 50 ? e.substring(0, 20)+'...'+e.substring(e.length-30) : e).join('\n'))
            }
        }

        MenuSeparator {
            ColumnLayout.fillWidth: true
            visible: progressPage.showCancel
        }

        Row {
            spacing: 10
            visible: progressPage.showCancel
            Button {
                text: qsTr('Cancel')
                onClicked: {
                    progressPage.cancel();
                }
            }

            Button {
                visible: progressPage.showCancel && progressPage.queue.length > 0
                text: qsTr('Cancel All')
                onClicked: {
                    progressPage.cancelAll();
                }
            }
        }
    }
}
