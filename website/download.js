"use strict";

// OS selection is only a convenience; every client link works without this file.
function detectPlatform(device) {
  const ua = device.userAgent || "";
  const platform = device.userAgentData?.platform || device.platform || "";
  if (/Android/i.test(platform) || (/Android/i.test(ua) && !/Windows Phone/i.test(ua))) return "android";
  if (/iPhone|iPad|iPod/i.test(ua + platform) || (/Mac/i.test(platform) && device.maxTouchPoints > 1)) return "ios";
  const mobile = device.userAgentData?.mobile ||
    /Android|iPhone|iPad|iPod|Windows Phone|Mobile/i.test(ua) ||
    (/Mac/i.test(platform) && device.maxTouchPoints > 1);
  if (mobile) return null;
  if (/Windows|Win32|Win64/i.test(platform)) return "windows";
  if (/macOS|MacIntel|MacPPC|Macintosh/i.test(platform)) return "macos";
  // Prefer an explicitly reported platform over a contradictory UA string.
  if (platform) return null;
  if (/Windows NT/i.test(ua)) return "windows";
  if (/Macintosh|Mac OS X/i.test(ua)) return "macos";
  return null;
}

// Store links carry one flag, data-store-status: "coming-soon" until the
// listing is published, then "live". Nothing else on the page needs to change.
function storeLive(link) {
  return link !== null && link.getAttribute("data-store-status") === "live";
}

function enhanceDownloads(device, page) {
  for (const name of ["android", "ios"]) {
    const store = page.getElementById(`download-${name}`);
    if (!store) continue;
    if (!storeLive(store)) {
      store.removeAttribute("href");
      store.setAttribute("aria-disabled", "true");
    } else if (store.getAttribute("data-store-url")) {
      store.setAttribute("href", store.getAttribute("data-store-url"));
      store.removeAttribute("aria-disabled");
    }
  }
  const platform = detectPlatform(device);
  if (!platform) return;
  const link = page.getElementById(`download-${platform}`);
  if (!link || (["android", "ios"].includes(platform) && !storeLive(link))) return;
  link.classList.add("recommended");
  link.querySelector(".recommendation").hidden = false;
}

if (typeof module !== "undefined") module.exports = { detectPlatform, enhanceDownloads, storeLive };
if (typeof document !== "undefined") enhanceDownloads(navigator, document);
