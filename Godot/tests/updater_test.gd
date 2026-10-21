extends SceneTree
# Release parsing, version comparison, checksum + zip handling and the install helper plan.
var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func make_zip(path: String, members: Dictionary) -> void:
	var packer = ZIPPacker.new()
	packer.open(path)
	for name in members:
		packer.start_file(name)
		packer.write_file(str(members[name]).to_utf8_buffer())
		packer.close_file()
	packer.close()

func run() -> void:
	var U = load("res://core/updater.gd")
	var updater = root.get_node("Updater")
	check(updater.state == updater.DISABLED, "No network check happens in scripted runs")
	check(U.current_version() != "0.0.0", "The build carries a version")
	check(U.is_newer("1.0.1", "1.0.0") and U.is_newer("v1.10.0", "1.9.9") and U.is_newer("2.0", "1.99.99"), "Newer versions are detected")
	check(not U.is_newer("1.0.0", "1.0.0") and not U.is_newer("0.9.9", "1.0.0") and not U.is_newer("1.0.0-beta", "1.0.0"), "Same or older is ignored")
	check(U.platform_asset("Windows", "x86_64") == "MARS_HOMER-windows-x86_64.zip", "Windows asset name")
	check(U.platform_asset("Linux", "arm64") == "MARS_HOMER-linux-arm64.zip", "Raspberry Pi asset name")
	var release = {"assets": [{"name": "MARS_HOMER-linux-arm64.zip", "browser_download_url": "https://x/zip"}, {"name": "MARS_HOMER-linux-arm64.zip.sha256", "browser_download_url": "https://x/sha"}, {"name": "MARS_HOMER-windows-x86_64.zip", "browser_download_url": "https://x/win"}]}
	var found = U.pick_asset(release, "MARS_HOMER-linux-arm64.zip")
	check(found.get("zip") == "https://x/zip" and found.get("sha") == "https://x/sha", "The platform zip and its checksum are picked")
	check(not U.pick_asset(release, "MARS_HOMER-windows-x86_64.zip").has("sha"), "A zip without a checksum file is reported incomplete")
	check(U.parse_checksum("ABCDEF  file.zip\n") == "abcdef", "Checksum file parsing")
	check(U.safe_member("MARS_HOMER.pck") and U.safe_member("sub/dir/file.txt"), "Normal members are safe")
	check(not U.safe_member("../evil") and not U.safe_member("/etc/passwd") and not U.safe_member("C:/x") and not U.safe_member("a/../../b"), "Unsafe members are refused")
	# A real zip: good checksum is staged, bad checksum and unsafe paths are rejected.
	DirAccess.make_dir_recursive_absolute("user://update-test")
	var good = ProjectSettings.globalize_path("user://update-test/good.zip")
	make_zip(good, {"MARS_HOMER.pck": "new pack", "README.md": "notes"})
	var sha = FileAccess.get_sha256(good)
	check(updater.verify_and_stage(good, sha) == "", "A matching checksum is staged")
	check(FileAccess.get_file_as_string("user://update/files/MARS_HOMER.pck") == "new pack", "Files are unpacked into the staging folder")
	check(updater.verify_and_stage(good, "0".repeat(64)) != "" and not FileAccess.file_exists(good), "A wrong checksum is rejected and the file discarded")
	var evil = ProjectSettings.globalize_path("user://update-test/evil.zip")
	make_zip(evil, {"MARS_HOMER.pck": "x", "../outside.txt": "boom"})
	check(updater.verify_and_stage(evil, FileAccess.get_sha256(evil)).contains("unsafe"), "A zip with a path outside the folder is rejected")
	var nopack = ProjectSettings.globalize_path("user://update-test/nopack.zip")
	make_zip(nopack, {"README.md": "only notes"})
	check(updater.verify_and_stage(nopack, FileAccess.get_sha256(nopack)).contains("pack"), "A zip without the application pack is rejected")
	# The helper plan for this platform.
	var plan = updater.build_apply(1234)
	check(plan.text.length() > 200 and (plan.args.has("1234") or plan.args.has("-ProcessId")), "The install helper is built with the process id")
	check(plan.text.contains(".previous"), "The helper keeps a backup and can roll back")
	check(FileAccess.get_file_as_string("res://platform/apply_update.ps1").contains("Start-Process") and FileAccess.get_file_as_string("res://platform/apply_update.sh").contains("nohup"), "Both helpers restart the app")
	updater.state = updater.READY
	var trial = root.get_node("Trial")
	trial.running = true
	check(not updater.apply(), "Nothing is installed while a trial is running")
	trial.running = false
	U.remove_tree(ProjectSettings.globalize_path("user://update-test"))
	U.remove_tree(ProjectSettings.globalize_path("user://update"))
	print("Updater: %d failures" % failures)
	quit(1 if failures else 0)
