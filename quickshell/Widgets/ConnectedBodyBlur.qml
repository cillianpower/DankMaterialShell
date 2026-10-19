import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import "../Common/ConnectorGeometry.js" as ConnectorGeometry
import "../Common/ConnectedSurfaceGeometry.js" as SurfaceGeometry

// The blur behind a connected surface's body (with its cap and the connectors into the bar and the screen edge), set on
// the surface's own window. The frame draws the same shape, but on its own window: when the frame paints no tint the
// blur is the body, and blur set on another window trails the content by a frame or more as it moves. Here it moves
// with the content, in the same commit.
Item {
    id: root

    visible: false

    required property var targetWindow
    property var descriptor: ({
            visible: false,
            barSide: "top"
        })
    property real dpr: 1
    property bool active: false

    readonly property bool _active: active && BlurService.enabled && !!targetWindow && (descriptor?.visible ?? false)
    readonly property string _side: descriptor?.barSide ?? "top"
    readonly property real _ccr: Theme.connectedCornerRadius
    readonly property real _surfaceRadius: Theme.connectedSurfaceRadius
    readonly property var _body: SurfaceGeometry.animatedBodyRect(descriptor, dpr)
    readonly property var _radii: SurfaceGeometry.connectorRadii(descriptor, _body, _ccr, _surfaceRadius, dpr, false)
    readonly property bool _horizontal: SurfaceGeometry.isHorizontal(_side)
    readonly property real _arcExtent: _horizontal ? bodyAnchor.height : bodyAnchor.width
    readonly property real _capThickness: Math.max(0, Math.min(Math.max(_radii.start, _radii.end), _arcExtent - _surfaceRadius))

    function _farBarSide(sourceSide, placement) {
        if (sourceSide === "top" || sourceSide === "bottom")
            return placement === "left" ? "left" : "right";
        return placement === "left" ? "top" : "bottom";
    }

    function _farPlacement(sourceSide) {
        if (sourceSide === "top")
            return "right";
        if (sourceSide === "bottom")
            return "left";
        if (sourceSide === "left")
            return "right";
        return "left";
    }

    component Connector: Region {
        id: connector
        required property string placement
        required property real connectorRadius
        property bool far: false

        readonly property bool _on: root._active && connectorRadius > 0
        readonly property var _rect: far ? SurfaceGeometry.farConnectorRect(root._side, root._body, placement, connectorRadius, root.dpr) : SurfaceGeometry.connectorRect(root._side, root._body, placement, 0, connectorRadius, root.dpr)
        readonly property string _arcCorner: far ? ConnectorGeometry.arcCorner(root._farBarSide(root._side, placement), root._farPlacement(root._side)) : ConnectorGeometry.arcCorner(root._side, placement)

        x: _on ? Math.round(_rect.x) : 0
        y: _on ? Math.round(_rect.y) : 0
        width: _on ? Math.round(_rect.width) : 0
        height: _on ? Math.round(_rect.height) : 0

        // the concave curve: the connector's square less a circle on its outer corner
        Region {
            readonly property bool _on: connector.width > 0 && connector.height > 0
            readonly property real _r: connector.connectorRadius

            intersection: Intersection.Subtract
            radius: _r
            x: _on ? Math.round((connector._arcCorner === "topLeft" || connector._arcCorner === "bottomLeft") ? connector.x - _r : connector.x + connector.width - _r) : 0
            y: _on ? Math.round((connector._arcCorner === "topLeft" || connector._arcCorner === "topRight") ? connector.y - _r : connector.y + connector.height - _r) : 0
            width: _on ? Math.round(_r * 2) : 0
            height: _on ? Math.round(_r * 2) : 0
        }
    }

    component FarCap: Region {
        required property string placement
        required property real capRadius

        readonly property bool _on: root._active && capRadius > 0
        readonly property var _rect: SurfaceGeometry.farBodyCapRect(root._side, root._body, placement, capRadius, root.dpr)

        x: _on ? Math.round(_rect.x) : 0
        y: _on ? Math.round(_rect.y) : 0
        width: _on ? Math.round(_rect.width) : 0
        height: _on ? Math.round(_rect.height) : 0
    }

    Region {
        id: blurRegion

        Region {
            id: bodyAnchor

            radius: root._surfaceRadius
            x: root._active ? Math.round(root._body.x) : 0
            y: root._active ? Math.round(root._body.y - (root.descriptor?.overflowTop ?? 0)) : 0
            width: root._active ? Math.round(root._body.width) : 0
            height: root._active ? Math.round(root._body.height + (root.descriptor?.overflowTop ?? 0) + (root.descriptor?.overflowBottom ?? 0)) : 0
        }

        // the side against the bar is square: a cap over the body's rounded corners there
        Region {
            readonly property bool _on: root._active && root._capThickness > 0 && bodyAnchor.width > 0 && bodyAnchor.height > 0
            readonly property int _w: (root._side === "left" || root._side === "right") ? Math.round(Math.min(root._capThickness, bodyAnchor.width)) : bodyAnchor.width
            readonly property int _h: (root._side === "top" || root._side === "bottom") ? Math.round(Math.min(root._capThickness, bodyAnchor.height)) : bodyAnchor.height

            x: !_on ? 0 : (root._side === "right" ? bodyAnchor.x + bodyAnchor.width - _w : bodyAnchor.x)
            y: !_on ? 0 : (root._side === "bottom" ? bodyAnchor.y + bodyAnchor.height - _h : bodyAnchor.y)
            width: _on ? _w : 0
            height: _on ? _h : 0
        }

        Connector {
            placement: "left"
            connectorRadius: root._radii.start
        }
        Connector {
            placement: "right"
            connectorRadius: root._radii.end
        }
        FarCap {
            placement: "left"
            capRadius: root._radii.farStart
        }
        FarCap {
            placement: "right"
            capRadius: root._radii.farEnd
        }
        Connector {
            placement: "left"
            far: true
            connectorRadius: root._radii.farStart
        }
        Connector {
            placement: "right"
            far: true
            connectorRadius: root._radii.farEnd
        }

        // a compositor that blurs the whole surface when the region lies outside it gets nothing outside
        Region {
            intersection: Intersection.Intersect
            width: root.targetWindow?.width ?? 0
            height: root.targetWindow?.height ?? 0
        }
    }

    function _apply() {
        if (targetWindow)
            targetWindow.BackgroundEffect.blurRegion = _active ? blurRegion : null;
    }

    on_ActiveChanged: _apply()
    onTargetWindowChanged: _apply()
    Component.onCompleted: _apply()
    Component.onDestruction: {
        if (targetWindow && targetWindow.BackgroundEffect.blurRegion === blurRegion)
            targetWindow.BackgroundEffect.blurRegion = null;
    }
}
