import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";
import { loadScript } from "./qml-script.mjs";

const source = readFileSync(new URL("../Services/NiriService.qml", import.meta.url), "utf8");
const handlers = ["setWorkspaces", "updateWorkspace", "updateCurrentOutputWorkspaces", "handleWorkspacesChanged", "handleWorkspaceActivated", "handleWorkspaceActiveWindowChanged", "handleWindowFocusChanged", "handleWindowOpenedOrChanged", "differsOnlyInTitle", "sortWindowsByLayout", "publishFocusMotion"];

const tiled = (id, workspace, column) => ({ id, workspace_id: workspace, title: `w${id}`, layout: { pos_in_scrolling_layout: [column, 1] } });

// eDP-1 holds workspaces 1 and 2 (and an empty 4), DP-1 holds 3; windows 10 and 11 are columns 1 and 2 of workspace 1
function niri() {
    const FocusMotion = loadScript(new URL("../Common/FocusMotion.js", import.meta.url));
    const context = vm.createContext({ workspaces: {}, allWorkspaces: [], windows: [], outputs: {}, FocusMotion, _focusMotionTracker: FocusMotion.tracker(), focusMotion: { axis: "none", sign: 0, serial: 0, time: 0 } });
    context.root = context;
    for (const [, name, args, body] of source.matchAll(/^    function (\w+)\(([^)]*)\) \{([\s\S]*?)^    \}/gm)) {
        if (handlers.includes(name))
            vm.runInContext(`function ${name}(${args}) {${body}}`, context);
    }
    context.handleWorkspacesChanged({ workspaces: [
        { id: 1, idx: 1, output: "eDP-1", is_active: true, is_focused: true },
        { id: 2, idx: 2, output: "eDP-1", is_active: false, is_focused: false },
        { id: 4, idx: 3, output: "eDP-1", is_active: false, is_focused: false },
        { id: 3, idx: 2, output: "DP-1", is_active: true, is_focused: false }
    ] });
    context.windows = [tiled(10, 1, 1), tiled(11, 1, 2), tiled(12, 2, 1), tiled(13, 3, 1)];
    context.handleWindowFocusChanged({ id: 10 });
    return context;
}

// the motions published while the events ran, in order
function publishes(state, events) {
    const seen = [];
    for (const [handler, data] of events) {
        const serial = state.focusMotion.serial;
        state[handler](data);
        if (state.focusMotion.serial !== serial)
            seen.push(`${state.focusMotion.axis}${state.focusMotion.sign > 0 ? "+" : state.focusMotion.sign < 0 ? "-" : ""}`);
    }
    return seen;
}

const focusWindow = id => ["handleWindowFocusChanged", { id }];
const activate = id => ["handleWorkspaceActivated", { id, focused: true }];
const activeWindow = (workspace_id, active_window_id) => ["handleWorkspaceActiveWindowChanged", { workspace_id, active_window_id }];

test("focus moving between columns publishes x, signed by the column it moved to", () => {
    const state = niri();
    assert.deepEqual(publishes(state, [activeWindow(1, 11), focusWindow(11)]), ["x+"]);
    assert.deepEqual(publishes(state, [focusWindow(10)]), ["x-"]);
    assert.deepEqual(publishes(state, [focusWindow(10)]), []);
});

test("a workspace switch on one output publishes y once, whichever event comes first", () => {
    const orders = [
        [activate(2), activeWindow(2, 12), focusWindow(12)],
        [focusWindow(12), activeWindow(2, 12), activate(2)]
    ];
    for (const events of orders) {
        const state = niri();
        assert.deepEqual(publishes(state, events), ["y+"]);
        assert.deepEqual(publishes(state, [activate(1), focusWindow(10)]), ["y-"]);
    }
    const state = niri();
    assert.deepEqual(publishes(state, [activate(4), focusWindow(null), activate(1), focusWindow(10)]), ["y+", "y-"]);
});

test("focus reaching another output publishes no direction", () => {
    for (const events of [[activate(3), focusWindow(13)], [focusWindow(13), activate(3)]]) {
        const state = niri();
        assert.deepEqual(publishes(state, events), ["none"]);
    }
});

test("a new window takes focus as it opens: beside the last, or with no layout yet, or before niri reports it", () => {
    const state = niri();
    const opened = window => ["handleWindowOpenedOrChanged", { window: { ...window, is_focused: true } }];
    assert.deepEqual(publishes(state, [opened(tiled(14, 1, 2))]), ["x+"]);
    const floating = { id: 15, workspace_id: 1, title: "w15", layout: { pos_in_scrolling_layout: null } };
    assert.deepEqual(publishes(state, [opened(floating)]), ["none"]);
    assert.deepEqual(publishes(state, [focusWindow(16), opened(tiled(16, 1, 3))]), ["none"]);
    assert.deepEqual(publishes(state, [focusWindow(11)]), ["x-"]);
});
