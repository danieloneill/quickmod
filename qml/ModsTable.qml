import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

import Qt.labs.qmlmodels 1.0

Item {
    id: modsTable

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
        x: 0-modsList.contentX
        height: 32
        width: implicitWidth > parent.width ? implicitWidth * 2 : parent.width * 2

        readonly property variant preferredWidths: [ 16, header.width*0.2, header.width*0.1, header.width*0.1, header.width*0.4, header.width*0.2, 16 ]

        Repeater {
            id: headerRepeater
            model: [ qsTr(''), qsTr('Name'), qsTr('Author'), qsTr('Version'), qsTr('Description'), qsTr('Website'), qsTr('') ]
            Label {
                SplitView.minimumWidth: 24
                text: modelData
                verticalAlignment: Text.AlignVCenter
                onWidthChanged: modsList.forceLayout();
                font.pointSize: 10
                font.bold: true
                leftPadding: 5
            }
        }

        Component.onCompleted: {
            try {
                if( settings.modListColumnSizes )
                {
                    header.restoreState( settings.modListColumnSizes );
                    modsList.forceLayout();
                    return;
                }
            } catch(err) {
                console.log("Couldn't restore column widths. Oh well.");
            }

            for( let sidx=0; sidx < headerRepeater.count; sidx++ )
                headerRepeater.itemAt(sidx).width = preferredWidths[sidx] || 32;
            modsList.forceLayout();
        }
        Component.onDestruction: {
            settings.modListColumnSizes = header.saveState();
        }
    }

    ScrollView {
        id: scrollView
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        TableView {
            id: modsList

            clip: true
            //boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                implicitHeight: model.column === 0 ? cellEnabled.height : cellText.implicitHeight + 15
                implicitWidth: model.column === 0 ? cellEnabled.width : cellText.implicitWidth
                clip: true

                color: (model.row % 2) === 0 ? Material.background : Qt.darker(Material.background, 1.20)

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
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 5
                    width: parent.width
                    height: parent.height
                    elide: Text.ElideRight
                    maximumLineCount: 1

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
                            onTriggered: reinstallMod(cellMenu.modent);
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
                return headerRepeater.itemAt(col).width + 5;
            }

            columnSpacing: 0
            rowSpacing: 0
        } // TableView
    } // ScrollView
}
