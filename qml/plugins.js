
function readLoadOrder()
{
    let sobj = gameSettings.objFor(currentGame);
    const adroot = `${sobj.userDataPath}/${currentGameEntry['appdir']}`;
    const pluginspath = `${adroot}/${currentGameEntry['loadorder']}`;
    const raw = ''+File.read(pluginspath);
    //console.log(`Reading "${pluginspath}": ${raw}`);

    const lines = raw.split('\r\n');
    //console.log(`Lines: ${JSON.stringify(lines,null,0)}`);

    let register = {};

    let ents = { 'masters':[], 'normal':[] };
    for( let a=0; a < lines.length; a++ )
    {
        const l = lines[a];
        if( l.length < 4 )
            continue;

        if( l.substring(0,1) === '#' )
            continue;

        const llc = l.toLowerCase();
        if( register[llc] )
            continue;
        register[llc] = true;

        if( llc.endsWith(".esm") )
            ents['masters'].push(l);
        else if( llc.endsWith(".esl") )
            ents['normal'].push(l);
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
    ['masters', 'normal'].forEach( function(sec) {
        loadorder[sec].forEach( function(ent) {
            output.push(`${ent}`);
        } );
    });
    const res = output.join("\r\n");
    console.log("Writing: "+res);

    let sobj = gameSettings.objFor(currentGame);
    const adroot = `${sobj.userDataPath}/${currentGameEntry['appdir']}`;
    const lopath = `${adroot}/${currentGameEntry['loadorder']}`;
    File.write(lopath, res);

    return res;
}

function readPlugins()
{
    let sobj = gameSettings.objFor(currentGame);
    const adroot = `${sobj.userDataPath}/${currentGameEntry['appdir']}`;
    const pluginspath = `${adroot}/${currentGameEntry['plugins']}`;
    const raw = ''+File.read(pluginspath);
    //console.log(`Reading "${pluginspath}": ${raw}`);

    const lines = raw.split('\r\n');
    //console.log(`Lines: ${JSON.stringify(lines,null,0)}`);

    let register = {};

    let plugins = { 'masters':[], 'normal':[] };
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

        if( register[llc] )
            continue;
        register[llc] = true;

        if( llc.endsWith(".esm") )
            plugins['masters'].push(nent);
        else if( llc.endsWith(".esl") )
            plugins['normal'].push(nent);
        else if( llc.endsWith(".esp") )
            plugins['normal'].push(nent);
        else
            console.log(` *** I don't know what to do with this entry: "${l}"`);
    }

    plugins = scanForLoose(plugins);


    ['masters', 'normal'].forEach( function(sec) {
        plugins[sec].forEach( function(ent) {
            // Read plugin info:
            const pluginPath = `${sobj.gamePath}/${currentGameEntry['datadir']}/${ent['filename']}`;
            let info = ModReader.readSkyrimMod(pluginPath);
            ent["plugin"] = info;
            //console.log(pluginPath+": "+JSON.stringify(info,null,2));
        } );
    } );

    delete register;
    let inorder = [];
    ['masters', 'normal'].forEach( function(sec) {
        plugins[sec].forEach( function(ent) {
            const lcfname = ent['filename'].toLowerCase();

            inorder.push(lcfname);

            if( ent['plugin'] )
            {
                if( ent['plugin']['masters'] )
                {
                    ent['plugin']['masters'].forEach( function(m) {
                        const lcm = m.toLowerCase();
                        if( !inorder.includes(lcm) )
                        {
                            console.log(`Can't find ${lcm} in ${JSON.stringify(inorder)}`);
                            if( !ent['missing'] )
                                ent['missing'] = [ m ];
                            else
                                ent['missing'].push(m);
                        }
                    } );
                }

                if( ent['plugin']['description'] )
                    ent['description'] = ent['plugin']['description'];
            }

            console.log(`${ent['filename']}: ${JSON.stringify(ent['plugin'],null,2)}`);

        } );
    } );

    updatePluginsTable(plugins);

    //console.log(`Plugins: ${JSON.stringify(plugins,null,2)}`);
    return plugins;
}

function writePlugins(plugins)
{
    let output = ["# Generated by Quickmod"];
    ['masters', 'normal'].forEach( function(sec) {
        plugins[sec].forEach( function(ent) {
            output.push(`${ ent['enabled'] ? '*' : '' }${ent['filename']}`);
        } );
    });
    const res = output.join("\r\n");
    console.log("Writing: "+res);

    let sobj = gameSettings.objFor(currentGame);
    const adroot = `${sobj.userDataPath}/${currentGameEntry['appdir']}`;
    const pluginspath = `${adroot}/${currentGameEntry['plugins']}`;
    File.write(pluginspath, res);

    updatePluginsTable(plugins);

    return res;
}

function scanForLoose(plugins)
{
    let sobj = gameSettings.objFor(currentGame);
    const path = `${sobj.gamePath}/${currentGameEntry['datadir']}`;
    const contents = File.dirContents(path);
    if( !contents )
        return plugins; // ... weird?

    const normalsLC = plugins['normal'].map( e => e['filename'].toLowerCase() );
    const mastersLC = plugins['masters'].map( e => e['filename'].toLowerCase() );

    for( let x=0; x < contents.length; x++ )
    {
        const ent = contents[x];
        const lcfn = ent['fileName'].toLowerCase();
        if( lcfn.endsWith('.esl') || lcfn.endsWith('.esp') )
        {
            if( !normalsLC.includes(lcfn) )
            {
                // ...append them.
                let nent = { 'enabled':false, 'filename':ent['fileName'] };
                plugins['normal'].push(nent);
                normalsLC.push(lcfn);
            }
        }
        else if( lcfn.endsWith('.esm') )
        {
            if( !mastersLC.includes(lcfn) )
            {
                // ...append them.
                let nent = { 'enabled':false, 'filename':ent['fileName'] };
                plugins['masters'].push(nent);
                mastersLC.push(lcfn);
            }
        }
    }

    return plugins;
}

function disableMod(mod)
{
    let plugins = readPlugins();
    ['masters', 'normal'].forEach( function(sec) {
        plugins[sec].forEach( function(ent) {
            console.log(`Comp: ${ent['filename']} => ${mod['filepath']}`);
            if( ent['filename'] === mod['filepath'] )
                ent['enabled'] = false;
        } );
    } );
    writePlugins(plugins);
    updatePluginsTable(plugins);
}

function enableMod(mod)
{
    let plugins = readPlugins();
    ['masters', 'normal'].forEach( function(sec) {
        plugins[sec].forEach( function(ent) {
            if( ent['filename'] === mod['filepath'] )
                ent['enabled'] = true;
        } );
    } );
    writePlugins(plugins);
    updatePluginsTable(plugins);
}

function updatePluginsTable(plugins)
{
    // Let's get hairy...
    let mods = db.getMods();
    let files = {};
    mods.forEach( function(mod) {
        files[mod['modId']] = db.getFiles(mod['modId']);
    } );

    let model = [];
    ['masters', 'normal'].forEach( function(sec) {
        plugins[sec].forEach( function(ent) {
            let nent = { 'enabled':ent['enabled'], 'filepath':ent['filename'], 'name':'???', 'description':'???' };

            if( ent['description'] )
                nent['description'] = ent['description'];

            if( ent['missing'] )
                nent['missing'] = ent['missing'];

            if( !ent['plugin'] )
                nent['notfound'] = true;

            let done = false;
            for( let a=0; a < mods.length && !done; a++ )
            {
                const mod = mods[a];
                const fent = files[mod['modId']];
                for( let b=0; b < fent.length && !done; b++ )
                {
                    const f = fent[b];
                    if( f['dest'].endsWith(ent['filename']) )
                    {
                        nent['name'] = mod['name'];
                        nent['description'] = mod['description'];
                        done = true;
                    }
                }
            }

            model.push(nent);
        } );
    } );

    pluginsTable.model = model;
}
