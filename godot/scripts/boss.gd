extends Node2D

const Rules = preload("res://godot/scripts/game_rules.gd")

var hp: int = Rules.BOSS_HP
var alive := true
var attack_left := Rules.BOSS_ATTACK_SECONDS

func reset_boss() -> void:
	hp = Rules.BOSS_HP
	alive = true
	attack_left = Rules.BOSS_ATTACK_SECONDS
	visible = true
	queue_redraw()

func _draw() -> void:
	if not alive:
		return
	draw_circle(Vector2(0, 11), 37, Color(0.02, 0.02, 0.07, 0.7))
	draw_line(Vector2(-19, -27), Vector2(-24, 5), Color("#c7c3b2"), 12)
	draw_line(Vector2(19, -27), Vector2(24, 5), Color("#c7c3b2"), 12)
	draw_circle(Vector2(0, -58), 32, Color("#82928e"))
	draw_circle(Vector2(0, -105), 27, Color("#d9dcc9"))
	draw_circle(Vector2(-11, -108), 6, Color("#59e9cd"))
	draw_circle(Vector2(11, -108), 6, Color("#59e9cd"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-29, -130), Vector2(-23, -157), Vector2(-9, -138),
		Vector2(0, -160), Vector2(9, -138), Vector2(23, -157),
		Vector2(29, -130)
	]), Color("#d3a657"))
	draw_line(Vector2(28, -71), Vector2(55, -15), Color("#c7c3b2"), 8)
	draw_line(Vector2(55, -15), Vector2(83, -58), Color("#7ce7db"), 7)
	draw_rect(Rect2(-50, -185, 100, 11), Color("#10191d"))
	draw_rect(Rect2(-47, -182, 94.0 * float(hp) / Rules.BOSS_HP, 5), Color("#b44162"))
