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

