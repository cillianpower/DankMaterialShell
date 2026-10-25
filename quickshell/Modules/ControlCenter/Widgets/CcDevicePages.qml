import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Services
import "../../../Common/CcPages.js" as CcPages

// The devices' own controls under a built-in page, from plugins ("controlCenterPage" in a plugin.json): a layer down.
Column {
    id: root

    // "brightness", "audioOutput" or "audioInput"
    property string parentPage: ""
    // [{ text, title }]: what a plugin's pattern is matched against, and the row's title when it gives none
    property var devices: []

    signal navigateRequested(string section)

    width: parent?.width ?? 0
    spacing: CcMetrics.detailContentGap
    visible: pages.count > 0

    CcSectionLabel {
        text: I18n.tr("Device Settings")
    }

    CcGroup {
        Repeater {
            id: pages
            model: CcPages.pagesForDevices(Object.values(PluginService.loadedPlugins), root.parentPage, root.devices)

            CcListRow {
                required property var modelData

                iconName: modelData.icon
                title: modelData.title
                clickable: true
                showChevron: true
                onClicked: root.navigateRequested(modelData.section)
            }
        }
    }
}
