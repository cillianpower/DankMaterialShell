import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property bool compactMode: SettingsData.widgetOption("focusedWindow", widgetData, "focusedWindowCompactMode")
    property bool showIcon: SettingsData.widgetOption("focusedWindow", widgetData, "focusedWindowShowIcon")
    readonly property int maxWidth: {
        const size = SettingsData.widgetOption("focusedWindow", widgetData, "focusedWindowSize");
        switch (size) {
        case 0:
            return 288;
        case 2:
            return 656;
        case 3:
            return 856;
        default:
            return 456;
        }
    }
    property real allottedPrimarySize: 0
    // real, as the bar allots it: a whole-pixel width cuts up to a pixel off a title on a fractional-scale grid
    property real availableWidth: allottedPrimarySize > 0 ? allottedPrimarySize : maxWidth
    // rounded up, not to the nearest pixel: a title half a pixel short of its width is elided
    readonly property real naturalPrimarySize: isVerticalOrientation ? height : !hasWindowsOnCurrentWorkspace ? 0 : Math.ceil((Math.min(contentItem?.naturalWidth ?? 0, maxWidth - horizontalPadding * 2) + horizontalPadding * 2) * dpr) / dpr
    readonly property real minimumPrimarySize: isVerticalOrientation ? height : Math.min(naturalPrimarySize, Theme.snap((contentItem?.minimumWidth ?? 0) + horizontalPadding * 2, dpr))
    readonly property real effectiveHorizontalWidth: Math.max(0, Math.min(maxWidth, availableWidth))
    readonly property real effectiveHorizontalInnerWidth: Math.max(0, effectiveHorizontalWidth - horizontalPadding * 2)
    property var activeWindow: null
    // focusedWindowTitleMotion: as the title changes it crossfades ("crossfade") or slides in the way niri's view moved
    // ("slide") while its width springs
    readonly property string titleMotion: isVerticalOrientation || SettingsData.reduceMotion || Theme.springMotionDisabled ? "none" : SettingsData.widgetOption("focusedWindow", widgetData, "focusedWindowTitleMotion")
    readonly property bool primarySizeAnimated: titleMotion !== "none"
    readonly property bool primarySizeMoving: contentItem?.sizeMoving ?? false
    // the last title fades out as the width springs shut (one binding: a separate "leaving" one lags it by an evaluation)
    readonly property bool titleShown: hasWindowsOnCurrentWorkspace || (primarySizeAnimated && (contentItem?.implicitWidth ?? 0) > 0)
    readonly property int focusMotionSerial: NiriService.focusMotion.serial
    onFocusMotionSerialChanged: contentItem?.lateMotion?.()
    property var activeDesktopEntry: null
    property bool isHovered: mouseArea.containsMouse

    readonly property string screenName: parentScreen?.name ?? ""
    readonly property bool popoutVisible: focusedWindowPopoutLoader.item?.shouldBeVisible ?? false

    function updateActiveWindow() {
        activeWindow = CompositorService.activeWindowForScreen(parentScreen ? parentScreen.name : null, activeWindow, popoutVisible);
    }

    Component.onCompleted: {
        updateActiveWindow();
        updateDesktopEntry();
    }

    readonly property Toplevel managerActiveToplevel: ToplevelManager.activeToplevel

    onManagerActiveToplevelChanged: updateActiveWindow()

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            root.updateActiveWindow();
        }
        function onWorkspaceStateChanged() {
            root.updateActiveWindow();
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.updateDesktopEntry();
        }
    }

    function syncPopoutState() {
        const popout = focusedWindowPopoutLoader.item;
        if (!popout || !activeWindow || !root.parentScreen)
            return;
        popout.currentWindow = activeWindow;
        popout.processId = CompositorService.windowPid(activeWindow);
        root.positionPopout(popout);
    }

    onActiveWindowChanged: {
        updateDesktopEntry();
        if (focusedWindowPopoutLoader.item?.shouldBeVisible) {
            if (activeWindow) {
                syncPopoutState();
                Qt.callLater(() => root.syncPopoutState());
            } else {
                focusedWindowPopoutLoader.item.close();
            }
        }
    }

    readonly property var settingsAppIdSubstitutions: SettingsData.appIdSubstitutions

    onSettingsAppIdSubstitutionsChanged: updateDesktopEntry()

    function updateDesktopEntry() {
        if (activeWindow && activeWindow.appId) {
            const moddedId = Paths.moddedAppId(activeWindow.appId);
            activeDesktopEntry = DesktopEntries.heuristicLookup(moddedId);
        } else {
            activeDesktopEntry = null;
        }
    }
    readonly property bool hasWindowsOnCurrentWorkspace: {
        CompositorService.windowStateRevision;
        if (!activeWindow || !(activeWindow.title || activeWindow.appId))
            return false;
        return CompositorService.windowOnActiveWorkspace(screenName, activeWindow, popoutVisible);
    }

    width: titleShown ? (isVerticalOrientation ? barThickness : (effectiveHorizontalInnerWidth > 0 ? visualWidth : 0)) : 0
    height: titleShown ? (isVerticalOrientation ? visualHeight : barThickness) : 0
    visible: titleShown && (isVerticalOrientation || effectiveHorizontalInnerWidth > 0)

    content: Component {
        Item {
            id: titleContent
            readonly property bool iconShown: horizontalAppIcon.visible || horizontalSteamIcon.visible
            readonly property real appTextNatural: appText.visible ? Math.min(appText.implicitWidth, root.compactMode ? 80 : 180) : 0
            readonly property real naturalWidth: {
                const parts = [];
                if (iconShown)
                    parts.push(contentRow.iconSize);
                if (appText.visible)
                    parts.push(appTextNatural);
                if (appSeparator.visible)
                    parts.push(appSeparator.width);
                if (titleText.visible)
                    parts.push(titleText.implicitWidth);
                return parts.reduce((sum, part) => sum + part, 0) + Math.max(0, parts.length - 1) * contentRow.spacing;
            }
            readonly property real minimumWidth: (iconShown ? contentRow.iconSize + contentRow.spacing : 0) + Math.min(48, appText.visible ? appTextNatural : titleText.visible ? titleText.implicitWidth : 0)
            readonly property real targetWidth: {
                if (!root.hasWindowsOnCurrentWorkspace)
                    return 0;
                if (root.isVerticalOrientation)
                    return root.contentThickness;
                return Math.min(contentRow.implicitWidth, root.effectiveHorizontalInnerWidth);
            }
            implicitWidth: root.primarySizeAnimated ? widthMotion.value : targetWidth
            onTargetWidthChanged: widthMotion.retarget(targetWidth)
            readonly property bool sizeMoving: widthMotion.running
            // the bar allots the width it springs to at once: a shrinking title keeps its width until the spring is there
            width: root.isVerticalOrientation ? root.contentThickness : root.primarySizeAnimated ? implicitWidth : Math.min(implicitWidth, root.effectiveHorizontalInnerWidth)
            implicitHeight: root.contentThickness
            clip: false

            IconImage {
                id: appIcon
                anchors.centerIn: parent
                width: 18
                height: 18
                visible: root.isVerticalOrientation && activeWindow && status === Image.Ready
                source: {
                    if (!activeWindow || !activeWindow.appId)
                        return "";
                    return Paths.getAppIcon(activeWindow.appId, activeDesktopEntry);
                }
                smooth: true
                mipmap: true
                asynchronous: true
                layer.enabled: activeWindow && Paths.isDmsAppId(activeWindow.appId)
                layer.smooth: true
                layer.mipmap: true
                layer.effect: MultiEffect {
                    saturation: 0
                    colorization: 1
                    colorizationColor: Theme.primary
                }
            }

            DIcon {
                anchors.centerIn: parent
                size: 18
                name: "sports_esports"
                color: root.contentColor
                visible: root.isVerticalOrientation && activeWindow && activeWindow.appId && appIcon.status !== Image.Ready && Paths.isSteamApp(activeWindow.appId)
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.isVerticalOrientation && activeWindow && activeWindow.appId && appIcon.status !== Image.Ready && !Paths.isSteamApp(activeWindow.appId)
                text: {
                    if (!activeWindow || !activeWindow.appId)
                        return "?";
                    const appName = Paths.getAppName(activeWindow.appId, activeDesktopEntry);
                    return appName.charAt(0).toUpperCase();
                }
                font.pixelSize: 10
                color: root.contentColor
            }

            property string shownTitle: ""
            property real titleChangedAt: 0
            property bool titleChangeDirected: true
            property var lastGhost: null
            // StyledText animates any opacity it is given; an animation's own writes pass it by
            property real enterOpacityFrom: 0

            SpringMotion {
                id: widthMotion
                enabled: root.primarySizeAnimated
                stiffness: Anims.smallSpring.stiffness
                damping: Anims.smallSpring.damping
                mass: Anims.smallSpring.mass
                positionEpsilon: 0.05
                velocityEpsilon: 0.05
                Component.onCompleted: snapTo(titleContent.targetWidth)
            }

            // a focus change younger than this is the one that changed the title
            readonly property int focusMotionWindow: 250

            function takeFocusMotion() {
                const motion = NiriService.focusMotion;
                if (motion.serial <= consumedMotionSerial || Date.now() - motion.time > focusMotionWindow)
                    return null;
                consumedMotionSerial = motion.serial;
                return motion;
            }
            property int consumedMotionSerial: NiriService.focusMotion.serial

            function slideOffset(motion) {
                if (root.titleMotion !== "slide" || !motion)
                    return Qt.point(0, 0);
                return Qt.point(motion.axis === "x" ? motion.sign * Theme.spacingL : 0, motion.axis === "y" ? motion.sign * Theme.spacingM : 0);
            }

            function titleChanged() {
                const previous = shownTitle;
                shownTitle = titleText.text;
                if (root.titleMotion === "none")
                    return;
                const motion = takeFocusMotion();
                const offset = slideOffset(motion);
                titleChangedAt = Date.now();
                titleChangeDirected = !!motion;
                // the leaving title goes on from wherever it is, so a change mid-transition never jumps
                lastGhost = previous ? ghostComponent.createObject(titleClip, {
                    "text": previous,
                    "offsetInRow": titleText.x,
                    // the budget the bar allots next is not out yet: this is still the leaving title's
                    "maximumWidth": titleText.budget,
                    "opacity": titleText.opacity,
                    "startX": titleShift.x,
                    "startY": titleShift.y,
                    "exitX": -offset.x,
                    "exitY": -offset.y
                }) : null;
                titleEnter.stop();
                enterOpacityFrom = 0;
                titleShift.x = offset.x;
                titleShift.y = offset.y;
                titleEnter.start();
            }

            // niri's event can land after the toplevel's: turn a fresh crossfade into the slide
            function lateMotion() {
                if (root.titleMotion !== "slide" || titleChangeDirected || Date.now() - titleChangedAt > Anims.smallDuration / 2)
                    return;
                const motion = takeFocusMotion();
                if (!motion)
                    return;
                titleChangeDirected = true;
                const offset = slideOffset(motion);
                const remaining = 1 - titleText.opacity;
                titleEnter.stop();
                enterOpacityFrom = titleText.opacity;
                titleShift.x = offset.x * remaining;
                titleShift.y = offset.y * remaining;
                titleEnter.start();
                lastGhost?.leaveTo(-offset.x, -offset.y);
            }

            ParallelAnimation {
                id: titleEnter

                NumberAnimation {
                    target: titleText
                    property: "opacity"
                    from: titleContent.enterOpacityFrom
                    to: 1
                    duration: Anims.smallDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anims.smoothSpatial
                }
                NumberAnimation {
                    target: titleShift
                    property: "x"
                    to: 0
                    duration: Anims.smallDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anims.smoothSpatial
                }
                NumberAnimation {
                    target: titleShift
                    property: "y"
                    to: 0
                    duration: Anims.smallDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anims.smoothSpatial
                }
            }

            Component {
                id: ghostComponent

                StyledText {
                    id: ghost
                    required property real offsetInRow
                    required property real maximumWidth
                    property real startX: 0
                    property real startY: 0
                    property real exitX: 0
                    property real exitY: 0

                    function leaveTo(x, y) {
                        exitX = x;
                        exitY = y;
                        leave.restart();
                    }

                    // where the centred row held it
                    x: (parent.width - offsetInRow - width) / 2 + offsetInRow
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, maximumWidth)
                    font.pixelSize: titleText.font.pixelSize
                    color: titleText.color
                    // a title that fit stays whole: Qt can middle-elide a text exactly its own width as it moves
                    elide: implicitWidth > maximumWidth ? titleText.elide : Text.ElideNone
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    transform: Translate {
                        id: ghostShift
                        x: ghost.startX
                        y: ghost.startY
                    }

                    ParallelAnimation {
                        id: leave
                        running: true
                        onFinished: ghost.destroy()

                        NumberAnimation {
                            target: ghost
                            property: "opacity"
                            to: 0
                            duration: Anims.smallDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anims.smoothSpatial
                        }
                        NumberAnimation {
                            target: ghostShift
                            property: "x"
                            to: ghost.exitX
                            duration: Anims.smallDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anims.smoothSpatial
                        }
                        NumberAnimation {
                            target: ghostShift
                            property: "y"
                            to: ghost.exitY
                            duration: Anims.smallDuration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anims.smoothSpatial
                        }
                    }
                }
            }

            Item {
                id: titleClip
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: root.barThickness

                Row {
                    id: contentRow
                    anchors.verticalCenter: parent.verticalCenter
                    // centred while its width springs, so a title keeps its place
                    x: root.primarySizeAnimated ? (parent.width - width) / 2 : 0
                    spacing: Theme.spacingS
                    visible: !root.isVerticalOrientation

                    readonly property real iconSize: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)

                    IconImage {
                        id: horizontalAppIcon
                        width: contentRow.iconSize
                        height: contentRow.iconSize
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showIcon && activeWindow && status === Image.Ready
                        source: {
                            if (!activeWindow || !activeWindow.appId)
                                return "";
                            return Paths.getAppIcon(activeWindow.appId, activeDesktopEntry);
                        }
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        layer.enabled: activeWindow && Paths.isDmsAppId(activeWindow.appId)
                        layer.smooth: true
                        layer.mipmap: true
                        layer.effect: MultiEffect {
                            saturation: 0
                            colorization: 1
                            colorizationColor: Theme.primary
                        }
                    }

                    DIcon {
                        id: horizontalSteamIcon
                        width: contentRow.iconSize
                        size: contentRow.iconSize
                        anchors.verticalCenter: parent.verticalCenter
                        name: "sports_esports"
                        color: root.contentColor
                        visible: root.showIcon && activeWindow && activeWindow.appId && horizontalAppIcon.status !== Image.Ready && Paths.isSteamApp(activeWindow.appId)
                    }

                    StyledText {
                        id: appText
                        text: {
                            if (compactMode || !activeWindow || !activeWindow.appId)
                                return "";
                            return Paths.getAppName(activeWindow.appId, activeDesktopEntry);
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: root.contentColor
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: {
                            const sp = contentRow.spacing;
                            let used = 0;
                            if (horizontalAppIcon.visible)
                                used += horizontalAppIcon.width + sp;
                            else if (horizontalSteamIcon.visible)
                                used += horizontalSteamIcon.width + sp;
                            const budget = Math.max(0, root.effectiveHorizontalInnerWidth - used);
                            return Math.min(implicitWidth, compactMode ? 80 : 180, budget);
                        }
                        visible: text.length > 0
                    }

                    StyledText {
                        id: appSeparator
                        text: compactMode ? "" : "•"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.outlineButton
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !compactMode && appText.text && titleText.text
                    }

                    StyledText {
                        id: titleText
                        text: {
                            if (!root.hasWindowsOnCurrentWorkspace)
                                return "";
                            const title = activeWindow && activeWindow.title ? activeWindow.title : "";
                            // the app's own name, also in compact mode where appText shows none
                            const appName = activeWindow && activeWindow.appId ? Paths.getAppName(activeWindow.appId, activeDesktopEntry) : "";

                            if (compactMode && (!title || title === appName))
                                return title || appName;
                            if (!title || !appName || !title.endsWith(appName))
                                return title;
                            const stripped = title.substring(0, title.length - appName.length).replace(/ (-|—|–) $/, "");
                            return compactMode ? stripped || appName : stripped;
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: root.contentColor
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.NoWrap
                        // the minimum information, title only (compact): a long title keeps its start and its end
                        elide: compactMode && SettingsData.minimalInfo ? Text.ElideMiddle : Text.ElideRight
                        maximumLineCount: 1
                        readonly property real budget: {
                            const sp = contentRow.spacing;
                            let used = 0;
                            if (horizontalAppIcon.visible)
                                used += horizontalAppIcon.width + sp;
                            else if (horizontalSteamIcon.visible)
                                used += horizontalSteamIcon.width + sp;
                            if (appText.visible)
                                used += appText.width + sp;
                            if (appSeparator.visible)
                                used += appSeparator.width + sp;
                            return Math.max(0, root.effectiveHorizontalInnerWidth - used);
                        }
                        width: Math.min(implicitWidth, budget)
                        visible: text.length > 0
                        transform: Translate {
                            id: titleShift
                        }
                        onTextChanged: titleChanged()
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        x: -root.leftMargin
        y: -root.topMargin
        width: root.width + root.leftMargin + root.rightMargin
        height: root.height + root.topMargin + root.bottomMargin
        hoverEnabled: root.isVerticalOrientation
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (root.isVerticalOrientation && activeWindow && activeWindow.appId && root.parentScreen) {
                tooltipLoader.active = true;
                if (tooltipLoader.item) {
                    const localPos = mapToItem(null, width / 2, height / 2);
                    const currentScreen = root.parentScreen;
                    const adjustedY = localPos.y + root.minTooltipY;
                    const tooltipX = root.axis?.edge === "left" ? (Theme.barHeight + (barConfig?.spacing ?? 4) + Theme.spacingXS) : (currentScreen.width - Theme.barHeight - (barConfig?.spacing ?? 4) - Theme.spacingXS);

                    const appName = Paths.getAppName(activeWindow.appId, activeDesktopEntry);
                    const title = activeWindow.title || "";
                    const tooltipText = appName + (title ? " • " + title : "");

                    const isLeft = root.axis?.edge === "left";
                    tooltipLoader.item.show(tooltipText, tooltipX, adjustedY, currentScreen, isLeft, !isLeft);
                }
            }
        }
        onExited: {
            if (tooltipLoader.item) {
                tooltipLoader.item.hide();
            }
            tooltipLoader.active = false;
        }

        acceptedButtons: Qt.LeftButton
        onClicked: {
            if (!activeWindow || !root.parentScreen)
                return;
            if (tooltipLoader.item)
                tooltipLoader.item.hide();
            tooltipLoader.active = false;

            // No context menu from inside the overflow popup; behave like a task switcher.
            const owner = BarWidgetService.registrationForItem(root)?.context?.owner;
            if (owner?.overflowAnchor) {
                CompositorService.activateToplevel(activeWindow);
                owner.overflowSurface?.close();
                return;
            }

            focusedWindowPopoutLoader.active = true;
            if (!focusedWindowPopoutLoader.item)
                return;

            root.syncPopoutState();
            focusedWindowPopoutLoader.item.toggle();
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DTooltip {}
    }

    Loader {
        id: focusedWindowPopoutLoader
        active: false
        sourceComponent: FocusedWindowContextMenu {
            onPopoutClosed: root.updateActiveWindow()
        }
    }

    onPopoutVisibleChanged: {
        if (!popoutVisible)
            updateActiveWindow();
    }
}
