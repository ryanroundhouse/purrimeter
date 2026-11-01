# Publish browser and native builds under one game release

The mobile browser version includes the full game and cross-platform multiplayer, so browser, macOS, and Windows builds will publish together under one release identity rather than follow independent release schedules. This preserves the server-designated admission policy and consistent gameplay across clients, at the cost of requiring all three builds to be ready for each release. Existing multiplayer visits may continue on an older release; browser players save and reload to obtain the required build before a new admission, while native players retain their existing update flow.

This accepted design extends [ADR 0009](0009-server-designated-release-admission.md); browser support has not yet been implemented.
