extends PathFollow2D

## Script do Seguidor de Trilha dos Adversários
## Trabalho 1 - DCC148 (UFJF) | Gabriel Lineker & Gianlucca Paiva

@export var speed: float = 140.0
@export var initial_progress: float = 0.0
@export var rotation_smoothing_speed: float = 14.0
@export var enemy_texture: Texture2D

var _last_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	rotates = false # Controle suave de curvamento idêntico ao player
	loop = false
	
	if initial_progress > 0.0 and progress == 0.0:
		progress = initial_progress
	
	_last_position = global_position
	rotation = 0.0
	
	# Se uma textura customizada foi definida (ex: Racer_2.png), aplica ao Sprite2D
	if enemy_texture:
		var sprite: Sprite2D = get_node_or_null("Enemy/Sprite2D")
		if sprite:
			sprite.texture = enemy_texture


func _process(delta: float) -> void:
	progress += speed * delta
	
	# Interpolação suave do ângulo acompanhando a curvatura da rampa (lógica similar ao player)
	var move_delta: Vector2 = global_position - _last_position
	if move_delta.length_squared() > 0.0001:
		var target_angle: float = move_delta.angle()
		rotation = lerp_angle(rotation, target_angle, rotation_smoothing_speed * delta)
	
	_last_position = global_position
