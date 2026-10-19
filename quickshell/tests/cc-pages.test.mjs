import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const pages = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/CcPages.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), pages);
const plain = value => JSON.parse(JSON.stringify(value));

const benq = { id: "benq-ddc-dms", icon: "monitor", controlCenterPage: { parent: "brightness", devices: "RD280UG|BenQ", title: "Picture" } };
const focusrite = { id: "scarlett", controlCenterPage: { parent: "audioOutput", devices: "Scarlett" } };
const eq = { id: "eq", icon: "equalizer", controlCenterPage: { parent: "audioOutput", title: "Equaliser" } };
const stray = [{ id: "plain" }, { id: "bad", controlCenterPage: { parent: "network" } }, { id: "loose", controlCenterPage: "brightness" }];
const plugins = [benq, focusrite, eq, ...stray];

test("the volume rows' chevrons open the audio pages; other rows keep their own", () => {
    assert.equal(pages.sliderSection("volumeSlider"), "audioOutput");
    assert.equal(pages.sliderSection("inputVolumeSlider"), "audioInput");
    assert.equal(pages.sliderSection("brightnessSlider"), "");
});

test("a device's own page sits under it when the plugin's pattern names it", () => {
    assert.deepEqual(plain(pages.pagesUnder(plugins, "brightness", "ddc:i2c-5 BenQ RD280UG")), [
        { section: "plugin_benq-ddc-dms", pluginId: "benq-ddc-dms", title: "Picture", icon: "monitor" }
    ]);
    assert.deepEqual(plain(pages.pagesUnder(plugins, "brightness", "intel_backlight Built-in display")), []);
    assert.deepEqual(plain(pages.pagesUnder(plugins, "audioOutput", "alsa_output.usb-Focusrite_Scarlett_4i4 Scarlett 4i4")).map(page => page.pluginId), ["scarlett"]);
});

test("a page without a device pattern belongs to the page itself, not to each device", () => {
    assert.deepEqual(plain(pages.pagesUnder(plugins, "audioOutput", null)).map(page => page.pluginId), ["eq"]);
    assert.deepEqual(plain(pages.pagesUnder(plugins, "audioOutput", "Scarlett 4i4")).map(page => page.pluginId), ["scarlett"]);
    assert.deepEqual(plain(pages.pagesUnder(plugins, "audioInput", null)), []);
});

test("a malformed pattern falls back to plain text", () => {
    const odd = [{ id: "odd", controlCenterPage: { parent: "brightness", devices: "RD280UG (" } }];
    assert.deepEqual(plain(pages.pagesUnder(odd, "brightness", "BenQ RD280UG (DP)")).map(page => page.pluginId), ["odd"]);
    assert.deepEqual(plain(pages.pagesUnder(odd, "brightness", "Dell")), []);
});

test("a plugin page opened from the bar has the page it sits under one layer up", () => {
    const widgets = [{ id: "volumeSlider" }, { id: "brightnessSlider", instanceId: "main" }];
    assert.equal(pages.parentSection("plugin_benq-ddc-dms", plugins, widgets), "brightnessSlider_main");
    assert.equal(pages.parentSection("plugin_benq-ddc-dms", plugins, []), "brightnessSlider_default");
    assert.equal(pages.parentSection("plugin_scarlett", plugins, widgets), "audioOutput");
    assert.equal(pages.parentSection("plugin_plain", plugins, widgets), "");
    assert.equal(pages.parentSection("network", plugins, widgets), "");
});

test("a device list's page rows: each claimed device once, titled by the device, then the page's own", () => {
    const devices = [
        { text: "alsa_output.usb-Focusrite_Scarlett_4i4 Scarlett 4i4", title: "Scarlett 4i4" },
        { text: "alsa_output.hdmi BenQ RD280UG", title: "RD280UG speakers" },
        { text: "alsa_output.usb-Focusrite_Scarlett_4i4.monitor Scarlett 4i4 monitor", title: "Scarlett monitor" }
    ];
    assert.deepEqual(plain(pages.pagesForDevices(plugins, "audioOutput", devices)).map(row => [row.pluginId, row.title]), [
        ["scarlett", "Scarlett 4i4"],
        ["eq", "Equaliser"]
    ]);
    assert.deepEqual(plain(pages.pagesForDevices(plugins, "audioInput", devices)), []);
});

test("a layer of a plugin's page sits under that page", () => {
    assert.equal(pages.parentSection("plugin_benq-ddc-dms/color-mode", plugins, []), "plugin_benq-ddc-dms");
});
