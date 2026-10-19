.pragma library

// The control centre's standard control page: a plugin hands it groups of controls and hears back when one changes,
// and every device's controls look and behave alike.
//   groups: [{ title, controls: [{ name, label, type: "choice" | "range" | "toggle", value,
//                                  options: [{ value, label }],   // choice
//                                  min, max, step, unit }] }]     // range
// ("cycle", bebenqli's word, is a choice.) A choice of off and on is drawn as a toggle; a short choice as a row of
// buttons; a longer one as a row showing its value, whose chevron opens its options a layer down.

const SEGMENT_MAX_OPTIONS = 3;
const SEGMENT_MAX_LABEL = 10;

function kind(control) {
    const type = control?.type === "cycle" ? "choice" : control?.type;
    if (type === "range" || type === "toggle")
        return type;
    if (type !== "choice")
        return "";
    const options = control.options || [];
    if (isToggle(options))
        return "toggle";
    if (options.length <= SEGMENT_MAX_OPTIONS && options.every(option => String(option.label).length <= SEGMENT_MAX_LABEL))
        return "segmented";
    return "list";
}

// off and on, in either order and any case
function isToggle(options) {
    if (!options || options.length !== 2)
        return false;
    const labels = options.map(option => String(option.label).toLowerCase()).sort();
    return labels[0] === "off" && labels[1] === "on";
}

function toggleValue(control, checked) {
    if (control?.type === "toggle")
        return checked;
    const option = (control?.options || []).find(o => String(o.label).toLowerCase() === (checked ? "on" : "off"));
    return option ? option.value : undefined;
}

function toggleChecked(control) {
    if (control?.type === "toggle")
        return !!control.value;
    const option = (control?.options || []).find(o => o.value === control?.value);
    return !!option && String(option.label).toLowerCase() === "on";
}

function optionLabel(control) {
    const option = (control?.options || []).find(o => o.value === control?.value);
    return option ? String(option.label) : "—";
}

function findControl(groups, name) {
    for (const group of groups || []) {
        const control = (group.controls || []).find(c => c.name === name);
        if (control)
            return control;
    }
    return null;
}

// A plugin page's section, "plugin_<id>" or a layer of it, "plugin_<id>/<sub>".
function parseSection(section) {
    const s = String(section || "");
    if (s.indexOf("plugin_") !== 0)
        return { "pluginId": "", "sub": "" };
    const rest = s.slice("plugin_".length);
    const at = rest.indexOf("/");
    return at < 0 ? { "pluginId": rest, "sub": "" } : { "pluginId": rest.slice(0, at), "sub": rest.slice(at + 1) };
}

// The page a section is a layer of: a plugin page's layers belong to the plugin page.
function pageRoot(section) {
    const parsed = parseSection(section);
    return parsed.pluginId ? "plugin_" + parsed.pluginId : String(section || "");
}

// A long page (more than INDEX_MIN_CONTROLS controls in several groups) lists its groups, each a layer down, so a
// device's settings read as an index first; a short one shows its controls straight away.
const INDEX_MIN_CONTROLS = 9;

function controlCount(groups) {
    return (groups || []).reduce((sum, group) => sum + (group.controls || []).length, 0);
}

function indexed(groups) {
    return (groups || []).filter(group => (group.controls || []).length > 0).length > 1 && controlCount(groups) >= INDEX_MIN_CONTROLS;
}

// A layer's name: a group ("@<title>"), a choice ("<name>"), or a choice in a group ("@<title>/<name>").
function subFor(groupTitle, controlName) {
    const group = groupTitle ? "@" + groupTitle : "";
    return group && controlName ? group + "/" + controlName : group || controlName || "";
}

// What a layer shows: { group, control } (either may be null; both null for the page itself or an unknown layer).
function resolveSub(groups, sub) {
    const s = String(sub || "");
    if (!s)
        return { "group": null, "control": null };
    if (s[0] !== "@")
        return { "group": null, "control": findControl(groups, s) };
    const at = s.indexOf("/");
    const title = at < 0 ? s.slice(1) : s.slice(1, at);
    const group = (groups || []).find(g => (g.title || "") === title) || null;
    const control = at < 0 || !group ? null : (group.controls || []).find(c => c.name === s.slice(at + 1)) || null;
    return { "group": group, "control": control };
}

// A group's row on the index: what's in it, by name.
function groupSummary(group, limit) {
    const labels = (group?.controls || []).map(control => control.label || control.name);
    const max = limit || 3;
    return labels.length > max ? labels.slice(0, max).join(", ") + "…" : labels.join(", ");
}
