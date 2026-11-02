extends Marker2D

# Экспортируем переменную, чтобы перетащить сцену зомби прямо в инспекторе
@export var zombie_scene: PackedScene

# Интервал спавна в секундах
@export var spawn_time: float = 2.0

var spawn_timer: Timer

func _ready() -> void:
	_setup_timer()

func _setup_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_time
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

func _on_spawn_timer_timeout() -> void:
	if not zombie_scene:
		push_warning("Сцена зомби не назначена в инспекторе спавнера!")
		return
		
	# Создаем экземпляр зомби
	var zombie = zombie_scene.instantiate()
	
	# Устанавливаем позицию спавна (координаты этого маркера)
	zombie.global_position = global_position
	
	# Добавляем зомби в текущую игровую сцену (к родителю спавнера)
	get_parent().add_child(zombie)
