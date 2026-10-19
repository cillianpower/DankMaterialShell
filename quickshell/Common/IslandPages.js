.pragma library

// The island's pages as its face shows them: each group on the home face that opens a page, in the face's order, so
// Left and Right (and Ctrl+Tab) walk what's on the bar.

// The page a home face group opens, as its click opens it (HomeCompact.activateGroup); null for a group that opens no
// page (volume and brightness show their level in the face; the tray and workspaces act in place).
function pageForGroup(groupId, mediaAvailable) {
    switch (groupId) {
    case "clock":
        return { "activity": "home", "section": "" };
    case "media":
        return mediaAvailable ? { "activity": "media", "section": "" } : null;
    case "weather":
        return { "activity": "weather", "section": "" };
    case "notifications":
        return { "activity": "notificationcenter", "section": "" };
    case "privacy":
        return { "activity": "controlcenter", "section": "audioInput" };
    case "status":
        return { "activity": "controlcenter", "section": "" };
    }
    return null;
}

// a layer of a plugin's page ("plugin_<id>/<sub>") is still that page
function sectionRoot(section) {
    const s = String(section || "");
    return s.indexOf("plugin_") === 0 && s.indexOf("/") >= 0 ? s.slice(0, s.indexOf("/")) : s;
}

function samePage(a, b) {
    return !!a && !!b && a.activity === b.activity && (a.activity !== "controlcenter" || sectionRoot(a.section) === sectionRoot(b.section));
}

// groups: the face's group ids in the order it shows them. Returns the pages they open, each once.
function facePages(groups, mediaAvailable) {
    const pages = [];
    for (const groupId of groups || []) {
        const page = pageForGroup(groupId, mediaAvailable);
        if (page && !pages.some(existing => samePage(existing, page)))
            pages.push(page);
    }
    return pages;
}

// The page after (direction 1) or before (-1) the one showing. A page the face doesn't open steps onto the first or
// last; a control centre on a page no group opens counts as the face's first control-centre page.
function stepPage(pages, current, direction) {
    if (!pages.length)
        return null;
    const step = direction < 0 ? -1 : 1;
    let at = pages.findIndex(page => samePage(page, current));
    if (at < 0)
        at = pages.findIndex(page => page.activity === current?.activity);
    if (at < 0)
        return step > 0 ? pages[0] : pages[pages.length - 1];
    return pages[(at + step + pages.length) % pages.length];
}

// The face's group lit while its page shows: the group whose page is the one showing, or for a page of the control
// centre no group opens (one reached from the grid), the group opening the grid, else the first opening the control
// centre. groups: the face's group ids in order; current: {activity, section}. "" when no group's page shows.
function litGroup(groups, current, mediaAvailable) {
    const list = (groups || []).map(groupId => ({ "groupId": groupId, "page": pageForGroup(groupId, mediaAvailable) })).filter(entry => entry.page);
    const exact = list.find(entry => samePage(entry.page, current));
    if (exact)
        return exact.groupId;
    const same = list.filter(entry => entry.page.activity === current?.activity);
    const grid = same.find(entry => !entry.page.section);
    return (grid ?? same[0])?.groupId ?? "";
}
