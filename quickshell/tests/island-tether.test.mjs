import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const resolver = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/LayoutResolver.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), resolver);
const plain = value => JSON.parse(JSON.stringify(value));

test("an island at its section's outer end is tethered to that end of the bar", () => {
    assert.equal(resolver.islandTetheredEnd({ rightWidgets: [{ id: "clock" }, { id: "island", enabled: true }] }), "end");
    assert.equal(resolver.islandTetheredEnd({ rightWidgets: ["island"] }), "end");
    assert.equal(resolver.islandTetheredEnd({ leftWidgets: [{ id: "island" }, { id: "workspaceSwitcher" }] }), "start");
    // a widget past it on the outside: not tethered
    assert.equal(resolver.islandTetheredEnd({ rightWidgets: [{ id: "island" }, { id: "clock" }] }), "");
    assert.equal(resolver.islandTetheredEnd({ centerWidgets: [{ id: "island" }] }), "");
    assert.equal(resolver.islandTetheredEnd({}), "");
    assert.equal(resolver.islandTetheredEnd(undefined), "");
});

test("a disabled widget past the island doesn't count", () => {
    assert.equal(resolver.islandTetheredEnd({ rightWidgets: [{ id: "island" }, { id: "clock", enabled: false }] }), "end");
});

test("a tethered sheet has no clearance at that end, and is square where it meets the screen's side", () => {
    assert.deepEqual(plain(resolver.islandAlongMargins("end", 8)), { start: 8, end: 0 });
    assert.deepEqual(plain(resolver.islandAlongMargins("", 8)), { start: 8, end: 8 });
    // a top bar: corners meeting the bar square (near 0), far ones round, the right-hand ones square at the screen edge
    assert.deepEqual(plain(resolver.islandSheetRadii("top", 0, 12, "")), [0, 0, 12, 12]);
    assert.deepEqual(plain(resolver.islandSheetRadii("top", 0, 12, "end")), [0, 0, 12, 0]);
    assert.deepEqual(plain(resolver.islandSheetRadii("top", 0, 12, "start")), [0, 0, 0, 12]);
    // a right-hand vertical bar tethered at its bottom end
    assert.deepEqual(plain(resolver.islandSheetRadii("right", 0, 12, "end")), [12, 0, 0, 0]);
});

test("an untinted frame pulls its blur in a pixel only when the bar's edge falls between device pixels", () => {
    // 24px at 1.5: 36 device pixels, on the grid: no seam
    assert.equal(resolver.frameBlurCompensation(0, [24, 0, 0, 0], 1.5), 0);
    // 23px at 1.5: 34.5 device pixels: keep the pixel back
    assert.equal(resolver.frameBlurCompensation(0, [23, 0, 0, 0], 1.5), 1);
    assert.equal(resolver.frameBlurCompensation(0, [24], 1), 0);
    // a tinted frame draws its own edge: never
    assert.equal(resolver.frameBlurCompensation(0.8, [23], 1.5), 0);
});
