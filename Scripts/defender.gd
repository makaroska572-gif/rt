extends CharacterBody2D

@export_group("Defender Settings")
@export var max_hp: float = 120.0
@export var move_speed: float = 110.0      
@export var attack_range: float = 350.0    

@export_group("Wander Settings")
@export var wander_radius: float = 150.0   
@export var wander_delay_min: float = 2.0  
@export var wander_delay_max: float = 5.0  

var current_hp: float = max_hp
var current_weapon: RigidBody2D = null

@export var pupil_max_distance: float = 5.0  
var left_pupil_center: Vector2
var right_pupil_center: Vector2
var original_sprite_scale: Vector2 = Vector2.ONE

var spawn_position: Vector2
var target_wander_position: Vector2
var wander_timer: float = 0.0

var ak47_scene = preload("res://Scenes/ak_47.tscn")

@onready var character_sprite: Sprite2D = $Sprite2D
@onready var left_pupil: Sprite2D = $Sprite2D/Eyes/LeftPupil
@onready var right_pupil: Sprite2D = $Sprite2D/Eyes/RightPupil
@onready var weapon_anchor: Node2D = $WeaponAnchor
@onready var health_label: Label = $HealthLabel
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	current_hp = max_hp
	update_health_hud()
	add_to_group("players") 
	
	if left_pupil: left_pupil_center = left_pupil.position
	if right_pupil: right_pupil_center = right_pupil.position
	if character_sprite: original_sprite_scale = character_sprite.scale
	
	spawn_position = global_position
	target_wander_position = global_position
	wander_timer = randf_range(wander_delay_min, wander_delay_max)
	
	if nav_agent:
		nav_agent.path_desired_distance = 15.0
		nav_agent.target_desired_distance = 15.0
	
	if ak47_scene and weapon_anchor:
		var ak47 = ak47_scene.instantiate()
		get_tree().root.call_deferred("add_child", ak47)
		call_deferred("equip_weapon", ak47)

func _process(delta: float) -> void:
	var closest_zombie = find_closest_zombie()
	
	if closest_zombie != null:
		var target_pos = closest_zombie.global_position
		update_defender_eyes(target_pos)
		
		if character_sprite:
			if target_pos.x < global_position.x:
				character_sprite.scale = Vector2(-original_sprite_scale.x, original_sprite_scale.y)
			else:
				character_sprite.scale = original_sprite_scale
				
		if weapon_anchor:
			weapon_anchor.look_at(target_pos)
			var angle := fmod(weapon_anchor.rotation_degrees, 360.0)
			if angle > 180: angle -= 360.0
			elif angle < -180: angle += 360.0
			
			# ОБНОВЛЕННЫЙ ВЫЗОВ: передаем команду в исправленное оружие
			if current_weapon and current_weapon.has_method("set_flipped"):
				if angle > 90 or angle < -90:
					current_weapon.set_flipped(true)
				else:
					current_weapon.set_flipped(false)
					
		var distance = global_position.distance_to(target_pos)
		if distance <= attack_range and current_weapon and has_clear_line_of_sight(closest_zombie):
			if current_weapon.has_method("shoot"):
				current_weapon.shoot("player") # Защитник передает фракцию людей
	else:
		if left_pupil: left_pupil.position = left_pupil_center
		if right_pupil: right_pupil.position = right_pupil_center
		if weapon_anchor:
			var default_look = global_position + Vector2(character_sprite.scale.x * 50.0, 0)
			weapon_anchor.look_at(default_look)

func _physics_process(delta: float) -> void:
	var closest_zombie = find_closest_zombie()
	
	if closest_zombie != null and nav_agent:
		var distance = global_position.distance_to(closest_zombie.global_position)
		
		if not has_clear_line_of_sight(closest_zombie) or distance > attack_range - 60.0:
			nav_agent.target_position = closest_zombie.global_position
			
			if not nav_agent.is_navigation_finished():
				var next_path_pos = nav_agent.get_next_path_position()
				var direction = global_position.direction_to(next_path_pos)
				velocity = direction * move_speed
				if character_sprite:
					character_sprite.scale = Vector2(-original_sprite_scale.x, original_sprite_scale.y) if velocity.x < 0 else original_sprite_scale
			else:
				velocity = Vector2.ZERO
		else:
			velocity = Vector2.ZERO
	else:
		if nav_agent:
			nav_agent.target_position = target_wander_position
			var dist_to_wander_target = global_position.distance_to(target_wander_position)
			
			if dist_to_wander_target > 15.0 and not nav_agent.is_navigation_finished():
				var next_path_pos = nav_agent.get_next_path_position()
				var direction = global_position.direction_to(next_path_pos)
				velocity = direction * move_speed
				if character_sprite:
					character_sprite.scale = Vector2(-original_sprite_scale.x, original_sprite_scale.y) if velocity.x < 0 else original_sprite_scale
			else:
				velocity = Vector2.ZERO
				wander_timer -= delta
				if wander_timer <= 0:
					var random_offset = Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
					target_wander_position = spawn_position + random_offset
					wander_timer = randf_range(wander_delay_min, wander_delay_max)
				
	move_and_slide()

func has_clear_line_of_sight(target: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	if result:
		if result.collider == target:
			return true
	return false

func find_closest_zombie() -> Node2D:
	var zombies = get_tree().get_nodes_in_group("enemies")
	var closest_zombie_node: Node2D = null
	var min_distance := INF
	for zombie in zombies:
		if zombie is Node2D and is_instance_valid(zombie):
			var dist = global_position.distance_to(zombie.global_position)
			if dist < min_distance:
				min_distance = dist
				closest_zombie_node = zombie
	return closest_zombie_node

func update_defender_eyes(target_pos: Vector2) -> void:
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

func equip_weapon(weapon_node: RigidBody2D) -> void:
	current_weapon = weapon_node
	current_weapon.set_equipped(weapon_anchor)

func take_damage(amount: float, hit_direction: Vector2 = Vector2.ZERO) -> void:
	current_hp -= amount
	update_health_hud()
	if current_hp <= 0:
		die()

func update_health_hud() -> void:
	if health_label:
		health_label.text = "HP: " + str(max(0, int(current_hp))) + " / " + str(int(max_hp))

func die() -> void:
	if current_weapon != null:
		var throw_direction := Vector2.RIGHT.rotated(weapon_anchor.global_rotation)
		var spawn_pos = global_position + throw_direction * 25.0
		current_weapon.drop(spawn_pos, throw_direction * 40.0, false)
	queue_free()
