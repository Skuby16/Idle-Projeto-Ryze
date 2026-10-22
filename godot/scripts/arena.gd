extends Node2D

@export var dungeon := false

func _draw() -> void:
	draw_rect(Rect2(-650, -360, 1300, 720), Color("#171725") if dungeon else Color("#11242a"))
	for row in range(10):
		for col in range(12):
			var x: float = (col - row) * 38.0
			var y: float = (col + row - 10) * 19.0
			var color := Color("#564451") if dungeon and (row * 7 + col * 11) % 7 == 0 else Color("#353644") if dungeon else Color("#435453") if (row * 7 + col * 11) % 7 == 0 else Color("#304846")
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y - 19), Vector2(x + 38, y),
				Vector2(x, y + 19), Vector2(x - 38, y)
			]), color)
	for point in [Vector2(-305, -70), Vector2(300, -72), Vector2(-90, 135)]:
		draw_rect(Rect2(point + Vector2(-5, -30), Vector2(10, 30)), Color("#718079"))
		draw_circle(point + Vector2(0, -32), 13, Color("#8b9790"))
