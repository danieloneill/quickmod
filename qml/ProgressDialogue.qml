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
            ColumnLayout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: parseInt(progressPage.value) + " / " + parseInt(progressPage.to)
        }
    }
}
