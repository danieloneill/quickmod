import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: modConfigPage

    readonly property variant page: modConfigWindow.m_pagesToDisplay && modConfigWindow.m_pagesToDisplay[modConfigPager.currentIndex] ? modConfigWindow.m_pagesToDisplay[modConfigPager.currentIndex] : {}
    readonly property string title: page && page['name'] && page['name']['Value'] ? page['name']['Value'] : ''

    property variant m_flagsToSet: ({})
    property variant m_selections: ({})
    property variant m_files: ({})

    property bool canProceed: true
    function clear() {
        step.m_flagsToSet = {};
        step.m_selections = {};
        step.m_files = {};
    }

    Component.onCompleted: {
        clear();
        checkCanProceed();
    }

    function checkCanProceed()
    {
        if( !groupRepeater.model )
            return;

        let p = true;
        for( let a=0; a < groupRepeater.model.length; a++ )
        {
            const i = groupRepeater.itemAt(a).item;
            if( !i.canProceed )
            {
                p = false;
                break;
            }
        }

        modConfigPage.canProceed = p;
    }

    SplitView {
        anchors.fill: parent

        Flickable {
            implicitWidth: contentWidth > modConfigPage.width * 0.33 ? contentWidth : modConfigPage.width * 0.33
            implicitHeight: contentHeight > modConfigPage.width * 0.33 ? contentHeight : modConfigPage.width * 0.33
            contentWidth: optionGroupsColumn.implicitWidth
            contentHeight: optionGroupsColumn.implicitHeight
            clip: true

            Column {
                id: optionGroupsColumn
                //implicitHeight: childrenRect.height
                //implicitWidth: childrenRect.width

                Repeater {
                    id: groupRepeater

                    delegate: Loader {
                        id: loader
                        sourceComponent: compSection
                        Binding {
                            target: loader.item
                            property: "model"
                            value: model
                        }
                    }

                    //model: modConfigPage.page['optionalFileGroups']['group'] || []
                    model: page && page['optionalFileGroups'] && page['optionalFileGroups']['group'] ? page['optionalFileGroups']['group'] : []
                }
            }
        }

        Component {
            id: compSection
            ModConfigSection {
                property var model
                pageId: page['uuid']
                sectionIndex: model.index
                sectionName: model.modelData['name']['Value']
                sectionType: model.modelData['type']['Value']
                sectionModel: model.modelData['plugins']['plugin']

                onCanProceedChanged: modConfigPage.checkCanProceed();
            }
        }

        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10

                Text {
                    id: optionDescription
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                AnimatedImage {
                    id: optionImage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fillMode: AnimatedImage.PreserveAspectFit
                    property string imagePath
                    source: imagePath.length > 0 ? 'file://' + modConfigWindow.m_rootPath + '/../' + imagePath.replace(/\\/g, '/') : ''
                }
            }
        }
    }
}
