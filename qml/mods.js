function manifestFromFomod(filepath, cb)
{
    console.log("manifestFromFomod: "+filepath);

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
                const raw = File.read(`${mainWin.m_tempPath}/fomod/info.xml`);
                result['info'] = FomodReader.readXMLFile( Utils.autoDecode(raw) );
            }
            if( pathConfig )
            {
                const raw = File.read(`${mainWin.m_tempPath}/fomod/moduleconfig.xml`);
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
            File.rmrecursive(`${mainWin.m_tempPath}/fomod`);
            File.mkdir(`${mainWin.m_tempPath}/fomod`, false);
            let toExtract = {};
            filelist.forEach(function(e) {
                if( e['type'] === 'file' && e['pathname'].toLowerCase().startsWith(fomodLow) )
                    toExtract[ e['pathname'] ] = `${mainWin.m_tempPath}/fomod/${ e['pathname'].substring(fomodDir.length+1).toLowerCase() }`;
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
    if( !cb )
        cb = function(result) { console.log("installFromFilesystem finished: "+result); }

    try {
        let pathArray = filepath.split(/\//g);
        let baseName = filepath;
        if( pathArray.length > 0 )
            baseName = pathArray.pop();

        statusBar.text = qsTr("Installing \"%1\"...").arg(baseName);

        manifestFromFomod(filepath, function(result) {
            if( false === result )
            {
                statusBar.text = qsTr("Error reading archive: %1").arg(filepath);
                cb(false);
                return;
            }

            if( !result['config'] || !result['info'] )
            {
                let ent = { 'filename':'', 'installed':false, 'enabled':false, 'name':baseName, 'author':'Unknown', 'version':'??', 'website':'', 'description':'', 'groups':[] };
                if( result['info'] )
                {
                    if( result['info']['fomod']['Name']['Characters'] )
                        ent['name'] = result['info']['fomod']['Name']['Characters'];

                    ent['author'] = result['info']['fomod']['Author']['Characters'];
                    ent['version'] = result['info']['fomod']['Version']['Characters'];
                    ent['description'] = result['info']['fomod']['Description']['Characters'];
                }

                statusBar.text = qsTr("Added basic mod \"%1\".").arg(filepath);
                cb( addMod2(filepath, ent) );
                return;
            }

            statusBar.text = qsTr("Added mod \"%1\".").arg(filepath);
            cb( addMod(result) );
        });
    } catch(err) { console.log("ERROR: "+err); }
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

function enableMod(mod)
{
    let sobj = gameSettings.objFor(currentGame);
    const files = db.getFiles(mod['modId']);
    console.log(`Enabling "${mod['name']}"...`);

    let updatePlugins = false;
    let plugins = Plugins.readPlugins();
    let loadorder = Plugins.readLoadOrder();
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
        else if( baseNameLC.endsWith(".esl") || baseNameLC.endsWith(".esp") )
        {
            plugins['normal'].push(ent);
            loadorder['normal'].push(baseName);
            updatePlugins = true;
        }
    });

    if( updatePlugins )
    {
        Plugins.writePlugins(plugins);
        Plugins.writeLoadOrder(loadorder);
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
    let sobj = gameSettings.objFor(currentGame);
    const files = db.getFiles(mod['modId']);
    console.log(`Disabling "${mod['name']}"...`);

    let updatePlugins = false;
    let plugins = Plugins.readPlugins();
    let loadorder = Plugins.readLoadOrder();
    files.forEach( function(f) {
        const parts = f['dest'].split(/\//g);
        if( parts.length === 1 )
        {
            const baseName = parts.pop();

            ['masters', 'normal'].forEach( function(sec) {
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
        Plugins.writePlugins(plugins);
        Plugins.writeLoadOrder(loadorder);
    }

    statusBar.text = qsTr('Disabled "%1".').arg(mod['name']);

    mod['enabled'] = false;
    db.updateMod(mod);
    modMasterList = db.getMods();
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
    let sobj = gameSettings.objFor(currentGame);
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

    statusBar.text = qsTr('Please wait, working...');

    console.log(`Installmod: ${JSON.stringify(mod,null,2)}`);
    let sobj = gameSettings.objFor(currentGame);
    const filepath = sobj.modsPath + '/' + mod['filename'];

    console.log(`Attempting to read manifest from fomod: ${filepath}`);
    manifestFromFomod(filepath, function(result) {
        statusBar.text = '';
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
    let sobj = gameSettings.objFor(currentGame);
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

    let sobj = gameSettings.objFor(currentGame);
    const filepath = sobj.modsPath + '/' + mod['filename'];
    File.rm(filepath);

    db.removeMod(mod['modId']);

    statusBar.text = qsTr('Mod "%1" has been deleted.').arg(mod['name']);
    modMasterList = db.getMods();
}

function installFancyMod(mod, files, folders, modinfo, flags)
{
    let sobj = gameSettings.objFor(currentGame);
    const filepath = sobj.modsPath + '/' + mod['filename'];

    const relative = modinfo['relative'];

    let addMaybe = function(to, ent)
    {
        if( !ent )
            return;

        if( !(ent instanceof Array) )
        {
            const nent = {};
            nent['source'] = ent['source'] ? ent['source']['Value'].replace(/\/\//g, '/').replace(/\\/g, '/') : '';
            nent['dest'] = ent['destination'] ? ent['destination']['Value'].replace(/\/\//g, '/').replace(/\\/g, '/') : '';
            nent['priority'] = ent['priority'] ? ent['priority']['Value'] : 0;
            to.push(nent);
            return;
        }

        ent.forEach( function(f) {
            const nent = {};
            nent['source'] = f['source'] ? f['source']['Value'].replace(/\/\//g, '/').replace(/\\/g, '/') : '';
            nent['dest'] = f['destination'] ? f['destination']['Value'].replace(/\/\//g, '/').replace(/\\/g, '/') : '';
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
            const sourceParts = f['source'].split(/\//g);
            let destParts = f['dest'].split(/\//g);

            console.log(` .-> "${sourceParts.join(' / ')}"`);
            console.log(` '-> "${destParts.join(' / ')}"`);

            let fdest = f['dest'].replace(/\/\//g, '/');
            if( fdest.length === 0 )
                fdest = sourceParts[ sourceParts.length-1 ];

            const src = `${relative.length > 0 ? relative+"/" : ""}${f['source']}`;
            const dpath = `${sobj.gamePath}/${currentGameEntry['datadir']}/${fdest}`;
            console.log(`1: Extract "${src}" -> "${dpath}"`);

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
            const fdest = f['dest'].replace(/\/\//g, '/').replace(/\\/g, '/');
            const src = `${relative.length > 0 ? relative+"/" : ""}${f['source']}`.replace(/\\/g, '/');
            const dpath = `${sobj.gamePath}/${currentGameEntry['datadir']}/${fdest}`;
            console.log(`1: Extract "${src}" -> "${dpath}"`);

            // const folderParts = f['source'].split(/\//g).filter( e => e.length > 0 && e !== '/' );
            const folderParts = src.split(/\//g).filter( e => e.length > 0 && e !== '/' );

            let extractedForPath = 0;

            // Handle directories, or as fomod calls them "folders":
            for( let d=0; d < filelist.length; d++ )
            {
                const arcfile = filelist[d];
                //console.log("Checking "+arcfile['pathname']+"...");
                if( arcfile['type'] !== 'file' )
                    continue;

                const arcParts = arcfile['pathname'].split(/\//g).filter( e => e.length > 0 && e !== '/' );

                let matched = true;
                for( let e=0; e < folderParts.length && matched; e++ )
                {
                    if( folderParts[e].toLowerCase() !== arcParts[e].toLowerCase() )
                        matched = false;
                }

                //console.log(`Found that "${folderParts.join(' / ')}" ${matched ? "contains":"does not contain"} "${arcParts.join(' / ')}"`);
                if( !matched ) continue;

                const pathtail = arcfile['pathname'].substr( src.length );
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
            extractFileMap(mod, fileMap, finished);
        else
            finished();
    } );
}

function extractFileMap(mod, fileMap, successCallback)
{
    let cancelled = false;
    const funcCancel = function() {
        cancelled = true;
        handle.stop();
        console.log("Extraction cancelled.");
    };

    extractProgress.title = 'Extracting...';
    extractProgress.value = 0;
    extractProgress.to = 0;
    extractProgress.text = '';
    extractProgress.showCancel = true;
    let handle = mod['archiveObject'].extract( fileMap, function(result, contents) {
        extractProgress.close();
        extractProgress.cancel.disconnect( funcCancel );
        if( cancelled )
            return;

        if( result )
            successCallback();
    }, function(sofar, total, latestSource, latestDest) {
        extractProgress.value = sofar;
        extractProgress.to = total;
        extractProgress.text = qsTr('Extracted "%1"').arg(latestDest);
        console.log(`Extraction: ${sofar}/${total} \t${latestSource} \t=> ${latestDest}`);
    });

    extractProgress.cancel.connect( funcCancel );
    extractProgress.open();
}

function installBasicMod(mod)
{
    let sobj = gameSettings.objFor(currentGame);
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
            console.log(`Extract "${f['pathname']}" -> "${dpath}"`);
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
            extractFileMap(mod, fileMap, finished);
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
