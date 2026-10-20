# norabu_bars

Dark-mode action bars for the World of Warcraft Classic client: a dark backdrop with the classic framed slots behind every bar, per-bar opacity, and a few optional button effects.

<img width="549" height="199" alt="image" src="https://github.com/user-attachments/assets/f229b00a-00a9-483c-a346-074e585f71e5" />


## What it does

- **Dark backdrop for each bar.** Main bar, the extra action bars, stance bar and pet bar each get a dark panel with a soft black border. It follows the bar's Edit Mode position and size, and buttons are never moved or re-parented.
- **Classic framed slots.** Blizzard's classic main-bar art is drawn on every button icon, tinted darker, replacing the default button frame. The native gryphons and bar art are hidden.
- **Opacity per bar.** The action bars, micro menu, bag bar and the XP / reputation bars each have an opacity slider. It also appears as an **Opacity** row in Edit Mode when you select one of them.
- **Range and mana colouring.** The icon turns red when out of range and blue when you lack the mana or energy.
- **Press flash.** A star burst on a button when you press it, in a colour you choose.
- **Cast animation hidden.** Turns off the default cast and interrupt animation on buttons.
- **White hotkey text.** Hotkeys stay white, whatever Blizzard tries to do with them.
- **Other bar addons.** EllesmereUI's action bars are covered by the same settings. Bartender4 and Dominos bars, if installed, get a backdrop and opacity as their own entries (Dominos support is untested).

The micro menu, bag bar and XP bars only get opacity, no backdrop.

## Install

1. Download this repo.
2. Copy the `norabu_bars` folder into your `Interface/AddOns` folder.
3. Start the game, or type `/reload`.

## Settings

Type `/nb` or `/norabubars`, or find **norabu_bars** under Esc > Options > AddOns.

- **Backdrop:** darkness, tint colour and an extra margin around the bars.
- **Bars:** turn the dark theme on or off per bar, and set each bar's opacity (10 to 100%).
- **Buttons:** classic framed slots, extra dark square behind buttons, range / mana colouring, press flash and its colour, and hiding the cast animation.

Everything applies immediately, and **Reset to defaults** puts it all back. Bar positions are set in Blizzard's Edit Mode, as usual.

Two extra commands help when something looks wrong:

- `/nb debug` prints each bar's size, backdrop size and button counts.
- `/nb align` draws outlines on icons, button frames and each backdrop's box so you can screenshot how they line up. Run it again to turn it off.

## Notes

- Buttons that Blizzard hides (empty slots with "Always Show Buttons" off) get no slot art. Turn that setting on for the bar in Edit Mode to see a slot on every position.
- The slot art is a slice of the classic strip, scaled to your icon size. It looks best with a little Edit Mode icon padding.

## Compatibility

- Built for the client with interface version 16001 (the classic beta / Forever client).
- Works alongside norabu_frames, which covers the unit frames.

## Credits

- The slot art and gryphons come from the game client itself, so no Blizzard art is included in this repo.
- The soft border and the frame-ring mask are generated (`tools/make_slot_mask.py` makes the mask; the border texture is shared with norabu_frames).
- The press flash idea comes from StormxUI, and Edit Mode and button handling were studied from EllesmereUI. No code is copied.
