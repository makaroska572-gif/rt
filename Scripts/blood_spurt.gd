extends Sprite2D

func _ready() -> void:
	# Случайный масштаб, чтобы пятна были уникальными
	var random_scale := randf_range(0.6, 1.2)
	scale = Vector2(random_scale, random_scale)
	
	# Случайный поворот пятна
	rotation = randf_range(0, TAU)
	
	# Запускаем таймер растворения: через 4 секунды кровь начнет исчезать
	await get_tree().create_timer(4.0).timeout
	
	# Плавно делаем пятно прозрачным за 1 секунду
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	
	# Удаляем пятно из игры
	queue_free()
