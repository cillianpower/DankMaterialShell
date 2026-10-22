import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const shadow = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/ShellShadow.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), shadow);
const plain = value => JSON.parse(JSON.stringify(value));

test("niri's css-style #rgba colour: the last digit is alpha", () => {
    const c = plain(shadow.parseColor("#0007"));
    assert.deepEqual([c.r, c.g, c.b], [0, 0, 0]);
    assert.ok(Math.abs(c.a - 0x77 / 255) < 1e-9);
    assert.deepEqual(plain(shadow.parseColor("#ff000080")).r, 1);
    assert.ok(Math.abs(shadow.parseColor("#ff000080").a - 128 / 255) < 1e-9);
    assert.equal(shadow.parseColor("#abc").g, 0xbb / 255);
});

test("sigma is half the softness and spread and offset round up, as niri's layout/shadow.rs", () => {
    const p = plain(shadow.params({ softness: 30, spread: 4.2, offsetX: 0, offsetY: 4.5, color: "#0007" }));
    assert.equal(p.sigma, 15);
    assert.equal(p.spread, 5);
    assert.equal(p.offsetY, 5);
    assert.equal(plain(shadow.params({ softness: 10, spread: -1.5, offsetX: 0, offsetY: 0, color: "#000" })).spread, -2);
});

test("the layout block is niri's shadow syntax, and a bad colour falls back to niri's default", () => {
    const kdl = shadow.niriBlock({ softness: 30, spread: 5, offsetX: 0, offsetY: 5, color: "#0007" });
    assert.match(kdl, /shadow \{\n\s+on\n\s+softness 30\n\s+spread 5\n\s+offset x=0 y=5\n\s+color "#0007"\n\s+\}/);
    assert.match(shadow.niriBlock({ softness: 1, spread: 1, offsetX: 1, offsetY: 1, color: "red; }" }), /color "#0007"/);
});
