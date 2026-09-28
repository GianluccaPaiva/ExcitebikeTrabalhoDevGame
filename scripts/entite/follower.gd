@tool
extends PathFollow2D

## Script do Seguidor de Trilha dos Adversários
## Trabalho 1 - DCC148 (UFJF) | Gabriel Lineker & Gianlucca Paiva

@export var speed: float = 140.0
@export var initial_progress: float = 0.0
@export var rotation_smoothing_speed: float = 14.0
@export var enemy_texture: Texture2D = preload("res://assets/sprites/Racer_1.png"):
	set(val):
		enemy_texture = val
		_aplicar_textura()

@export var corrida_iniciada: bool = false

var _last_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_aplicar_textura()
	
	if Engine.is_editor_hint():
		return
	
	rotates = false # Controle suave de curvamento idêntico ao player
	loop = false
	
	if initial_progress > 0.0 and progress == 0.0:
		progress = initial_progress
	
	_last_position = global_position
	rotation = 0.0
	
	# Se a corrida ainda não começou, pausa a rotação das rodas no grid
	if not corrida_iniciada:
		var anim: AnimationPlayer = _obter_animation_player()
		if anim:
			anim.pause()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_aplicar_textura()
		return

	if not corrida_iniciada:
		_last_position = global_position
		return

	# Checa se atingiu o fim da trilha após a rampa final
	if get_parent() is Path2D and get_parent().curve:
		var total_length: float = get_parent().curve.get_baked_length()
		if progress >= total_length - 2.0:
			# Finalizou a corrida na reta final
			return

	progress += speed * delta
	
	# Interpolação suave do ângulo acompanhando a curvatura da rampa (lógica similar ao player)
	var move_delta: Vector2 = global_position - _last_position
	if move_delta.length_squared() > 0.0001:
		var target_angle: float = move_delta.angle()
		rotation = lerp_angle(rotation, target_angle, rotation_smoothing_speed * delta)
	
	_last_position = global_position


func _aplicar_textura() -> void:
	var sprite: Sprite2D = _obter_sprite()
	if sprite:
		var tex_alvo: Texture2D = enemy_texture
		if tex_alvo == null:
			tex_alvo = preload("res://assets/sprites/Racer_1.png")
		if sprite.texture != tex_alvo:
			sprite.texture = tex_alvo


func _obter_sprite() -> Sprite2D:
	var sprite: Sprite2D = get_node_or_null("Enemy/Sprite2D")
	if not sprite:
		sprite = find_child("Sprite2D", true, false) as Sprite2D
	return sprite


func _obter_animation_player() -> AnimationPlayer:
	var anim: AnimationPlayer = get_node_or_null("Enemy/AnimationPlayer")
	if not anim:
		anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	return anim


## Chamado pelo CountdownUI ao exibir "VAI!" para iniciar a corrida
func iniciar_corrida() -> void:
	corrida_iniciada = true
	_last_position = global_position
	var anim: AnimationPlayer = _obter_animation_player()
	if anim:
		anim.play("andar")
