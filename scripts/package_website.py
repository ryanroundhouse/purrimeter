#!/usr/bin/env python3
"""Snapshot the site and existing client ZIPs; this never builds or publishes."""
import hashlib
import json
import shutil
import subprocess
import tarfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def package():
    subprocess.run(["node", "--test", "website/tests/download.test.cjs"], cwd=ROOT, check=True)
    clients = {
        "Purrimeter-macOS.zip": "macos/Purrimeter.app/Contents/MacOS/Purrimeter",
        "Purrimeter-Windows.zip": "Purrimeter.exe",
    }
    # The signed game manifest identifies these exact archives, independently of the website.
    signed = ROOT / "dist" / "game-release.json"
    release_tool = ROOT / "build" / "purrimeter-release"
    game_release = json.loads(subprocess.check_output([str(release_tool), "verify", str(signed)], text=True))
    for platform, name in (("macos", "Purrimeter-macOS.zip"), ("windows", "Purrimeter-Windows.zip")):
        package = game_release["packages"][platform]
        archive_path = ROOT / "dist" / name
        if sha256(archive_path) != package["sha256"] or archive_path.stat().st_size != package["size"]:
            raise ValueError(f"{name}: does not match signed game release; build a release first")
        with zipfile.ZipFile(archive_path) as archive:
            stamp = json.loads(archive.read("macos/game-build.json" if platform == "macos" else "game-build.json"))
            if stamp["id"] != game_release["id"] or stamp["sequence"] != game_release["sequence"]:
                raise ValueError("platform build identity differs from signed release")
    # Inspect before replacing the previous local preview.
    for name, executable in clients.items():
        with zipfile.ZipFile(ROOT / "dist" / name) as archive:
            names = archive.namelist()
            if executable not in names:
                raise ValueError(f"{name}: missing {executable}")
            if name.endswith("Windows.zip") and "Purrimeter.pck" not in names:
                raise ValueError("Windows ZIP must include Purrimeter.pck")
            if archive.testzip() is not None:
                raise ValueError(f"{name}: ZIP integrity check failed")

    site = ROOT / "build" / "website"
    if site.exists():
        shutil.rmtree(site)
    site.mkdir(parents=True)
    for name in ("index.html", "style.css", "download.js"):
        shutil.copy2(ROOT / "website" / name, site / name)
    shutil.copytree(ROOT / "website" / "assets", site / "assets")
    shutil.copy2(signed, site / "game-release.json")
    (site / "downloads").mkdir()
    checksums = []
    for name in clients:
        shutil.copy2(ROOT / "dist" / name, site / "downloads" / name)
        checksums.append(f"{sha256(site / 'downloads' / name)}  {name}\n")
    (site / "downloads" / "SHA256SUMS.txt").write_text("".join(checksums))
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    manifest = {
        "prepared_at": datetime.now(timezone.utc).isoformat(),
        "source_commit": commit,
        "source_dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)),
        "files": {str(p.relative_to(site)): sha256(p) for p in sorted(site.rglob("*")) if p.is_file()},
    }
    (site / "release.json").write_text(json.dumps(manifest, indent=2) + "\n")
    release = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + sha256(site / "release.json")[:12]
    (ROOT / "build" / "website-release.txt").write_text(release + "\n")
    bundle = ROOT / "build" / "purrimeter-website.tar.gz"
    with tarfile.open(bundle, "w:gz") as archive:
        archive.add(site, arcname="public")
        archive.add(ROOT / "website" / "deploy", arcname="deploy")
    print(f"Prepared {site}\nRelease: {release}\nBundle: {bundle}")


if __name__ == "__main__":
    package()
