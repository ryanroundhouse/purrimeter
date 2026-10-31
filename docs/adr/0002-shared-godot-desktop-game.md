# Share one Godot game across macOS and Windows

The user wants native Mac play and a Windows game to send to their son. The original AppKit/AVFoundation interface cannot compile for Windows, so the accepted design replaces it with a shared Godot 4.7.2 game and ports the simulation rules while retaining the original Swift source for reference. One project now produces a universal Mac app and a portable Windows x86-64 executable/resource pack, avoiding divergent gameplay and artwork implementations on the two platforms.
