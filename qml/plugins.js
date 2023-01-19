
function readLoadOrder()
{
    let sobj = gameSettings.objFor(currentGame);
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

    let sobj = gameSettings.objFor(currentGame);
    const adroot = `${sobj.userDataPath}/${currentGameEntry['appdir']}`;
    const pluginspath = `${adroot}/${currentGameEntry['plugins']}`;
    File.write(pluginspath, res);

    return res;
}
