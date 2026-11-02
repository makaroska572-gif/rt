extends Area2D

@export var speed: float = 900.0  
var damage: float = 0.0          

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		# Находим вектор направления полета пули
		var bullet_direction := Vector2.RIGHT.rotated(rotation)
		
		# Передаем урон и направление полета в тело жертвы
		if body.has_method("take_damage"):
			body.take_damage(damage, bullet_direction)
			
		queue_free()
