import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

import Qt.labs.settings 1.0
import Qt.labs.platform 1.1 as Platform

import 'downloader.js' as Downloader

ApplicationWindow {
    id: mainWin
    width: 640
    height: 480
    //visible: true
    title: qsTr("Quickmod")

    Material.theme: Material.Dark

    property bool m_gamingMode: false

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
                    onTriggered: enableMods();
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
                        text: modelData['name']
                        checked: modelData['name'] === currentGame
                        onClicked: {
                            currentGame = modelData['name'];
                            gamesMenu.close();
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
        //implicitWidth: statusBar.width
        Label {
            id: statusBar
            anchors.centerIn: parent
            width: parent.width
            text: qsTr('Welcome.')
        }
    }

    ModsTable {
        id: modTable
        anchors.fill: parent
        model: modMasterList
        onInstallMod: function(mod) { mainWin.installMod(mod); }
        onUninstallMod: function(mod) { mainWin.uninstallMod(mod); }
        onEnableMod: function(mod) { mainWin.enableMod(mod); }
        onDisableMod: function(mod) { mainWin.disableMod(mod); }
        onReinstallMod: function(mod) { mainWin.reinstallMod(mod); }
        onDeleteMod: function(mod) { mainWin.deleteMod(mod); }
    }

    Settings {
        id: settings
        category: 'Global'

        property string currentGame
        property var modListColumnSizes

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

/*
    WebSocket {
        id: ws
        url: "wss://sso.nexusmods.com"

        property string op: 'none'

        Component.onCompleted: {
            ws.active = true;
        }

        onStatusChanged: {
            if( WebSocket.Open === status )
            {
                // Unregistered...
                if( !settings.nexusUuid )
                {
                    settings.nexusUuid = Utils.uuid();
                    settings.nexusToken = null;
                    register();
                }
            }
        }

        onTextMessageReceived: function(pkt) {
            try {
                const obj = JSON.parse(pkt);

                if( 'register' === ws.op )
                {
                    // {"success":true,"data":{"connection_token":"X5SjO3P4i8tiBgMdYVTCh3z57ZnWVK5z"},"error":null}
                    if( !obj['success'] )
                    {
                        console.log(`Ngeh, register failed: ${pkt}`);
                        return;
                    }

                    const url = `https://www.nexusmods.com/sso?id=${settings.nexusUuid}&application=${obj['connection_token']}`;
                    Qt.openUrlExternally(url);
                }
            } catch(e) {
                console.log(`Parse error: ${e}`);
            }
        }

        function register()
        {
            ws.op = 'register';
            const json = JSON.stringify( { 'id':settings.nexusUuid, 'token':settings.nexusToken, 'protocol':2 } );
            ws.sendTextMessage(json);
        }
    }
*/
    /*
    function configFromArchive(archive, target)
    {
        console.log(`Going to extract "${target}" from ${archive}...`);
        const raw = File.extract(archive, target);
        return FomodReader.readXMLFile( Utils.autoDecode(raw) );
    }
    */

    function manifestFromFomod(filepath, cb)
    {
        const a = File.archive(filepath);
        a.list( function(success, filelist) {
            if( filelist.length === 0 )
            {
                console.log("Empty file listing for archive, it's ... probably corrupted.");
                return false;
            }
            console.log("CONTENTS: "+JSON.stringify(filelist,null,2));

            let fomodDir = '';
            let fomodLow = '';
            let pathInfo = false;
            let pathConfig = false;
            filelist.forEach( function(e) {
                if( e['type'] === 'dir' && ( e['pathname'].toLowerCase().endsWith('fomod') || e['pathname'].toLowerCase().endsWith('fomod/') ) )
                    fomodDir = e['pathname'];
            } );

            let rel = '';

            const finish = function()
            {
                let result = {
                    'root':filepath,
                    'relative':rel,
                    'fomodDir':fomodDir
                };

                if( pathInfo )
                {
                    const raw = File.read('/tmp/fomod/info.xml');
                    result['info'] = FomodReader.readXMLFile( Utils.autoDecode(raw) );
                }
                if( pathConfig )
                {
                    const raw = File.read('/tmp/fomod/moduleconfig.xml');
                    result['config'] = FomodReader.readXMLFile( Utils.autoDecode(raw) );
                }

                console.log(`Result: ${JSON.stringify(result,null,2)}`);

                cb(result);
            }

            if( fomodDir )
            {
                if( fomodDir.endsWith('/') )
                    fomodDir = fomodDir.substring(0, fomodDir.length-1);

                fomodLow = fomodDir.toLowerCase();
                console.log("FomodDir: "+fomodDir);

                let fomodParts = fomodDir.split(/\//g);
                if( fomodParts.length > 1 )
                {
                    fomodParts.pop();
                    rel = fomodParts.join('/');
                }

                pathInfo = filelist.find( e => e['pathname'].toLowerCase() === fomodLow + '/info.xml' );
                pathConfig = filelist.find( e => e['pathname'].toLowerCase() === fomodLow + '/moduleconfig.xml' );

                if( pathInfo )
                    pathInfo = pathInfo['pathname'];
                if( pathConfig )
                    pathConfig = pathConfig['pathname'];

                // Just grab the whole fomod contents, plop it in tmp:
                File.rmrecursive("/tmp/fomod");
                File.mkdir("/tmp/fomod", false);
                let toExtract = {};
                filelist.forEach(function(e) {
                    if( e['pathname'].toLowerCase().startsWith(fomodLow) )
                        toExtract[ e['pathname'] ] = '/tmp/fomod/'+e['pathname'].substring(fomodDir.length+1).toLowerCase();
                });
                console.log("To Extract: "+JSON.stringify(toExtract,null,2));

                a.extract(toExtract, function(success, results) {
                    finish();
                }, function(sofar, total, latestSource, latestDest) {
                    console.log(`Progress: [${sofar} / ${total}]: ${latestSource}\t => ${latestDest}`);
                });
                //File.extractBatch(filepath, toExtract);
            }
            else
                finish();
        } );
    }

    function installFromFilesystem(filepath, cb)
    {
        manifestFromFomod(filepath, function(result) {
            if( false === result )
            {
                cb(false);
                return;
            }

            if( !result['config'] || !result['info'] )
            {
                const baseName = filepath.split(/\//g).pop();
                let ent = { 'filename':'', 'installed':false, 'enabled':false, 'name':baseName, 'author':'Unknown', 'version':'??', 'website':'', 'description':'', 'groups':[] };
                if( result['info'] )
                {
                    if( result['info']['fomod']['Name']['Characters'] )
                        ent['name'] = result['info']['fomod']['Name']['Characters'];

                    ent['author'] = result['info']['fomod']['Author']['Characters'];
                    ent['version'] = result['info']['fomod']['Version']['Characters'];
                    ent['description'] = result['info']['fomod']['Description']['Characters'];
                }

                cb( addMod2(filepath, ent) );
                return;
            }

            cb( addMod(result) );
        });
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

                if( !installFromFilesystem(filepath) )
                    return;
            }
        }
        onRejected: {
            console.log("Canceled");
        }
    }

    property alias currentGame: settings.currentGame
    property var currentGameEntry

    Component.onCompleted: {
        console.log("Args: "+JSON.stringify(Args,null,2));
        console.log("Sess:" + Utils.getEnv("DESKTOP_SESSION"));

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

        loadForGame();

        settingsChanged();
/*
        // Testing:
        console.log("Testing... ");
        console.log("----------");
        const a = File.archive("/DATA/SteamLibrary/steamapps/common/Skyrim Special Edition/Quickmods/StarClothMage.tar.xz");

        const startTimeB = new Date();
        const ents = ["zImages/Screenshot 2022-01-29 210536.png"];
        let ba = a.get(ents, function(found, contents) {
            const nowB = new Date();
            console.log(`${found ? 'Extracted' : 'Failed to find'} ${ents[0]} (${contents[ents[0]].byteLength}B) in ${nowB.getTime()-startTimeB.getTime()}ms`);
        } );

        const startTimeA = new Date();
        let w = a.list( function(result, entries) {
            const nowA = new Date();
            console.log(`Read ${entries.length} entries in ${nowA.getTime()-startTimeA.getTime()}ms. Beginning extract (all):`);

            const paths = entries.filter( e => e['type'] === 'file' );
            let matrix = {};
            paths.forEach( e => { matrix[ e['pathname'] ] = '/tmp/test/'+e['pathname']; } );
            console.log(JSON.stringify(matrix,null,2));

            const startTimeC = new Date();
            a.extract( matrix, function(code, map) {
                const nowC = new Date();
                console.log('Behold!');
                console.log('--------')
                const keys = Object.keys(map);
                let succeeded = 0;
                keys.forEach( function(k) {
                    if( map[k] !== true )
                        console.log(`Failed to extract file "${k}": ${map[k]}`);
                    else
                        succeeded++;
                } );
                console.log(`${succeeded} of ${paths.length} successfully extracted in ${nowC.getTime()-startTimeC.getTime()}ms`);

            }, function(sofar, total, latestSource, latestDest) {
                console.log(`Progress: [${sofar} / ${total}]: ${latestSource}\t => ${latestDest}`);
            } );
        } );
*/

/*
        // DEBUG
        const cfgraw = File.read('/home/doneill/code/quickmod/fun.xml');
        const cfgjson = FomodReader.readXMLFile( Utils.autoDecode(cfgraw) );
        JSON.stringify(cfgjson,null,2);
        let modinfo = { 'config':cfgjson };
        installFancyMod(currentGameEntry, [], '', modinfo, {'option_b':'selected', 'texture_red':'selected'});
*/
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

            let sobj = repeaterSettings.objFor(gd['name']);
            const enabled = sobj.enabled;

            console.log(`: ${gd['name']} => ${enabled ? 'on' : 'off'}`);
            if( !enabled )
                continue;

            gamesMenuOptions.push( gd );
        }
        console.log('`---');
        gamesMenuRepeater.model = gamesMenuOptions;
    }

    onCurrentGameChanged: loadForGame();
    function loadForGame()
    {
        db.close();

        currentGameEntry = gameEntryByName(currentGame);
        if( !currentGameEntry )
            return;

        const ent = installedEntity(currentGame);
        if( !ent )
            return;

        const dbpath = `${ent['paths']['gamePath']}/Quickmod.sqlite`;
        db.open(dbpath);

        modMasterList = db.getMods();

        statusBar.text = qsTr('Now managing "%1"').arg(currentGame);
        readPlugins();
    }

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

            installFancyMod(m_mod, m_files, m_folders, m_modinfo, m_flags);
        }
    }

    function readLoadOrder()
    {
        let sobj = repeaterSettings.objFor(currentGame);
        const adroot = `${sobj.userDataPath}/${currentGameEntry['appdir']}`;
        const pluginspath = `${adroot}/${currentGameEntry['loadorder']}`;
        const raw = ''+File.read(pluginspath);
        //console.log(`Reading "${pluginspath}": ${raw}`);

        const lines = raw.split('\r\n');
        //console.log(`Lines: ${JSON.stringify(lines,null,0)}`);

        let ents = { 'masters':[], 'light':[], 'normal':[] };
        for( let a=0; a < lines.length; a++ )
        {
            const l = lines[a];
            if( l.length < 4 )
                continue;

            if( l.substring(0,1) === '#' )
                continue;

            const llc = l.toLowerCase();
            if( llc.endsWith(".esm") )
                ents['masters'].push(l);
            else if( llc.endsWith(".esl") )
                ents['light'].push(l);
            else if( llc.endsWith(".esp") )
                ents['normal'].push(l);
            else
                console.log(` *** I don't know what to do with this entry: "${l}"`);
        }

        //console.log(`LoadOrder: ${JSON.stringify(plugins,null,2)}`);
        return ents;
    }

    function writeLoadOrder(loadorder)
    {
        let output = ["# Generated by Quickmod"];
        ['masters', 'light', 'normal'].forEach( function(sec) {
            loadorder[sec].forEach( function(ent) {
                output.push(`${ent}`);
            } );
        });
        const res = output.join("\r\n");
        console.log("Writing: "+res);

        let sobj = repeaterSettings.objFor(currentGame);
        const adroot = `${sobj.userDataPath}/${currentGameEntry['appdir']}`;
        const lopath = `${adroot}/${currentGameEntry['loadorder']}`;
        File.write(lopath, res);

        return res;
    }

    function readPlugins()
    {
        let sobj = repeaterSettings.objFor(currentGame);
        const adroot = `${sobj.userDataPath}/${currentGameEntry['appdir']}`;
        const pluginspath = `${adroot}/${currentGameEntry['plugins']}`;
        const raw = ''+File.read(pluginspath);
        //console.log(`Reading "${pluginspath}": ${raw}`);

        const lines = raw.split('\r\n');
        //console.log(`Lines: ${JSON.stringify(lines,null,0)}`);

        let plugins = { 'masters':[], 'light':[], 'normal':[] };
        for( let a=0; a < lines.length; a++ )
        {
            const l = lines[a];
            if( l.length < 4 )
                continue;

            if( l.substring(0,1) === '#' )
                continue;

            let nent = { 'enabled':false, 'filename':l };
            if( l.substring(0,1) === '*' )
            {
                nent['enabled'] = true;
                nent['filename'] = l.substring(1);
            }

            const llc = l.toLowerCase();
            if( llc.endsWith(".esm") )
                plugins['masters'].push(nent);
            else if( llc.endsWith(".esl") )
                plugins['light'].push(nent);
            else if( llc.endsWith(".esp") )
                plugins['normal'].push(nent);
            else
                console.log(` *** I don't know what to do with this entry: "${l}"`);
        }

        //console.log(`Plugins: ${JSON.stringify(plugins,null,2)}`);
        return plugins;
    }

    function writePlugins(plugins)
    {
        let output = ["# Generated by Quickmod"];
        ['masters', 'light', 'normal'].forEach( function(sec) {
            plugins[sec].forEach( function(ent) {
                output.push(`${ ent['enabled'] ? '*' : '' }${ent['filename']}`);
            } );
        });
        const res = output.join("\r\n");
        console.log("Writing: "+res);

        let sobj = repeaterSettings.objFor(currentGame);
        const adroot = `${sobj.userDataPath}/${currentGameEntry['appdir']}`;
        const pluginspath = `${adroot}/${currentGameEntry['plugins']}`;
        File.write(pluginspath, res);

        return res;
    }

    function enableMod(mod)
    {
        let sobj = repeaterSettings.objFor(currentGame);
        const files = db.getFiles(mod['modId']);
        console.log(`Enabling "${mod['name']}"...`);

        let updatePlugins = false;
        let plugins = readPlugins();
        let loadorder = readLoadOrder();
        files.forEach( function(f) {
            let baseName = f['dest'];

            let parts = f['dest'].split(/\//g);
            if( parts.length > 1 )
                baseName = parts.pop();

            const baseNameLC = baseName.toLowerCase();
            const ent = { 'enabled':true, 'filename':baseName };
            if( baseNameLC.endsWith(".esm") )
            {
                plugins['masters'].push(ent);
                loadorder['masters'].push(baseName);
                updatePlugins = true;
            }
            else if( baseNameLC.endsWith(".esl") )
            {
                plugins['light'].push(ent);
                loadorder['light'].push(baseName);
                updatePlugins = true;
            }
            else if( baseNameLC.endsWith(".esp") )
            {
                plugins['normal'].push(ent);
                loadorder['normal'].push(baseName);
                updatePlugins = true;
            }
        });

        if( updatePlugins )
        {
            writePlugins(plugins);
            writeLoadOrder(loadorder);
            statusBar.text = qsTr('Enabled "%1".').arg(mod['name']);
        }
        else
            statusBar.text = qsTr('Enabled "%1", but ... there was nothing to do, really.').arg(mod['name']);

        mod['enabled'] = true;
        db.updateMod(mod);
        modMasterList = db.getMods();
    }

    function disableMod(mod)
    {
        let sobj = repeaterSettings.objFor(currentGame);
        const files = db.getFiles(mod['modId']);
        console.log(`Disabling "${mod['name']}"...`);

        let updatePlugins = false;
        let plugins = readPlugins();
        let loadorder = readLoadOrder();
        files.forEach( function(f) {
            const parts = f['dest'].split(/\//g);
            if( parts.length === 1 )
            {
                const baseName = parts.pop();

                ['masters', 'light', 'normal'].forEach( function(sec) {
                    let nsec = plugins[sec].filter( m => m['filename'] !== baseName );
                    if( nsec.length !== plugins[sec].length )
                    {
                        plugins[sec] = nsec;
                        updatePlugins = true;
                    }

                    let nlo = loadorder[sec].filter( m => m !== baseName );
                    if( nsec.length !== loadorder[sec].length )
                    {
                        loadorder[sec] = nlo;
                        updatePlugins = true;
                    }
                } );
            }
        });

        if( updatePlugins )
        {
            writePlugins(plugins);
            writeLoadOrder(loadorder);
        }

        statusBar.text = qsTr('Disabled "%1".').arg(mod['name']);

        mod['enabled'] = false;
        db.updateMod(mod);
        modMasterList = db.getMods();
    }

    AboutDialogue {
        id: aboutDialogue
        anchors.centerIn: parent
    }

    Repeater {
        id: repeaterSettings
        Item {
            property alias enabled: intobj.enabled
            property alias gamePath: intobj.gamePath
            property alias modsPath: intobj.modsPath
            property alias modStagingPath: intobj.modStagingPath
            property alias userDataPath: intobj.userDataPath

            Settings {
                id: intobj
                category: modelData['name']

                property bool enabled: false
                property string gamePath
                property string modsPath
                property string modStagingPath
                property string userDataPath
            }
        }
        model: gameDefinitions

        function objFor(name)
        {
            for( let a=0; a < repeaterSettings.count; a++ )
                if( model[a]['name'] === name )
                    return itemAt(a);
            return false;
        }
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

    function gameEntryByName(gamename)
    {
        for( let a=0; a < gameDefinitions.length; a++ )
        {
            const ent = gameDefinitions[a];
            if( ent['name'] === gamename )
                return ent;
        }
        return false;
    }

    function installedEntity(gamename)
    {
        let entry = gameEntryByName(gamename);

        let sobj = repeaterSettings.objFor(gamename);

        const gpath = sobj.gamePath;
        if( !gpath || gpath.length === 0 )
        {
            console.log(`No gamepath, nope.`);
            return false;
        }

        const udpath = sobj.userDataPath;
        if( !udpath || udpath.length === 0 )
        {
            console.log(`No userdata path, nope.`);
            return false;
        }

        entry['paths'] = { 'gamePath':gpath, 'userData':udpath };
        return entry;
    }

    function checkOverwrites(fileMap)
    {
        let overwrites = [];
        Object.keys(fileMap).forEach( function(fsource) {
            const fdest = fileMap[fsource];
            const st = File.stat(fdest);
            if( st['exists'] )
            {
                let ent = { 'source':fsource, 'destination':fdest };
                const conflictingFiles = db.getFilesByDests([fdest]);
                if( conflictingFiles.length > 0 )
                    ent['providers'] = conflictingFiles;

                overwrites.push( ent );
            }
        } );
        return overwrites;
    }

    function addESP(espname)
    {
        const entry = installedEntity(mainWin.currentGame);
        if( !entry )
        {
            console.log(`Cannot find game data info for '${mainWin.currentGame}'!`);
            return false;
        }

        const pluginini = entry['plugins'];
        const loadorderini = entry['loadorder'];
        console.log(`Gonna add '${espname}' to ${entry['paths']['userData']}/${entry['appdir']}/${loadorderini}'`);
        console.log(`Gonna add '*${espname}' to ${entry['paths']['userData']}/${entry['appdir']}/${pluginini}'`);
        return true;
    }

    function addMod(mod)
    {
        const i = mod['info'];
        console.log(`Add mod: (${mod['root']}) ${JSON.stringify(i,null,2)}`);

        const f = i['fomod'];
        if( !f )
            return false;

        const mname = f['Name'] ? f['Name']['Characters'] : mod['root'].split(/\//g).pop();
        if( !mname )
            return false;

        // TODO: Already installed? Check now.
        for( let a=0; a < modMasterList.length; a++ )
        {
            const ment = modMasterList[a];
            if( ment['name'] === mname )
            {
                statusBar.text = qsTr('This mod is already installed.');
                return false;
            }
        }

        const mauth = f['Author'] ? f['Author']['Characters'] : '';
        const mver = f['Version'] ? f['Version']['Characters'] : '';
        const mweb = f['Website'] ? f['Website']['Characters'] : '';
        const mdesc = f['Description'] ? f['Description']['Characters'] : '';

        let tgroups = [];
        if( f['Groups'] && f['Groups']['element'] )
        {
            let e = f['Groups']['element'];
            if( !( e instanceof Array ) )
                e = [e];

            e.forEach( gn => { tgroups.push(gn['Characters']) } );
        }

        let ent = { 'filename':'', 'installed':false, 'enabled':false, 'name':mname, 'author':mauth, 'version':mver, 'website':mweb, 'description':mdesc, 'groups':tgroups };
        ent = addMod2( mod['root'], ent );
        statusBar.text = qsTr('"%1" is added.').arg(mname);

        return true;
    }

    function addMod2(archive, ent)
    {
        // Now copy it to our storage:
        let sobj = repeaterSettings.objFor(currentGame);
        const baseName = archive.split(/\//g).pop();
        const destPath = sobj.modsPath;
        console.log(`Creating directory "${destPath}"...`);
        File.mkdir(destPath);

        ent['filename'] = baseName;

        let destFile = destPath+'/'+baseName;
        destFile = destFile.replace(/\.\./g, '');

        console.log(`Copying "${archive}" to "${destFile}"...`);
        File.copy(archive, destFile);

        // modId
        ent = db.insertMod(ent);
        modMasterList = db.getMods();
        return ent;
    }

    function enableMods()
    {
        const entry = installedEntity(mainWin.currentGame);
        if( !entry )
        {
            console.log(`Cannot find game data info for '${mainWin.currentGame}'!`);
            return;
        }

        if( entry.enableMods() )
            statusBar.text = qsTr('Mods have been enabled for "%1".').arg(entry['name']);
        else
            statusBar.text = qsTr('An error happened when trying to enable mods for "%1".').arg(entry['name']);
    }

    function installMod(mod, cb)
    {
        let wrappedCB = function(result)
        {
            modTable.enabled = true;
            menuBar.enabled = true;
            if( cb )
                cb(result);
        }

        modTable.enabled = false;
        menuBar.enabled = false;

        console.log(`Installmod: ${JSON.stringify(mod,null,2)}`);
        let sobj = repeaterSettings.objFor(currentGame);
        const filepath = sobj.modsPath + '/' + mod['filename'];

        console.log(`Attempting to read manifest from fomod: ${filepath}`);
        manifestFromFomod(filepath, function(result) {
            if( false === result )
                return wrappedCB(false);

            if( !result['config'] )
                return wrappedCB( installBasicMod(mod) );

            wrappedCB( configureMod(mod, result) );
        });
    }

    function reinstallMod(mod)
    {
        uninstallMod(mod);
        installMod(mod);
    }

    function uninstallMod(mod)
    {
        let sobj = repeaterSettings.objFor(currentGame);
        const files = db.getFiles(mod['modId']);
        console.log(`Uninstalling "${mod['name']}"...`);

        if( mod['enabled'] )
            disableMod(mod);

        let toRemove = [];
        files.forEach( function(f) {
            const dpath = sobj.gamePath + '/' + currentGameEntry['datadir'] + '/' + f['dest'];
            console.log(`Deleting file "${f['dest']}" at "${dpath}"...`);
            File.rm(dpath, true);
            toRemove.push( f['fileId'] );
            //db.removeFile(f['fileId']);
        } );

        db.removeModFiles(mod['modId']);

        mod['installed'] = false;
        db.updateMod(mod);

        statusBar.text = qsTr('Mod "%1" has been uninstalled.').arg(mod['name']);
        modMasterList = db.getMods();
    }

    function deleteMod(mod)
    {
        if( mod['installed'] )
            uninstallMod(mod);

        let sobj = repeaterSettings.objFor(currentGame);
        const filepath = sobj.modsPath + '/' + mod['filename'];
        File.rm(filepath);

        db.removeMod(mod['modId']);

        statusBar.text = qsTr('Mod "%1" has been deleted.').arg(mod['name']);
        modMasterList = db.getMods();
    }

    function installFancyMod(mod, files, folders, modinfo, flags)
    {
        let sobj = repeaterSettings.objFor(currentGame);
        const filepath = sobj.modsPath + '/' + mod['filename'];

        const relative = modinfo['relative'];

        let addMaybe = function(to, ent)
        {
            if( !ent )
                return;

            if( !(ent instanceof Array) )
            {
                const nent = {};
                nent['source'] = ent['source'] ? ent['source']['Value'].replace(/\/\//g, '/') : '';
                nent['dest'] = ent['destination'] ? ent['destination']['Value'].replace(/\/\//g, '/') : '';
                nent['priority'] = ent['priority'] ? ent['priority']['Value'] : 0;
                to.push(nent);
                return;
            }

            ent.forEach( function(f) {
                const nent = {};
                nent['source'] = f['source'] ? f['source']['Value'].replace(/\/\//g, '/') : '';
                nent['dest'] = f['destination'] ? f['destination']['Value'].replace(/\/\//g, '/') : '';
                nent['priority'] = f['priority'] ? f['priority']['Value'] : 0;
                to.push(nent);
            } );
        }

        const cfi = modinfo['config']['config']['conditionalFileInstalls'];
        if( cfi && cfi['patterns'] && cfi['patterns']['pattern'] )
        {
            let conditions = cfi['patterns']['pattern'];
            if( !( conditions instanceof Array ) )
            {
                conditions = [ conditions ];
            }

            for( let a=0; a < conditions.length; a++ )
            {
                const cent = conditions[a]['dependencies'];
                console.log(`Condition ${a+1}: ${JSON.stringify(cent,null,2)}`);
                const op = cent['operator'] ? cent['operator']['Value'] : 'And';
                if( cent && cent['flagDependency'] )
                {
                    let fds = cent['flagDependency'];
                    if( !( fds instanceof Array ) )
                        fds = [fds];

                    let matchedConds = 0;
                    fds.forEach( function(fd) {
                        const flagn = fd['flag']['Value'];
                        const flagv = fd['value']['Value'];
                        console.log(`Checking condition: ${flagn} => ${flagv} vs. ${flags[flagn]}`);
                        if( flags[flagn] === flagv )
                            matchedConds++;
                    } );

                    if( op === 'And' && matchedConds < fds.length )
                        continue;
                    else if( op === 'Or' && matchedConds === 0 )
                        continue;

                    console.log("Pass.");
                    let condfiles = conditions[a]['files'];
                    if( !condfiles )
                        continue;

                    addMaybe(files, condfiles['file']);
                    addMaybe(folders, condfiles['folder']);
                }
            }
        }

        const rfi = modinfo['config']['config']['requiredInstallFiles'];
        if( rfi )
        {
            addMaybe(files, rfi['file']);
            addMaybe(folders, rfi['folder']);

            console.log(`Adding required files: ${JSON.stringify(rfi['file'])}`);
            console.log(`Adding required folders: ${JSON.stringify(rfi['folder'])}`);
        }

        if( !mod['archiveObject'] )
            mod['archiveObject'] = File.archive(filepath);

        mod['archiveObject'].list( function(result, filelist) {
            let fileMap = {};
            let toCommit = [];
            for( let c=0; c < files.length; c++ )
            {
                let f = files[c];
                const fdest = f['dest'].replace(/\/\//g, '/');
                const src = `${relative.length > 0 ? relative+"/" : ""}${f['source']}`.replace(/\/\//g, '/');
                const dpath = `${sobj.gamePath}/${currentGameEntry['datadir']}/${fdest}`;
                //console.log(`1: Extract "${src}" -> "${dpath}"`);

                if( !filelist.find( e => { return e['pathname'].toLowerCase() === src.toLowerCase() && e['type'] === 'file' } ) )
                {
                    console.log(` *** No files found for extraction for path: ${src}`);
                    continue;
                }

                console.log(`Extract "${src}" -> "${dpath}"`);
                fileMap[src] = dpath;

                f['source'] = src;
                f['dest'] = fdest;
                toCommit.push(f);
            }

            for( let c=0; c < folders.length; c++ )
            {
                let f = folders[c];
                const fdest = f['dest'].replace(/\/\//g, '/');
                const src = `${relative.length > 0 ? relative+"/" : ""}${f['source']}`;
                const dpath = `${sobj.gamePath}/${currentGameEntry['datadir']}/${fdest}`;
                //console.log(`1: Extract "${src}" -> "${dpath}"`);

                // const folderParts = f['source'].split(/\//g).filter( e => e.length > 0 && e !== '/' );
                const folderParts = src.split(/\//g).filter( e => e.length > 0 && e !== '/' );

                let extractedForPath = 0;

                // Handle directories, or as fomod calls them "folders":
                for( let d=0; d < filelist.length; d++ )
                {
                    const arcfile = filelist[d];
                    if( arcfile['type'] !== 'file' )
                        continue;

                    const arcParts = arcfile['pathname'].split(/\//g).filter( e => e.length > 0 && e !== '/' );

                    let matched = true;
                    for( let e=0; e < folderParts.length && matched; e++ )
                    {
                        if( folderParts[e].toLowerCase() !== arcParts[e].toLowerCase() )
                            matched = false;
                    }

                    //console.log(`Found that "${arcfile['path']}" ${matched ? "contains":"does not contain"} "${src}"`);
                    if( !matched ) continue;

                    const pathtail = arcfile['path'].substr( src.length );
                    const nsrc = (src + pathtail).replace(/\/\//g, '/');
                    const ndest = (dpath + pathtail).replace(/\/\//g, '/');
                    const recdest = (fdest + pathtail).replace(/\/\//g, '/');

                    console.log(`Extract "${nsrc}" -> "${ndest}"`);
                    fileMap[nsrc] = ndest;

                    //File.extractSourceDest(filepath, nsrc, ndest);
                    let nf = { 'source':nsrc, 'dest':recdest };
                    toCommit.push(nf);
                    extractedForPath++;
                }

                if( 0 === extractedForPath )
                    console.log(` *** No folders found for extraction for path: ${src}`);
            }

            // Avoid overwriting:
            const overwrites = checkOverwrites(fileMap);

            console.log(`DB committing files: ${JSON.stringify(toCommit,null,2)}`);

            let finished = function()
            {
                if( toCommit.length > 0 )
                    db.insertFiles(mod['modId'], toCommit);

                mod['installed'] = true;
                db.updateMod(mod);

                statusBar.text = qsTr('Mod "%1" has been installed.').arg(mod['name']);
                modMasterList = db.getMods();
            }

            if( Object.keys(fileMap).length > 0 )
                mod['archiveObject'].extract( fileMap, function(result, contents) {
                    if( result )
                        finished();
                }, function(sofar, total, latestSource, latestDest) {
                    console.log(`Extraction: ${sofar}/${total} \t${latestSource} \t=> ${latestDest}`);
                });
            else
                finished();
        } );
    }

    function installBasicMod(mod)
    {
        let sobj = repeaterSettings.objFor(currentGame);
        const filepath = sobj.modsPath + '/' + mod['filename'];

        if( !mod['archiveObject'] )
            mod['archiveObject'] = File.archive(filepath);

        mod['archiveObject'].list( function(result, filelist) {
            // If everything is in a subdirectory, the SAME subdirectory, the mod creator is killing us:
            let topdirs = [];
            filelist.forEach( function(e) {
                const p = e['pathname'].toLowerCase().split(/\//g);
                if( !topdirs.includes(p[0]) )
                    topdirs.push(p[0]);
            } );

            let inDataDir = true;
            filelist.forEach( function(e) {
                const p = e['pathname'].toLowerCase().split(/\//g);
                //console.log(`[TD=${topdirs.length}] Comparing "${p[0]}" with "${currentGameEntry['datadir'].toLowerCase()}"...`);
                if( inDataDir && topdirs.length !== 1 && p[0] === currentGameEntry['datadir'].toLowerCase() )
                    inDataDir = false;
                else if( inDataDir && topdirs.length === 1 && p[1] === currentGameEntry['datadir'].toLowerCase() )
                    inDataDir = false;
            } );

            let fileMap = {};
            let toCommit = [];
            for( let a=0; a < filelist.length; a++ )
            {
                let f = filelist[a];
                if( ''+f['type'] !== 'file' )
                    continue;

                let parts = f['pathname'].split(/\//g);
                const fpath = f['pathname'].replace(/\/\//g, '/');
                let fdpath = f['pathname'];

                if( topdirs.length === 1 )
                {
                    // Ex: "FNIS Behavior SE 7.6/Data/tools/GenerateFNIS_for_Users/GenerateFNISforUsers.exe"
                    //  -> "Data/tools/GenerateFNIS_for_Users/GenerateFNISforUsers.exe"
                    console.log("Mod author is possibly murdering me, Smalls.  Compensating...");
                    parts.shift();

                    fdpath = parts.join('/');
                }

                if( !inDataDir )
                //if( parts[0].toLowerCase() === currentGameEntry['datadir'].toLowerCase() )
                {
                    // Ex: "data/SKSE/Plugins/hdtSkinnedMeshConfigs/configs.xml"
                    //  -> "SKSE/Plugins/hdtSkinnedMeshConfigs/configs.xml"
                    console.log("Mod author is possibly killing me, Smalls.  Compensating...");
                    if( parts.length > 1 )
                        parts.shift();
                    else
                        parts.unshift('..'); // TODO: Maybe this should be sobj['gamePath']? For gamebryo this will work, though.

                    fdpath = parts.join('/');
                }

                const dpath = (sobj.gamePath + '/' + currentGameEntry['datadir'] + '/' + fdpath).replace(/\/\//g, '/');
                console.log(`Extract "${f['path']}" -> "${dpath}"`);
                fileMap[fpath] = dpath;
                //File.extractSourceDest(filepath, f['path'], dpath);
                toCommit.push( { 'source':fpath, 'dest':fdpath, 'priority':0 } )
            }

            let finished = function() {
                if( toCommit.length > 0 )
                    db.insertFiles(mod['modId'], toCommit);

                mod['installed'] = true;
                db.updateMod(mod);

                statusBar.text = qsTr('Basic mod "%1" has been installed.').arg(mod['name']);
                modMasterList = db.getMods();
            }

            if( Object.keys(fileMap).length > 0 )
                mod['archiveObject'].extract(fileMap, function(success, results) {
                    if( success )
                        finished();
                }, function(sofar, total, latestSource, latestDest) {
                    console.log(`Extraction: ${sofar}/${total} \t${latestSource} \t=> ${latestDest}`);
                });
            else
                finished();
        } );
    }

    function configureMod(mod, modinfo)
    {
        console.log(`Got: ${JSON.stringify(modinfo,null,2)}`);
        let steps = modinfo['config']['config']['installSteps']['installStep'];

        // Change objects to arrays of objects where it makes sense:
        if( !( steps instanceof Array ) )
            steps = [ steps ];

        steps.forEach( page => {
            page['uuid'] = Utils.uuid();
            page['selections'] = {};
            page['files'] = {};
            if( !( page['optionalFileGroups']['group'] instanceof Array ) )
                page['optionalFileGroups']['group'] = [ page['optionalFileGroups']['group'] ];
            page['optionalFileGroups']['group'].forEach( group => {
                if( !( group['plugins']['plugin'] instanceof Array ) )
                    group['plugins']['plugin'] = [ group['plugins']['plugin'] ];
            } );
        } );

        //console.log(JSON.stringify(steps,null,2));

        console.log(`Loaded config, launching...`);
        modConfigWindow.clear();
        modConfigWindow.m_mod = mod;
        modConfigWindow.m_modinfo = modinfo;
        modConfigWindow.m_rootPath = modinfo['root'];
        modConfigWindow.m_pages = steps;
        modConfigWindow.visible = true;
        modConfigWindow.flagsUpdated();
    }
}
