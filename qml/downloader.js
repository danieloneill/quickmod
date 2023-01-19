let m_downloading = false;
let m_downloadQueue = [];

function downloadNext()
{
    m_downloading = false;
    if( m_downloadQueue.length > 0 )
    {
        const f = m_downloadQueue.shift();
        mainWin.downloadFile(f);
    }
}
function downloadFile(path)
{
    if( m_downloading )
    {
        m_downloadQueue.push(path);
        downloadProgress.queue = m_downloadQueue;
        return;
    }

    m_downloading = true;

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
        if( code === 'OK' )
        {
            let json = {};
            try {
                json = JSON.parse(content);
            } catch(err) {
                console.log(`Parse error: ${err}`);
                return downloadNext();
            }

            console.log("Json: "+JSON.stringify(json,null,2));
            const fileUrl = json[0]['URI'];
            console.log("URL: "+fileUrl);
            const fileName = Utils.urlFilename(fileUrl);
            console.log("Extrapolated filename: "+fileName);

            let sobj = gameSettings.objFor(currentGame);
            const destPath = sobj.modsPath + '/' + fileName;

            let cancelled = false;
            const funcCancel = function() {
                cancelled = true;
                handle.stop();
                console.log("Download cancelled.");
                downloadNext();
            };
            const funcCancelAll = function() {
                cancelled = true;
                handle.stop();
                downloadProgress.close();
                console.log("All downloads cancelled.");
            };

            downloadProgress.queue = m_downloadQueue;
            downloadProgress.value = 0;
            downloadProgress.to = 0;
            downloadProgress.text = fileName;
            const handle = HTTP.getFile(fileUrl, destPath, function(code, path, tot) {
                console.log(`Result: ${code}`);
                if( !cancelled && 'OK' === code )
                {
                    downloadProgress.close();
                    console.log("Download complete. Installing...");
                    Mods.installFromFilesystem(destPath);
                } else if( !cancelled ) {
                    console.log("Download error: "+code);
                    downloadProgress.close();
                }

                downloadProgress.cancel.disconnect( funcCancel );
                downloadProgress.cancelAll.disconnect( funcCancelAll );
                downloadNext();
            }, headers, function(val, tot) {
                downloadProgress.to = tot;
                downloadProgress.value = val;
            } );
            downloadProgress.showCancel = true;
            downloadProgress.cancel.connect( funcCancel );
            downloadProgress.cancelAll.connect( funcCancelAll );
            downloadProgress.open();
        } else
            downloadNext();
    }, headers);
}
