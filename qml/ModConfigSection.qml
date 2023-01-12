import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Column {
    id: groupColumn
    height: childrenRect.height
    width: childrenRect.width

    property string pageId
    property string sectionName: 'Section has no name'
    required property int sectionIndex
    property string sectionType: 'SelectExactlyOne'
    property variant sectionModel: []

    property bool canProceed: sectionGroup.exclusive && sectionGroup.checkState === Qt.Unchecked ? false : true

    Label { text: sectionName }
    ButtonGroup {
        id: sectionGroup
        exclusive: sectionType === 'SelectAtMostOne' || sectionType === 'SelectExactlyOne' ? true : false

        onClicked: function(button) {
            saveSelections();
        }
    }

    function saveSelections() {
        let checked = {};
        for( let b=0; b < sectionGroup.buttons.length; b++ )
        {
            const button = sectionGroup.buttons[b];
            if( button.checked )
                modConfigWindow.m_selections[ button.selToken ] = `${sectionName} - ${button.text}`;
            else
                delete modConfigWindow.m_selections[ button.selToken ];
        }

        console.log(`SAVE Selections: ${JSON.stringify(modConfigWindow.m_selections)}`);
    }

    function loadSelections() {
        let checked;
        for( let b=0; b < sectionGroup.buttons.length; b++ )
        {
            const button = sectionGroup.buttons[b];
            if( modConfigWindow.m_selections[ button.selToken ] )
                checked = button;
            else
                button.checked = false;
        }
        if( checked )
            checked.checked = true;

        console.log(`LOAD Selections: ${JSON.stringify(modConfigWindow.m_selections)}`);
    }

    Timer {
        id: checkboxTimer
        interval: 10
        repeat: true
        onTriggered: {
            for( let a=0; a < optionRepeater.model.length; a++ )
            {
                if( Loader.Ready !== optionRepeater.itemAt(a).status )
                    return;
            }

            loadSelections();
            checkboxTimer.stop();
        }
    }

    onPageIdChanged: checkboxTimer.start();

    Column {
        id: optionsColumn
        width: parent.width

        Repeater {
            id: optionRepeater

            delegate: Loader {
                id: loader
                sourceComponent: sectionType === 'SelectExactlyOne' ? compRadio : compCheckbox
                Binding {
                    target: loader.item
                    property: "model"
                    value: model
                }
            }

            model: sectionModel
        }
    }

    Component {
        id: compCheckbox
        ModConfigCheckbox {
            property var model

            ButtonGroup.group: sectionGroup

            text: model.modelData['name']['Value']
            pageId: groupColumn.pageId
            sectionId: sectionIndex
            optionId: model.index
            description: model.modelData['description']['Characters']
            imageUrl: model.modelData['image'] ? model.modelData['image']['path']['Value'] : ''

            conditionFlags: model.modelData['conditionFlags']
            files: model.modelData['files']
        }
    }

    Component {
        id: compRadio
        ModConfigRadiobutton {
            property var model

            ButtonGroup.group: sectionGroup

            text: model.modelData['name']['Value']
            pageId: groupColumn.pageId
            sectionId: sectionIndex
            optionId: model.index
            description: model.modelData['description']['Characters']
            imageUrl: model.modelData['image'] ? model.modelData['image']['path']['Value'] : ''

            conditionFlags: model.modelData['conditionFlags']
            files: model.modelData['files']
        }
    }
}
