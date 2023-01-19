import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

import Qt.labs.platform 1.1 as Platform

Dialog {
    id: reviewPage
    title: qsTr('Preferences')
    modal: true
    clip: true

    onAboutToShow: {
        let pages = [ {'name':qsTr('General')} ];
        gameDefinitions.forEach( g => pages.push(g) );
        pageRepeater.model = pages;

        textNexusAPI.text = settings.nexusApiKey
        for( let a=0; a < gameDefinitions.length; a++ )
        {
            let g = gameDefinitions[a];
            const ent = gamesRepeater.itemAt(a);

            // Just help out:
            ent.gamename = g['name'];
            ent.steamid = g['steamid'];

            let sobj = gameSettings.objFor(g['name']);
            ent.enabled = sobj.enabled || false;
            ent.modspath = sobj.modsPath || `/DATA/SteamLibrary/steamapps/common/${g['gamedir']}/Quickmods`;
            ent.modstagingpath = sobj.modStagingPath || `/DATA/SteamLibrary/steamapps/common/${g['gamedir']}/QuickmodStaging`;
            ent.gamepath = sobj.gamePath || `/DATA/SteamLibrary/steamapps/common/${g['gamedir']}`;
            ent.userpath = sobj.userDataPath || `/DATA/SteamLibrary/steamapps/compatdata/${g['steamid']}/pfx/drive_c/users/steamuser`;
        }
    }

    onAccepted: {
        settings.nexusApiKey = textNexusAPI.text;
        for( let a=0; a < gameDefinitions.length; a++ )
        {
            let g = gameDefinitions[a];
            const ent = gamesRepeater.itemAt(a);

            let sobj = gameSettings.objFor(g['name']);
            sobj.enabled = ent.enabled;
            sobj.modsPath = ent.modspath;
            sobj.modStagingPath = ent.modstagingpath;
            sobj.gamePath = ent.gamepath;
            sobj.userDataPath = ent.userpath;
        }
    }

    header: TabBar {
        id: bar
        Repeater {
            id: pageRepeater

            TabButton {
                text: modelData['name']
            }
        }
    }

    footer: DialogButtonBox {
        Button {
            text: qsTr("Cancel")
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
        Button {
            text: qsTr("Save")
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
        }
    }

    Item {
        id: pager
        anchors.fill: parent
        property int currentIndex: bar.currentIndex

        implicitWidth: 750
        implicitHeight: 400

        Item {
            id: contentStuff
            visible: pager.currentIndex === 0
            implicitHeight: childrenRect.height + 40
            anchors.fill: parent

            Label {
                id: labelVortexApiKey
                anchors {
                    top: parent.top
                    left: parent.left
                    bottom: textNexusAPI.bottom
                    margins: 5
                }

                verticalAlignment: Text.AlignVCenter
                text: qsTr('Vortex API Key:')
            }
            TextField {
                id: textNexusAPI
                anchors {
                    top: parent.top
                    right: parent.right
                    left: labelVortexApiKey.right
                    margins: 5
                }
            }

            Label {
                id: labelAboutAPI
                anchors {
                    top: textNexusAPI.bottom
                    left: parent.left
                    right: parent.right
                    margins: 5
                }

                textFormat: Text.RichText
                wrapMode: Text.Wrap
                text: qsTr(`I don't have a fancy application API key yet because I just whipped this app up to begin with, but if you're willing to take a chance and put your personal NexusMods API key in, here's where you'd do it.<br><br>You can find (or request) your personal API key at <a href="https://www.nexusmods.com/users/myaccount?tab=api">https://www.nexusmods.com/users/myaccount?tab=api</a> down at the bottom.<br><br>You'll also need to set <b>quickmod</b> as your system handler for nxm links.`)
                onLinkActivated: function(url) { Qt.openUrlExternally(url); }
            }

            MenuSeparator {
                id: sep
                anchors {
                    top: labelAboutAPI.bottom
                    left: parent.left
                    right: parent.right
                    margins: 5
                }
            }

            Label {
                id: labelInstallMethod
                anchors {
                    top: sep.bottom
                    left: parent.left
                    bottom: installMethod.bottom
                    margins: 5
                }

                verticalAlignment: Text.AlignVCenter
                text: qsTr('Installation Method:')
            }
            ComboBox {
                id: installMethod
                anchors {
                    left: labelInstallMethod.right
                    top: sep.bottom
                    right: parent.right
                    margins: 5
                }

                model: [ { 'type':'symlink', 'text':'Symbolic Link' }, { 'type':'hardlink', 'text':'Hard Link' }, { 'type':'copy', 'text':'Copy Files' } ]
                textRole: 'text'
                valueRole: 'type'
            }

            Label {
                anchors {
                    top: installMethod.bottom
                    left: parent.left
                    right: parent.right
                    margins: 5
                }

                textFormat: Text.RichText
                wrapMode: Text.Wrap
                text: qsTr("<ul><li><b>Symbolic Link</b> - Links to the configured mod files are created in your game's installation. Base game data cannot be mucked with. This is the safest option, and very fast.</li>"
                          +"<li><b>Hard Link</b> - It's like a symbolic link but breaks if the mod files and game directory are on different media. This probably isn't what you want.</li>"
                          +"<li><b>Copy Files</b> - This is the oldschool method: extract the mod files right into your goshdarn game directory. Technically it's the fastest option, but it isn't really safe."
                          +"</ul><p><center><i>This isn't actually implemented yet, it will always be 'Copy Files'</i></center></p>")
            }
        }

        Repeater {
            id: gamesRepeater
            model: gameDefinitions

            Item {
                id: gameItem
                visible: pager.currentIndex === 1+index
                anchors.fill: parent
                implicitWidth: 580
                implicitHeight: 240

                readonly property real rowHeight: 32

                property alias enabled: cbEnabled.checked
                property alias modspath: modsPath.text
                property alias modstagingpath: modStagingPath.text
                property alias gamepath: gamePath.text
                property alias userpath: userDataPath.text

                property string steamid: modelData['steamid']
                property string gamename: modelData['name']

                CheckBox {
                    id: cbEnabled
                    text: qsTr('Enabled')
                    anchors {
                        top: parent.top
                        left: parent.left
                        margins: 10
                    }
                }

                Column {
                    id: columnLabels
                    spacing: 5
                    anchors {
                        top: cbEnabled.bottom
                        left: parent.left
                        margins: 10
                    }
                    height: childrenRect.height
                    width: childrenRect.width

                    Label {
                        height: gameItem.rowHeight
                        text: qsTr('Mod Storage Directory:')
                        enabled: cbEnabled.checked
                    }
                    Label {
                        height: gameItem.rowHeight
                        text: qsTr('Mod Staging Directory:')
                        enabled: cbEnabled.checked
                    }
                    Label {
                        height: gameItem.rowHeight
                        text: qsTr('Game Data Directory:')
                        enabled: cbEnabled.checked
                    }
                    Label {
                        height: gameItem.rowHeight
                        text: qsTr('User Data Directory:')
                        enabled: cbEnabled.checked
                    }
                }

                Column {
                    id: columnEdits
                    spacing: 5
                    anchors {
                        left: columnLabels.right
                        top: cbEnabled.bottom
                        right: columnButtons.left
                        margins: 10
                    }
                    height: childrenRect.height

                    TextField {
                        id: modsPath
                        enabled: cbEnabled.checked
                        height: gameItem.rowHeight
                        width: columnEdits.width

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('This is where the mod archive itself is stashed for safe-keeping.\n\nEg: /DATA/SteamLibrary/steamapps/common/%1/Quickmods').arg(gamename)
                    }
                    TextField {
                        id: modStagingPath
                        enabled: cbEnabled.checked
                        height: gameItem.rowHeight
                        width: columnEdits.width

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('This is where mods are extracted to and linked to the game from.\n\nEg: /DATA/SteamLibrary/steamapps/common/%1/QuickmodStaging').arg(gamename)
                    }
                    TextField {
                        id: gamePath
                        enabled: cbEnabled.checked
                        height: gameItem.rowHeight
                        width: columnEdits.width

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('Where the game is installed.\n\nEg: /DATA/SteamLibrary/steamapps/common/%1').arg(gamename)
                    }
                    TextField {
                        id: userDataPath
                        enabled: cbEnabled.checked
                        height: gameItem.rowHeight
                        width: columnEdits.width

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('This is the root directory of wherever your data and preferences are stored.\n\nEg: /DATA/SteamLibrary/steamapps/compatdata/%1/pfx/drive_c/users/steamuser').arg(steamid)
                    }
                }

                Column {
                    id: columnButtons
                    spacing: 5
                    anchors {
                        top: cbEnabled.bottom
                        right: gameItem.right
                        margins: 10
                    }

                    height: childrenRect.height
                    width: childrenRect.width

                    Button {
                        text: qsTr('Browse...')
                        height: gameItem.rowHeight
                        enabled: cbEnabled.checked
                        onClicked: {
                            modsPathDialogue.currentFolder = 'file://' + modsPath.text;
                            modsPathDialogue.open();
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('This is where the mod archive itself is stashed for safe-keeping.\n\nEg: /DATA/SteamLibrary/steamapps/common/%1/Quickmods').arg(gamename)
                    }
                    Button {
                        text: qsTr('Browse...')
                        height: gameItem.rowHeight
                        enabled: cbEnabled.checked
                        onClicked: {
                            modStagingPathDialogue.currentFolder = 'file://' + modStagingPath.text;
                            modStagingPathDialogue.open();
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('This is where mods are extracted to.\n\nEg: /DATA/SteamLibrary/steamapps/common/%1/QuickmodStaging').arg(gamename)
                    }
                    Button {
                        text: qsTr('Browse...')
                        height: gameItem.rowHeight
                        enabled: cbEnabled.checked
                        onClicked: {
                            gamePathDialogue.currentFolder = 'file://' + gamePath.text;
                            gamePathDialogue.open();
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('Where the game is installed.\n\nEg: /DATA/SteamLibrary/steamapps/common/%1').arg(gamename)
                    }
                    Button {
                        height: gameItem.rowHeight
                        text: qsTr('Browse...')
                        enabled: cbEnabled.checked
                        onClicked: {
                            userDataPathDialogue.currentFolder = 'file://' + userDataPath.text;
                            userDataPathDialogue.open();
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('This is the root directory of wherever your data and preferences are stored.\n\nEg: /DATA/SteamLibrary/steamapps/compatdata/%1/pfx/drive_c/users/steamuser').arg(steamid)
                    }
                } // Column

                Platform.FolderDialog {
                    id: modsPathDialogue
                    //visible: false
                    title: qsTr("Select where to store installed mods...")
                    onAccepted: {
                        modsPath.text = (''+folder).substring(7);
                    }
                }

                Platform.FolderDialog {
                    id: modStagingPathDialogue
                    //visible: false
                    title: qsTr("Select where to extract mods to...")
                    onAccepted: {
                        modStagingPath.text = (''+folder).substring(7);
                    }
                }

                Platform.FolderDialog {
                    id: gamePathDialogue
                    //visible: false
                    title: qsTr("Select the installed game path...")
                    onAccepted: {
                        gamePath.text = (''+folder).substring(7);
                    }
                }

                Platform.FolderDialog {
                    id: userDataPathDialogue

                    //visible: false
                    title: qsTr("Select the user data path...")
                    onAccepted: {
                        userDataPath.text = (''+folder).substring(7);
                    }
                }
            } // Item
        } // Repeater
    }
}
