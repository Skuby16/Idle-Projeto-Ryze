extends Node2D

var hp: int = 30
var alive := true
var respawn_left := 0.0
var attack_left := 1.6

func _draw() -> void:
	if not alive:
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
	draw_rect(Rect2(-23, -70, 46.0 * float(hp) / 30.0, 3), Color("#cb7471"))
