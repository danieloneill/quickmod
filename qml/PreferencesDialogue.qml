import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

import QtQuick.Dialogs

Dialog {
    id: reviewPage
    title: qsTr('Preferences')
    modal: true

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

            let sobj = repeaterSettings.objFor(g['name']);
            ent.enabled = sobj.enabled || false;
            ent.modspath = sobj.modsPath || `/DATA/SteamLibrary/steamapps/common/${g['gamedir']}/Quickmods`;
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

            let sobj = repeaterSettings.objFor(g['name']);
            sobj.enabled = ent.enabled;
            sobj.modsPath = ent.modspath;
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

    SwipeView {
        anchors.fill: parent
        currentIndex: bar.currentIndex
        interactive: false
        clip: true

        GridLayout {
            columns: 2

            Label {
                text: qsTr('Vortex API Key:')
            }
            TextField {
                id: textNexusAPI
                Layout.fillWidth: true
            }

            Label {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                textFormat: Text.RichText
                wrapMode: Text.Wrap
                text: qsTr(`I don't have a fancy application API key yet because I just whipped this app up to begin with, but if you're willing to take a chance and put your personal NexusMods API key in, here's where you'd do it.<br><br>You can find (or request) your personal API key at <a href="https://www.nexusmods.com/users/myaccount?tab=api">https://www.nexusmods.com/users/myaccount?tab=api</a> down at the bottom.<br><br>You'll also need to set <b>quickmod</b> as your system handler for nxm links.`)
                onLinkActivated: function(url) { Qt.openUrlExternally(url); }
            }
        }

        Repeater {
            id: gamesRepeater
            model: gameDefinitions

            Item {
                implicitWidth: innerGrid.implicitWidth + 40
                implicitHeight: innerGrid.implicitHeight + 40

                property alias enabled: cbEnabled.checked
                property alias modspath: modsPath.text
                property alias gamepath: gamePath.text
                property alias userpath: userDataPath.text

                property string steamid: modelData['steamid']
                property string gamename: modelData['name']

                GridLayout {
                    id: innerGrid
                    columns: 3
                    anchors.margins: 10
                    anchors.fill: parent

                    CheckBox {
                        id: cbEnabled
                        text: qsTr('Enabled')
                        Layout.columnSpan: 3
                    }

                    Label {
                        text: qsTr('Mod Storage Directory:')
                        enabled: cbEnabled.checked
                    }

                    TextField {
                        id: modsPath
                        enabled: cbEnabled.checked
                        Layout.fillWidth: true

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('Eg: /DATA/SteamLibrary/steamapps/common/%1/Quickmods').arg(gamename)
                    }

                    Button {
                        text: qsTr('Browse...')
                        enabled: cbEnabled.checked
                        onClicked: {
                            modsPathDialogue.currentFolder = 'file://' + modsPath.text;
                            modsPathDialogue.open();
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('Eg: /DATA/SteamLibrary/steamapps/common/%1/Quickmods').arg(gamename)
                    }

                    Label {
                        text: qsTr('Game Data Directory:')
                        enabled: cbEnabled.checked
                    }

                    TextField {
                        id: gamePath
                        enabled: cbEnabled.checked
                        Layout.fillWidth: true

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('Eg: /DATA/SteamLibrary/steamapps/common/%1').arg(gamename)
                    }

                    Button {
                        text: qsTr('Browse...')
                        enabled: cbEnabled.checked
                        onClicked: {
                            gamePathDialogue.currentFolder = 'file://' + gamePath.text;
                            gamePathDialogue.open();
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('Eg: /DATA/SteamLibrary/steamapps/common/%1').arg(gamename)
                    }

                    Label {
                        text: qsTr('User Data Directory:')
                        enabled: cbEnabled.checked
                    }

                    TextField {
                        id: userDataPath
                        enabled: cbEnabled.checked
                        Layout.fillWidth: true

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('Eg: /DATA/SteamLibrary/steamapps/compatdata/%1/pfx/drive_c/users/steamuser').arg(steamid)
                    }

                    Button {
                        text: qsTr('Browse...')
                        enabled: cbEnabled.checked
                        onClicked: {
                            userDataPathDialogue.currentFolder = 'file://' + userDataPath.text;
                            userDataPathDialogue.open();
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: qsTr('Eg: /DATA/SteamLibrary/steamapps/compatdata/%1/pfx/drive_c/users/steamuser').arg(steamid)
                    }
                } // GridLayout

                FolderDialog {
                    id: modsPathDialogue
                    visible: false
                    title: qsTr("Select where to store installed mods...")
                    onAccepted: {
                        modsPath.text = (''+selectedFolder).substring(7);
                    }
                }

                FolderDialog {
                    id: gamePathDialogue
                    visible: false
                    title: qsTr("Select the installed game path...")
                    onAccepted: {
                        gamePath.text = (''+selectedFolder).substring(7);
                    }
                    options: FolderDialog.ReadOnly
                }

                FolderDialog {
                    id: userDataPathDialogue
                    visible: false
                    title: qsTr("Select the user data path...")
                    onAccepted: {
                        userDataPath.text = (''+selectedFolder).substring(7);
                    }
                    options: FolderDialog.ReadOnly
                }
            } // Item
        } // Repeater
    }
}
