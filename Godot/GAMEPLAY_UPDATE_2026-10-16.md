# Patient-paced gameplay update

- The normal game HUD has Play/Pause and Exit, time, score and per-game total stars. Bubble Sparkle no longer recreates its extra buttons on resize.
- Table Wiping and Fireworks ignore Ctrl+G and manual speed changes. Targets remain until completed; Fireworks waits for the complete display before presenting another target. The session remains 60 active seconds.
- Table Wiping reuses three original Unity spill sprites. Unity's physical brush-area rule is retained: radius squared = selected cloth area / assessed workspace area × screen pixel area / pi. Sprite alpha determines the percentage cleaned; completion is above 95%. The stain footprint is fixed, as in the port of Unity's scaled sprite. Progress fills smoothly, with suds and a completion celebration.
- Ping Pong uses a rebound wall, directional collision checks, a spinning ball and impact squash. Easy mode is on the movement/game selection screen: a larger paddle and gentler launch angles. Unity has a PPEasyMode toggle, but its ball controller does not read that value; this behavior is explicitly implemented in Godot.
- Space Shooter requires 0.3 seconds of stillness (below 0.002 m/s) and spaces shots by 0.65 seconds. Slow movement resets the hold.
- Fireworks has a 650-particle cap, shorter trails and reduced fountain emission. Its saved ReachSpeed is zero and GameParameter is the 0.85-second ignition hold. Table Wiping retains Unity's zero ReachSpeed and scrub-area GameParameter convention. CSV columns are unchanged.
- Match Catch's color cue sits below the HUD. Diamond Catcher has a faceted gem, countdown ring and separate hold ring. Fish Rescue, Bubble Sparkle and moving timed targets show local countdown feedback.
- Character Flight rotates scenery and lighting per trial. Rajini/Vijay collect coins, Mr Bean collects Teddy, and Bheem/Chutki/Raju collect laddoos. Reef Runner rotates three underwater backgrounds per trial. Both have stronger pass/collection effects; passed obstacles still leave the camera and are removed.

Validated with gameplay, patient-pacing, integration, physical timing, plane/metres/persistence and scenery-rotation checks, plus rendered game screens. No physical robot was moved or calibrated during these checks. Raspberry Pi performance must still be checked on the device.
