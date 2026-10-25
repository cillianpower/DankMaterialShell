import QtQuick
import Quickshell
import qs.Common
import "../Common/PixelGrid.js" as PixelGrid

// clockTimeOverlay: a clock in the frame shares the frame's one full-screen surface, which redraws whole, so a ticking time there
// redraws the whole screen every second. This draws the time on a small surface of its own, laid exactly over the
// clock that hands it the time (ClockContent.timeHost), and that clock keeps only a fixed, unseen placeholder: a tick
// costs the time's own pixels.
//
// One per clock's place (a bar's clock, an island's face), beside it in the same window, kept mapped while it's
// enabled: a clock built anew (the island's face lays out its groups again as a notification arrives) takes the surface
// over at once, instead of waiting the frames a new surface takes to show.
Item {
    id: root

    property bool enabled: false
    // the window the clock is drawn in (this item's own: it sits beside the clock)
    readonly property var parentWindow: QsWindow.window
    // the clock drawn here (set by the clock itself) and the placeholder in it that the time sits over
    property Item clock: null
    readonly property Item timeItem: root.clock?.timeItem ?? null
    // on screen: only then do clocks hand their time over
    readonly property bool shown: overlayShown
    property bool overlayShown: false

    // where the time sits in its window and how much of it shows, summed up the parents by hand so every ancestor's
    // offset, opacity and visibility is a binding dependency
    function placement(item) {
        let x = 0, y = 0, opacity = 1, visible = !!item;
        for (let it = item; it; it = it.parent) {
            x += it.x;
            y += it.y;
            opacity *= it.opacity;
            visible = visible && it.visible;
        }
        return { "x": x, "y": y, "opacity": opacity, "visible": visible && (root.clock?.windowShown ?? false) };
    }

    Timer {
        id: shownTimer
        interval: 50
        onTriggered: root.overlayShown = true
    }

    Loader {
        active: root.enabled && root.parentWindow !== null
        onActiveChanged: if (!active) {
            shownTimer.stop();
            root.overlayShown = false;
        }

        // a popup of the window the clock is in: stacked above it always, shown and hidden with it (a fullscreen
        // window covers both), but a surface of its own, so redrawing it leaves that window alone
        sourceComponent: PopupWindow {
            id: overlay

            readonly property var at: root.placement(root.timeItem)
            // anchored on a device pixel, the rest as the text's offset: an anchor between pixels is rounded onto the
            // grid by the compositor, and a time at a fractional place lands a pixel off the clock it stands in for
            readonly property real dpr: root.parentWindow?.devicePixelRatio ?? 1
            readonly property int anchorX: PixelGrid.gridFloor(at.x, dpr)
            readonly property int anchorY: PixelGrid.gridFloor(at.y, dpr)

            anchor.window: root.parentWindow
            anchor.rect.x: anchorX
            anchor.rect.y: anchorY
            anchor.rect.width: 1
            anchor.rect.height: 1
            anchor.edges: Edges.Top | Edges.Left
            anchor.gravity: Edges.Bottom | Edges.Right
            anchor.adjustment: PopupAdjustment.None
            visible: true
            // room for the offset, which stays under a step: a size following it would resize the popup as it moves
            implicitWidth: Math.max(1, Math.ceil((root.timeItem?.width ?? 0) + PixelGrid.gridStep(dpr)))
            implicitHeight: Math.max(1, Math.ceil((root.timeItem?.height ?? 0) + PixelGrid.gridStep(dpr)))
            color: "transparent"
            // clicks and hover go through to the clock underneath
            mask: Region {}
            onBackingWindowVisibleChanged: {
                if (backingWindowVisible) {
                    shownTimer.restart();
                    return;
                }
                shownTimer.stop();
                root.overlayShown = false;
            }

            NumericText {
                readonly property var clock: root.clock
                readonly property bool drawn: !!clock && clock.overlayDraws && overlay.at.visible
                x: overlay.at.x - overlay.anchorX
                y: overlay.at.y - overlay.anchorY
                width: root.timeItem?.width ?? implicitWidth
                height: root.timeItem?.height ?? implicitHeight
                text: drawn ? (clock.timeLines[0] ?? "") : ""
                // as the clock sets its own time (ClockContent.StackedLines)
                horizontalAlignment: clock?.proportionalFigures ? Text.AlignLeft : Text.AlignHCenter
                isMonospace: false
                // the clock's opacity as it is this frame, through the colour (opacity itself would fade after it)
                color: drawn ? Qt.rgba(clock.textColor.r, clock.textColor.g, clock.textColor.b, clock.textColor.a * overlay.at.opacity) : "transparent"
                font.pixelSize: clock?.fontSize ?? Theme.fontSizeMedium
                font.features: clock?.proportionalFigures ? ({ "tnum": 0 }) : ({ "tnum": 1 })
            }
        }
    }
}
