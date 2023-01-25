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

        let q = conn.query("CREATE TABLE IF NOT EXISTS mods(modId INTEGER PRIMARY KEY NOT NULL, nexusGameCode TEXT, nexusId INTEGER, nexusFileId INTEGER, name TEXT NOT NULL, author TEXT, version VARCHAR(32), website TEXT, description TEXT, groups TEXT, installed INT NOT NULL DEFAULT 0, enabled INT NOT NULL DEFAULT 0, filename TEXT)", []);
        q.destroy();

        q = conn.query("CREATE TABLE IF NOT EXISTS files(fileId INTEGER PRIMARY KEY NOT NULL, modId INTEGER NOT NULL, relative TEXT, source TEXT, dest TEXT, priority INTEGER)", []);
        q.destroy();

        q = conn.query("CREATE TABLE IF NOT EXISTS selections(modId INTEGER UNIQUE NOT NULL, json TEXT)", []);
        q.destroy();

        if( !upgradeIfNeeded() )
        {
            q = conn.query("CREATE TABLE IF NOT EXISTS version(version INTEGER NOT NULL)", []);
            q.destroy();

            q = conn.query("INSERT OR REPLACE INTO version (version)VALUES(1)", []);
            q.destroy();
        }
    }

    function upgradeIfNeeded()
    {
        try {
            let q = conn.query("SELECT version FROM version", []);
            let v = q.toArray();
            q.destroy();

            if( v.length === 1 )
            {
                if( v[0]['version'] === 1 )
                    return true;

                console.log(`This database version (${v[0]['version']}) isn't one I'm aware of, probably made with a newer version of quickmod.`);
                return true;
            }
        } catch(err) {
            console.log("No version table, probably version 0.");
        }

        try {
            // We're on version 0.
            let nq = conn.query( "ALTER TABLE mods DROP COLUMN nexusId", []);
            nq.destroy();

            nq = conn.query( "ALTER TABLE mods ADD COLUMN nexusId INTEGER", []);
            nq.destroy();

            nq = conn.query( "ALTER TABLE mods ADD COLUMN nexusFileId INTEGER", []);
            nq.destroy();

            nq = conn.query( "ALTER TABLE mods ADD COLUMN nexusGameCode TEXT", []);
            nq.destroy();
        } catch(err) {
            console.log("Failed to upgrade to version 1, so we probably have no database.");
        }

        return false; // Because we didn't have a version table.
    }

    // Mods
    function getMods()
    {
        if( !checkConnection ) return;

        let q = conn.query("SELECT modId, name, nexusGameCode, nexusId, nexusFileId, author, version, website, description, groups, enabled, installed, filename FROM mods");
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

        let q = conn.query("UPDATE mods SET nexusGameCode=?, nexusId=?, nexusFileId=?, name=?, author=?, version=?, website=?, description=?, groups=?, installed=?, enabled=?, filename=? WHERE modId=?",
                               [modinfo['nexusGameCode'], modinfo['nexusId'], modinfo['nexusFileId'], modinfo['name'], modinfo['author'], modinfo['version'], modinfo['website'], modinfo['description'], tgroups, modinfo['installed'], modinfo['enabled'], modinfo['filename'], modinfo['modId']]);
        q.destroy();
    }

    function insertMod(modinfo)
    {
        if( !checkConnection ) return;

        const tgroups = JSON.stringify(modinfo['groups']);

        let q = conn.query("INSERT INTO mods (nexusGameCode, nexusId, nexusFileId, name, author, version, website, description, groups, installed, enabled, filename)VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                               [modinfo['nexusGameCode'], modinfo['nexusId'], modinfo['nexusFileId'], modinfo['name'], modinfo['author'], modinfo['version'], modinfo['website'], modinfo['description'], tgroups, modinfo['installed'], modinfo['enabled'], modinfo['filename']]);
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

    function getFilesByDests(dests)
    {
        if( !checkConnection ) return;

        let qstr = "SELECT fileId, modId, relative, source, dest, priority FROM files";
        let token = ' WHERE ';
        let args = [];

        // I has feels this is gonna get beat tf up...
        dests.forEach( function(d) {
            qstr += token + "dest=?";
            token = ' OR ';
            args.push(d);
        } );

        let q = conn.query(qstr, args);
        const results = q.toArray();
        q.destroy();

        return results;
    }

    function getFilesEndingWith(suffixes)
    {
        if( !checkConnection ) return;

        let qstr = "SELECT fileId, modId, relative, source, dest, priority FROM files";
        let token = ' WHERE ';
        let args = [];

        // I has feels this is gonna get beat tf up...
        suffixes.forEach( function(d) {
            qstr += token + "dest LIKE '%' || ?";
            token = ' OR ';
            args.push(d);
        } );

        let q = conn.query(qstr, args);
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
