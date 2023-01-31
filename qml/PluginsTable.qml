import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

import QtQml.Models 2.15

Item {
    id: pluginsTable

    signal enableMod(variant mod)
    signal disableMod(variant mod)

    signal writeRequested(variant plugins)

    ListModel {
        id: pluginsModel
        dynamicRoles: true
        function some( scb )
        {
            for( let a=0; a < count; a++ )
            {
                const ment = get(a);
                if( scb(ment) )
                    return a;
            }
            return false;
        }
    }

    function setModel(newModel)
    {
        // Remove old:
        for( let i=0; i < pluginsModel.count; i++ )
        {
            const midx = i; //dmodel.items.get(i).model.index;
            const me = pluginsModel.get(midx);
            if( newModel.some( ne => ne['filename'] === me['filename'] ) )
                continue;

            //console.log(` --- ${JSON.stringify(me)}`);
            pluginsModel.remove(midx);
            i--;
            continue;
        }

        // Insert new:
        for( let j=0; j < newModel.length; j++ )
        {
            const ne = newModel[j];
            let pos = pluginsModel.some( me => ne['filename'] === me['filename'] );
            if( pos !== false )
            {
                // Update entry:
                const myent = pluginsModel.get(pos);
                Object.keys(ne).forEach( function(k) {
                    if( ne[k] !== myent[k] )
                    {
                        //console.log(`Updating #${pos}: { '${k}': '${ne[k]}' }`);
                        pluginsModel.setProperty(pos, k, ne[k]);
                    }
                } );
                Object.keys(myent).forEach( function(k) {
                    if( !Object.keys(ne).includes(k) )
                    {
                        //console.log(`Deleting #${pos}: { '${k}': false }`);
                        pluginsModel.setProperty(pos, k, false);
                    }
                } );

                continue;
            }

            const midx = pluginsModel.count;
            pluginsModel.append(ne);
            //console.log(` +++ ${JSON.stringify(ne)}`);
        }
    }

    SplitView {
        id: header
        x: 0-pluginsList.contentX
        height: 32
        width: implicitWidth > parent.width ? implicitWidth * 2 : parent.width * 2

        property variant widths: ({})

        readonly property variant preferredWidths: [ 32, header.width*0.30, header.width*0.30, header.width*0.30, 16 ]

        Repeater {
            id: headerRepeater
            model: [ qsTr(''), qsTr('Filename'), qsTr('Mod Name'), qsTr('Description'), qsTr('') ]
            Label {
                SplitView.minimumWidth: 32
                text: modelData
                verticalAlignment: Text.AlignVCenter
                font.pointSize: 10
                font.bold: true
                leftPadding: 5
                onWidthChanged: { header.widths[ index ] = width; header.widths = header.widths; }
                Component.onCompleted: { header.widths[ index ] = width; header.widths = header.widths; }
            }
        }

        Component.onCompleted: {
            try {
                if( settings.pluginsListColumnSizes )
                {
                    header.restoreState( settings.pluginsListColumnSizes );
                    pluginsList.forceLayout();
                    return;
                }
            } catch(err) {
                console.log("Couldn't restore column widths. Oh well.");
            }

            for( let sidx=0; sidx < headerRepeater.count; sidx++ )
                headerRepeater.itemAt(sidx).width = preferredWidths[sidx] || 32;
            pluginsList.forceLayout();
        }
        Component.onDestruction: {
            settings.pluginsListColumnSizes = header.saveState();
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

        ListView {
            id: pluginsList
            spacing: 0

            clip: true
            interactive: false

            model: dmodel
            //delegate: pluginRowDelegate

            move: Transition { SmoothedAnimation {} }
        } // ListView
    } // ScrollView

    Component {
        id: pluginRowDelegate
        MouseArea {
            id: dragArea
            implicitHeight: row.height
            implicitWidth: row.width
            height: implicitHeight
            width: implicitWidth

            readonly property int rowIndex: index
            readonly property int modelIndex: dmodel.items.get(rowIndex).model.index
            property variant modent: pluginsModel.get(modelIndex)
            property bool held: false
            property bool targeted: false
            property int previousIndex: -1
            drag.target: held ? row : undefined
            drag.axis: Drag.YAxis

            onPressed: function(ev) { if( Qt.LeftButton === ev.button ) held = true; }
            onReleased: held = false

            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(ev) {
                if( Qt.RightButton === ev.button )
                    cellMenu.popup();
            }

            hoverEnabled: true

            onHeldChanged: {
                //console.log(dragArea.DelegateModel.itemsIndex+" is "+(held?'held':'not held'));
                if( held )
                {
                    previousIndex = dragArea.DelegateModel.itemsIndex;
                    return;
                }
                else
                {
                    if( !checkOrder() && previousIndex > -1 )
                    {
                        //console.log(`Reverting: ${dragArea.DelegateModel.itemsIndex} => ${previousIndex}`);
                        dmodel.items.move(dragArea.DelegateModel.itemsIndex, previousIndex);
                    } else
                        saveLoadOrder();
                }
            }

            function checkOrder()
            {
                let inMasters = true;
                for( let a=0; a < pluginsModel.count; a++ )
                {
                    const midx = dmodel.items.get(a).model.index;
                    const ent = pluginsModel.get(midx);
                    const lcName = ent['filename'].toLowerCase();
                    //console.log(`[${lcName}] => ${inMasters}`);
                    if( lcName.endsWith('.esm') && !inMasters )
                        return false;
                    else if( !lcName.endsWith('.esm') && !lcName.endsWith('.esl') )
                        inMasters = false;
                }
                return true;
            }

            function saveLoadOrder()
            {
                let oplugins = [];
                for( let a=0; a < pluginsModel.count; a++ )
                {
                    const midx = dmodel.items.get(a).model.index;
                    const ent = pluginsModel.get(midx);
                    oplugins.push(ent);
                }
                pluginsTable.writeRequested(oplugins);
            }

            Rectangle {
                id: row
                opacity: dragArea.held ? 0.25 : 1.0
                anchors {
                    verticalCenter: parent.verticalCenter
                    horizontalCenter: parent.horizontalCenter
                }

                width: realRow.implicitWidth
                height: realRow.implicitHeight + 15

                border.width: dragArea.held ? 1 : 0
                border.color: dragArea.held ? "lightsteelblue" : "transparent"

                Drag.active: dragArea.held
                Drag.source: dragArea
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                property color rowColour: (dragArea.rowIndex % 2) === 0 ? Material.background : Qt.darker(Material.background, 1.20)
                property color validColour: dragArea.modent && dragArea.modent['notfound'] ? '#888800' : rowColour

                color: dragArea.modent && dragArea.modent['missing'] ? '#880000' : validColour

                ToolTip.visible: dragArea.containsMouse && dragArea.modent && (dragArea.modent['missing'] || dragArea.modent['notfound']) ? true : false
                ToolTip.text: dragArea.modent && dragArea.modent['missing'] ? qsTr('Missing (or loaded out of order) masters will prevent this plugin from loading:\n\n%1').arg(dragArea.modent['missing'].join('\n'))
                                                                            : dragArea.modent && dragArea.modent['notfound'] ? qsTr("The file for this entry can't be found, so it won't be loaded.") : ''

                Row {
                    id: realRow
                    clip: true
                    anchors.centerIn: parent

                    Item {
                        Switch {
                            id: cellEnabled

                            checked: dragArea.modent && dragArea.modent['enabled'] ? true : false
                            anchors.centerIn: parent
                            onClicked: {
                                if( !dragArea.modent['enabled'] )
                                    enableMod(dragArea.modent);
                                else
                                    disableMod(dragArea.modent);
                            }

                            indicator: Rectangle {
                                implicitWidth: 32
                                implicitHeight: 16
                                x: cellEnabled.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 13
                                color: cellEnabled.checked ? "#17a81a" : "#ffffff"
                                Behavior on color {
                                    ColorAnimation { duration: 350 }
                                }
                                border.color: cellEnabled.checked ? "#17a81a" : "#cccccc"

                                Rectangle {
                                    x: cellEnabled.checked ? parent.width - width : 0
                                    Behavior on x {
                                        SmoothedAnimation { duration: 250 }
                                    }
                                    width: 16
                                    height: 16
                                    radius: 13
                                    color: cellEnabled.down ? "#cccccc" : "#ffffff"
                                    border.color: cellEnabled.checked ? (cellEnabled.down ? "#17a81a" : "#21be2b") : "#999999"
                                }
                            }
                        }
                        width: header.widths ? header.widths[ 0 ] : 24
                        height: 24
                    }

                    Loader {
                        sourceComponent: textCell
                        property string modelText: dragArea.modent ? dragArea.modent['filename'] : '???'
                        width: header.widths ? header.widths[ 1 ] : 24
                        height: 24
                    }

                    Loader {
                        sourceComponent: textCell
                        property string modelText: dragArea.modent ? dragArea.modent['name'] : '???'
                        width: header.widths ? header.widths[ 2 ] : 24
                        height: 24
                    }

                    Loader {
                        sourceComponent: textCell
                        property string modelText: dragArea.modent ? dragArea.modent['description'] : '???'
                        width: header.widths ? header.widths[ 3 ] : 24
                        height: 24
                    }
                } // Row

                Menu {
                    id: cellMenu
                    MenuItem {
                        text: dragArea.modent && dragArea.modent['enabled'] ? qsTr('Disable') : qsTr('Enable')
                        onTriggered: {
                            if( !dragArea.modent['enabled'] )
                                enableMod(dragArea.modent);
                            else
                                disableMod(dragArea.modent);
                        }
                    }
                }

                states: State {
                    when: dragArea.held

                    ParentChange { target: row; parent: pluginsTable }
                    AnchorChanges {
                        target: row
                        anchors { horizontalCenter: undefined; verticalCenter: undefined }
                    }
                }
            } // Rectangle

            DropArea {
                anchors.fill: parent
                enabled: !dragArea.held

                onEntered: function(drag) {
                    //console.log(`Drag: ${drag.source.rowIndex} -> ${dragArea.rowIndex}`);
                    dragArea.targeted = true;
                    dmodel.items.move(drag.source.DelegateModel.itemsIndex, dragArea.DelegateModel.itemsIndex);
                }
                onExited: dragArea.targeted = false;
            }
        } // MouseArea
    } // Component:pluginRowDelegate

    DelegateModel {
        id: dmodel
        delegate: pluginRowDelegate
        model: pluginsModel
    }

    Component {
        id: textCell

        Label {
            id: textLabel
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            leftPadding: 5
            elide: Text.ElideRight
            maximumLineCount: 1
            text: modelText
        } // Label
    }
}
