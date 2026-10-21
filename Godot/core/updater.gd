extends Node
## Self-updater for the exported app on Windows and Linux (Raspberry Pi included).
##
## 1. At start-up it asks GitHub for the latest release of the repository.
## 2. If that release is newer than this build it downloads the zip for this platform
##    (MARS_HOMER-windows-x86_64.zip, MARS_HOMER-linux-arm64.zip, ...) and checks its SHA-256
##    against the .sha256 file published next to it. A download without a matching checksum is rejected.
## 3. The zip is unpacked into a staging folder. A small helper script (PowerShell or sh) then waits
##    for this app to exit, copies the new files over the install folder (keeping the old ones in
##    .previous/ and restoring them if the copy fails) and starts the app again.
## Nothing is installed while a trial is running; the login screen offers "Install now" and
## applies the update by itself after a short countdown. Source checkouts and the Godot editor never update.
signal state_changed
enum { IDLE, CHECKING, DOWNLOADING, READY, UP_TO_DATE, FAILED, DISABLED }
const DEFAULT_REPO = "GokulrajE/MARS-HOMER"
const API = "https://api.github.com/repos/%s/releases/latest"
const STAGE = "user://update"
var state = IDLE
var message = ""
var latest_version = ""
var release_notes = ""
var zip_path = ""
var request: HTTPRequest
var asset_name = ""
var checksum_url = ""
var download_url = ""
var checking_manually = false
## The user chose "Later": the update waits, with no countdown, until they install it.
var postponed = false

static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## 1.10.0 > 1.9.2; a leading "v" and anything after "-" or "+" are ignored.
static func parse_version(text: String) -> Array:
	var clean = text.strip_edges().trim_prefix("v").trim_prefix("V").get_slice("+", 0).get_slice("-", 0)
	var parts: Array = []
	for piece in clean.split("."):
		parts.append(int(piece) if piece.is_valid_int() else 0)
	while parts.size() < 3: parts.append(0)
	return parts

static func is_newer(candidate: String, current: String) -> bool:
	var a = parse_version(candidate)
	var b = parse_version(current)
	for i in maxi(a.size(), b.size()):
		var x = a[i] if i < a.size() else 0
		var y = b[i] if i < b.size() else 0
		if x != y: return x > y
	return false

## The release asset name for this machine, for example MARS_HOMER-linux-arm64.zip.
static func platform_asset(os_name: String = OS.get_name(), architecture: String = Engine.get_architecture_name()) -> String:
	var system = "windows" if os_name == "Windows" else "linux" if os_name in ["Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"] else "macos" if os_name == "macOS" else os_name.to_lower()
	var cpu = {"x86_64": "x86_64", "arm64": "arm64", "x86_32": "x86_32", "arm32": "arm32"}.get(architecture, architecture)
	return "MARS_HOMER-%s-%s.zip" % [system, cpu]

## Picks this platform's zip (and its checksum file) from a GitHub release.
static func pick_asset(release: Dictionary, wanted: String) -> Dictionary:
	var found = {}
	for asset in release.get("assets", []):
		var name = str(asset.get("name", ""))
		if name == wanted: found["zip"] = str(asset.get("browser_download_url", ""))
		elif name == wanted + ".sha256": found["sha"] = str(asset.get("browser_download_url", ""))
	return found

## "<hash>  file" or just "<hash>".
static func parse_checksum(text: String) -> String:
	return text.strip_edges().split(" ")[0].to_lower()

## Zip members must stay inside the staging folder.
static func safe_member(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.begins_with("\\") or path.contains(":"): return false
	for part in path.replace("\\", "/").split("/"):
		if part == "..": return false
	return true

static func can_update_here() -> bool:
	return not OS.has_feature("editor") and not OS.has_feature("web") and OS.get_name() in ["Windows", "Linux"]

func repo() -> String:
	return str(Services.settings.get_value("updates", "repo", DEFAULT_REPO))

func enabled() -> bool:
	return bool(Services.settings.get_value("updates", "enabled", true))

func set_enabled(value: bool) -> void:
	Services.settings.set_value("updates", "enabled", value)
	Services.save()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Scripted tests and source runs never touch the network.
	if "--script" in OS.get_cmdline_args() or not can_update_here():
		set_state(DISABLED, "Updates apply to the installed app, not to a source checkout or the editor.")
		return
	if not enabled():
		set_state(DISABLED, "Automatic updates are switched off.")
		return
	# A moment after start-up, so the login screen is up first.
	get_tree().create_timer(4.0).timeout.connect(check)

func set_state(value: int, text: String = "") -> void:
	state = value
	message = text
	state_changed.emit()

func status_text() -> String:
	match state:
		CHECKING: return "Checking for updates…"
		DOWNLOADING: return "Downloading version %s…" % latest_version
		READY: return "Version %s is ready to install." % latest_version
		UP_TO_DATE: return "You have the latest version (%s)." % current_version()
		FAILED: return "Update problem: " + message
	return message if message != "" else "Version " + current_version()

## Looks for a newer release. `manual` shows the result even when nothing is new.
func check(manual: bool = false) -> void:
	if state in [CHECKING, DOWNLOADING, READY]: return
	if not can_update_here():
		set_state(DISABLED, "Updates apply to the installed app, not to a source checkout or the editor.")
		return
	checking_manually = manual
	set_state(CHECKING)
	request = HTTPRequest.new()
	request.timeout = 20.0
	add_child(request)
	request.request_completed.connect(on_release_info)
	var headers = ["User-Agent: MARS-HOMER-updater", "Accept: application/vnd.github+json"]
	var token = str(Services.settings.get_value("updates", "token", ""))
	if token != "": headers.append("Authorization: Bearer " + token)
	if request.request(API % repo(), headers) != OK: fail("Could not reach GitHub.")

func fail(text: String) -> void:
	if is_instance_valid(request): request.queue_free()
	request = null
	set_state(FAILED, text)

func on_release_info(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request.queue_free()
	request = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		# Being offline is normal in a clinic: stay quiet unless the user asked.
		set_state(FAILED if checking_manually else IDLE, "Could not check for updates (offline?).")
		return
	var release = JSON.parse_string(body.get_string_from_utf8())
	if not release is Dictionary or release.get("draft", false) or release.get("prerelease", false):
		set_state(UP_TO_DATE)
		return
	latest_version = str(release.get("tag_name", "")).trim_prefix("v")
	release_notes = str(release.get("body", ""))
	if not is_newer(latest_version, current_version()):
		set_state(UP_TO_DATE)
		return
	asset_name = platform_asset()
	var found = pick_asset(release, asset_name)
	if not found.has("zip") or not found.has("sha"):
		fail("Release %s has no %s (with a .sha256 file) for this computer." % [latest_version, asset_name])
		return
	download_url = found.zip
	checksum_url = found.sha
	start_download()

func start_download() -> void:
	set_state(DOWNLOADING)
	DirAccess.make_dir_recursive_absolute(STAGE)
	zip_path = STAGE.path_join(asset_name)
	request = HTTPRequest.new()
	request.download_file = zip_path
	request.timeout = 600.0
	add_child(request)
	request.request_completed.connect(on_zip_downloaded)
	var headers = ["User-Agent: MARS-HOMER-updater"]
	if request.request(download_url, headers) != OK: fail("Could not start the download.")

func on_zip_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	request.queue_free()
	request = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		fail("The download failed (code %d)." % code)
		return
	# Fetch the published checksum, then verify the zip.
	request = HTTPRequest.new()
	request.timeout = 30.0
	add_child(request)
	request.request_completed.connect(on_checksum)
	if request.request(checksum_url, ["User-Agent: MARS-HOMER-updater"]) != OK: fail("Could not fetch the checksum.")

func on_checksum(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	request.queue_free()
	request = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		fail("Could not fetch the checksum (code %d)." % code)
		return
	var problem = verify_and_stage(zip_path, parse_checksum(body.get_string_from_utf8()))
	if problem != "":
		fail(problem)
		return
	Records.log_event("Update %s downloaded and verified" % latest_version)
	set_state(READY)

## Checks the zip against its published SHA-256 and unpacks it into STAGE/files. Returns "" or a reason.
func verify_and_stage(path: String, expected: String) -> String:
	if expected.length() != 64: return "The published checksum is not valid."
	if FileAccess.get_sha256(path) != expected:
		DirAccess.remove_absolute(path)
		return "The downloaded file does not match its checksum and was discarded."
	var reader = ZIPReader.new()
	if reader.open(path) != OK: return "The downloaded file is not a valid zip."
	var target = ProjectSettings.globalize_path(STAGE.path_join("files"))
	remove_tree(target)
	DirAccess.make_dir_recursive_absolute(target)
	var has_pack = false
	for member in reader.get_files():
		if not safe_member(member):
			reader.close()
			return "The update contains an unsafe path (%s)." % member
		if member.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(target.path_join(member))
			continue
		DirAccess.make_dir_recursive_absolute(target.path_join(member).get_base_dir())
		var out = FileAccess.open(target.path_join(member), FileAccess.WRITE)
		if out == null:
			reader.close()
			return "Could not unpack " + member
		out.store_buffer(reader.read_file(member))
		out.close()
		if member.ends_with(".pck"): has_pack = true
	reader.close()
	if not has_pack: return "The update does not contain the application pack (.pck)."
	return ""

static func remove_tree(path: String) -> void:
	var directory = DirAccess.open(path)
	if directory == null: return
	for sub in directory.get_directories(): remove_tree(path.path_join(sub))
	for file in directory.get_files(): DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)

func install_dir() -> String:
	return OS.get_executable_path().get_base_dir()

## True when the install folder can be written (not always so for Program Files).
func install_dir_writable() -> bool:
	var probe = install_dir().path_join(".update-probe")
	var file = FileAccess.open(probe, FileAccess.WRITE)
	if file == null: return false
	file.close()
	DirAccess.remove_absolute(probe)
	return true

## The helper script and the command that runs it (separate so tests can inspect them).
func build_apply(pid: int) -> Dictionary:
	var stage = ProjectSettings.globalize_path(STAGE.path_join("files"))
	var install = install_dir()
	var exe = OS.get_executable_path()
	if OS.get_name() == "Windows":
		var script = ProjectSettings.globalize_path(STAGE.path_join("apply.ps1"))
		var text = FileAccess.get_file_as_string("res://platform/apply_update.ps1")
		return {"script": script, "text": text, "program": "powershell.exe", "args": PackedStringArray(["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", script, "-ProcessId", str(pid), "-Stage", stage, "-Install", install, "-Exe", exe])}
	var sh = ProjectSettings.globalize_path(STAGE.path_join("apply.sh"))
	var body = FileAccess.get_file_as_string("res://platform/apply_update.sh")
	return {"script": sh, "text": body, "program": "/bin/sh", "args": PackedStringArray([sh, str(pid), stage, install, exe])}

## Hands over to the helper and quits; the helper restarts the app once the files are replaced.
func apply() -> bool:
	if state != READY or Trial.running: return false
	if not install_dir_writable():
		fail("The app folder is not writable. Run the app from a folder you own, or update it manually.")
		return false
	var plan = build_apply(OS.get_process_id())
	var out = FileAccess.open(plan.script, FileAccess.WRITE)
	if out == null:
		fail("Could not write the update helper.")
		return false
	out.store_string(plan.text)
	out.close()
	Records.log_event("Installing update %s" % latest_version)
	if OS.create_process(plan.program, plan.args, false) <= 0:
		fail("Could not start the update helper.")
		return false
	Robot.disconnect_port(false)
	get_tree().quit()
	return true
