# Cata Camera Fix

Fixes the **camera suddenly snapping to a random direction** when you hold right-click to turn in **World of Warcraft: Cataclysm 4.3.4 (build 15595)**. It happens most with high polling rate mice (1000 Hz and up). You don't need to lower your polling rate anymore.

Tested on TwinStar. Should work on any server that uses the standard 4.3.4 (15595) client.

Made by stealthzi.

## Install

1. [Download the latest release](../../releases/latest) and unzip it.
2. Close WoW.
3. Copy these three files into your WoW folder (the one with `Wow.exe`):
   - `CataCameraFix.ps1`
   - `Install Camera Fix.bat`
   - `Remove Camera Fix.bat`
4. Double-click **Install Camera Fix.bat**. It should say *Camera fix installed.*
5. Start the game the way you normally do.

The first time, a backup of your original exe is saved as `Wow.exe.before-camfix`.

If your launcher ever puts the original `Wow.exe` back, run **Install Camera Fix.bat** again.

## Remove

Double-click **Remove Camera Fix.bat**. Or copy `Wow.exe.before-camfix` back over `Wow.exe`.

## What causes the bug

While you hold right-click, the game hides the cursor and warps it to the **middle of the window** many times a second, measuring how far it drifts each time.

When you first press right-click, the cursor is wherever you clicked. The game warps it to the middle, but with a fast mouse Windows sometimes reports a position from *just before* that warp. The game then thinks the cursor moved from the middle all the way to where you clicked, in one step, and turns the camera by that whole distance. The "random" direction is really the direction from the middle of the screen to where you clicked.

## What the fix does

The hidden cursor is no longer warped to the middle. It stays **pinned where you clicked**. The game still measures each movement from there and puts it back. A late position report now equals the pin point, so it counts as zero movement instead of a big spin.

If you click right at the edge of the window, the pin point creeps inward by 1 pixel per movement until it's 50 px from the edge, so turning never runs out of room.

Nothing else changes: camera speed, sensitivity and everything else are the same.

## Technical details

- One function is rewritten: the mouselook recenter routine at `0x874750`. It now warps to the saved click point (`0xEC6B50` / `0xEC6B54`, client coordinates) and converts it with the game's own `LogicalToPhysicalPoint` / `SetPhysicalCursorPos` helper at `0x8731A0`. It then stores the physical point at `0xEC6B44` / `0xEC6B48`, which the mouse-move handler compares against.
- The exe has ASLR enabled, so the function's 11 base relocations are updated too: 3 point at the new absolute operands and the rest become no-op entries.
- The installer checks the original bytes before touching anything, and refuses to patch any other exe. Removing the fix restores the file byte-for-byte.
- `source/` has the scripts that build the patch (Python with pefile, keystone and capstone).

## Notes

- This changes your game exe. It doesn't give you any gameplay advantage, but check that your server is fine with client changes before you use it.
- The patched `Wow.exe` is not included here. The installer patches your own copy.

## Credits

Based on the vanilla camera skip glitch fix by **Bon** (Turtle WoW Discord), shipped in [vanilla-tweaks](https://github.com/brndd/vanilla-tweaks). This is a new build of the same idea for the Cataclysm client.

## License

MIT. See [LICENSE](LICENSE).
