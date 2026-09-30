Cata Camera Fix - WoW 4.3.4 (build 15595)
=========================================

Fixes the camera suddenly snapping to a random direction when you hold
right-click to turn (much worse with high polling rate mice, 1000 Hz+).

What it changes
---------------
While you mouselook, the game hides the cursor and keeps warping it to the
middle of the window. With a fast mouse, a late cursor update can report the
spot you clicked instead of the middle, and the game turns that gap into one
huge camera turn. The fix keeps the hidden cursor pinned where you clicked
instead, so a late update counts as zero movement.

Same idea as the Turtle WoW / vanilla-tweaks "camera skip glitch fix"
(credit: Bon, Turtle WoW Discord), rebuilt for the Cataclysm client. It
rewrites one small function inside Wow.exe. Nothing else is touched.

Updating from 1.0.0
-------------------
Replace CataCameraFix.ps1 in your WoW folder with this one (the .bat
files are the same), close WoW, and run "Install Camera Fix.bat" again.
It should end with "Auto-fix is on".

Install (easy way)
------------------
1. Close WoW.
2. Copy these three files into your WoW folder (the one with Wow.exe):
     CataCameraFix.ps1
     Install Camera Fix.bat
     Remove Camera Fix.bat
3. Double-click "Install Camera Fix.bat".
   A backup is saved as Wow.exe.before-camfix the first time.

That's it. Start the game the way you normally do.

Auto-fix
--------
Some launchers put the original Wow.exe back now and then (after an
update or a file check). Install also turns on auto-fix: a small hidden
watcher that starts with Windows and puts the fix back within a few
seconds whenever that happens. If the game is running at that moment,
it waits until you close it.

- It writes what it did to CataCameraFix.log in your WoW folder.
- If something keeps putting the original back, it pauses for 15
  minutes instead of fighting it.
- Don't want it? Run this in PowerShell from your WoW folder instead:
    powershell -ExecutionPolicy Bypass -File CataCameraFix.ps1 -NoAuto

Remove
------
Double-click "Remove Camera Fix.bat". It turns auto-fix off and puts the
original Wow.exe back.

Notes
-----
- Only works on the standard 4.3.4 (15595) Wow.exe. Any other exe is left
  alone.
- It's a change to the game exe. Check that TwinStar is fine with that.
  If the launcher or login complains, remove the fix.
- If you click right at the edge of the window, the hidden cursor creeps
  1 pixel per move until it's 50 px from the edge, so turning never
  runs out of room.

Made by stealthzi - https://github.com/notforever-ship-it/CataCameraFix
