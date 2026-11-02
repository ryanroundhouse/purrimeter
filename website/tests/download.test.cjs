const { test } = require("node:test");
const assert = require("node:assert/strict");
const { detectPlatform, enhanceDownloads } = require("../download.js");

const cases = [
  ["Mac Safari", { platform: "MacIntel", userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", maxTouchPoints: 0 }, "macos"],
  ["Mac Chrome client hints", { userAgentData: { platform: "macOS", mobile: false } }, "macos"],
  ["Windows Chrome client hints", { userAgentData: { platform: "Windows", mobile: false } }, "windows"],
  ["Windows Firefox", { platform: "Win32", userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }, "windows"],
  ["iPad desktop mode", { platform: "MacIntel", userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15)", maxTouchPoints: 5 }, null],
  ["iPhone", { platform: "iPhone", userAgent: "iPhone; CPU iPhone OS 18 like Mac OS X" }, null],
  ["Android", { platform: "Linux armv8l", userAgent: "Linux; Android 15", userAgentData: { platform: "Android", mobile: true } }, "android"],
  ["Android UA only", { platform: "Linux armv8l", userAgent: "Mozilla/5.0 (Linux; Android 14; Pixel 8) Mobile" }, "android"],
  ["Windows Phone", { platform: "Win32", userAgent: "Windows Phone 10.0; Android 6.0" }, null],
  ["Linux", { platform: "Linux x86_64", userAgent: "X11; Linux x86_64" }, null],
  ["ChromeOS", { userAgentData: { platform: "Chrome OS", mobile: false }, userAgent: "X11; CrOS x86_64" }, null],
  ["Unknown", {}, null],
  ["UA-only Windows", { userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }, "windows"],
  ["UA-only Mac", { userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" }, "macos"],
  ["Explicit platform beats UA", { userAgentData: { platform: "Linux" }, userAgent: "Windows NT 10.0" }, null],
];
for (const [name, device, expected] of cases) {
  test(name, () => assert.equal(detectPlatform(device), expected));
}

function fakePage(status) {
  const element = (id, attrs = {}) => {
    const classes = new Set();
    const recommendation = { hidden: true };
    return {
      id, attrs: { ...attrs }, classList: { add: c => classes.add(c), contains: c => classes.has(c) },
      getAttribute(name) { return name in this.attrs ? this.attrs[name] : null; },
      setAttribute(name, value) { this.attrs[name] = value; },
      removeAttribute(name) { delete this.attrs[name]; },
      querySelector() { return recommendation; }, recommendation,
    };
  };
  const links = {
    "download-macos": element("download-macos", { href: "/downloads/Purrimeter-macOS.zip" }),
    "download-windows": element("download-windows", { href: "/downloads/Purrimeter-Windows.zip" }),
    "download-android": element("download-android", { href: "https://play.google.com/store/apps/details?id=com.roundhouselabsinc.purrimeter", "data-store-status": status }),
  };
  return { links, getElementById: id => links[id] || null };
}
const android = { userAgentData: { platform: "Android", mobile: true } };

test("coming soon disables the Play link and never recommends it", () => {
  const page = fakePage("coming-soon");
  enhanceDownloads(android, page);
  const store = page.links["download-android"];
  assert.equal(store.getAttribute("href"), null);
  assert.equal(store.getAttribute("aria-disabled"), "true");
  assert.equal(store.classList.contains("recommended"), false);
  assert.equal(store.recommendation.hidden, true);
});

test("live listing keeps its link and is recommended on Android", () => {
  const page = fakePage("live");
  enhanceDownloads(android, page);
  const store = page.links["download-android"];
  assert.ok(store.getAttribute("href").startsWith("https://play.google.com/"));
  assert.equal(store.classList.contains("recommended"), true);
  assert.equal(store.recommendation.hidden, false);
});

test("desktop recommendation is unaffected by the store flag", () => {
  const page = fakePage("coming-soon");
  enhanceDownloads({ userAgentData: { platform: "macOS", mobile: false } }, page);
  assert.equal(page.links["download-macos"].classList.contains("recommended"), true);
  assert.equal(page.links["download-android"].getAttribute("href"), null);
});
