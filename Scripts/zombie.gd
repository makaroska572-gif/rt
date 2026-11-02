extends CharacterBody2D

@export_group("Zombie Settings")
@export var max_hp: float = 100.0
@export var move_speed: float = 95.0
@export var attack_damage: float = 12.0
@export var infection_amount: float = 15.0 
@export var attack_delay: float = 0.7  

@export_group("Eyes Settings")
@export var pupil_max_distance: float = 5.0  

var current_hp: float = max_hp
var can_attack: bool = true
var original_sprite_scale: Vector2 = Vector2.ONE

var left_pupil_center: Vector2
var right_pupil_center: Vector2
var blood_scene = preload("res://Scenes/blood_spurt.tscn")

@onready var health_label: Label = $HealthLabel
@onready var character_sprite: Sprite2D = $Sprite2D
@onready var left_pupil: Sprite2D = $Sprite2D/Eyes/LeftPupil
@onready var right_pupil: Sprite2D = $Sprite2D/Eyes/RightPupil
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	current_hp = max_hp
	update_health_hud()
	add_to_group("enemies")
	
	if left_pupil: left_pupil_center = left_pupil.position
	if right_pupil: right_pupil_center = right_pupil.position
	if character_sprite: original_sprite_scale = character_sprite.scale
	
	if nav_agent:
		nav_agent.path_desired_distance = 15.0
		nav_agent.target_desired_distance = 15.0

func _process(delta: float) -> void:
	var target = find_closest_target()
	
	if target != null:
		update_zombie_eyes(target.global_position)
		if character_sprite:
			if target.global_position.x < global_position.x:
				character_sprite.scale = Vector2(-original_sprite_scale.x, original_sprite_scale.y)
			else:
				character_sprite.scale = original_sprite_scale

func _physics_process(delta: float) -> void:
	# СНАЧАЛА проверяем, нет ли баррикады прямо перед носом зомби, преграждающей путь
	var blocking_wall = check_for_blocking_wall()
	var target: Node2D = null
	
	if blocking_wall != null:
		# Если стена закрывает проход, она становится главной приоритетной целью для уничтожения!
		target = blocking_wall
	else:
		# Если проход чист, ищем людей или флаг
		target = find_closest_target()
	
	if target != null and nav_agent:
		nav_agent.target_position = target.global_position
		
		# Логика атаки (кусаем / ломаем)
		var distance = global_position.distance_to(target.global_position)
		if distance < 55.0:
			velocity = Vector2.ZERO
			if can_attack:
				attack_target(target)
		else:
			# Логика движения к цели в обход статических стен карты
			if not nav_agent.is_navigation_finished():
				var next_path_pos = nav_agent.get_next_path_position()
				var direction = global_position.direction_to(next_path_pos)
				velocity = direction * move_speed
			else:
				velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
		
	move_and_slide()

# УМНЫЙ ПОИСК ЦЕЛИ (Люди или Флаг)
func find_closest_target() -> Node2D:
	var all_targets = []
	all_targets.append_array(get_tree().get_nodes_in_group("players"))
	
	var flag_node = get_tree().current_scene.get_node_or_null("Flag")
	if flag_node: all_targets.append(flag_node)
	
	var closest_target: Node2D = null
	var min_distance := INF
	
	for t in all_targets:
		if t is Node2D and is_instance_valid(t):
			var dist = global_position.distance_to(t.global_position)
			if dist < min_distance:
				min_distance = dist
				closest_target = t
				
	return closest_target

# Проверка: есть ли баррикада в радиусе укуса зомби (чтобы проломить её)
func check_for_blocking_wall() -> Node2D:
	var walls = get_tree().get_nodes_in_group("barricades")
	var closest_wall: Node2D = null
	var min_distance := INF
	
	for wall in walls:
		if wall is Node2D and is_instance_valid(wall):
			var dist = global_position.distance_to(wall.global_position)
			# Если стена прямо перед зомби (ближе 60 пикселей)
			if dist < 60.0 and dist < min_distance:
				min_distance = dist
				closest_wall = wall
	return closest_wall

func update_zombie_eyes(target_pos: Vector2) -> void:
	if left_pupil:
		var dir = target_pos - left_pupil.global_position
		var offset = dir.limit_length(pupil_max_distance)
		if character_sprite and character_sprite.scale.x < 0: offset.x = -offset.x
		left_pupil.position = left_pupil_center + offset
	if right_pupil:
		var dir = target_pos - right_pupil.global_position
		var offset = dir.limit_length(pupil_max_distance)
		if character_sprite and character_sprite.scale.x < 0: offset.x = -offset.x
		right_pupil.position = right_pupil_center + offset

func attack_target(target_node: Node2D) -> void:
	can_attack = false
	if target_node.has_method("take_damage"):
		if "current_infection" in target_node:
			target_node.take_damage(attack_damage, infection_amount) 
		else:
			target_node.take_damage(attack_damage) 
			
	if get_tree():
		await get_tree().create_timer(attack_delay).timeout
		can_attack = true

func take_damage(amount: float, hit_direction: Vector2 = Vector2.ZERO) -> void:
	current_hp -= amount
	update_health_hud()
	if blood_scene and hit_direction != Vector2.ZERO:
		var blood = blood_scene.instantiate()
		get_tree().root.add_child(blood)
		blood.global_position = global_position + (hit_direction * 15.0)
		blood.global_position += Vector2(randf_range(-10, 10), randf_range(-10, 10))
	if current_hp <= 0:
		die()

func update_health_hud() -> void:
	if health_label:
		health_label.text = "HP: " + str(max(0, int(current_hp))) + " / " + str(int(max_hp))

func die() -> void:
	if blood_scene:
		for i in range(3):
			var final_blood = blood_scene.instantiate()
			get_tree().root.add_child(final_blood)
			final_blood.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	queue_free()
