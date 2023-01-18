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
    Plugins.readPlugins();
}

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

