import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const pages = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/IslandPages.js", import.meta.url), "utf8").replace(/^\.pragma.*$/m, ""), pages);
const plain = value => JSON.parse(JSON.stringify(value));
const cc = section => ({ activity: "controlcenter", section });
const page = activity => ({ activity, section: "" });

test("the face's pages are the ones its groups open, in the face's order", () => {
    assert.deepEqual(plain(pages.facePages(["tray", "notifications", "status", "volume", "clock"], false)),
        [page("notificationcenter"), cc(""), page("home")]);
});

test("groups that act in place open no page", () => {
    assert.deepEqual(plain(pages.facePages(["tray", "volume", "brightness", "workspaces"], true)), []);
});

test("media is a page only while something plays", () => {
    assert.deepEqual(plain(pages.facePages(["media", "clock"], false)), [page("home")]);
    assert.deepEqual(plain(pages.facePages(["media", "clock"], true)), [page("media"), page("home")]);
});

test("privacy opens the microphone's page of the control centre, status the grid; each page once", () => {
    assert.deepEqual(plain(pages.facePages(["privacy", "status", "status"], false)), [cc("audioInput"), cc("")]);
});

test("right and left step through the face's pages and wrap", () => {
    const list = pages.facePages(["notifications", "status", "clock"], false);
    assert.deepEqual(plain(pages.stepPage(list, page("home"), 1)), page("notificationcenter"));
    assert.deepEqual(plain(pages.stepPage(list, page("notificationcenter"), -1)), page("home"));
    assert.deepEqual(plain(pages.stepPage(list, cc(""), 1)), page("home"));
    assert.equal(pages.stepPage([], page("home"), 1), null);
});

test("a page no group opens steps onto the face's first or last page; the control centre elsewhere counts as its own", () => {
    const list = pages.facePages(["status", "clock"], false);
    assert.deepEqual(plain(pages.stepPage(list, page("launcher"), 1)), cc(""));
    assert.deepEqual(plain(pages.stepPage(list, page("launcher"), -1)), page("home"));
    // the control centre moved on to the audio page: still the status group's page
    assert.deepEqual(plain(pages.stepPage(list, cc("audioOutput"), 1)), page("home"));
});

test("a layer of a plugin's page is still that page", () => {
    assert.equal(pages.samePage(cc("plugin_benq/picture"), cc("plugin_benq")), true);
    assert.equal(pages.samePage(cc("audioInput"), cc("")), false);
});

test("the face lights the group whose page shows", () => {
    const groups = ["tray", "privacy", "notifications", "status", "volume", "clock"];
    assert.equal(pages.litGroup(groups, page("home"), false), "clock");
    assert.equal(pages.litGroup(groups, page("notificationcenter"), false), "notifications");
    assert.equal(pages.litGroup(groups, cc(""), false), "status");
    assert.equal(pages.litGroup(groups, cc("audioInput"), false), "privacy");
});

test("a control-centre page no group opens lights the group opening the grid", () => {
    assert.equal(pages.litGroup(["status", "clock"], cc("audioOutput"), false), "status");
    assert.equal(pages.litGroup(["privacy", "status"], cc("plugin_benq/picture"), false), "status");
    // no grid group: the first control-centre group
    assert.equal(pages.litGroup(["privacy", "clock"], cc("brightness"), false), "privacy");
});

test("nothing lights for a page the face doesn't open", () => {
    assert.equal(pages.litGroup(["status", "clock"], page("launcher"), false), "");
    assert.equal(pages.litGroup([], page("home"), false), "");
    assert.equal(pages.litGroup(["media", "clock"], page("media"), false), "");
});
