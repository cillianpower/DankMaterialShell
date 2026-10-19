import QtQuick
import qs.Modules.ControlCenter.Widgets
import qs.Services

Item {
    id: root

    property string pluginId: ""
    property var builtinInstance: null
    // a layer of the plugin's page ("plugin_<id>/<sub>"): handed to its content, which shows that layer
    property string subPage: ""

    readonly property var instance: builtinInstance ?? pluginHost.instance
    readonly property real preferredHeight: instance?.ccDetailHeight ?? 0
    // content that knows its own height and scrolls past the panel's (the standard control page) sizes the page
    readonly property bool scrollsItself: contentLoader.item?.scrollsItself === true
    implicitHeight: scrollsItself ? contentLoader.item.implicitHeight : 0
    // a layer is titled by its content; a page under a built-in one ("controlCenterPage" in plugin.json) as its row is
    readonly property string title: (root.subPage ? contentLoader.item?.title : "") || PluginService.loadedPlugins[pluginId]?.controlCenterPage?.title || instance?.ccWidgetPrimaryText || PluginService.loadedPlugins[pluginId]?.name || PluginService.availablePluginsList.find(p => p.id === pluginId)?.name || ""

    // the content opening a layer of its own, or going back up from one
    signal navigateRequested(string section)
    signal dismissRequested

    PluginInstanceHost {
        id: pluginHost
        pluginId: root.builtinInstance ? "" : root.pluginId
    }

    Loader {
        id: contentLoader
        anchors.fill: parent
        sourceComponent: root.instance?.ccDetailContent ?? null
    }

    Binding {
        target: contentLoader.item
        property: "subPage"
        value: root.subPage
        when: contentLoader.item !== null && contentLoader.item.subPage !== undefined
    }

    Connections {
        target: contentLoader.item
        ignoreUnknownSignals: true

        function onNavigateRequested(sub) {
            root.navigateRequested("plugin_" + root.pluginId + "/" + sub);
        }

        function onDismissRequested() {
            root.dismissRequested();
        }
    }
}
