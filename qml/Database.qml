import QtQuick 2.15

import org.ONeill.Sql 1.0

Item {
    SqlDatabase {
        id: sql
    }

    property var conn

    function open(path) {
        if( conn )
            close();

        console.log('Opening DB: '+path);
        conn = sql.open('QSQLITE', path, {});
        console.log(`Result: ${conn.ping()}`);

        updateDatabase();
    }

    function close() {
        if( !conn )
            return;

        conn.close();
        conn = false;
    }

    function checkConnection()
    {
        if( !conn )
        {
            console.log(`Don't be a turdburglar, you isn't connectorated to no datumbass.`);
            return false;
        }
        return true;
    }

    function updateDatabase()
    {
        if( !checkConnection ) return;

        if( !conn )
        {
            console.log(`Don't be a turdburglar, you isn't connectorated to no datumbass.`);
            return false;
        }

        let q = conn.query("CREATE TABLE IF NOT EXISTS mods(modId INTEGER PRIMARY KEY NOT NULL, nexusId TEXT, name TEXT NOT NULL, author TEXT, version VARCHAR(32), website TEXT, description TEXT, groups TEXT, installed INT NOT NULL DEFAULT 0, enabled INT NOT NULL DEFAULT 0, filename TEXT)", []);
        q.destroy();

        q = conn.query("CREATE TABLE IF NOT EXISTS files(fileId INTEGER PRIMARY KEY NOT NULL, modId INTEGER NOT NULL, relative TEXT, source TEXT, dest TEXT, priority INTEGER)", []);
        q.destroy();

        q = conn.query("CREATE TABLE IF NOT EXISTS selections(modId INTEGER UNIQUE NOT NULL, json TEXT)", []);
        q.destroy();
    }

    // Mods
    function getMods()
    {
        if( !checkConnection ) return;

        let q = conn.query("SELECT modId, name, nexusId, author, version, website, description, groups, enabled, installed, filename FROM mods");
        const results = q.toArray();
        q.destroy();

        results.map( function(m) {
            if( m['groups'].length > 0 )
                m['groups'] = JSON.parse(m['groups']);
            else m['groups'] = [];
        } );

        return results;
    }

    function updateMod(modinfo)
    {
        if( !checkConnection ) return;

        const tgroups = JSON.stringify(modinfo['groups']);

        let q = conn.query("UPDATE mods SET nexusId=?, name=?, author=?, version=?, website=?, description=?, groups=?, installed=?, enabled=?, filename=? WHERE modId=?",
                               [modinfo['nexusId'], modinfo['name'], modinfo['author'], modinfo['version'], modinfo['website'], modinfo['description'], tgroups, modinfo['installed'], modinfo['enabled'], modinfo['filename'], modinfo['modId']]);
        q.destroy();
    }

    function insertMod(modinfo)
    {
        if( !checkConnection ) return;

        const tgroups = JSON.stringify(modinfo['groups']);

        let q = conn.query("INSERT INTO mods (nexusId, name, author, version, website, description, groups, installed, enabled, filename)VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                               [modinfo['nexusId'], modinfo['name'], modinfo['author'], modinfo['version'], modinfo['website'], modinfo['description'], tgroups, modinfo['installed'], modinfo['enabled'], modinfo['filename']]);
        modinfo['modId'] = q.lastInsertId();
        q.destroy();

        return modinfo;
    }

    function removeMod(modId)
    {
        if( !checkConnection ) return;

        let q = conn.query("DELETE FROM mods WHERE modId=?", [modId]);
        q.destroy();
    }

    // Files
    function getFiles(modId)
    {
        if( !checkConnection ) return;

        let q = conn.query("SELECT fileId, modId, relative, source, dest, priority FROM files WHERE modId=?", [modId]);
        const results = q.toArray();
        q.destroy();

        return results;
    }

    function insertFile(modId, fileInfo)
    {
        if( !checkConnection ) return;

        let q = conn.query("INSERT INTO files (modId, relative, source, dest, priority)VALUES(?, ?, ?, ?, ?)",
                               [modId, fileInfo['relative'], fileInfo['source'], fileInfo['dest'], fileInfo['priority']]);
        fileInfo['fileId'] = q.lastInsertId();
        q.destroy();

        return fileInfo;
    }

    function insertFiles(modId, fileInfos)
    {
        if( !checkConnection ) return;

        let q = conn.query("BEGIN DEFERRED TRANSACTION", []);
        q.destroy();
        fileInfos.forEach( function(fileInfo) {
            q = conn.query("INSERT INTO files (modId, relative, source, dest, priority)VALUES(?, ?, ?, ?, ?)",
                                   [modId, fileInfo['relative'], fileInfo['source'], fileInfo['dest'], fileInfo['priority']]);
            q.destroy();
        } );
        q = conn.query("COMMIT TRANSACTION");
        q.destroy();

        return true;
    }

    function removeFile(fileId)
    {
        if( !checkConnection ) return;

        let q = conn.query("DELETE FROM files WHERE fileId=?", [fileId]);
        q.destroy();
    }

    function removeModFiles(modId)
    {
        if( !checkConnection ) return;

        let q = conn.query("DELETE FROM files WHERE modId=?", [modId]);
        q.destroy();
    }

    function removeFiles(fileIds)
    {
        if( !checkConnection ) return;

        let q = conn.query("BEGIN DEFERRED TRANSACTION", []);
        q.destroy();
        fileIds.forEach( function(fileId) {
            let q = conn.query("DELETE FROM files WHERE fileId=?", [fileId]);
            q.destroy();
        } );
        q = conn.query("COMMIT TRANSACTION");
        q.destroy();

        return true;
    }

    // Selections
    function getSelections(modId)
    {
        if( !checkConnection ) return;

        let q = conn.query("SELECT json FROM selections WHERE modId=?", [modId]);
        const results = q.toArray();
        q.destroy();

        return results[0]['json'];
    }

    function updateSelections(modId, json)
    {
        if( !checkConnection ) return;

        let q = conn.query("REPLACE INTO selections (modId, json)VALUES(?, ?)", [json, modId]);
        q.destroy();
    }

    function clearSelections(modId)
    {
        if( !checkConnection ) return;

        let q = conn.query("DELETE FROM selections WHERE modId=?", [modId]);
        q.destroy();
    }
}
