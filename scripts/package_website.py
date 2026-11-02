#!/usr/bin/env python3
"""Snapshot the site and matching native/browser release ZIPs; this never builds or publishes."""
import argparse
import gzip
import hashlib
import json
import re
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


def package(source_commit=None):
    subprocess.run(["node", "--test", "website/tests/download.test.cjs"], cwd=ROOT, check=True)
    clients = {
        "Purrimeter-macOS.zip": "macos/Purrimeter.app/Contents/MacOS/Purrimeter",
        "Purrimeter-Windows.zip": "Purrimeter.exe",
        "Purrimeter-Web.zip": "index.html",
    }
    # The signed game manifest identifies these exact archives, independently of the website.
    signed = ROOT / "dist" / "game-release.json"
    release_tool = ROOT / "build" / "purrimeter-release"
    game_release = json.loads(subprocess.check_output([str(release_tool), "verify", str(signed)], text=True))
    for platform, name in (("macos", "Purrimeter-macOS.zip"), ("windows", "Purrimeter-Windows.zip"), ("web", "Purrimeter-Web.zip")):
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
            if name == "Purrimeter-Web.zip" and not {"index.js", "index.wasm", "index.pck", "config.js", "browser.js", "browser.css", "game-build.json"}.issubset(names):
                raise ValueError("Browser ZIP is missing runtime files")
            if archive.testzip() is not None:
                raise ValueError(f"{name}: ZIP integrity check failed")

    server_archive = ROOT / "dist/Purrimeter-Server.tar.gz"
    if not server_archive.is_file():
        raise ValueError("Missing server download; run scripts/build_server.sh first")
    with tarfile.open(server_archive) as archive:
        required = {"server/purrimeter-relay-linux-amd64", "server/purrimeter-relay-linux-arm64", "server/README.md"}
        if not required.issubset(archive.getnames()):
            raise ValueError("Server archive is incomplete")

    site = ROOT / "build" / "website"
    if site.exists():
        shutil.rmtree(site)
    site.mkdir(parents=True)
    for name in ("index.html", "style.css", "download.js"):
        shutil.copy2(ROOT / "website" / name, site / name)
    shutil.copytree(ROOT / "website" / "assets", site / "assets")
    shutil.copytree(ROOT / "website" / "privacy", site / "privacy")
    # Extract the signed browser archive, not mutable loose export files.
    with zipfile.ZipFile(ROOT / "dist" / "Purrimeter-Web.zip") as archive:
        for entry in archive.infolist():
            if entry.filename.startswith("/") or ".." in Path(entry.filename).parts:
                raise ValueError("Unsafe browser archive path")
        archive.extractall(site / "play")
    # Each page references one immutable browser build, avoiding mixed .pck/.wasm
    # during publication. The shell stays at /play/ so saved gardens keep origin.
    play = site / "play"
    base = f"/game-releases/{game_release['id']}/web/"
    html = (play / "index.html").read_text()
    for name in ("index.js", "config.js", "browser.js", "browser.css"):
        html = html.replace(f'"{name}"', f'"{base}{name}"')
    (play / "index.html").write_text(html)
    config = (play / "config.js").read_text()
    # Engine config fileSizes use the same executable prefix as the fetched files.
    config = config.replace('"index', '"' + base + 'index')
    (play / "config.js").write_text(config)
    (play / "config.js.gz").write_bytes(gzip.compress(config.encode(),mtime=0))
    shutil.copy2(signed, site / "game-release.json")
    (site / "downloads").mkdir()
    checksums = []
    for name in [*clients, server_archive.name]:
        shutil.copy2(ROOT / "dist" / name, site / "downloads" / name)
        checksums.append(f"{sha256(site / 'downloads' / name)}  {name}\n")
    (site / "downloads" / "SHA256SUMS.txt").write_text("".join(checksums))
    if source_commit is not None and not re.fullmatch(r"[a-f0-9]{40}", source_commit):
        raise ValueError("Source commit must be a full Git commit ID")
    commit = source_commit or subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    manifest = {
        "prepared_at": datetime.now(timezone.utc).isoformat(),
        "source_commit": commit,
        "source_dirty": False if source_commit else bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)),
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-commit", help="Provenance of an isolated git-archive build (deployment orchestrator only)")
    package(parser.parse_args().source_commit)
