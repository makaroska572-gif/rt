extends TextureProgressBar # Меняем первую строчку на TextureProgressBar

@export var lerp_speed: float = 10.0
var target_value: float = 100.0

func _ready() -> void:
	value = max_value
	target_value = max_value

func _process(delta: float) -> void:
	value = lerp(value, target_value, lerp_speed * delta)
	
	if is_equal_approx(value, max_value):
		modulate.a = move_toward(modulate.a, 0.0, delta * 2.0)
	else:
		modulate.a = move_toward(modulate.a, 1.0, delta * 4.0)
