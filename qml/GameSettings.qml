import QtQuick 2.15
import Qt.labs.settings 1.0

Item {
    id: gameSettings

    Repeater {
        id: repeaterSettings
        Item {
            property alias enabled: intobj.enabled
            property alias gamePath: intobj.gamePath
            property alias modsPath: intobj.modsPath
            property alias modStagingPath: intobj.modStagingPath
            property alias userDataPath: intobj.userDataPath

            Settings {
                id: intobj
                category: modelData['name']

                property bool enabled: false
                property string gamePath
                property string modsPath
                property string modStagingPath
                property string userDataPath
            }
        }
        model: gameDefinitions
    }

    function objFor(name)
    {
        for( let a=0; a < repeaterSettings.count; a++ )
            if( repeaterSettings.model[a]['name'] === name )
                return repeaterSettings.itemAt(a);
        return false;
    }
}
