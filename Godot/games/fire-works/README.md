# Garden of Light

## Interactive celebrations

- Rest on the target for 0.85 seconds to warm its visible fuse. A 0.6-second lighting sequence follows before ignition. A softly pulsing ring and directional chevron guide the next movement; Gentle effects removes the pulse.
- Larger fountains build up, reach a colourful peak, and taper into falling sparks. Random variants include gold rain, rainbow, and jewel colours. Aerial rewards include flower, heart, and star patterns.
- Every successful ignition lights one of twelve flowers beside the movement path. Progress remains visible through the session.
- After the twelfth reward, a choreographed seven-rocket finale plays before the Play again button appears. Pause freezes the finale too; replay clears the garden and starts fresh. There is only one movement target at a time and no countdown or missed-target penalty.

## 4K edition

The game uses a 3840 × 2160 design canvas and adapts to the window or monitor resolution. Press F11 (or use Settings) for fullscreen. A 4K display is needed for native 4K fullscreen; smaller screens render at their available resolution.

Seven original SVG assets provide detailed lanterns, lamps, all four fireworks, and flowers. They are rasterized at 576 × 576 per asset at startup, comfortably above their displayed 4K size. Animated trails, fuse ignition, swaying flowers and lanterns, mist, soft glow, and orbiting player sparks remain live game effects. Gentle effects reduces trails and disables ambient movement. No reference-image screenshot is used as a static game background.

Run `--script res://render_4k.gd` graphically to render all four scenes to verified 3840 × 2160 PNGs. Rendering at 4K has been checked; a sustained 60 fps at 4K is not guaranteed on every graphics card.

Open project.godot in Godot 4.6 and press F5. Press Start, then move the glowing lantern with your mouse, touch, or left/right arrow keys. Rest within the target ring for 0.85 seconds to ignite it.

Four randomly chosen fireworks: ascending sky rockets, golden fountains, rotating sparkle wheels, and five-petal aerial flower bursts. Targets alternate left and right at varied distances. Each session contains 12 fireworks, without time limits or missed-target penalties.

Settings offers Small, Medium, and Wide reach, sound on/off, and gentle effects. Pause or Escape freezes movement and animation. Resume continues; Play again resets the session.

The game maps screen movement only. A physical device is not connected. A device adapter can call `set_movement(value)` with a calibrated value between -1 and +1. Choose comfortable reach settings appropriate to the player.

All graphics and audio are generated locally. No downloads, external assets, or patient data collection.

## Living backgrounds

Choose Moonlit Garden, Aurora Lake, Lantern Festival, or Twilight Coast in Settings. Each has its own scenery and palette: garden trees and fireflies, flowing aurora and lake reflections, floating lanterns and festival lights, or palms and twilight water. Soft textured glows, sparkling particle trails, burst rings, flowers, and progress medallions enrich the scene.

Fresh theme each session rotates the scene on replay and next launch. Turn it off to retain your chosen theme. Theme preferences are saved locally. Background motion pauses with the game; Gentle effects freezes ambient motion and reduces fireworks. Themes do not change automatically during a session.

Validation: run Godot with --headless --path . --script res://verify.gd. Running the same script graphically also saves preview.png.


## Living world update

Sky rockets now randomly produce golden willows, Saturn rings, butterfly silhouettes, delayed double bursts, or crackling chrysanthemums, with different flight timing and synthesized sound accents. The finale alternates sides, overlaps contrasting patterns, then closes with long golden willow trails.

Burst colours softly illuminate the landscape, flowers, lamps, and player lantern. Lake and coast scenes have animated colour reflections. A small firefly follows the player, looks toward launches, and celebrates ignitions. Earned hanging lights and floating lanterns progressively decorate the scene. Every fourth success can reveal a butterfly or a small constellation after an aerial burst. Existing layered mist, clouds, and foreground foliage retain the scene depth.

All effect timers and the companion freeze on Pause. Replay clears delayed effects and surprises. Gentle effects reduces particle counts, limits companion motion, and omits broad burst illumination. Updated checks cover every new burst pattern, delayed events, surprises, and finale completion.
