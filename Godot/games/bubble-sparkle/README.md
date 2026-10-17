# Bubble Touch — The Sparkle Expedition

Open project.godot in Godot 4.6 or later and press F5. Touch or click the glowing stationary bubble to collect starlight and bring a themed world to life.

## Combined movement journey
Every session combines left, right, forward, and return cues in one balanced 12-target sequence. Each direction appears three times, with a different order in each four-target stage:

1. First Glow: left, forward, right, return.
2. Brighter Steps: right, forward, left, return.
3. Full of Wonder: forward, right, return, left.

Each bubble earns 10 starlight. Every four bubbles completes a stage with an extended celebration. Complete all three stages to earn three star medallions and 120 starlight. No countdown, miss penalty, speed scoring, or automatic reach increase. Target centers remain stationary until touched.

Forward/return are upper/lower screen cues, not measurements of physical anterior/posterior movement. Physical placement and shoulder movement guidance should be determined with the treating therapist. This game does not track shoulder movement or collect patient data.

## Controls
- Small / Medium / Wide: choose comfortable target spacing.
- Start: begin or continue the session; after completion, begin a new game.
- Stop or Escape: freeze the session and animation.
- Ctrl+X: reveal or hide extra settings. Settings are hidden on launch.
- Sound: toggle synthesized chimes.
- Motion low: stop ambient motion and bubble shimmer, reduce particle counts, and hide flying reward trails.
- Only Start and Stop are visible by default. Reach, sound, motion, and theme options appear after Ctrl+X.

## Visuals
Procedural iridescent bubble shader, soft entrance animation, three sparkle emission patterns, changing particle colors, floating reward messages, starlight collection trails, stage color transitions, swaying coral that grows with progress, layered currents, light shafts, and a jellyfish companion. No external asset dependencies.

## Validation
Run Godot with --headless --path . --script res://verify.gd. It verifies equal directional coverage, all reach bounds, stationary targets, touch/mouse input, ignored misses, pause, duplicate-hit prevention, stage progression, completion, reset, and reduced-motion particle counts. A graphical run also saves preview PNGs.

Main scene: main.tscn. Game code: scripts/main.gd. Bubble material: shaders/bubble.gdshader. Designed for a 1920 × 1080 Full HD canvas with window scaling.

## Themes and reference-inspired feedback
Ocean, Twilight garden, and Starry sky rotate between games and application launches. Keep theme locks the current scene; this choice is saved locally. Themes never switch during a reach. Controls and movement logic stay identical.

Idle bubbles shimmer gently. A successful touch briefly compresses the bubble, emits three soft ripple rings, and dissolves into glossy droplets and stars. Low motion uses one restrained ripple and slower, fewer particles. Larger celebrations occur at chapter milestones.



## Minimal game view
The game fills the entire Full HD canvas. The score appears in the upper left and Start/Stop in the upper right. Headings, sidebar, instructions, and chapter cards are removed. Ctrl+X toggles a compact settings overlay. Bubbles are about 17% smaller, with proportionally adjusted glow and a 73-pixel touch radius.


## Living worlds
Each successful touch adds a fish, flower, or linked constellation star. Gold-ringed fourth targets trigger special reveals. Companions react, and touches follow a melody ending in a completion chord. Ctrl+X exposes 8/12/16 reaches for the next game; changing it during play does not alter the current session. Start after completion resets discoveries. Reduced motion removes reward travel and growth animation. No speed bonus or miss penalty is used.


## Session variety and secrets
Each new game chooses a different visual variation, shifting discovery colors and milestone surprises. Slow light ribbons and distant fish or fireflies add depth. Milestones reveal jellyfish, butterflies, or shooting stars. Tap the companion once during play to reveal a pearl constellation and earn a crown for that game; this does not affect score or required reaches. Completion adds a brief star celebration. Stop freezes these effects, and low motion keeps the new scenery static and the finale restrained.


## Score and player pointer
The score counts up with a reward pulse, +10 indicator, and session progress bar. The mouse becomes a glowing orb with a short fading trail; hovering over a bubble turns it gold and pressing contracts it. Touch shows the active contact only. This indicates input position, not tracked body position. Low motion disables the trail and score pulse. The native cursor is restored when leaving the window or exiting the game.


## Typography and end card
Uses Segoe UI with Trebuchet MS/sans-serif fallbacks through Godot SystemFont; no proprietary font files are redistributed. The completion card shows final score and completed reaches with a Play Again button, keyboard focus, and gentle fade-in (instant with reduced motion).

