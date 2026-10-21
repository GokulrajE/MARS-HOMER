extends SceneTree
# The login field is a search bar: typing suggests matching patients, a click logs in, and a new
# valid ID offers "Create new patient".
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func buttons(login: Control) -> Array:
	return login.suggestions.get_children().filter(func(c): return c is Button)

func run() -> void:
	var Login = load("res://core/login.gd")
	var known = PackedStringArray(["anna", "Bob", "joanna", "rahul", "ravi", "zed"])
	check(Login.suggest("ra", known) == ["rahul", "ravi"], "Prefix matches are suggested")
	check(Login.suggest("ann", known) == ["anna", "joanna"], "Prefix matches come before inner matches")
	check(Login.suggest("BOB", known) == ["Bob"], "Matching ignores case")
	check(Login.suggest("", known).size() == Login.MAX_SUGGESTIONS, "An empty search lists a few patients")
	check(Login.suggest("q", known).is_empty(), "No match, no suggestions")
	var trial = root.get_node("Trial")
	root.get_node("Services").settings.set_value("ui", "tutorial_done", true)
	trial.data_root = "res://test-output/ls-" + str(Time.get_ticks_usec())
	var login = Login.new()
	root.add_child(login)
	await process_frame
	var signed: Array = []
	login.signed_in.connect(func(id): signed.append(id))
	login.id_edit.text = "zz-new"
	login.id_edit.text_changed.emit("zz-new")
	await process_frame
	var items = buttons(login)
	check(items.size() == 1 and items[0].text.contains("Create new patient"), "A new valid ID offers to create it")
	items[0].pressed.emit()
	check(signed == ["zz-new"], "Clicking the create suggestion logs in as the new patient")
	login.id_edit.text = "a/b"
	login.id_edit.text_changed.emit("a/b")
	await process_frame
	check(buttons(login).filter(func(b): return b.text.contains("Create")).is_empty(), "An invalid ID offers no create option")
	print("Login search: %d failures" % failures)
	quit(1 if failures else 0)
