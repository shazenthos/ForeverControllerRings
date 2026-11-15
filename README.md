# Forever Controller Rings (v0.2.0, untested in the real client)

Two radial rings for WoW: Forever's gamepad UI, and nothing else:

- **Consumables**: everything of item class Consumable in your bags (food and drink, potions, bandages, scrolls, elixirs, flasks, Forever's new kinds). Up to 24, in pages of 8.
- **Quest Items**: items you use for a quest, then items that start one.

They are **mapped like a spell**: you put each ring on a button of Forever's own gamepad bar. No R3, no button combinations; the ring opens when you press that button.

## Order and colours
Each kind of item has its own page (D-pad left/right turns pages), in a fixed order, each kind with its own colour on the rim of its slots: Food (orange), Drink (blue), Potion (red), Bandage (cream), Elixir / Flask (green), Scroll (gold), Other (violet). Within a kind the best item (highest required level) comes first. The page's kind is named at the top of the ring. Quest items: ones you use (teal), then ones that start a quest (gold).

You choose which kinds show and in what order: in the window, press **Kinds and order** under a ring, untick the kinds you do not want and use the arrows to move a kind up or down (the order is the order of the pages).

## Vibration
A short buzz opens the ring, a light tick marks each new slot you aim at, a firm one confirms an item. Turn it off with the checkbox in the window or `/fcr rumble off`. `/fcr rumble test` plays two taps and a buzz to check that your controller vibrates through the game.

## Install
Copy the `ForeverControllerRings` folder into your Forever client's `Interface/AddOns/` folder, then restart the game fully (a `/reload` does not load new files).

## Map a ring (from the UI)
1. Open the **Forever Controller Rings** window: the addon list entry (addon compartment), or *Options > AddOns > Forever Controller Rings > Open the mapping window*.
2. Click **Map** on a ring. The window closes and a panel says *Press the D-pad or face button you want for this ring*.
3. Press that button on the controller. Hold the left or right modifier first to use that bar (both: the bottom bar). The top bar's face buttons are the game's own and are refused. **B** alone cancels.
4. The window comes back showing where the ring is mapped. **Remap** repeats the steps; **Clear** empties the slot.

(`/fcr` also opens the window. Other `/fcr` subcommands are for debugging: `/fcr help`.)

## Use
Press the mapped button: the ring opens. The right stick aims (the camera stays still, the left stick still walks). Then:

- let go of the stick: uses the slot it points at (a checkbox in the window turns this off),
- or **A**: uses the picked slot (D-pad up/down also steps through it),
- **D-pad left/right**: previous/next page,
- **B**: close. Pressing the mapped button again also closes it.

Works in combat: the ring and its buttons are secure. The contents refresh out of combat only (loot from a fight shows after it).

## Credits / license
MIT. The vibration settings (heavy motor only) and the way button pictures are found come from what Controller Companion by Mathis Becker (MIT) documents and measured. The secure ring design (a secure handler, wrapped secure buttons, stick directions as keys through `GamePadStickAxisButtons`, `GetGamePadState` in the restricted environment) and the mapping panel approach (override bindings catching the press, the macro written with Forever's `GamepadActionBarBindingUtil`, because the game's own "Bind to Action Bar" panel taints when opened from an addon) follow patterns proven in ImprovedForever by markgravity (MIT, https://github.com/markgravity/ImprovedForever).
