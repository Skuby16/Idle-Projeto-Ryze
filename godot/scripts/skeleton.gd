extends Node2D

const Rules = preload("res://godot/scripts/game_rules.gd")

var hp: int = Rules.SKELETON_HP
var alive := true
var respawn_left := 0.0
var display_seconds := 0
var attack_left := Rules.SKELETON_ATTACK_SECONDS

func _draw() -> void:
	if not alive:
		draw_circle(Vector2(0, 5), 17, Color(0.02, 0.08, 0.09, 0.45))
		draw_rect(Rect2(-13, -26, 26, 30), Color("#788b86"))
		draw_string(ThemeDB.fallback_font, Vector2(-11, -33), str(display_seconds), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#d6dfd9"))
		return
	draw_circle(Vector2(0, 6), 16, Color(0.02, 0.08, 0.09, 0.5))
	draw_line(Vector2(-7, -10), Vector2(-9, 3), Color("#c4c7b5"), 5)
	draw_line(Vector2(7, -10), Vector2(9, 3), Color("#c4c7b5"), 5)
	draw_circle(Vector2(0, -27), 12, Color("#bac1b3"))
	draw_circle(Vector2(0, -45), 12, Color("#d6d9c7"))
	draw_circle(Vector2(-5, -46), 3, Color("#283537"))
	draw_circle(Vector2(5, -46), 3, Color("#283537"))
	draw_line(Vector2(11, -27), Vector2(22, -7), Color("#879991"), 3)
	draw_rect(Rect2(-25, -72, 50, 7), Color("#0d1a1e"))
	draw_rect(Rect2(-23, -70, 46.0 * float(hp) / Rules.SKELETON_HP, 3), Color("#cb7471"))
