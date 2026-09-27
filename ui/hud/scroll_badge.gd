extends Control
## The quest scroll emblem at the end of the tracker's title ribbon.


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, 17, Color(0.1, 0.09, 0.08))
	draw_circle(c, 15, Color(0.97, 0.96, 0.92))
	var roll := Rect2(c + Vector2(-8, -9), Vector2(16, 18))
	draw_rect(roll, Color(0.93, 0.8, 0.45))
	draw_rect(roll, Color(0.25, 0.18, 0.08), false, 1.5)
	draw_circle(c + Vector2(-8, -9), 3, Color(0.8, 0.6, 0.25))
	draw_circle(c + Vector2(8, 9), 3, Color(0.8, 0.6, 0.25))
	for i in 3:
		draw_line(c + Vector2(-5, -4 + i * 4), c + Vector2(5, -4 + i * 4), Color(0.4, 0.3, 0.15), 1.2)
