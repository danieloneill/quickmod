import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

import QtWebSockets

import Qt.labs.settings 1.0

import QtQuick.Dialogs

ApplicationWindow {
    id: mainWin
    width: 640
    height: 480
    visible: true
    title: qsTr("Quickmod")

    Material.theme: Material.Light

    menuBar: MenuBar {
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

    SplitView {
        anchors.fill: parent

        ModsTable {
            model: modMasterList
            onInstallMod: function(mod) { mainWin.installMod(mod); }
            onUninstallMod: function(mod) { mainWin.uninstallMod(mod); }
            onEnableMod: function(mod) { mainWin.enableMod(mod); }
            onDisableMod: function(mod) { mainWin.disableMod(mod); }
            onReinstallMod: function(mod) { mainWin.reinstallMod(mod); }
            onDeleteMod: function(mod) { mainWin.deleteMod(mod); }
        }
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

    Connections {
        target: NXMHandler
        function onDownloadRequested(path)
        {
            console.log(` >>> ${path} <<< `);

            const halves = path.substring(6).split('?');
            const mainInfo = halves[0].split(/\//g);
            const qparts = halves[1].split(/\&/g);

            let query = {};
            qparts.forEach( e => { const p = e.split('='); query[ p[0] ] = p[1]; } );

            console.log(`Info: ${JSON.stringify(mainInfo,null,2)}`);
            console.log(`QParts: ${JSON.stringify(qparts,null,2)}`);

            const reqUrl = `https://api.nexusmods.com/v1/games/${mainInfo[0]}/mods/${mainInfo[2]}/files/${mainInfo[4]}/download_link.json?key=${query['key']}&expires=${query['expires']}&user_id=${query['user_id']}`;
            console.log(reqUrl);

            const headers = { 'apiKey':settings.nexusApiKey };
            console.log(`Headers: ${JSON.stringify(headers,null,2)}`);
            HTTP.get(reqUrl, function(code, content) {
                console.log(`Result: Code=${code} / Content:${content}`);
                try {
                    const json = JSON.parse(content);
                    console.log("Json: "+JSON.stringify(json,null,2));
                    const fileUrl = json[0]['URI'];
                    console.log("URL: "+fileUrl);
                    const fileName = Utils.urlFilename(fileUrl);
                    console.log("Extrapolated filename: "+fileName);

                    let sobj = repeaterSettings.objFor(currentGame);
                    const destPath = sobj.modsPath + '/' + fileName;

                    HTTP.getFile(fileUrl, destPath, function(code, path) {
                        console.log(`Result: ${code}`);
                        if( 'OK' === code )
                            installFromFilesystem(destPath);
                    }, {});
                } catch(err) {
                    console.log(`Parse error: ${err}`);
                }
            }, headers);
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
    function configFromArchive(archive, target)
    {
        const raw = File.extract(archive, target);
        return FomodReader.readXMLFile( Utils.autoDecode(raw) );
    }

    function manifestFromFomod(filepath)
    {
        const filelist = File.archiveList(filepath);

        //console.log("CONTENTS: "+filelist);
        let pathInfo = filelist.find( (e) => e.path.endsWith('fomod/info.xml') );
        let pathConfig = filelist.find( (e) => e.path.endsWith('fomod/moduleconfig.xml') );

        if( !pathInfo || !pathConfig || pathInfo['type'] == 'dir' || pathConfig['type'] == 'dir' )
        {
            console.log(`Can't find a "fomod/info.xml" (or "fomod/moduleconfig.xml") file. This isn't a fomod.`);
            console.log(JSON.stringify(filelist,null,2));
            return false;
        }

        pathInfo = pathInfo['path'];
        pathConfig = pathConfig['path'];

        let result = {
            'root':filepath,
            'info':configFromArchive(filepath, pathInfo),
            'config':configFromArchive(filepath, pathConfig)
        };

        // Because some authors... well... it's not exactly a 'standard':
        result['relative'] = '';
        if( pathInfo.indexOf('fomod/info.xml') > 0 )
            result['relative'] = pathInfo.substring(0, pathInfo.length - ('/fomod/info.xml'.length));

        console.log("Relative: "+result['relative']+" for "+pathInfo);

        return result;
    }

    function installFromFilesystem(filepath)
    {
        let result = manifestFromFomod(filepath);
        if( !result || !result['info'] )
        {
            const baseName = filepath.split(/\//g).pop();
            let ent = { 'filename':'', 'installed':false, 'enabled':false, 'name':baseName, 'author':'Unknown', 'version':'??', 'website':'', 'description':'', 'groups':[] };
            return addMod2(filepath, ent)
        }

        return addMod(result);
    }

    FileDialog {
        id: fileDialog
        visible: false
        title: qsTr("Select a mod archive to install...")
        onAccepted: {
            const selections = fileDialog.selectedFiles;

            for( let a=0; a < selections.length; a++ )
            {
                const rawpath = ''+selections[a];
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
        if( !currentGame )
            return;

        loadForGame();

        settingsChanged();
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
            console.log(JSON.stringify(m_mod))
            console.log(JSON.stringify(m_files, null, 2));

            installFancyMod(m_mod, m_files, m_modinfo['relative']);
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
            const parts = f['dest'].split(/\//g);
            if( parts.length === 1 )
            {
                const baseName = parts.pop();
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
            property alias userDataPath: intobj.userDataPath

            Settings {
                id: intobj
                category: modelData['name']

                property bool enabled: false
                property string gamePath
                property string modsPath
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

        const mname = f['Name']['Characters'];
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

    function installMod(mod)
    {
        console.log(`Installmod: ${JSON.stringify(mod,null,2)}`);
        let sobj = repeaterSettings.objFor(currentGame);
        const filepath = sobj.modsPath + '/' + mod['filename'];

        console.log(`Attempting to read manifest from fomod: ${filepath}`);
        let result = manifestFromFomod(filepath);
        if( !result || !result['info'] )
            return installBasicMod(mod);

        configureMod(mod, result);
    }

    function installFancyMod(mod, files, relative)
    {
        let sobj = repeaterSettings.objFor(currentGame);
        const filepath = sobj.modsPath + '/' + mod['filename'];

        const filelist = File.archiveList(filepath);
        for( let a=0; a < files.length; a++ )
        {
            let f = files[a];
            const src = `${relative}/${f['source']}`.toLowerCase();
            const dpath = `${sobj.gamePath}/${currentGameEntry['datadir']}/${f['dest']}`;
            console.log(`1: Extract "${src}" -> "${dpath}"`);

            // Handle directories, or as fomod calls them "folders":
            for( let b=0; b < filelist.length; b++ )
            {
                const arcfile = filelist[b];

                console.log(`Check: ${arcfile['path']} vs. ${src}...`);

                // "/meshes/human/male/mesh.mesh" startsWith "/meshes/human"
                // "/test" startsWith "/test"
                if( arcfile['path'].startsWith(src) )
                {
                    const nsrc = src + arcfile['path'].substr( src.length );
                    const ndest = dpath + arcfile['path'].substr( src.length );
                    if( ''+arcfile['type'] === 'file' )
                    {
                        console.log(`2: Extract "${nsrc}" -> "${ndest}"`);
                        File.extractSourceDest(filepath, nsrc, ndest);
                        f['source'] = nsrc;
                        f['dest'] = ndest;
                        db.insertFile(mod['modId'], f);
                    }
                }
            }
        }

        mod['installed'] = true;
        db.updateMod(mod);

        statusBar.text = qsTr('Mod "%1" has been installed.').arg(mod['name']);
        modMasterList = db.getMods();
    }

    function installBasicMod(mod)
    {
        let sobj = repeaterSettings.objFor(currentGame);
        const filepath = sobj.modsPath + '/' + mod['filename'];

        const filelist = File.archiveList(filepath);
        for( let a=0; a < filelist.length; a++ )
        {
            let f = filelist[a];
            if( ''+f['type'] !== 'file' )
                continue;

            const dpath = sobj.gamePath + '/' + currentGameEntry['datadir'] + '/' + f['path'];
            console.log(`Extract "${f['path']}" -> "${dpath}"`);
            File.extractSourceDest(filepath, f['path'], dpath);
            db.insertFile(mod['modId'], { 'source':f['path'], 'dest':f['path'], 'priority':0 });
        }

        mod['installed'] = true;
        db.updateMod(mod);

        statusBar.text = qsTr('Basic mod "%1" has been installed.').arg(mod['name']);
        modMasterList = db.getMods();
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

        files.forEach( function(f) {
            const dpath = sobj.gamePath + '/' + currentGameEntry['datadir'] + '/' + f['dest'];
            console.log(`Deleting file "${dpath}"...`);
            File.rm(dpath);
            db.removeFile(f['fileId']);
        } );

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

    function configureMod(mod, modinfo)
    {
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
