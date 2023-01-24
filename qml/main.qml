import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

import Qt.labs.settings 1.0
import Qt.labs.platform 1.1 as Platform

import 'downloader.js' as Downloader
import 'plugins.js' as Plugins
import 'game.js' as Game
import 'mods.js' as Mods

ApplicationWindow {
    id: mainWin
    width: 800
    height: 600
    //visible: true
    title: qsTr("Quickmod")

    Material.theme: Material.Dark

    property bool m_gamingMode: false
    readonly property string m_tempPath: (''+Platform.StandardPaths.writableLocation(Platform.StandardPaths.TempLocation)).substring(7);

    function installFromFilesystem(filePath, gamecode, nexusModId, nexusFileId)
    {
        Mods.installFromFilesystem(filePath, function() {}, gamecode, nexusModId, nexusFileId);
    }

    function getModInfo(gamecode, nexusModId, cb)
    {
        Downloader.modInfo(gamecode, nexusModId, cb);
    }

    menuBar: Item {
        width: mainWin.width
        height: m_gamingMode ? 75 : menuBar.implicitHeight
        MenuBar {
            id: menuBar
            anchors {
                left: parent.left
                bottom: parent.bottom
            }

            Menu {
                title: qsTr("&File")
                Action {
                    text: qsTr("&Install mod (file)...");
                    onTriggered: fileDialog.open();
                    enabled: currentGame && gameDefinitions[currentGame]
                }
                MenuSeparator { }
                Action {
                    text: qsTr("&Settings");
                    onTriggered: preferencesDialogue.open();
                }
                Action {
                    text: qsTr("&Enable mods in game");
                    onTriggered: Game.enableMods();
                    enabled: currentGame && gameDefinitions[currentGame] && gameDefinitions[currentGame]['enableMods']
                }
                MenuSeparator { }
                Action {
                    text: qsTr("&Quit");
                    onTriggered: Qt.quit();
                }
            }

            Menu {
                id: gamesMenu
                title: qsTr("&Games")

                Repeater {
                    id: gamesMenuRepeater
                    model: []
                    RadioButton {
                        rightPadding: 5
                        leftPadding: 5
                        topPadding: 5
                        bottomPadding: 5
                        text: modelData['name']
                        checked: modelData['name'] === currentGame
                        onClicked: {
                            currentGame = modelData['name'];
                            gamesMenu.close();
                            settingsChanged();
                        }
                    }
                }
            }

            Menu {
                title: qsTr("&Help")
                Action {
                    text: qsTr("&About")
                    onTriggered: aboutDialogue.open();
                }
            }
        }
    }

    footer: Frame {
        implicitHeight: statusBar.height + 10
        Label {
            id: statusBar
            anchors.centerIn: parent
            width: parent.width
            text: qsTr('Welcome.')
        }
    }

    TabBar {
        id: tabSection
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        TabButton {
            text: qsTr('Mods')
        }
        TabButton {
            text: qsTr('Plugins / Load Order')
        }
    }

    StackLayout {
        anchors {
            top: tabSection.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        currentIndex: tabSection.currentIndex

        ModsTable {
            id: modTable
            model: modMasterList
            onInstallMod: function(mod) { Mods.installMod(mod); }
            onUninstallMod: function(mod) { Mods.uninstallMod(mod); }
            onEnableMod: function(mod) { Mods.enableMod(mod); }
            onDisableMod: function(mod) { Mods.disableMod(mod); }
            onReinstallMod: function(mod) { Mods.reinstallMod(mod); }
            onDeleteMod: function(mod) { Mods.deleteMod(mod); }
        }
        PluginsTable {
            id: pluginsTable

            onEnableMod: function(mod) { Plugins.enableMod(mod); }
            onDisableMod: function(mod) { Plugins.disableMod(mod); }

            onWriteRequested: function(plugins, loadOrder) {
                Plugins.writePlugins(plugins);
                Plugins.writeLoadOrder(loadOrder);
            }
        }
    }

    Settings {
        id: settings
        category: 'Global'

        property string currentGame
        property var modListColumnSizes
        property var pluginsListColumnSizes
        property var loadorderListColumnSizes

        property string nexusApiKey
        property string nexusUuid
        property string nexusToken
    }

    Database {
        id: db
    }

    ProgressDialogue {
        id: downloadProgress
        anchors.centerIn: parent
    }

    ProgressDialogue {
        id: extractProgress
        anchors.centerIn: parent
    }

    Connections {
        target: NXMHandler
        function onDownloadRequested(path)
        {
            Downloader.downloadFile(path);
        }
    }

    Platform.FileDialog {
        id: fileDialog
        visible: false
        folder: Platform.StandardPaths.writableLocation(Platform.StandardPaths.DownloadLocation)
        title: qsTr("Select a mod archive to install...")
        nameFilters: ["Archive files (*.zip *.7z *.rar *.tar.gz *.tar.xz *.tar.bz2)", "All Files (*)"]
        onAccepted: {
            const selections = fileDialog.currentFiles;

            for( let a=0; a < selections.length; a++ )
            {
                const rawpath = ''+selections[a];
                console.log("Path: "+rawpath);

                const filepath = rawpath.substring(7);

                if( !Mods.installFromFilesystem(filepath) )
                    return;
            }
        }
        onRejected: {
            console.log("Canceled");
        }
    }

    property alias currentGame: settings.currentGame
    property var currentGameEntry
    property bool loadComplete: false

    Component.onCompleted: {
        console.log("Args: "+JSON.stringify(Args,null,2));
        console.log("Sess:" + Utils.getEnv("DESKTOP_SESSION"));
        console.log("Temp: "+m_tempPath);

        m_gamingMode = ("gamescope-wayland" === Utils.getEnv("DESKTOP_SESSION"));

        // For dev purposes, only simulate file/dir modifying ops (except archive invalidation):
        File.simulate = false;

        if( Args[0] === '-f' )
            mainWin.showMaximized();
        else if( m_gamingMode )
        {
            mainWin.width = 1280;
            mainWin.height = 800;
            mainWin.showMaximized();
        }
        else
            mainWin.show();

        if( !currentGame )
            return;

        settingsChanged();
        loadComplete = true;
    }

    Component.onDestruction: {
        settings.sync();
    }

    function settingsChanged()
    {
        let gamesMenuOptions = [];

        console.log('.---');
        for( let a=0; a < gameDefinitions.length; a++ )
        {
            const gd = gameDefinitions[a];

            let sobj = gameSettings.objFor(gd['name']);
            const enabled = sobj.enabled;

            console.log(`: ${gd['name']} => ${enabled ? 'on' : 'off'}`);
            if( !enabled )
                continue;

            gamesMenuOptions.push( gd );
        }
        console.log('`---');
        gamesMenuRepeater.model = gamesMenuOptions;
        Game.loadForGame();
    }

    onCurrentGameChanged: if( loadComplete ) Game.loadForGame();

    PreferencesDialogue {
        id: preferencesDialogue
        anchors.centerIn: parent
        width: parent.width * 0.75
        onAccepted: settingsChanged();
    }

    ModConfiguration {
        id: modConfigWindow
        onReadyForInstall: {
            console.log("Ready to install!");
            console.log('m_mod: '+JSON.stringify(m_mod))
            console.log('m_files: '+JSON.stringify(m_files, null, 2));
            console.log('m_folders: '+JSON.stringify(m_folders, null, 2));

            Mods.installFancyMod(m_mod, m_files, m_folders, m_modinfo, m_flags);
        }
    }

    AboutDialogue {
        id: aboutDialogue
        anchors.centerIn: parent
    }

    GameSettings {
        id: gameSettings
    }

    property var modMasterList: []

    readonly property variant gameDefinitions: [
        {
            'steamid': '611670',
            'name': 'Skyrim VR',
            'gamedir': 'SkyrimVR',
            'appdir': 'AppData/Local/Skyrim VR',
            'confdir': 'Documents/My Games/Skyrim VR',
            'ini': 'Skyrim.ini',
            'datadir': 'Data',
            'plugins': 'plugins.txt',
            'loadorder': 'loadorder.txt',
            'builtin': [
                'Skyrim.esm',
                'Update.esm',
                'Dawnguard.esm',
                'HearthFires.esm',
                'Dragonborn.esm',
                'SkyrimVR.esm',
                'ccBGSSSE001-Fish.esm',
                'ccQDRSSE001-SurvivalMode.esl',
                'ccBGSSSE025-AdvDSGS.esm',
                'ccBGSSSE037-Curios.esl',
            ],
            'enableMods': function() {
                const adroot = `${this['paths']['userData']}/${this['confdir']}`;
                const inipath = `${adroot}/${this['ini']}`;
                Utils.configSet(inipath, 'Archive', 'bInvalidateOlderFiles', '1');
                Utils.configSet(inipath, 'Archive', 'sResourceDataDirsFinal', '');
                return true;
            }
        },
        {
            'steamid': '489830',
            'name': 'Skyrim Special Edition',
            'gamedir': 'Skyrim Special Edition',
            'appdir': 'AppData/Local/Skyrim Special Edition',
            'confdir': 'Documents/My Games/Skyrim Special Edition',
            'ini': 'Skyrim.ini',
            'datadir': 'Data',
            'plugins': 'plugins.txt',
            'loadorder': 'loadorder.txt',
            'builtin': [
                'Skyrim.esm',
                'Update.esm',
                'Dawnguard.esm',
                'HearthFires.esm',
                'Dragonborn.esm',
                'ccBGSSSE001-Fish.esm',
                'ccQDRSSE001-SurvivalMode.esl',
                'ccBGSSSE025-AdvDSGS.esm',
                'ccBGSSSE037-Curios.esl',
            ],
            'enableMods': function() {
                const adroot = `${this['paths']['userData']}/${this['confdir']}`;
                const inipath = `${adroot}/${this['ini']}`;
                Utils.configSet(inipath, 'Archive', 'bInvalidateOlderFiles', '1');
                Utils.configSet(inipath, 'Archive', 'sResourceDataDirsFinal', '');
                return true;
            }
        },
        {
            'steamid': '611660',
            'name': 'Fallout 4 VR',
            'gamedir': 'Fallout 4 VR',
            'appdir': 'AppData/Local/Fallout4VR',
            'confdir': 'Documents/My Games/Fallout4VR',
            'ini': 'Fallout4.ini',
            'datadir': 'Data',
            'plugins': 'plugins.txt',
            'loadorder': 'loadorder.txt',
            'builtin': [
                'Fallout4.esm',
                'Fallout4_VR.esm',
                'DLCCoast.esm',
                'DLCNukaWorld.esm',
                'DLCRobot.esm',
                'DLCworkshop01.esm',
                'DLCworkshop02.esm',
                'DLCworkshop03.esm',
            ],
            'enableMods': function() {
                const adroot = `${this['paths']['userData']}/${this['confdir']}`;
                const inipath = `${adroot}/${this['ini']}`;
                Utils.configSet(inipath, 'Archive', 'bInvalidateOlderFiles', '1');
                Utils.configSet(inipath, 'Archive', 'sResourceDataDirsFinal', '');
                return true;
            }
        },
        {
            'steamid': '377160',
            'name': 'Fallout 4',
            'gamedir': 'Fallout 4',
            'appdir': 'AppData/Local/Fallout4',
            'confdir': 'Documents/My Games/Fallout4',
            'ini': 'Fallout4.INI',
            'datadir': 'Data',
            'plugins': 'Plugins.txt',
            'loadorder': 'DLCList.txt',
            'builtin': [
                'Fallout4.esm',
                'DLCCoast.esm',
                'DLCNukaWorld.esm',
                'DLCRobot.esm',
                'DLCworkshop01.esm',
                'DLCworkshop02.esm',
                'DLCworkshop03.esm',
            ],
            'enableMods': function() {
                const adroot = `${this['paths']['userData']}/${this['confdir']}`;
                const inipath = `${adroot}/${this['ini']}`;
                Utils.configSet(inipath, 'Archive', 'bInvalidateOlderFiles', '1');
                Utils.configSet(inipath, 'Archive', 'sResourceDataDirsFinal', '');
                return true;
            }
        }
    ]
}
