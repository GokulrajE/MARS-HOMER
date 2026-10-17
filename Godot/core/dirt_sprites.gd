extends RefCounted
## Original Unity dirt sprites; preserve one fixed footprint and physical brush area.
static func make(kind:int)->Image:
	var names=["dirt-coffee","dirt-jam","dirt-cream"]
	return load("res://assets/legacy/"+names[kind%3]+".png").get_image()
