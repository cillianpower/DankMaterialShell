pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Details
import qs.DCommon.Widgets
import "../utils/sections.js" as Sections
import "../../../Common/CcControls.js" as CcControls

FocusScope {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string section: ""
    property var model: null
    property string screenName: ""
    property string screenModel: ""
    property var transientSurfaceTracker: null
    property real topInset: 0
    property vector4d cornerRadii: Qt.vector4d(Theme.windowRadius, Theme.windowRadius, Theme.windowRadius, Theme.windowRadius)
    property real coverage: 0
    property var runningToplevels: []
    // the panel is opening straight onto this page: no fade in
    property bool instantEnter: false
    // in place: the page replaces the grid instead of covering it
    readonly property bool inPlace: SettingsData.controlCenterPagesInPlace
    readonly property real sideInset: inPlace ? CcMetrics.sheetPadding : CcMetrics.detailDialogInset

    signal dismissed
    signal backRequested
    signal collapseRequested
    signal closeRequested
    signal codecSelectorRequested(var device)
    signal portSelectorRequested(var node)
    // a page opening a deeper one (a device's own page); Back and Escape come back up
    signal navigateRequested(string section)

    property string shownSection: ""
    property bool enterPending: false
    readonly property bool animationsEnabled: CcMetrics.animationsEnabled && !SettingsData.reduceMotion
    readonly property bool transitioning: enterPending || enterAnimation.running
    readonly property var pageItem: pageLoader.item
    readonly property real pageHeight: (pageItem?.implicitHeight ?? 0) > 0 ? pageItem.implicitHeight : CcMetrics.preferredDetailHeight(shownSection, pageItem?.preferredHeight ?? 0)
    readonly property real contentHeight: pageHeight
    readonly property real chromeHeight: header.height + (inPlace ? 0 : CcMetrics.detailDialogPadding * 2)
    readonly property real maximumHeight: height - topInset - sideInset
    // the panel's height for the page when it stands in the grid's place
    readonly property real inPlaceHeight: topInset + chromeHeight + contentHeight + sideInset
    // plugin detail content may not scroll itself, so the panel grows to fit it
    readonly property bool pageScrollsItself: !shownSection.startsWith("plugin_") || pageItem?.scrollsItself === true
    readonly property real minimumHeight: chromeHeight + (pageScrollsItself ? Math.min(contentHeight, CcMetrics.detailMinContentHeight) : pageHeight)
    readonly property string title: {
        const own = pageItem?.title ?? "";
        if (own)
            return own;
        const parsed = Sections.parse(shownSection);
        return model?.getWidgetForId(parsed.base)?.text ?? "";
    }
    visible: shownSection !== ""
    opacity: 0
    layer.enabled: enterPending || enterAnimation.running || exitAnimation.running
    layer.smooth: true
    Accessible.role: Accessible.Dialog
    Accessible.name: title

    function finishClose() {
        if (section !== "")
            return;
        pageLoader.sourceComponent = null;
        shownSection = "";
        dismissed();
    }

    function containsItem(item) {
        for (let ancestor = item; ancestor; ancestor = ancestor.parent) {
            if (ancestor === root)
                return true;
        }
        return false;
    }

    function moveFocus(backwards) {
        const current = root.Window.window?.activeFocusItem ?? root;
        const next = current.nextItemInFocusChain(!backwards);
        const edge = root.inPlace ? backButton : closeButton;
        const target = root.containsItem(next) ? next : backwards ? edge : root.nextItemInFocusChain(true);
        (root.containsItem(target) ? target : edge).forceActiveFocus(backwards ? Qt.BacktabFocusReason : Qt.TabFocusReason);
    }

    Shortcut {
        sequence: "Tab"
        enabled: root.section !== "" && root.activeFocus
        onActivated: root.moveFocus(false)
    }

    Shortcut {
        sequences: ["Backtab", "Shift+Tab"]
        enabled: root.section !== "" && root.activeFocus
        onActivated: root.moveFocus(true)
    }

    function dismissTransient() {
        const item = pageItem;
        if (!item || typeof item.dismissTransient !== "function")
            return false;
        return item.dismissTransient() === true;
    }

    function _componentFor(sectionId) {
        const parsed = Sections.parse(sectionId);
        switch (parsed.base) {
        case "network":
        case "wifi":
            return networkComponent;
        case "bluetooth":
            return bluetoothComponent;
        case "audioOutput":
            return audioOutputComponent;
        case "audioInput":
            return audioInputComponent;
        case "battery":
            return batteryComponent;
        case "doNotDisturb":
            return dndComponent;
        case "idleInhibitor":
            return idleInhibitComponent;
        case "diskUsage":
            return diskUsageComponent;
        case "brightnessSlider":
            return brightnessComponent;
        case "runningApps":
            return runningAppsComponent;
        }
        if (sectionId.startsWith("builtin_") || sectionId.startsWith("plugin_"))
            return pluginComponent;
        return null;
    }

    onSectionChanged: {
        enterPending = false;
        enterAnimation.stop();
        exitAnimation.stop();
        if (section === "") {
            if (!animationsEnabled) {
                root.opacity = 0;
                finishClose();
                return;
            }
            exitBlocker.forceActiveFocus();
            exitAnimation.start();
            return;
        }
        const opening = shownSection === "";
        enterPending = opening && animationsEnabled && !instantEnter;
        root.opacity = enterPending ? 0 : 1;
        dialogSurface.entryScale = enterPending && !inPlace ? CcMetrics.popupEnterScale : 1;
        shownSection = section;
        pageLoader.sourceComponent = _componentFor(section);
        (pageItem ?? root).forceActiveFocus();
    }

    Connections {
        target: root.Window.window
        enabled: root.enterPending

        function onFrameSwapped() {
            root.enterPending = false;
            enterAnimation.start();
        }
    }

    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: CcMetrics.fadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
        NumberAnimation {
            target: dialogSurface
            property: "entryScale"
            to: 1
            duration: Theme.expressiveDurations.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
        }
    }

    NumberAnimation {
        id: exitAnimation
        target: root
        property: "opacity"
        to: 0
        duration: CcMetrics.fadeDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        onFinished: root.finishClose()
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.cornerRadii.x
        topRightRadius: root.cornerRadii.y
        bottomRightRadius: root.cornerRadii.z
        bottomLeftRadius: root.cornerRadii.w
        color: Theme.scrimColor
        opacity: Theme.scrimAlpha
        visible: !root.inPlace
    }

    MouseArea {
        anchors.fill: parent
        // in place, only the page itself catches clicks
        anchors.topMargin: root.inPlace ? root.topInset : 0
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onClicked: {
            if (root.section !== "" && !root.inPlace)
                root.backRequested();
        }
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        id: dialogSurface

        x: root.sideInset
        y: root.topInset + (root.inPlace ? 0 : Math.max(0, (root.maximumHeight - height) / 2))
        width: Math.max(0, root.width - root.sideInset * 2)
        height: Math.max(0, Math.min(root.chromeHeight + root.contentHeight, root.maximumHeight))
        radius: root.inPlace ? 0 : Theme.cornerRadiusXL

        Behavior on height {
            enabled: root.animationsEnabled && !root.transitioning && root.section !== ""
            NumberAnimation {
                duration: Theme.expressiveDurations.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.standard
            }
        }
        color: root.inPlace ? "transparent" : CcMetrics.dialogColor
        border.width: root.inPlace ? 0 : Theme.layerOutlineWidth
        border.color: Theme.outlineMedium
        property real entryScale: 1
        scale: Math.min(1, entryScale)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Item {
            id: panel

            anchors.fill: parent
            anchors.margins: root.inPlace ? 0 : CcMetrics.detailDialogPadding
            opacity: CcMetrics.hideCoveredContent ? 1 - root.coverage : 1

            Item {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: CcMetrics.pageHeaderHeight

                DActionButton {
                    id: backButton
                    visible: root.inPlace
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    buttonSize: CcMetrics.headerActionSize
                    iconName: "chevron_left"
                    iconSize: CcMetrics.headerActionIconSize
                    iconColor: Theme.surfaceText
                    Accessible.name: I18n.tr("Back")
                    onClicked: root.backRequested()
                }

                StyledText {
                    anchors.left: root.inPlace ? backButton.right : parent.left
                    anchors.leftMargin: root.inPlace ? Theme.spacingXS : CcMetrics.rowPaddingH
                    anchors.right: headerSlot.left
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                    font.pixelSize: CcMetrics.pageTitleSize
                    font.weight: Theme.macosTypeScale ? Font.Bold : Theme.fontWeight
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                }

                Item {
                    id: headerSlot
                    anchors.right: root.inPlace ? parent.right : closeButton.left
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    width: childrenRect.width
                    height: childrenRect.height
                }

                DActionButton {
                    id: closeButton
                    visible: !root.inPlace
                    anchors.right: parent.right
                    anchors.rightMargin: CcMetrics.headerEdgeInset
                    anchors.verticalCenter: parent.verticalCenter
                    buttonSize: CcMetrics.headerActionSize
                    iconName: "close"
                    iconSize: CcMetrics.headerActionIconSize
                    iconColor: Theme.surfaceText
                    Accessible.name: I18n.tr("Close")
                    onClicked: root.backRequested()
                }
            }

            Loader {
                id: pageLoader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                active: root.shownSection !== ""
                onLoaded: {
                    const actions = item.headerActions ?? null;
                    if (actions)
                        actions.parent = headerSlot;
                }
            }
        }
    }

    MouseArea {
        id: exitBlocker

        anchors.fill: parent
        visible: root.section === ""
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
        Keys.onPressed: event => event.accepted = true
        Keys.onReleased: event => event.accepted = true
    }

    Connections {
        target: root.pageItem
        ignoreUnknownSignals: true

        function onMountPathChanged(newMountPath) {
            Sections.updateWidgetForSection(root.shownSection, {
                "mountPath": newMountPath
            });
            root.collapseRequested();
        }

        function onDeviceNameChanged(newDeviceName) {
            Sections.updateWidgetForSection(root.shownSection, {
                "deviceName": newDeviceName
            });
        }

        function onShowCodecSelector(device) {
            root.codecSelectorRequested(device);
        }

        function onShowPortSelector(node) {
            root.portSelectorRequested(node);
        }

        function onDismissRequested() {
            root.backRequested();
        }

        function onCloseRequested() {
            root.closeRequested();
        }

        function onNavigateRequested(section) {
            root.navigateRequested(section);
        }
    }

    Component {
        id: networkComponent
        NetworkDetail {
            transientSurfaceTracker: root.transientSurfaceTracker
            transitioning: root.transitioning
        }
    }

    Component {
        id: bluetoothComponent
        BluetoothDetail {
            transientSurfaceTracker: root.transientSurfaceTracker
        }
    }

    Component {
        id: audioOutputComponent
        AudioOutputDetail {}
    }

    Component {
        id: audioInputComponent
        AudioInputDetail {}
    }

    Component {
        id: batteryComponent
        BatteryDetail {}
    }

    Component {
        id: dndComponent
        DoNotDisturbDetail {}
    }

    Component {
        id: idleInhibitComponent
        IdleInhibitorDetail {}
    }

    Component {
        id: diskUsageComponent
        DiskUsageDetail {
            readonly property var widgetEntry: Sections.widgetForSection(root.shownSection)
            currentMountPath: widgetEntry?.mountPath || "/"
        }
    }

    Component {
        id: brightnessComponent
        BrightnessDetail {
            readonly property var widgetEntry: Sections.widgetForSection(root.shownSection)
            initialDeviceName: widgetEntry?.deviceName || ""
            instanceId: widgetEntry?.instanceId || ""
            screenName: root.screenName
            screenModel: root.screenModel
        }
    }

    Component {
        id: runningAppsComponent
        RunningAppsDetail {
            toplevels: root.runningToplevels
        }
    }

    Component {
        id: pluginComponent
        PluginDetailShell {
            pluginId: CcControls.parseSection(root.shownSection).pluginId
            subPage: CcControls.parseSection(root.shownSection).sub
            builtinInstance: root.shownSection.startsWith("builtin_") ? (root.model?.builtinInstances[root.shownSection] ?? null) : null
        }
    }
}
