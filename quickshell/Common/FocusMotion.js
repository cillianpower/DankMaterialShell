.pragma library

// Which way niri's view moved as focus changed: axis "x" (a column) or "y" (a workspace on the same output), sign +1
// toward later columns or workspaces, or axis "none". A tracker remembers the focus as these events last saw it,
// since niri reports a workspace switch and the window focus in either order.

const none = Object.freeze({
    axis: "none",
    sign: 0
});

function tracker() {
    return {
        windowId: null,
        workspaceId: null
    };
}

function column(window) {
    const pos = window?.layout?.pos_in_scrolling_layout;
    return pos && pos.length >= 2 ? pos[0] : null;
}

function workspaceStep(from, to) {
    if (!from || !to || from.id === to.id)
        return null;
    if (from.output !== to.output || from.idx === to.idx)
        return none;
    return {
        axis: "y",
        sign: Math.sign(to.idx - from.idx)
    };
}

// null: nothing new to publish
function workspaceFocused(state, workspaceId, workspaces) {
    const from = workspaces[state.workspaceId];
    state.workspaceId = workspaceId;
    return workspaceStep(from, workspaces[workspaceId]);
}

function windowFocused(state, windowId, windows, workspaces) {
    if (windowId === null || windowId === undefined)
        return null;
    const fromId = state.windowId;
    state.windowId = windowId;
    if (fromId === windowId)
        return null;
    const to = windows.find(w => w.id === windowId);
    const from = fromId === null ? null : windows.find(w => w.id === fromId);
    const lastWorkspace = state.workspaceId;
    if (to)
        state.workspaceId = to.workspace_id;
    if (!from || !to)
        return none;
    if (from.workspace_id !== to.workspace_id) {
        // the workspace switch already published it
        if (lastWorkspace === to.workspace_id)
            return null;
        return workspaceStep(workspaces[from.workspace_id], workspaces[to.workspace_id]) ?? none;
    }
    const fromColumn = column(from);
    const toColumn = column(to);
    if (fromColumn === null || toColumn === null || fromColumn === toColumn)
        return none;
    return {
        axis: "x",
        sign: Math.sign(toColumn - fromColumn)
    };
}
