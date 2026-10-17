extends SceneTree
# All six reference clips in the shared frame, for a size/alignment check.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var Video = load("res://core/video.gd")
	var holder = Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var backdrop = ColorRect.new()
	backdrop.color = Color("0b1220")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(backdrop)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(20, 20)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	holder.add_child(grid)
	var cards: Array = []
	for key in Video.CLIPS:
		var card = Video.new()
		card.custom_minimum_size = Vector2(500, 400)
		grid.add_child(card)
		cards.append([card, key])
	await process_frame
	for entry in cards: entry[0].play(entry[1])
	await create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-output/videos-grid.png")
	var sizes: Array = []
	for entry in cards: sizes.append(entry[0].frame.get_child(0).size)
	print("FRAME SIZES ", sizes)
	quit()
