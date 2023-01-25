import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

import QtQml.Models 2.15
import Qt.labs.qmlmodels 1.0

Item {
    id: pluginsTable

    property var model: []

    signal enableMod(variant mod)
    signal disableMod(variant mod)

    signal writeRequested(variant plugins, variant loadOrder)

    SplitView {
        id: header
        x: 0-pluginsList.contentX
        height: 32
        width: implicitWidth > parent.width ? implicitWidth * 2 : parent.width * 2

        property variant widths: ({})

        readonly property variant preferredWidths: [ 16, header.width*0.30, header.width*0.30, header.width*0.30, 16 ]

        Repeater {
            id: headerRepeater
            model: [ qsTr(''), qsTr('Filename'), qsTr('Mod Name'), qsTr('Description'), qsTr('') ]
            Label {
                SplitView.minimumWidth: 24
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

            clip: true
            interactive: false

            model: visualModel

            move: Transition { SmoothedAnimation {} }
        } // ListView
    } // ScrollView

    Component {
        id: pluginRowDelegate
        MouseArea {
            id: dragArea
            implicitHeight: realRow.implicitHeight + 15
            implicitWidth: realRow.implicitWidth

            property variant modent: pluginsTable.model[row.rowIndex]
            property int previousIndex
            property bool held: false
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
                //console.log(index+" is "+(held?'held':'not held'));

                if( held )
                {
                    previousIndex = dragArea.DelegateModel.itemsIndex;
                    return;
                }

                if( !checkValid() )
                {
                    console.log("Not valid, reverting...");
                    visualModel.items.move(dragArea.DelegateModel.itemsIndex, previousIndex);
                } else {
                    let nidx = dragArea.DelegateModel.itemsIndex;

                    console.log(`The new position of ${index} is ${nidx}`);
                    saveLoadOrder();
                    visualModel.items.move(dragArea.DelegateModel.itemsIndex, previousIndex);
                }
            }

            function checkValid()
            {
                let inMasters = true;
                for( let a=0; a < visualModel.items.count; a++ )
                {
                    const ent = visualModel.items.get(a);
                    //console.log(`Visual item ${a}: ${JSON.stringify(ent.model.index)}`);
                    //const modent = ent.model.modelData;
                    const modent = mmodel.get(ent.model.index);

                    if( modent['filepath'].toLowerCase().endsWith('.esp')
                     || modent['filepath'].toLowerCase().endsWith('.esl'))
                        inMasters = false;
                    else if( inMasters == false
                          && modent['filepath'].toLowerCase().endsWith('.esm') )
                        return false;
                }
                return true;
            }

            function saveLoadOrder()
            {
                // One last check...
                if( !checkValid() )
                    return;

                let plugins = { 'masters':[], 'normal':[] };
                let loadOrder = { 'masters':[], 'normal':[] };
                for( let a=0; a < visualModel.items.count; a++ )
                {
                    const ent = visualModel.items.get(a);
                    //const modent = ent.model.modelData;
                    const modent = mmodel.get(ent.model.index);

                    const nent = { 'enabled':modent['enabled'], 'filename':modent['filepath'] };
                    if( modent['filepath'].toLowerCase().endsWith('.esm') )
                    {
                        plugins['masters'].push( nent );
                        if( modent['enabled'] )
                            loadOrder['masters'].push( modent['filepath'] );
                    } else {
                        plugins['normal'].push( nent );
                        if( modent['enabled'] )
                            loadOrder['normal'].push( modent['filepath'] );
                    }
                }

                pluginsTable.writeRequested(plugins, loadOrder);
            }

            Rectangle {
                id: row
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

                readonly property int rowIndex: index

                property color rowColour: (rowIndex % 2) === 0 ? Material.background : Qt.darker(Material.background, 1.20)
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
                        Rectangle {
                            id: cellEnabled

                            radius: 90
                            color: dragArea.modent && dragArea.modent['enabled'] ? 'green' : row.color
                            anchors.centerIn: parent
                            height: 12
                            width: 12
                        }
                        width: 24
                        height: 24
                    }

                    Loader {
                        sourceComponent: textCell
                        property string modelText: dragArea.modent ? dragArea.modent['filepath'] : '???'
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

                DropArea {
                    anchors { fill: parent; margins: 10 }
                    enabled: !dragArea.held

                    onEntered: function(drag) {
                        //console.log(`Drag: ${drag.source.DelegateModel.itemsIndex} -> ${dragArea.DelegateModel.itemsIndex}`);
                        visualModel.items.move(
                                drag.source.DelegateModel.itemsIndex,
                                dragArea.DelegateModel.itemsIndex);
                    }
                }
            } // Rectangle
        } // MouseArea
    } // Component:pluginRowDelegate

    // Try to smoothly update the model to avoid our scroll position getting
    // clobbered whenever we save a change.
    onModelChanged: function() {
        // we key on the filename:
        let mnames = model.map( m => m['filepath'] );

        let toremove = [];

        let lmmap = {};
        for( let a=0; a < mmodel.count; a++ )
        {
            const dentry = mmodel.get(a);
            let ent = { 'index':a, 'entry':dentry };
            if( !mnames.includes(dentry['filepath']) )
                toremove.unshift(a);
            else
                lmmap[ dentry['filepath'] ] = ent;
        }

        toremove.forEach( i => mmodel.remove(i) );

        for( let b=0; b < mnames.length; b++ )
        {
            const n = mnames[b];
            const nent = model[b];
            if( !lmmap[ n ] )
            {
                mmodel.append( nent );
                continue;
            }

            mmodel.set( b, nent );
        }

        for( let c=0; c < visualModel.items.count; c++ )
        {
            const vobj = visualModel.items.get(c);
            const vidx = vobj.model.index;

            let same = true;
            const nent = mmodel.get(c);
            const vent = mmodel.get(vidx);
            const nkeys = Object.keys(nent);
            for( let d=0; d < nkeys.length; d++ )
            {
                const k = nkeys[d];
                if( vent[k] !== nent[k] )
                {
                    same = false;
                    break;
                }
            }

            if( same )
                continue;

            //console.log(`Updating ${c} => ${JSON.stringify(nent)}`);
            mmodel.set( c, nent );
        }
    }

    ListModel {
        id: mmodel
        dynamicRoles: true
    }

    DelegateModel {
        id: visualModel

        model: mmodel
        delegate: pluginRowDelegate
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
