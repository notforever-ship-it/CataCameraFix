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

Install (easy way)
------------------
1. Close WoW.
2. Copy these three files into your WoW folder (the one with Wow.exe):
     CataCameraFix.ps1
     Install Camera Fix.bat
     Remove Camera Fix.bat
3. Double-click "Install Camera Fix.bat".
   A backup is saved as Wow.exe.before-camfix the first time.

If the TwinStar launcher ever puts the original Wow.exe back, just run
"Install Camera Fix.bat" again.

Remove
------
Double-click "Remove Camera Fix.bat" (or copy Wow.exe.before-camfix back
over Wow.exe).

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
