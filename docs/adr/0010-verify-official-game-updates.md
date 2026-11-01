# Verify automatic updates as official Purrimeter releases

Players may choose custom multiplayer servers, but accepting a server's release requirement must not grant it authority to distribute arbitrary executable code. The initial updater therefore accepts only official Purrimeter releases verified against an official signing key, rather than trusting any package supplied by the selected server. Self-hosted servers retain control over upgrade timing, while distributing modified clients through this updater is outside the initial scope.

Keep the dedicated release-signing key outside the repository on the publishing machine and require signed metadata for public game releases. This update trust mechanism does not expand the scope to Apple notarization or Windows publisher certification; retain the existing platform distribution approach.
