import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const source = readFileSync(new URL("../Services/SessionService.qml", import.meta.url), "utf8");
const restore = source.match(/^    function restoreWrapperEnv\(env\) \{\n[\s\S]*?^    \}/m)[0];

function environment(snapshots, initial = {}) {
    const context = vm.createContext({ Quickshell: { env: key => snapshots[key] ?? null } });
    vm.runInContext(restore, context);
    return context.restoreWrapperEnv(initial);
}

test("private Mesa paths are removed from app launches when originally unset", () => {
    const keys = ["__EGL_VENDOR_LIBRARY_FILENAMES", "GBM_BACKENDS_PATH", "LIBGL_DRIVERS_PATH"];
    const snapshots = Object.fromEntries(keys.map(key => [`DMS_ORIG_${key}`, ""]));
    const result = environment(snapshots, { XCURSOR_SIZE: "24" });
    for (const key of keys)
        assert.equal(result[key], null);
    assert.equal(result.XCURSOR_SIZE, "24");
});

test("original graphics paths are restored when recorded", () => {
    const result = environment({ DMS_ORIG_LIBGL_DRIVERS_PATH: "/original/dri" });
    assert.equal(result.LIBGL_DRIVERS_PATH, "/original/dri");
});

test("launch environments without wrapper snapshots retain app overrides", () => {
    const initial = { LIBGL_DRIVERS_PATH: "/app/dri" };
    assert.equal(environment({}, initial).LIBGL_DRIVERS_PATH, "/app/dri");
});
