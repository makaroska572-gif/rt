extends RigidBody2D

@export_group("Weapon Settings")
@export var weapon_name: String = "Базовое оружие"
@export var custom_texture: Texture2D

@export_group("Shooting Settings")
@export var shoot_delay: float = 0.15     # Скорострельность
@export var damage: float = 15.0          # Урон пули
@export var max_ammo_clip: int = 30       # Патронов в магазине
@export var max_ammo_reserve: int = 120   # Запас патронов
@export var reload_time: float = 1.5      # Время перезарядки в секундах

@export_group("Accuracy Settings")
@export var spread_degrees: float = 5.0    # Разброс пули в градусах

@export_group("Audio Settings")
@export var shoot_sound: AudioStream       

# Предзагрузка сцены пули
var bullet_scene = preload("res://Scenes/bullet.tscn")

# Переменные текущего состояния
var current_ammo_clip: int = 30
var current_ammo_reserve: int = 120
var can_shoot: bool = true
var is_reloading: bool = false
var is_equipped: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var pick_up_area: Area2D = $PickUpArea
@onready var pick_up_shape: CollisionShape2D = $PickUpArea/CollisionShape2D
@onready var muzzle: Marker2D = $Muzzle
@onready var shoot_player: AudioStreamPlayer2D = $ShootPlayer 

func _ready() -> void:
	gravity_scale = 0.0
	
	if pick_up_area:
		pick_up_area.body_entered.connect(_on_pick_up_area_body_entered)
	if custom_texture and sprite:
		sprite.texture = custom_texture
		
	if shoot_player and shoot_sound:
		shoot_player.stream = shoot_sound
		
	current_ammo_clip = max_ammo_clip
	current_ammo_reserve = max_ammo_reserve
	linear_damp = 4.0
	angular_damp = 3.0

func _on_pick_up_area_body_entered(body: Node2D) -> void:
	if not is_equipped and body.has_method("equip_weapon") and body.current_weapon == null:
		body.equip_weapon(self)

# Функция выстрела
func shoot(from_group: String = "") -> void:
	if not is_equipped or not can_shoot or is_reloading:
		return
		
	if current_ammo_clip <= 0:
		start_reload()
		return

	current_ammo_clip -= 1
	can_shoot = false
	
	if shoot_player and shoot_player.stream != null:
		shoot_player.stop() 
		shoot_player.play() 
	
	if bullet_scene and muzzle:
		var bullet = bullet_scene.instantiate()
		var tree_root = get_tree().root
		if tree_root:
			tree_root.add_child(bullet)
		
		var random_offset := randf_range(-spread_degrees, spread_degrees)
		var random_offset_radians := deg_to_rad(random_offset)
		
		bullet.global_position = muzzle.global_position
		bullet.global_rotation = global_rotation + random_offset_radians
		bullet.damage = damage
		if "shooter_group" in bullet:
			bullet.shooter_group = from_group
		
	await get_tree().create_timer(shoot_delay).timeout
	can_shoot = true

# Логика перезарядки
func start_reload() -> void:
	if is_reloading or current_ammo_clip == max_ammo_clip or current_ammo_reserve <= 0:
		return
		
	is_reloading = true
	await get_tree().create_timer(reload_time).timeout
	
	var needed_ammo = max_ammo_clip - current_ammo_clip
	
	if current_ammo_reserve >= needed_ammo:
		current_ammo_clip = max_ammo_clip
		current_ammo_reserve -= needed_ammo
	else:
		current_ammo_clip += current_ammo_reserve
		current_ammo_reserve = 0
		
	is_reloading = false
	can_shoot = true

func set_equipped(player_anchor: Node2D) -> void:
	is_equipped = true
	process_mode = PROCESS_MODE_DISABLED
	freeze = true 
	
	if collision: collision.disabled = true
	if pick_up_shape: pick_up_shape.disabled = true
	if pick_up_area:
		pick_up_area.monitoring = false
		pick_up_area.monitorable = false
	
	get_parent().remove_child(self)
	player_anchor.add_child(self)
	
	position = Vector2.ZERO
	rotation = 0
	scale = Vector2.ONE 
	if sprite:
		sprite.position = Vector2.ZERO
		
	process_mode = PROCESS_MODE_INHERIT

func drop(spawn_position: Vector2, drop_impulse: Vector2, is_throwing: bool) -> void:
	is_equipped = false
	is_reloading = false 
	can_shoot = true
	
	var tree_root = get_tree().root
	if pick_up_area:
		pick_up_area.monitoring = true
		pick_up_area.monitorable = true
		
	get_parent().remove_child(self)
	if tree_root:
		tree_root.add_child(self)
	
	global_position = spawn_position
	scale = Vector2.ONE 
	
	gravity_scale = 0.0
	freeze = false
	if collision: collision.disabled = false
	
	if is_throwing:
		lock_rotation = false
		linear_damp = 3.0
		angular_damp = 2.0
		apply_central_impulse(drop_impulse)
		var spin_dir = 1 if randf() > 0.5 else -1
		apply_torque_impulse(spin_dir * 15000.0) 
	else:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		linear_damp = 100.0
		angular_damp = 100.0
		lock_rotation = true
		apply_central_impulse(drop_impulse)
	
	await get_tree().create_timer(0.4).timeout
	if pick_up_shape: pick_up_shape.disabled = false

# ИСПРАВЛЕННЫЙ ПЕРЕВОРОТ: учитывает разворот родительского спрайта
func set_flipped(should_flip: bool) -> void:
	# Находим узел Sprite2D самого персонажа (у игрока и бота это $Sprite2D)
	var parent_character = get_parent().get_parent()
	var is_parent_flipped_left = false
	
	if parent_character and "scale" in parent_character:
		# Если узел персонажа развернут влево (scale.x отрицательный)
		if parent_character.scale.x < 0:
			is_parent_flipped_left = true
			
	if should_flip:
		# Если персонаж смотрит влево И пушка направлена влево, масштаб Y инвертируется зеркально
		scale.y = 1.0 if is_parent_flipped_left else -1.0
	else:
		scale.y = -1.0 if is_parent_flipped_left else 1.0
		
	if muzzle:
		muzzle.position.y = -abs(muzzle.position.y) if should_flip else abs(muzzle.position.y)
