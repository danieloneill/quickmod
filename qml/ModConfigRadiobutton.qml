import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

RadioButton {
    id: me

    property string pageId: page['uuid']
    property int sectionId
    property int optionId
    property string description
    property string imageUrl
    property variant conditionFlags
    property variant files

    readonly property string token: `${sectionId}_${optionId}`
    readonly property string selToken: `${pageId}_${sectionId}_${optionId}`

    checked: modConfigWindow.m_selections[selToken] ? true : false

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onContainsMouseChanged: {
            if( containsMouse )
            {
                optionDescription.text = description;
                if( imageUrl )
                    optionImage.imagePath = imageUrl;
            }
        }
        onClicked: function(ev) { parent.toggle(); sectionGroup.clicked(me); }
    }

    onCheckedChanged: updateChecked();
    function updateChecked() {
        // Files:
        modConfigPage.m_files[token] = [];
        if( checked && files['file'] )
        {
            console.log(`Adding files: ${JSON.stringify(files['file'])}...`);

            if( files['file'] instanceof Array )
                files['file'].forEach( f => modConfigPage.m_files[token].push(f) );
            else
                modConfigPage.m_files[token].push(files['file']);
        }
        if( checked && files['folder'] )
        {
            console.log(`Adding folders: ${JSON.stringify(files['folder'])}...`);

            if( files['folder'] instanceof Array )
                files['folder'].forEach( f => modConfigPage.m_files[token].push(f) );
            else
                modConfigPage.m_files[token].push(files['folder']);
        }
        console.log(`Files for page: ${JSON.stringify(modConfigPage.m_files)}`);

        // Flags:
        if( !conditionFlags )
            return;

        let flagArray = conditionFlags['flag'];
        if( !(flagArray instanceof Array) )
            flagArray = [ flagArray ];

        if( checked )
        {
            flagArray.forEach( function(ent) {
                modConfigPage.m_flagsToSet[ ent['name']['Value'] ] = ent['Characters'];
            } );
        }
        else
        {
            flagArray.forEach( function(ent) {
                delete modConfigPage.m_flagsToSet[ ent['name']['Value'] ];
            } );
        }
    }
}
