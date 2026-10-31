# Prefer open routes before considering breaches

Enemies take the shortest open route whenever one exists, even if destroying a tower would reach the exit sooner. Only a fully blocked enemy minimizes estimated travel plus destruction time, using its own damage rather than predicted help from other enemies. This preserves the agreed maze-building rule and makes breaching a response to a sealed route; globally minimizing escape time across both open and destructive routes would change that gameplay contract.

Amended by [ADR 0005](0005-frenzy-breaks-rerouting-loops.md): enemies in frenzy are exempt from open-route priority to prevent repeated rerouting loops. The original rule continues to apply to enemies outside frenzy.
