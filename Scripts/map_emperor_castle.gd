extends Node2D

@export_group("Wave Configurations")
# Ссылка на сцену зомби
var zombie_scene = preload("res://Scenes/zombie.tscn")
# Ссылка на сцену карт для переноса при победе
var maps_scene_path: String = "res://Scenes/maps.tscn"

# Тайминги священной минуты подготовки (в секундах)
@export var prep_time: float = 60.0  

# Количество зомби на каждую из 5 волн
var wave_zombie_counts: Array[int] = [5, 10, 15, 22, 30]

# Переменные текущего состояния
var current_wave: int = 0 # 0 — подготовка, 1-5 — волны
var wave_timer: float = 0.0
var is_prep_phase: bool = true
var zombies_to_spawn: int = 0
var spawn_cooldown: float = 0.0

@onready var wave_label: Label = $CanvasLayer/WaveLabel # Путь к тексту волн
@onready var spawner_positions: Node2D = $SpawnerPositions # Путь к папке маркеров

func _ready() -> void:
	current_wave = 0
	is_prep_phase = true
	wave_timer = prep_time
	update_wave_hud()

func _process(delta: float) -> void:
	# ФАЗА 1: Священная минута подготовки
	if is_prep_phase:
		wave_timer -= delta
		if wave_timer <= 0:
			start_next_wave()
		update_wave_hud()
		
	# ФАЗА 2: Активная волна (Идет спавн зомби)
	else:
		if zombies_to_spawn > 0:
			spawn_cooldown -= delta
			if spawn_cooldown <= 0:
				spawn_zombie()
				# Скорость спавна зомби (каждые 0.8 сек рождается новый)
				spawn_cooldown = 0.8 
				
		# Проверка: если все зомби этой волны заспавнились и были уничтожены
		elif get_tree().get_nodes_in_group("enemies").size() == 0:
			# Если продержались все 5 волн — ПОБЕДА!
			if current_wave >= 5:
				win_game()
			else:
				# Если волна кончилась, запускаем подготовку к следующей
				start_prep_phase()

# Старт волны зомби
func start_next_wave() -> void:
	is_prep_phase = false
	current_wave += 1
	zombies_to_spawn = wave_zombie_counts[current_wave - 1]
	spawn_cooldown = 0.0
	print("Началась волна: ", current_wave)
	update_wave_hud()

# Старт фазы отдыха и баррикадирования окопов
func start_prep_phase() -> void:
	is_prep_phase = true
	wave_timer = prep_time
	print("Минута подготовки началась!")
	update_wave_hud()

# Спавн одного мертвеца в случайном маркере
func spawn_zombie() -> void:
	if not zombie_scene or not spawner_positions: return
	if spawner_positions.get_child_count() == 0: return
	
	zombies_to_spawn -= 1
	
	# Выбираем случайный маркер из папки SpawnerPositions
	var markers = spawner_positions.get_children()
	var random_marker = markers[randi() % markers.size()] as Marker2D
	
	var zombie = zombie_scene.instantiate()
	# Добавляем зомби на карту
	get_tree().current_scene.add_child(zombie)
	zombie.global_position = random_marker.global_position

# Обновление текста HUD на русском языке
func update_wave_hud() -> void:
	if not wave_label: return
	
	if is_prep_phase:
		wave_label.text = "ПОДГОТОВКА: " + str(int(wave_timer)) + " сек"
		if current_wave > 0:
			wave_label.text += " (Волна " + str(current_wave + 1) + " скоро)"
	else:
		var alive_zombies = get_tree().get_nodes_in_group("enemies").size()
		wave_label.text = "ВОЛНА: " + str(current_wave) + " / 5 | ОСТАЛОСЬ: " + str(alive_zombies + zombies_to_spawn)

# Перенос в Maps.tscn при триумфе обороны
func win_game() -> void:
	print("Поздравляем! Осада выдержана!")
	if ResourceLoader.exists(maps_scene_path):
		get_tree().change_scene_to_file(maps_scene_path)
