extends SceneTree
# One typeface everywhere, Titan One for game feedback, one looping track, and a different
# capture / miss sound for every game.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func peak(stream: AudioStreamWAV) -> int:
	var best = 0
	for i in range(0, stream.data.size() - 1, 2): best = maxi(best, absi(stream.data.decode_s16(i)))
	return best

func run() -> void:
	var Sfx = load("res://core/sfx.gd")
	var UITheme = load("res://core/ui_theme.gd")
	check(ThemeDB.fallback_font.resource_path.ends_with("AtkinsonHyperlegibleNext.ttf"), "Default font is Atkinson everywhere")
	check(UITheme.DISPLAY.resource_path.ends_with("TitanOne-Regular.ttf"), "Titan One is available for game feedback")
	var seen: Dictionary = {}
	for game in ["SS", "MC", "PP", "DC", "TW", "TT", "CB", "BS", "FW", "FR"]:
		for kind in (["capture"] if game == "FW" else ["capture", "miss"]): # Fireworks has no misses
			var stream: AudioStreamWAV = Sfx.capture(game, 0) if kind == "capture" else Sfx.miss(game, 0)
			check(stream.data.size() > 2000 and peak(stream) > 3000, game + " " + kind + " is audible")
			check(peak(stream) < 32000, game + " " + kind + " does not clip")
			var key = str(hash(stream.data))
			if game in ["TT", "FR"] and seen.has(key): continue # Reef Runner and Fish Rescue share the water voice
			check(not seen.has(key), game + " " + kind + " differs from " + str(seen.get(key, "")))
			seen[key] = game + " " + kind
		check(Sfx.capture(game, 0).data != Sfx.capture(game, 3).data, game + " capture has pitch variants")
	var music = root.get_node("Music")
	await process_frame
	check(music.player != null and music.player.playing, "Background music plays")
	check(music.player.stream is AudioStreamMP3 and music.player.stream.loop, "Background music loops")
	check(music.target_db() == music.MENU_DB, "Music sits at menu level outside games")
	var trial = root.get_node("Trial")
	trial.running = true
	trial.game = "SS"
	check(music.target_db() == music.GAME_DB, "Music ducks during a game")
	trial.running = false
	music.set_enabled(false)
	check(music.target_db() <= -59.0, "Music can be switched off")
	music.set_enabled(true)
	print("Sound & font: %d failures" % failures)
	quit(1 if failures else 0)
