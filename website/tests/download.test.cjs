const { test } = require("node:test");
const assert = require("node:assert/strict");
const { detectPlatform } = require("../download.js");

const cases = [
  ["Mac Safari", { platform: "MacIntel", userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", maxTouchPoints: 0 }, "macos"],
  ["Mac Chrome client hints", { userAgentData: { platform: "macOS", mobile: false } }, "macos"],
  ["Windows Chrome client hints", { userAgentData: { platform: "Windows", mobile: false } }, "windows"],
  ["Windows Firefox", { platform: "Win32", userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }, "windows"],
  ["iPad desktop mode", { platform: "MacIntel", userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15)", maxTouchPoints: 5 }, null],
  ["iPhone", { platform: "iPhone", userAgent: "iPhone; CPU iPhone OS 18 like Mac OS X" }, null],
  ["Android", { platform: "Linux armv8l", userAgent: "Linux; Android 15", userAgentData: { platform: "Android", mobile: true } }, null],
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
