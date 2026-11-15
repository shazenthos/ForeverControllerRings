# Changelog

## 0.3.1
- Fix: in combat the ring no longer moves, scales or calls movement commands on anything the game guards, which raised "blocked from an action only available to the Blizzard UI". The picked slot's halo is now one per slot, shown and hidden; the zoom and the walk-stop run out of combat only.

## 0.3.0
- Quick flicks of the right stick now pick the right slot even in combat: the ring also reads which direction keys went down, and a diagonal (two keys) only counts as released when both are up. New `/fcr debug` prints every stick key event, to diagnose a release that does nothing.
- Letting go of the stick now uses exactly the slot that is lit (out of combat the pick is synced every frame instead of waiting for the stick's direction keys).
- New look: teal rim and deep navy face, round icons with a rim tinted by item quality, thin dividers between slots, a golden halo and a slight zoom on the picked slot, outlined item names (the picked one in gold), a gold title.

## 0.2.3
- Fix: the character could keep walking in one direction after the ring closed with the left stick still pushed. The ring now stops every walk it may have started.

## 0.2.2
- The ring now shows each item's name under its icon (two lines at most).

## 0.2.1
- Release pipeline test: first version published automatically from GitHub. No code changes.

## 0.2.0
- Map each ring to Forever's gamepad bar from a window (no slash commands needed).
- Consumables ring and Quest Items ring, secure and usable in combat.
- First public release; tested only with stubs so far, please report bugs.
