import QtQuick
import qs.Common
import "OverflowLayout.js" as OverflowLayout

Item {
    id: root

    required property var sectionContext
    required property var itemData
    required property int occurrenceOrder
    readonly property alias host: widgetLoader
    readonly property alias slot: slot
    readonly property alias item: widgetLoader.item
    readonly property var widgetItem: widgetLoader.item
    readonly property bool active: widgetLoader.active
    readonly property bool itemVisible: widgetItem?.visible ?? false
    readonly property bool effectiveVisible: widgetItem?.effectiveVisible ?? true
    readonly property real itemWidth: widgetItem?.width ?? 0
    readonly property real itemHeight: widgetItem?.height ?? 0
    readonly property bool available: active && widgetLoader.widgetEnabled && itemVisible && effectiveVisible && itemWidth > 0 && itemHeight > 0
    readonly property real targetPrimarySize: available ? (sectionContext.isVertical ? itemHeight : itemWidth) : 0
    // smooth motion: the slot springs as the widget appears, goes and resizes, and its gap opens with it (presence); a
    // widget that springs its own size (primarySizeAnimated) only has its slot come and go
    readonly property bool slotMotion: primed && Anims.smoothMotion && !Theme.springMotionDisabled
    readonly property bool primarySizeAnimated: !!widgetItem && "primarySizeAnimated" in widgetItem && widgetItem.primarySizeAnimated
    readonly property real primarySize: sizeMotion.enabled ? sizeMotion.value : targetPrimarySize
    readonly property real presence: presenceMotion.value
    readonly property bool moving: sizeMotion.running || presenceMotion.running || (primarySizeAnimated && !!widgetItem.primarySizeMoving)
    property bool primed: false
    // A flexible widget reports the width it wants and the width it can live with; the resolver allots between them.
    readonly property real preferredSize: !available ? 0 : widgetItem && "naturalPrimarySize" in widgetItem ? widgetItem.naturalPrimarySize : targetPrimarySize
    readonly property real minimumSize: available && widgetItem && "minimumPrimarySize" in widgetItem ? Math.min(preferredSize, widgetItem.minimumPrimarySize) : preferredSize
    readonly property real allottedSize: sectionContext.allottedSizes[occurrenceOrder] ?? 0
    readonly property string overflowMode: OverflowLayout.placement(itemData, sectionContext.overflowDefaultMode)
    readonly property bool inOverflow: overflowMode === "always" || sectionContext.overflowIndices.includes(occurrenceOrder)
    readonly property bool inPopup: inOverflow && sectionContext.overflowOpen && !!sectionContext.overflowParent
    readonly property bool participates: available && !inOverflow
    readonly property bool presentationLive: !inOverflow || inPopup
    property real popupX: 0
    property real popupY: 0

    visible: active && widgetLoader.widgetEnabled && !inOverflow
    width: participates ? (sectionContext.isVertical ? sectionContext.width : itemWidth) : 0
    height: participates ? itemHeight : 0
    opacity: presence

    onTargetPrimarySizeChanged: sizeMotion.retarget(targetPrimarySize)
    onAvailableChanged: presenceMotion.retarget(available ? 1 : 0)
    // the first layout lands in place
    Component.onCompleted: Qt.callLater(() => root.primed = true)

    SpringMotion {
        id: sizeMotion
        enabled: root.slotMotion && !root.primarySizeAnimated
        stiffness: Anims.smallSpring.stiffness
        damping: Anims.smallSpring.damping
        mass: Anims.smallSpring.mass
        positionEpsilon: 0.05
        velocityEpsilon: 0.05
        Component.onCompleted: snapTo(root.targetPrimarySize)
    }

    SpringMotion {
        id: presenceMotion
        enabled: root.slotMotion
        stiffness: Anims.smallSpring.stiffness
        damping: Anims.smallSpring.damping
        mass: Anims.smallSpring.mass
        positionEpsilon: 0.002
        velocityEpsilon: 0.002
        Component.onCompleted: snapTo(root.available ? 1 : 0)
    }

    Item {
        id: slot
        // The slot moves between the wrapper, the parking host and the popup; the widget never changes anchors.
        parent: root.inOverflow ? (root.inPopup ? root.sectionContext.overflowParent : root.sectionContext.parkingHost) : root
        x: root.inOverflow ? root.popupX : 0
        y: root.inOverflow ? root.popupY : 0
        width: root.inOverflow ? root.itemWidth : root.width
        height: root.inOverflow ? root.itemHeight : root.height

        SectionWidget {
            id: widgetLoader
            // Constant anchors: changing the anchor set, even for one evaluation, makes Qt stretch the loader and overwrite the widget's size.
            anchors.left: root.sectionContext.isVertical ? undefined : parent.left
            anchors.verticalCenter: root.sectionContext.isVertical ? undefined : parent.verticalCenter
            anchors.top: root.sectionContext.isVertical ? parent.top : undefined
            anchors.horizontalCenter: root.sectionContext.isVertical ? parent.horizontalCenter : undefined
            enabled: root.presentationLive
            live: root.presentationLive
            sectionContext: root.sectionContext
            widgetData: root.itemData
            occurrenceOrder: root.occurrenceOrder
            isFirst: !root.inOverflow && root.sectionContext.inlineOrder[0] === root.occurrenceOrder
            isLast: !root.inOverflow && root.sectionContext.inlineOrder[root.sectionContext.inlineOrder.length - 1] === root.occurrenceOrder
            sectionSpacing: root.inOverflow ? 0 : root.sectionContext.widgetSpacing
            segmentRole: root.inOverflow ? "solo" : root.sectionContext.roleAt(root.occurrenceOrder)
            blurBarWindow: root.inOverflow ? null : root.sectionContext.blurBarWindow
            isLeftBarEdge: !root.inOverflow && !isInColumn && section === "left" && root.sectionContext.edgeIsScreenEdge
            isRightBarEdge: !root.inOverflow && !isInColumn && section === "right" && root.sectionContext.edgeIsScreenEdge
            isTopBarEdge: !root.inOverflow && isInColumn && section === "left" && root.sectionContext.edgeIsScreenEdge
            isBottomBarEdge: !root.inOverflow && isInColumn && section === "right" && root.sectionContext.edgeIsScreenEdge
            crossEdgeExtension: !root.inOverflow && !isInColumn && section !== "center" ? root.sectionContext.crossEdgeExtension : 0
            allottedPrimarySize: root.inOverflow ? 0 : root.allottedSize
            overflowAnchor: root.inOverflow ? root.sectionContext.overflowButton : null
            overflowSurface: root.inOverflow ? root.sectionContext.overflowSurface : null
        }
    }
}
