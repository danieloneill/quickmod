import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

import Qt.labs.qmlmodels 1.0

ColumnLayout {
    id: modsTable
    spacing: 0

    //property alias header: header

    property var model: []
    signal installMod(variant mod)
    signal uninstallMod(variant mod)
    signal enableMod(variant mod)
    signal disableMod(variant mod)
    signal reinstallMod(variant mod)
    signal deleteMod(variant mod)

    SplitView {
        id: header
        Layout.fillWidth: true
        Layout.minimumHeight: 24
        readonly property variant preferredWidth: [ 16, header.width*0.2, header.width*0.1, header.width*0.1, header.width*0.4, header.width*0.2 ]

        Repeater {
            id: headerRepeater
            model: [ qsTr(''), qsTr('Name'), qsTr('Author'), qsTr('Version'), qsTr('Description'), qsTr('Website') ]
            Label {
                SplitView.minimumWidth: 24
                text: modelData
                verticalAlignment: Text.AlignVCenter
                onWidthChanged: modsList.forceLayout();
                font.pointSize: 10
                font.bold: true
            }
        }

        Component.onCompleted: {
            try {
                header.restoreState( settings.modListColumnSizes );
            } catch(err) {
                console.log("Couldn't restore column widths. Oh well.");
            }
        }
        Component.onDestruction: {
            settings.modListColumnSizes = header.saveState();
        }
    }

    TableView {
        id: modsList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            implicitHeight: model.column === 0 ? cellEnabled.height : cellText.implicitHeight
            implicitWidth: model.column === 0 ? cellEnabled.width : cellText.implicitWidth
            clip: true

            Rectangle {
                id: cellEnabled
                visible: model.column === 0

                readonly property var modent: modsTable.model[model.row]
                radius: 90
                color: modent ? ( modent['installed'] ? ( modsTable.model[model.row]['enabled'] ? 'green' : 'red' ) : 'gray' ) : ''
                anchors.centerIn: parent
                height: 12
                width: 12
            }

            Label {
                id: cellText
                visible: model.column !== 0
                text: model.modelData

                Menu {
                    id: cellMenu
                    readonly property var modent: modsTable.model[model.row]
                    MenuItem {
                        text: cellMenu.modent && cellMenu.modent['installed'] ? qsTr('Uninstall') : qsTr('Install')
                        onTriggered: {
                            if( cellMenu.modent['installed'] )
                                uninstallMod(cellMenu.modent);
                            else
                                installMod(cellMenu.modent);
                        }
                    }
                    MenuItem {
                        text: cellMenu.modent && cellMenu.modent['enabled'] ? qsTr('Disable') : qsTr('Enable')
                        enabled: cellMenu.modent && cellMenu.modent['installed'] ? true:false
                        onTriggered: {
                            if( !cellMenu.modent['enabled'] )
                                enableMod(cellMenu.modent);
                            else
                                disableMod(cellMenu.modent);
                        }
                    }
                    MenuItem {
                        text: qsTr('Delete')
                        onTriggered: deleteMod(cellMenu.modent);
                    }
                    MenuItem {
                        text: qsTr('Reinstall')
                        enabled: cellMenu.modent && cellMenu.modent['installed'] ? true:false
                        onTriggered: reinstalLMod(cellMenu.modent);
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(ev) {
                        if( Qt.RightButton === ev.button )
                            cellMenu.popup();
                    }
                }
            }
        }

        model: TableModel {
            TableModelColumn { display: "enabled" }
            TableModelColumn { display: "name" }
            TableModelColumn { display: "author" }
            TableModelColumn { display: "version" }
            TableModelColumn { display: "description" }
            TableModelColumn { display: "website" }
            rows: model
        }

        columnWidthProvider: function(col) {
            return headerRepeater.itemAt(col).width;
        }

        columnSpacing: 5
        rowSpacing: 5
    }
}
