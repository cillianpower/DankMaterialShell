import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const grid = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/PixelGrid.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), grid);

test("a popup anchored at gridFloor starts on a device pixel, at most a step before the item", () => {
    for (const dpr of [1, 1.25, 1.5, 1.75, 2, 4 / 3])
        for (const value of [0, 3, 3.5, 4, 7.25, 101, 1279.5]) {
            const at = grid.gridFloor(value, dpr);
            assert.ok(Math.abs(at * dpr - Math.round(at * dpr)) < 1e-9, `${value} at ${dpr} anchors off the grid: ${at}`);
            assert.ok(at <= value && value - at < grid.gridStep(dpr), `${value} at ${dpr}: ${at}`);
        }
    assert.deepEqual([grid.gridFloor(3.5, 1.5), grid.gridFloor(5, 1.25), grid.gridFloor(3.5, 1)], [2, 4, 3]);
});
