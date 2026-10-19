import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets

Item {
    id: root

    property bool vertical: false
    property bool live: visible && enabled
    property string displayMode: "both"
    property bool dateFirst: false
    property real fontSize: Theme.fontSizeMedium
    property real availableWidth: fontSize * 2
    property color textColor: Theme.surfaceText
    property color dateColor: textColor
    property color separatorColor: Theme.outlineButton
    property bool segmented: false
    property var locale: I18n.locale()
    property date date: systemClock.date
    // agartha: a ClockTimeOverlay to draw the ticking time on a surface of its own (a clock in the frame, whose one
    // full-screen surface redraws whole), while detachWanted (the owner says when the clock is at rest). The two surfaces
    // can't change in the same frame, so a handover always overlaps instead of leaving a gap: the overlay starts
    // drawing, then the placeholder here goes unseen; back, the time here shows, then the overlay stops.
    property var timeHost: null
    property bool detachWanted: true
    readonly property bool hostReady: !!timeHost && timeHost.clock === root && timeHost.shown && detachWanted && !vertical && showTime
    property bool overlayDraws: false
    property bool timeDetached: false
    readonly property bool windowShown: Window.window?.visible ?? false
    onHostReadyChanged: root.syncDetached()
    onTimeHostChanged: root.claimTimeHost()
    Component.onCompleted: {
        root.claimTimeHost();
        root.syncDetached();
    }
    Component.onDestruction: {
        if (root.timeHost?.clock === root)
            root.timeHost.clock = null;
    }
    function claimTimeHost() {
        if (root.timeHost)
            root.timeHost.clock = root;
    }
    function syncDetached() {
        if (root.hostReady) {
            attachDelay.stop();
            // once its place has settled (a face just laid out may still move)
            if (!root.overlayDraws)
                detachDelay.restart();
            return;
        }
        detachDelay.stop();
        hideDelay.stop();
        root.timeDetached = false;
        if (root.overlayDraws)
            attachDelay.restart();
    }
    Timer {
        id: detachDelay
        interval: 120
        onTriggered: {
            root.overlayDraws = true;
            hideDelay.restart();
        }
    }
    Timer {
        id: hideDelay
        interval: 40
        onTriggered: root.timeDetached = root.hostReady
    }
    Timer {
        id: attachDelay
        interval: 40
        onTriggered: root.overlayDraws = false
    }
    // the time's line, for drawing it in the same place elsewhere
    readonly property Item timeItem: (root.dateFirst ? lastLoader.item : firstLoader.item) ?? null

    readonly property string timeText: date.toLocaleTimeString(locale, SettingsData.getEffectiveTimeFormat())
    readonly property string dateText: date.toLocaleDateString(locale, SettingsData.getEffectiveDateFormat())
    readonly property var timeLines: vertical ? stackedTime() : [timeText]
    readonly property var dateLines: vertical ? stackedDate() : [dateText]
    readonly property bool showTime: displayMode !== "date"
    readonly property bool showDate: displayMode !== "time"
    readonly property bool split: segmented && !vertical && showTime && showDate
    readonly property real splitOffset: split ? layout.x + separator.x + separator.width / 2 : 0

    implicitWidth: vertical ? availableWidth : layout.implicitWidth
    implicitHeight: layout.implicitHeight

    function pad(value) {
        return String(value).padStart(2, "0");
    }

    function stackedTime() {
        const hours = date.getHours();
        const lines = [pad(SettingsData.use24HourClock ? hours : (hours % 12 || 12)), pad(date.getMinutes())];
        if (SettingsData.showSeconds)
            lines.push(pad(date.getSeconds()));
        if (!SettingsData.use24HourClock)
            lines.push(hours >= 12 ? locale.pmText : locale.amText);
        return lines;
    }

    function stackedDate() {
        const format = locale.dateFormat(Locale.ShortFormat);
        const day = pad(date.getDate());
        const month = pad(date.getMonth() + 1);
        return format.indexOf("d") < format.indexOf("M") ? [day, month] : [month, day];
    }

    component StackedLines: Column {
        id: stack

        property var lines: []
        property color color: root.textColor
        // the time keeps a slot as wide as its widest reading, so nothing after it moves as it ticks
        property bool steady: false
        // drawn elsewhere: these lines are the slot itself, unchanging and unseen
        property bool detached: false

        width: root.vertical ? root.availableWidth : implicitWidth

        Repeater {
            model: stack.lines.length

            NumericText {
                id: line

                required property int index
                // in a row (the bar), figures are proportional: tabular ones leave a lone 1 in a digit-wide box
                // ("1 1:4 1"). the slot is the time with every digit its widest, and the time sits at its start, so the
                // hours stay put and only its end moves a pixel as the seconds tick
                readonly property bool proportional: !root.vertical
                anchors.horizontalCenter: proportional ? undefined : parent.horizontalCenter
                readonly property string lineText: stack.lines[index]
                text: stack.detached ? lineText.replace(/\d/g, widestDigit) : lineText
                // unseen by colour, not opacity: opacity fades (StyledText), and the time has to be back the moment it's
                // drawn here again
                reserveText: lineText.replace(/\d/g, "0")
                width: proportional ? (stack.steady ? Math.ceil(Math.max(implicitWidth, widestSlot.width)) : Math.ceil(implicitWidth)) : Math.ceil(reservedWidth)
                horizontalAlignment: proportional ? Text.AlignLeft : Text.AlignHCenter
                isMonospace: false
                color: stack.detached ? "transparent" : stack.color
                font.pixelSize: root.fontSize
                font.features: proportional ? ({ "tnum": 0 }) : ({ "tnum": 1 })

                FontMetrics {
                    id: digitMetrics
                    font: line.font
                }
                readonly property string widestDigit: {
                    let best = "0";
                    for (const digit of "0123456789") {
                        if (digitMetrics.advanceWidth(digit) > digitMetrics.advanceWidth(best))
                            best = digit;
                    }
                    return best;
                }
                TextMetrics {
                    id: widestSlot
                    font: line.font
                    text: line.lineText.replace(/\d/g, line.widestDigit)
                }
            }
        }
    }

    Grid {
        id: layout

        anchors.centerIn: parent
        columns: root.vertical ? 1 : Math.max(1, layout.visibleChildren.length)
        spacing: root.vertical ? 0 : Theme.spacingS

        Loader {
            id: firstLoader
            sourceComponent: root.dateFirst && root.showDate || !root.showTime ? dateComponent : timeComponent
        }

        Item {
            id: separator
            visible: root.showTime && root.showDate
            width: root.vertical ? root.availableWidth : (root.split ? Theme.groupedListGap : dot.implicitWidth)
            height: root.vertical ? Theme.spacingM : root.fontSize

            Rectangle {
                visible: root.vertical
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: 1
                color: root.separatorColor
            }

            StyledText {
                id: dot
                visible: !root.vertical && !root.split
                anchors.centerIn: parent
                text: "•"
                color: root.separatorColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Loader {
            id: lastLoader
            active: root.showTime && root.showDate
            visible: active
            sourceComponent: root.dateFirst ? timeComponent : dateComponent
        }
    }

    Component {
        id: timeComponent

        StackedLines {
            lines: root.timeLines
            steady: true
            detached: root.timeDetached
        }
    }

    Component {
        id: dateComponent

        StackedLines {
            lines: root.dateLines
            color: root.dateColor
        }
    }

    SystemClock {
        id: systemClock
        enabled: root.live
        precision: SettingsData.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Connections {
        target: SessionService
        function onSessionResumed() {
            systemClock.enabled = false;
            systemClock.enabled = Qt.binding(() => root.live);
        }
    }
}
