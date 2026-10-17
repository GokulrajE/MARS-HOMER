extends RefCounted
## Figures shown on Welcome, Choose Movement and Summary. They mirror
## MarsUserData in Assets/scripts/others.cs and read only saved records.
const MOVEMENTS = ["ML", "AP", "MLAP"]
const STALE_DAYS = 13

static func today() -> String:
	return Trial.stamp().left(10)

static func day_number(date: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(date.left(10) + "T00:00:00") / 86400)

static func prescribed(movement: String) -> float:
	return float(Records.profile.get(movement, 0))

static func has_prescription() -> bool:
	return not Records.profile.is_empty()

static func today_minutes(movement: String) -> float:
	return Records.today_minutes(movement)

static func remaining_minutes() -> Dictionary:
	var plan = 0.0
	var done = 0.0
	for movement in MOVEMENTS:
		plan += prescribed(movement)
		done += today_minutes(movement)
	return {"minutes": int(absf(plan - done)), "exceeded": done > plan, "plan": plan, "done": done}

## Unity counts whole days since the first configured start date.
static func training_day() -> int:
	var start = str(Records.profile.get("StartDate", ""))
	if start.length() < 10: return 0
	var iso = start.substr(6, 4) + "-" + start.substr(3, 2) + "-" + start.substr(0, 2)
	return day_number(today()) - day_number(iso)

static func minutes_on(date: String, movement: String = "") -> float:
	var seconds = 0.0
	for row in Trial.history:
		if row[4].left(10) == date and (movement == "" or row[7] == movement): seconds += float(row[14])
	return seconds / 60.0

static func date_string(offset_days: int) -> String:
	var unix = (day_number(today()) + offset_days) * 86400
	return Time.get_date_string_from_unix_time(unix)

## The seven days before today, newest first, as Unity's pie row shows them.
static func past_days(count: int = 7) -> Array:
	var days: Array = []
	for i in range(1, count + 1):
		var date = date_string(-i)
		var unix = Time.get_unix_time_from_datetime_string(date + "T00:00:00")
		var weekday = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][Time.get_date_dict_from_unix_time(unix).weekday]
		days.append({"day": weekday, "date": date.substr(8, 2) + "/" + date.substr(5, 2), "minutes": minutes_on(date)})
	return days

## Days since the assessment at the current training plane; -1 means none.
static func days_since(kind: String) -> int:
	var row = Records.weight if kind == "WEIGHT" else Records.corners.get(kind, {})
	if row.is_empty(): return -1
	return maxi(0, day_number(today()) - day_number(str(row.get("DateTime", today()))))

static func assessment_line(kind: String) -> Dictionary:
	var label = "Arm Weight" if kind == "WEIGHT" else kind + " AROM"
	var days = days_since(kind)
	if days < 0: return {"text": label + ": N/A", "ok": false}
	return {"text": "%s: %d day%s ago" % [label, days, "" if days == 1 else "s"], "ok": days < STALE_DAYS}

## Per game: today's and cumulative hits/targets and star counts.
static func game_scores(code: String) -> Dictionary:
	var now = today()
	var result = {"today_hits": 0, "today_targets": 0, "total_hits": 0, "total_targets": 0, "star_today": false, "stars": 0, "stars_before_today": 0}
	for row in Trial.history:
		if row[9] != code: continue
		result.total_hits += int(row[16])
		result.total_targets += int(row[15])
		result.stars += int(row[21])
		if row[4].begins_with(now):
			result.today_hits += int(row[16])
			result.today_targets += int(row[15])
			if int(row[21]) > 0: result.star_today = true
		else: result.stars_before_today += int(row[21])
	return result
