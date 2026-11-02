extends CharacterBody2D

@export_group("Movement")
@export var walk_speed: float = 200.0
@export var run_speed: float = 400.0

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 30.0
@export var stamina_regen: float = 20.0
@export var stamina_threshold: float = 20.0

@export_group("Audio Settings")
@export var walk_step_delay: float = 0.35  
@export var run_step_delay: float = 0.22   

@export_group("Eyes Settings")
@export var pupil_max_distance: float = 5.0  

@export_group("Player Stats")
@export var max_hp: float = 100.0
@export var max_infection: float = 100.0

var current_hp: float = max_hp
var current_infection: float = 0.0
var current_stamina: float = max_stamina
var is_exhausted: bool = false
var step_timer: float = 0.0
var current_weapon: RigidBody2D = null

var is_building_mode: bool = false
var wall_scene = preload("res://Scenes/wall.tscn")
var b_key_was_pressed: bool = false 
var mouse_was_pressed: bool = false 

var left_pupil_center: Vector2
var right_pupil_center: Vector2
var original_sprite_scale: Vector2 = Vector2.ONE
var maps_scene_path: String = "res://Scenes/maps.tscn"

@onready var stamina_bar: TextureProgressBar = $CanvasLayer/StaminaBar
@onready var health_bar: TextureProgressBar = $CanvasLayer/HealthBar
@onready var infection_bar: TextureProgressBar = $CanvasLayer/InfectionBar

@onready var weapon_anchor: Node2D = $WeaponAnchor
@onready var ammo_label: Label = $CanvasLayer/AmmoLabel
@onready var footsteps_player: AudioStreamPlayer2D = $FootstepsPlayer

@onready var character_sprite: Sprite2D = $Sprite2D
@onready var left_pupil: Sprite2D = $Sprite2D/Eyes/LeftPupil
@onready var right_pupil: Sprite2D = $Sprite2D/Eyes/RightPupil

func _ready() -> void:
	current_hp = max_hp
	current_infection = 0.0
	add_to_group("players")
	
	if stamina_bar: stamina_bar.max_value = max_stamina
	if health_bar: health_bar.max_value = max_hp
	if infection_bar: infection_bar.max_value = max_infection
	update_ammo_hud()
	
	if left_pupil: left_pupil_center = left_pupil.position
	if right_pupil: right_pupil_center = right_pupil.position
	if character_sprite: original_sprite_scale = character_sprite.scale

func _process(delta: float) -> void:
	update_pupils_look()
	var mouse_pos := get_global_mouse_position()

	if character_sprite:
		if mouse_pos.x < global_position.x:
			character_sprite.scale = Vector2(-original_sprite_scale.x, original_sprite_scale.y)
		else:
			character_sprite.scale = original_sprite_scale

	var b_pressed = Input.is_physical_key_pressed(KEY_B)
	if b_pressed and not b_key_was_pressed:
		is_building_mode = !is_building_mode
		if is_building_mode and current_weapon:
			current_weapon.visible = false 
		elif current_weapon:
			current_weapon.visible = true
	b_key_was_pressed = b_pressed

	if is_building_mode:
		if ammo_label: ammo_label.text = "[РЕЖИМ СТРОИТЕЛЬСТВА]"
		
		var lkm_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if lkm_pressed and not mouse_was_pressed and wall_scene:
			var wall = wall_scene.instantiate()
			get_tree().current_scene.add_child(wall)
			var spawn_dir = global_position.direction_to(mouse_pos)
			wall.global_position = global_position + (spawn_dir * 45.0)
		mouse_was_pressed = lkm_pressed
	else:
		if current_weapon != null:
			weapon_anchor.look_at(mouse_pos)
			var angle := fmod(weapon_anchor.rotation_degrees, 360.0)
			if angle > 180: angle -= 360.0
			elif angle < -180: angle += 360.0
			
			if current_weapon.has_method("set_flipped"):
				current_weapon.set_flipped(angle > 90 or angle < -90)
				
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				if current_weapon.has_method("shoot"): current_weapon.shoot("player")
			if Input.is_key_pressed(KEY_R):
				if current_weapon.has_method("start_reload"): current_weapon.start_reload()
			if Input.is_key_pressed(KEY_G): drop_current_weapon(false)
			elif Input.is_key_pressed(KEY_H): drop_current_weapon(true)
		update_ammo_hud()

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var shift_pressed := Input.is_key_pressed(KEY_SHIFT) and direction != Vector2.ZERO
	var is_running := shift_pressed and not is_exhausted
	var current_speed := walk_speed
	
	if is_running:
		current_speed = run_speed
		current_stamina -= stamina_drain * delta
		if current_stamina <= 0:
			current_stamina = 0
			is_exhausted = true
	else:
		if current_stamina < max_stamina:
			current_stamina += stamina_regen * delta
			if current_stamina > max_stamina: current_stamina = max_stamina
		if is_exhausted and current_stamina >= stamina_threshold: is_exhausted = false

	if stamina_bar: stamina_bar.value = current_stamina
	if health_bar: health_bar.value = current_hp
	if infection_bar: infection_bar.value = current_infection

	if direction != Vector2.ZERO:
		velocity = direction * current_speed
		var current_step_delay = run_step_delay if is_running else walk_step_delay
		step_timer += delta
		if step_timer >= current_step_delay:
			if footsteps_player and footsteps_player.stream != null: footsteps_player.play() 
			step_timer = 0.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, current_speed)
		if footsteps_player and footsteps_player.playing: footsteps_player.stop()
		step_timer = walk_step_delay

	move_and_slide()

func take_damage(hp_amount: float, infect_amount: float = 0.0) -> void:
	current_hp -= hp_amount
	current_infection += infect_amount
	if current_hp <= 0 or current_infection >= max_infection:
		if get_tree() and ResourceLoader.exists(maps_scene_path):
			get_tree().call_deferred("change_scene_to_file", maps_scene_path)

func update_pupils_look() -> void:
	var mouse_pos = get_global_mouse_position()
	if left_pupil:
		var dir_to_mouse = mouse_pos - left_pupil.global_position
		var offset = dir_to_mouse.limit_length(pupil_max_distance)
		if character_sprite and character_sprite.scale.x < 0: offset.x = -offset.x
		left_pupil.position = left_pupil_center + offset
	if right_pupil:
		var dir_to_mouse = mouse_pos - right_pupil.global_position
		var offset = dir_to_mouse.limit_length(pupil_max_distance)
		if character_sprite and character_sprite.scale.x < 0: offset.x = -offset.x
		right_pupil.position = right_pupil_center + offset

func update_ammo_hud() -> void:
	if ammo_label:
		if current_weapon != null:
			ammo_label.text = "ПЕРЕЗАРЯДКА..." if current_weapon.is_reloading else str(current_weapon.current_ammo_clip) + " / " + str(current_weapon.current_ammo_reserve)
		else:
			ammo_label.text = "нет оружия"

func equip_weapon(weapon_node: RigidBody2D) -> void:
	current_weapon = weapon_node
	current_weapon.set_equipped(weapon_anchor)

func drop_current_weapon(is_throwing: bool) -> void:
	var weapon_to_drop = current_weapon
	current_weapon = null 
	var throw_direction := Vector2.RIGHT.rotated(weapon_anchor.global_rotation)
	var impulse = throw_direction * 650.0 if is_throwing else throw_direction * 10.0
	var spawn_pos = global_position + throw_direction * 25.0
	weapon_to_drop.drop(spawn_pos, impulse, is_throwing)
