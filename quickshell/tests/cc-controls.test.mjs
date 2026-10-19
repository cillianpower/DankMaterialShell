import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const controls = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/CcControls.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), controls);
const plain = value => JSON.parse(JSON.stringify(value));

// shapes from bebenqli's json snapshot of an RD280UG
const source = { name: "source", label: "Source", type: "cycle", value: 17, options: [{ value: 15, label: "DP" }, { value: 17, label: "HDMI" }, { value: 19, label: "USB-C" }] };
const aiContrast = { name: "ai-contrast", label: "AI Contrast", type: "cycle", value: 0, options: [{ value: 0, label: "OFF" }, { value: 1, label: "ON" }] };
const colorMode = { name: "color-mode", label: "Color Mode", type: "cycle", value: 15, options: [{ value: 48, label: "Coding Dark" }, { value: 49, label: "Coding Light" }, { value: 15, label: "M-Book" }, { value: 10, label: "sRGB" }] };
const nightMode = { name: "night-mode", label: "Night Mode", type: "cycle", value: 2, options: [{ value: 0, label: "OFF" }, { value: 1, label: "ON" }, { value: 2, label: "AUTO" }] };
const lightMode = { name: "mh-light-mode", label: "Light Mode", type: "cycle", value: 1, options: [{ value: 1, label: "270°" }, { value: 2, label: "360°" }] };
const biSwitch = { name: "bi-switch", label: "Brightness Intelligence", type: "cycle", value: 0, options: [{ value: 0, label: "OFF" }, { value: 1, label: "Brightness" }, { value: 2, label: "Brightness + Color Temp" }] };
const contrast = { name: "contrast", label: "Contrast", type: "range", value: 50, min: 0, max: 100 };

test("each control gets the standard row for its shape", () => {
    assert.equal(controls.kind(contrast), "range");
    assert.equal(controls.kind(aiContrast), "toggle");
    assert.equal(controls.kind(source), "segmented");
    assert.equal(controls.kind(nightMode), "segmented");
    assert.equal(controls.kind(lightMode), "segmented");
    // too many options, or too long to sit side by side: a layer down
    assert.equal(controls.kind(colorMode), "list");
    assert.equal(controls.kind(biSwitch), "list");
    assert.equal(controls.kind({ type: "toggle", value: true }), "toggle");
    assert.equal(controls.kind({ type: "mystery" }), "");
});

test("an off/on choice reads and writes as a toggle", () => {
    assert.equal(controls.toggleChecked(aiContrast), false);
    assert.equal(controls.toggleValue(aiContrast, true), 1);
    assert.equal(controls.toggleValue(aiContrast, false), 0);
    assert.equal(controls.toggleChecked({ ...aiContrast, value: 1 }), true);
    assert.equal(controls.toggleValue({ type: "toggle" }, true), true);
});

test("a choice shows the label of its value, or a dash when the monitor reports something unknown", () => {
    assert.equal(controls.optionLabel(colorMode), "M-Book");
    assert.equal(controls.optionLabel({ ...colorMode, value: 99 }), "—");
});

test("controls are found by name across groups", () => {
    const groups = [{ title: "Image", controls: [contrast, colorMode] }, { title: "Input", controls: [source] }];
    assert.equal(controls.findControl(groups, "source"), source);
    assert.equal(controls.findControl(groups, "nope"), null);
});

test("a plugin page's layers are sections under it", () => {
    assert.deepEqual(plain(controls.parseSection("plugin_benq-ddc-dms")), { pluginId: "benq-ddc-dms", sub: "" });
    assert.deepEqual(plain(controls.parseSection("plugin_benq-ddc-dms/color-mode")), { pluginId: "benq-ddc-dms", sub: "color-mode" });
    assert.deepEqual(plain(controls.parseSection("network")), { pluginId: "", sub: "" });
    assert.equal(controls.pageRoot("plugin_benq-ddc-dms/color-mode"), "plugin_benq-ddc-dms");
    assert.equal(controls.pageRoot("audioOutput"), "audioOutput");
});

const many = [
    { title: "Image", controls: [contrast, colorMode, { name: "sharpness", label: "Sharpness", type: "range", value: 6, min: 0, max: 10 }, { name: "brightness", label: "Brightness", type: "range", value: 55, min: 0, max: 100 }, aiContrast] },
    { title: "Eye Care", controls: [nightMode, biSwitch, { name: "night-level", label: "Night Level", type: "range", value: 1, min: 1, max: 10 }] },
    { title: "Input", controls: [source] }
];

test("a long page of several groups is an index of its groups; a short one shows its controls", () => {
    assert.equal(controls.indexed(many), true);
    assert.equal(controls.indexed([{ title: "Monitoring", controls: [aiContrast] }, { title: "Clock", controls: [colorMode] }]), false);
    // one group, however long, has nothing to index
    assert.equal(controls.indexed([{ title: "All", controls: many.flatMap(g => g.controls) }]), false);
});

test("layers name a group, a choice, or a choice within a group, and resolve back", () => {
    assert.equal(controls.subFor("Eye Care", ""), "@Eye Care");
    assert.equal(controls.subFor("Eye Care", "bi-switch"), "@Eye Care/bi-switch");
    assert.equal(controls.subFor("", "color-mode"), "color-mode");
    const group = controls.resolveSub(many, "@Eye Care");
    assert.equal(group.group.title, "Eye Care");
    assert.equal(group.control, null);
    const inGroup = controls.resolveSub(many, "@Eye Care/bi-switch");
    assert.equal(inGroup.group.title, "Eye Care");
    assert.equal(inGroup.control, biSwitch);
    assert.equal(controls.resolveSub(many, "color-mode").control, colorMode);
    assert.deepEqual(plain(controls.resolveSub(many, "@Nope")), { group: null, control: null });
    assert.deepEqual(plain(controls.resolveSub(many, "")), { group: null, control: null });
});

test("an index row says what its group holds", () => {
    assert.equal(controls.groupSummary(many[1]), "Night Mode, Brightness Intelligence, Night Level");
    assert.equal(controls.groupSummary(many[0]), "Contrast, Color Mode, Sharpness…");
});
