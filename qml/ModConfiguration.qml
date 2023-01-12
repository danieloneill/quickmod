import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Window {
    id: modConfigWindow
    title: qsTr('Module Configuration')
    width: 800
    height: 600

    property var m_mod: ({})
    property var m_modinfo: ({})
    property var m_files: []

    property string m_rootPath
    property alias m_page: modConfigPager.currentIndex
    //readonly property int m_pageCount: FomodConfigModel.length
    //readonly property int m_pageCount: m_pages ? m_pages.length : 0
    readonly property int m_pageCount: m_pagesToDisplay ? m_pagesToDisplay.length : 0
    property variant m_pages
    property variant m_pagesToDisplay: m_pages
    property variant m_flags
    property variant m_selections: ({})

    signal readyForInstall()

    function clear()
    {
        m_mod = {};
        m_modinfo = {};
        m_files = [];
        m_rootPath = '';
        m_page = 0;
        m_pages = [];
        m_pagesToDisplay = [];
        m_flags = {};
        m_selections = {};
        flagsUpdated();
    }

    function flagsUpdated()
    {
        let a;
        for( a=0; a < m_pages.length; a++ )
        {
            m_pages[a]['pageEnabled'] = true;
            let p = m_pages[a];

            if( !p['visible'] )
                continue;

            p = p['visible'];
            if( !p['dependencies'])
                continue;

            p = p['dependencies'];
            if( !p['flagDependency'])
                continue;

            p = p['flagDependency'];
            if( !(p instanceof Array) )
                p = [p];

            for( let b=0; b < p.length; b++ )
            {
                const f = p[b];
                if( modConfigWindow.m_flags[ f['flag']['Value'] ] !== f['value']['Value'] )
                    m_pages[a]['pageEnabled'] = false;
            }
        }

        console.log(`Flags: ${JSON.stringify(modConfigWindow.m_flags)}`);
        let newPages = [];
        for( a=0; a < m_pages.length; a++ )
        {
            //console.log(`Page ${a+1} is ${ m_pages[a]['pageEnabled'] ? 'enabled':'disabled'}`);
            if( m_pages[a]['pageEnabled'] )
                newPages.push( m_pages[a] );
        }

        m_pagesToDisplay = newPages;
    }

    function storeFiles()
    {
        console.log( (new Error()).stack );

        let files = [];
        const entfiles = Object.keys(modConfigPager.currentItem.m_files);
        entfiles.forEach( function(skey) {
            let sels = modConfigPager.currentItem.m_files[skey];
            console.log(`SELS: ${JSON.stringify(sels)}`);
            if( sels )
            {
                if( !(sels instanceof Array) )
                    sels = [sels];

                sels.forEach( function(file) {
                    let fent = {};
                    if( file['source'] )
                        fent['source'] = file['source']['Value'];

                    if( file['destination'] )
                        fent['destination'] = file['destination']['Value'];

                    if( file['priority'] )
                        fent['priority'] = parseInt(file['priority']['Value']);

                    files.push(fent);
                } );
            }
        });

        // This is a display page, find the original:
        let a;
        const targetUUID = m_pagesToDisplay[ modConfigPager.currentIndex ]['uuid'];
        for( a=0; a < m_pages.length; a++ )
        {
            if( m_pages[a]['uuid'] === targetUUID )
            {
                modConfigWindow.m_pages[ a ]['files'] = files;
                break;
            }
        }

        for( a=0; a < m_pages.length; a++ )
            console.log( `Files for page #${a+1} => ${JSON.stringify(modConfigWindow.m_pages[a]['files'])}` );
    }

    function storeFlags()
    {
        const flagset = modConfigPager.currentItem.m_flagsToSet;
        const keys = Object.keys( flagset );
        keys.forEach( function(e) {
            modConfigWindow.m_flags[ e ] = flagset[e];
        } );
        modConfigWindow.flagsUpdated();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10

        Label {
            text: qsTr("Step %1 of %2%3").arg(modConfigWindow.m_page+1).arg(modConfigWindow.m_pageCount).arg( modConfigPager.currentItem && modConfigPager.currentItem.title ? ` - ${modConfigPager.currentItem.title}` : '' )
            Layout.fillWidth: true
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: modConfigPager
                clip: true
                anchors.fill: parent

                readonly property int count: m_pagesToDisplay ? m_pagesToDisplay.length : 0
                property int currentIndex: 0
                property alias currentItem: step

                function incrementCurrentIndex() {
                    if( currentIndex >= m_pagesToDisplay.length-1 )
                        return;

                    step.clear();
                    currentIndex++;
                }

                function decrementCurrentIndex() {
                    if( currentIndex <= 0 )
                        return;

                    step.clear();
                    currentIndex--;
                }

                ModConfigurationStep {
                    id: step
                    anchors.fill: parent
                }
            }

            PageIndicator {
                count: modConfigPager.count
                currentIndex: modConfigPager.currentIndex

                anchors.margins: 5
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Row {
            Layout.alignment: Qt.AlignRight
            spacing: 5

            Button {
                text: qsTr('Cancel');
                onClicked: modConfigWindow.visible = false;
            }
            Button {
                text: qsTr('Previous');
                onClicked: {
                    storeFiles();
                    storeFlags();

                    modConfigPager.decrementCurrentIndex();
                }
                enabled: modConfigPager.currentIndex > 0
            }
            Button {
                text: modConfigPager.currentIndex < modConfigPager.count - 1 ? qsTr('Next') : qsTr('Finish');
                onClicked: {
                    storeFiles();
                    storeFlags();

                    if( modConfigPager.currentIndex < modConfigPager.count - 1 )
                        modConfigPager.incrementCurrentIndex();
                    else
                        reviewPage.open();
                }
                enabled: step.canProceed
            }
        }
    }

    ReviewPage {
        id: reviewPage
        anchors.centerIn: parent
        onAccepted: finalise();
    }

    function finalise()
    {
        flagsUpdated();

        let finalFileList = [];

        let fileCount = 0;
        for( let a=0; a < m_pagesToDisplay.length; a++ )
        {
            if( !( m_pagesToDisplay[a]['files'] instanceof Array ) )
                continue;

            const flist = m_pagesToDisplay[a]['files'];
            for( let b=0; b < flist.length; b++ )
            {
                const fent = flist[b];
                let src = fent['source'].replace(/\\/g, '/');
                let dst = fent['destination'].replace(/\\/g, '/');
/*
                if( Qt.platform.os !== 'windows' )
                {
                    src = src.toLowerCase();
                    dst = dst.toLowerCase();
                }
*/
                console.log( `[File ${fileCount+1}] Page #${a+1}: (${b+1}/${flist.length}) Install "${src}" to "${dst}"...` );
                finalFileList.push( { 'source':src, 'dest':dst, 'priority':fent['priority'] } );
                fileCount++;
            }
        }

        m_files = finalFileList;
        readyForInstall();

        modConfigWindow.close();
    }
}
