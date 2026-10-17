extends SceneTree
var failures=0
func _initialize()->void: call_deferred("run")
func run()->void:
	var trial=root.get_node("Trial")
	trial.data_root="user://fireworks-check"
	trial.configure("render-test")
	trial.select_game("FW")
	trial.begin()
	var game=load("res://games/fire-works/main.tscn").instantiate()
	root.add_child(game)
	game.scale=Vector2.ONE
	game.set_process(false)
	game.sound_on=false
	game.start_session()
	for name in ["lantern","lamp","rocket","fountain","wheel","flower","blossom"]:
		if not game.hd_sprites.has(name) or game.hd_sprites[name].get_width()<=0:
			failures+=1
			push_error("Missing packaged sprite: "+name)
	for k in 4:
		game.kind=k
		game.target_x=800
		game.queue_redraw()
		await process_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://fireworks-kind-%d.png" % k)
	trial.finish("TEST")
	print("Packaged fireworks sprites: %d failures" % failures)
	quit(1 if failures else 0)
