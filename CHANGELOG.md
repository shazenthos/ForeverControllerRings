# Changelog

## 0.4.0
- Items are now sorted and colour-coded by kind. Consumables go round the ring in a fixed order: Food (orange), Drink (blue), Potion (red), Bandage (cream), Elixir / Flask (green), Scroll (gold), Other (violet); inside each kind the best (highest required level) comes first. Quest items: ones you use (teal), then ones that start a quest (gold). The rim of each slot has its kind's colour and the kind is named in the middle of the ring.

## 0.3.2
- Fix the "blocked from an action only available to the Blizzard UI" popup when closing the ring or choosing an item: the calls that stop a walk (added in 0.2.3) are blocked to addons, even from a pcall. They are gone. The left stick now does nothing while the ring is open (it used to be bound to the movement commands, which left the character running if the ring closed with the stick held).
- The ring is bigger (520 instead of 400): larger icons, wider room for item names, and a roomier centre.
- The text in the middle of the ring is smaller and wraps inside the hub instead of running over its rim.
- If the game blocks any other call of the addon, the chat now says which function it was.

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
