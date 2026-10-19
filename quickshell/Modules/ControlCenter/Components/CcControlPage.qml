pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Widgets
import qs.Modules.Settings.Widgets
import qs.DCommon.Widgets
import "../../../Common/CcControls.js" as CcControls

// The control centre's standard page for a device's controls (Common/CcControls.js has the data's shape). A plugin
// sets groups and handles changed(). Its layers (subPage) go down in a discoverable order: a long page first lists its
// groups, each a layer of its own; a longer choice opens its options a layer further down.
Item {
    id: root

    property var groups: []
    property string subPage: ""
    // one line at the top: a device's state ("Applying…", an error); empty for none
    property string status: ""

    readonly property var showing: CcControls.resolveSub(groups, subPage)
    readonly property var choice: showing.control && CcControls.kind(showing.control) === "list" ? showing.control : null
    readonly property var shownGroups: showing.group ? [showing.group] : groups
    readonly property bool showIndex: !subPage && CcControls.indexed(groups)
    readonly property string title: choice?.label ?? showing.group?.title ?? ""
    // sized by its rows, scrolling past the panel's height
    readonly property bool scrollsItself: true

    signal changed(string name, var value)
    signal navigateRequested(string sub)
    signal dismissRequested

    implicitHeight: column.height

    DFlickable {
        anchors.fill: parent
        contentHeight: column.height
        clip: true

        Column {
            id: column
            width: parent.width
            spacing: CcMetrics.detailContentGap

            StyledText {
                width: parent.width
                visible: root.status !== ""
                text: root.status
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
            }

            // a choice's options, a layer down
            CcGroup {
                visible: root.choice !== null

                Repeater {
                    model: root.choice?.options ?? []

                    CcListRow {
                        required property var modelData

                        title: String(modelData.label)
                        active: modelData.value === root.choice?.value
                        clickable: true
                        onClicked: {
                            // the current choice again only goes back up
                            if (modelData.value !== root.choice.value)
                                root.changed(root.choice.name, modelData.value);
                            root.dismissRequested();
                        }
                    }
                }
            }

            // a long page's index: its groups, each a layer down
            CcGroup {
                visible: root.showIndex

                Repeater {
                    model: root.showIndex ? root.groups.filter(group => (group.controls ?? []).length > 0) : []

                    CcListRow {
                        required property var modelData

                        title: modelData.title ?? ""
                        subtitle: CcControls.groupSummary(modelData)
                        clickable: true
                        showChevron: true
                        onClicked: root.navigateRequested(CcControls.subFor(modelData.title ?? "", ""))
                    }
                }
            }

            // the controls: every group on a short page, or the one group a layer shows
            Repeater {
                model: root.choice || root.showIndex ? [] : root.shownGroups

                Column {
                    id: group

                    required property var modelData

                    width: column.width
                    spacing: CcMetrics.detailContentGap
                    visible: (modelData.controls ?? []).length > 0

                    CcSectionLabel {
                        // a group's own layer is titled already
                        text: root.showing.group ? "" : (group.modelData.title ?? "")
                        visible: text !== ""
                    }

                    CcGroup {
                        Repeater {
                            model: group.modelData.controls ?? []

                            Loader {
                                required property var modelData
                                readonly property var control: modelData
                                readonly property string kind: CcControls.kind(modelData)
                                readonly property string groupTitle: root.showing.group ? (group.modelData.title ?? "") : ""

                                width: parent?.width ?? 0
                                active: kind !== ""
                                visible: active
                                sourceComponent: kind === "range" ? rangeRow : kind === "toggle" ? toggleRow : kind === "segmented" ? segmentedRow : listRow
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: rangeRow

        SettingsSliderRow {
            readonly property var control: parent?.control ?? ({})

            paddingH: CcMetrics.rowPaddingH
            paddingV: CcMetrics.rowPaddingV
            rowColor: CcMetrics.rowColor
            text: control.label ?? ""
            value: control.value ?? control.min ?? 0
            minimum: control.min ?? 0
            maximum: control.max ?? 100
            step: control.step ?? 1
            unit: control.unit ?? ""
            onSliderValueChanged: newValue => {
                if (newValue !== control.value)
                    root.changed(control.name, newValue);
            }
        }
    }

    Component {
        id: toggleRow

        CcToggleRow {
            readonly property var control: parent?.control ?? ({})

            text: control.label ?? ""
            checked: CcControls.toggleChecked(control)
            onToggled: checked => {
                const value = CcControls.toggleValue(control, checked);
                if (value !== undefined)
                    root.changed(control.name, value);
            }
        }
    }

    Component {
        id: segmentedRow

        SettingsButtonGroupRow {
            readonly property var control: parent?.control ?? ({})

            paddingH: CcMetrics.rowPaddingH
            paddingV: CcMetrics.rowPaddingV
            rowColor: CcMetrics.rowColor
            text: control.label ?? ""
            model: (control.options ?? []).map(option => String(option.label))
            values: (control.options ?? []).map(option => option.value)
            value: control.value
            onValueSelected: value => {
                if (value !== control.value)
                    root.changed(control.name, value);
            }
        }
    }

    Component {
        id: listRow

        CcListRow {
            readonly property var control: parent?.control ?? ({})
            readonly property string groupTitle: parent?.groupTitle ?? ""

            title: control.label ?? ""
            subtitle: CcControls.optionLabel(control)
            clickable: true
            showChevron: true
            onClicked: root.navigateRequested(CcControls.subFor(groupTitle, control.name))
        }
    }
}
