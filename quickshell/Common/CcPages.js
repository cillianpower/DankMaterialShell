.pragma library

// The control centre's depth: which page a row's chevron opens, which plugin pages sit under a built-in page (a
// device's own controls, such as a monitor's picture modes over ddc), and which page is one layer up from a page.
//
// A plugin puts its page under a built-in one from its plugin.json, and draws it with its ccDetailContent:
//   "controlCenterPage": { "parent": "brightness" | "audioOutput" | "audioInput",
//                          "devices": "RD280UG|BenQ",   // a pattern for the devices it controls; leave out for the page itself
//                          "title": "Picture" }          // the row's title; the device's own name when left out

const PARENTS = ["brightness", "audioOutput", "audioInput"];

// The page a slider row's chevron opens.
function sliderSection(widgetId) {
    switch (widgetId) {
    case "volumeSlider":
        return "audioOutput";
    case "inputVolumeSlider":
        return "audioInput";
    }
    return "";
}

function pageSpec(plugin) {
    const spec = plugin?.controlCenterPage;
    if (!spec || typeof spec !== "object" || PARENTS.indexOf(spec.parent) < 0)
        return null;
    return spec;
}

function deviceMatches(pattern, deviceText) {
    if (!pattern)
        return false;
    try {
        return new RegExp(pattern, "i").test(deviceText || "");
    } catch (e) {
        return String(deviceText || "").toLowerCase().indexOf(String(pattern).toLowerCase()) >= 0;
    }
}

// The plugin pages under a built-in page: those for one device (deviceText: its name and title), or, with no
// device, those for the page itself. plugins: the loaded plugins' manifests.
function pagesUnder(plugins, parent, deviceText) {
    const pages = [];
    for (const plugin of plugins || []) {
        const spec = pageSpec(plugin);
        if (!spec || spec.parent !== parent)
            continue;
        const forDevice = !!spec.devices;
        if (deviceText === undefined || deviceText === null ? forDevice : !deviceMatches(spec.devices, deviceText))
            continue;
        pages.push({
            "section": "plugin_" + plugin.id,
            "pluginId": plugin.id,
            "title": spec.title || "",
            "icon": plugin.icon || "tune"
        });
    }
    return pages;
}

// A plugin's page, opened straight from the bar, keeps the page it sits under one layer up, so Back and Escape go
// there first. widgets: the control centre's widget entries (for the brightness row's own page).
function parentSection(section, plugins, widgets) {
    if (!section || section.indexOf("plugin_") !== 0)
        return "";
    const rest = section.slice("plugin_".length);
    // a layer of a plugin's page ("plugin_<id>/<sub>") sits under that page
    if (rest.indexOf("/") >= 0)
        return "plugin_" + rest.slice(0, rest.indexOf("/"));
    const id = rest;
    const spec = pageSpec((plugins || []).find(plugin => plugin?.id === id));
    if (!spec)
        return "";
    if (spec.parent !== "brightness")
        return spec.parent;
    const row = (widgets || []).find(widget => widget?.id === "brightnessSlider");
    return "brightnessSlider_" + (row?.instanceId || "default");
}

// Every plugin page on a built-in page that lists devices: one row per device a plugin claims (titled with the
// device when the plugin gives no title), then the page's own. devices: [{text, title}].
function pagesForDevices(plugins, parent, devices) {
    const rows = [];
    for (const device of devices || []) {
        for (const page of pagesUnder(plugins, parent, device.text)) {
            if (rows.some(row => row.section === page.section))
                continue;
            rows.push(Object.assign({}, page, {
                "title": page.title || device.title || ""
            }));
        }
    }
    return rows.concat(pagesUnder(plugins, parent, null));
}
