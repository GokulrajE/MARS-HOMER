# Reef Rescue

Open `project.godot` with Godot 4.6 or newer and press F5.

## Play

Mouse steering supports any direction and curves. Select Keyboard for arrows / WASD, with equal-speed diagonals. Stay within the glowing fish ring for 3 continuous seconds; leaving resets the hold. After confirmation, the fish swims automatically to the safe reef. Eight successful rescues complete the session.

Each target has a 15-second rescue timer. The shark continuously patrols before expiry. When time runs out, it rushes toward the target at 700 logical pixels per second. On arrival that fish disappears exactly once, then a new target appears after one second. There is no cave recovery in this version. A confirmed rescue cannot be stolen. A player completing the hold in the same simulation update takes priority. Turning off Active Shark also suspends the target timer.

Pause or Escape freezes gameplay, countdown, lighting, and effects. Finish ends the session. Restart resets the game and selects the next environment.

## Environments and display

Two simpler environments rotate without consecutive repeats: Quiet Lagoon and Pearl Cove. Selection persists locally across launches in `user://reef_settings.cfg`. The lagoons have open sandy playfields, sparse corner decoration, and a simple pebble sanctuary. A quiet ray silhouette occasionally passes along an edge; small fish drift around the borders. Nearby target fish give a greeting wiggle, and successful rescues create a short bubble celebration while the sanctuary fills with fish and coral. Reduced motion suppresses these decorative reactions.

F10 selects a 3840x2160 window. F11 toggles fullscreen at the display's native resolution. The normal window is 1600x900. Canvas rendering scales the logical playfield and native UI to the actual window resolution. A native 3840x2160 rendered frame is verified by `tests/capture_4k.gd`.

Artwork resolution is distinct from render resolution: the two new backgrounds were requested at 3840x2160, but the built-in image service returned 1672x941 files. They are scaled during rendering, not native 4K source artwork. The original background is 1536x1024. Assets and exact generation prompts are in `assets/` and `assets/ART_DIRECTION.md`.

## Animation and lighting

The background uses muted color (42% saturation), softer detail, reduced contrast, and compressed highlights to keep attention on the target. Slow peripheral scenery sway, moving light rays, and gentle caustics add atmosphere without moving the central rescue zone. Distant fish move slowly with lower opacity, and fewer dim particles drift through the water. The shark has a steady amber outline and soft halo, with no flashing. Background Saturation and Background Ambience are adjustable in the root Inspector.

Submarine banking, propeller motion, and bubble trails; detailed fish sprites with animated tails and fins; shark tail strokes, fin flex, and directional banking. Rush mode increases its swim cadence. Coral grows after successful rescues, particles drift, and completion has a gentle celebration. Animations use procedural shaders and transforms on the current artwork.

A 60-second day/night cycle changes the reef lighting; fish and the sanctuary glow at night. The Lighting menu also offers fixed Daylight or Night Glow. Reduced motion suppresses decorative animation and holds automatic lighting changes; gameplay movement still continues.

## Configuration and checks

Hold time, target timer, shark patrol/rush speeds, session goal, and lighting cycle duration are exposed on the root Inspector. Sensor mode accepts `submit_tracking(Vector2(x, y), confidence)` from an external main-thread adapter; invalid or stale tracking freezes the game. No hardware tracker, calibration workflow, or audio is bundled.

- Logic: `godot --headless --path . --script tests/game_test.gd`
- Animated rendering and pause/reduced-motion checks: `godot --path . --script tests/animation_render_test.gd`
- 4K rendering: `godot --path . --script tests/capture_4k.gd`
