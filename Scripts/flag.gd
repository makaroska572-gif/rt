extends Area2D

func _ready() -> void:
	# Подключаем проверку: кто зашел в зону флага
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Если флага коснулся узел из группы зомби ("enemies")
	if body.is_in_group("enemies"):
		print("Зомби захватили флаг! Оборона прорвана!")
		# Перезапускаем уровень, так как база пала
		get_tree().reload_current_scene()
