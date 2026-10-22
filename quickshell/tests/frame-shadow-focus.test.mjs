import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const context = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/ConnectedSurfaceDescriptor.js", import.meta.url), "utf8").replace(".pragma library", ""), context);
const focus = list => vm.runInContext("holdsUserFocus", context)(list);
const d = (kind, visible) => ({ kind, visible });

test("the bar alone is not focus", () => {
    assert.equal(focus([]), false);
    assert.equal(focus([d("popout", false), d("island", false), d("modal", false), d("slideout", false)]), false);
});

test("a summoned surface is focus", () => {
    for (const kind of ["popout", "slideout", "modal", "launcher", "island"])
        assert.equal(focus([d("popout", false), d(kind, true)]), true, kind);
});

test("notifications, osds and docks are not focus", () => {
    for (const kind of ["notification", "osd", "dock"])
        assert.equal(focus([d(kind, true)]), false, kind);
});
