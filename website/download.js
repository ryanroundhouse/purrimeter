"use strict";

// OS selection is only a convenience; every client link works without this file.
function detectPlatform(device) {
  const ua = device.userAgent || "";
  const platform = device.userAgentData?.platform || device.platform || "";
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

function enhanceDownloads(device, page) {
  const platform = detectPlatform(device);
  if (!platform) return;
  const link = page.getElementById(`download-${platform}`);
  link.classList.add("recommended");
  link.querySelector(".recommendation").hidden = false;
}

if (typeof module !== "undefined") module.exports = { detectPlatform, enhanceDownloads };
if (typeof document !== "undefined") enhanceDownloads(navigator, document);
