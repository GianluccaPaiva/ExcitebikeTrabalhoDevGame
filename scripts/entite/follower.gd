@tool
extends PathFollow2D

signal percurso_concluido(bot: Node2D)

@export var speed: float = 140.0
@export var initial_progress: float = 0.0
@export var rotation_smoothing_speed: float = 14.0
@export var enemy_texture: Texture2D = preload("res://assets/sprites/entites/Racer_1.png"):
	set(val):
		enemy_texture = val
		_aplicar_textura()

@export var enemy_material: Material = null:
	set(val):
		enemy_material = val
		_aplicar_material()

@export var enemy_modulate: Color = Color.WHITE:
	set(val):
		enemy_modulate = val
		_aplicar_modulate()

@export var corrida_iniciada: bool = false

var _last_position: Vector2 = Vector2.ZERO
var percurso_finalizado: bool = false
var current_speed: float = -1.0
var em_desaceleracao: bool = false
@export var taxa_desaceleracao: float = 215.0
var tempo_efeito_restante: float = 0.0


func _ready() -> void:
	rotates = false # Impede que a engine rotacione o seguidor automaticamente
	loop = false
	rotation = 0.0
	_aplicar_textura()
	_aplicar_material()
	_aplicar_modulate()
	
	if Engine.is_editor_hint():
		return
	
	if initial_progress > 0.0 and progress == 0.0:
		progress = initial_progress
	
	_last_position = global_position
	
	# Se a corrida ainda não começou, pausa a animação das rodas no grid
	if not corrida_iniciada:
		var anim: AnimationPlayer = _obter_animation_player()
		if anim:
			anim.pause()


func aplicar_efeito_pista(fator: float, duracao: float) -> void:
	current_speed = speed * fator
	tempo_efeito_restante = duracao


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_aplicar_textura()
		_aplicar_material()
		_aplicar_modulate()
		rotates = false
		rotation = 0.0
		return

	if not corrida_iniciada:
		_last_position = global_position
		rotation = 0.0
		return

	if current_speed < 0.0:
		current_speed = speed

	if tempo_efeito_restante > 0.0 and not em_desaceleracao:
		tempo_efeito_restante -= delta
		if tempo_efeito_restante <= 0.0:
			current_speed = speed

	# Zona de desaceleração pós-chegada (para parar suavemente antes dos fotógrafos/guys)
	if global_position.x >= 17640.0:
		em_desaceleracao = true

	if em_desaceleracao:
		current_speed = move_toward(current_speed, 0.0, taxa_desaceleracao * delta)
		if current_speed <= 1.0:
			current_speed = 0.0
			var anim: AnimationPlayer = _obter_animation_player()
			if anim and anim.is_playing() and anim.current_animation != "RESET":
				anim.pause()
			rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * delta)
			_last_position = global_position
			if not percurso_finalizado:
				percurso_finalizado = true
				percurso_concluido.emit(self)
			return

	# Checa se atingiu o fim da trilha após a rampa final
	if get_parent() is Path2D and get_parent().curve:
		var total_length: float = get_parent().curve.get_baked_length()
		if progress >= total_length - 2.0:
			# Finalizou a corrida na reta final
			var anim: AnimationPlayer = _obter_animation_player()
			if anim and anim.is_playing() and anim.current_animation != "RESET":
				anim.pause()
			rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * delta)
			_last_position = global_position
			if not percurso_finalizado:
				percurso_finalizado = true
				percurso_concluido.emit(self)
			return

	progress += current_speed * delta
	
	# Fluxo de direções controlado: impede inversão de sentido e limita inclinação
	var move_delta: Vector2 = global_position - _last_position
	if move_delta.length_squared() > 0.0001:
		if move_delta.x > 0.001:
			var target_angle: float = move_delta.angle()
			# Clampa para ângulo seguro (~16 graus) acompanhando as rampas sem empinar excessivamente
			target_angle = clampf(target_angle, -0.28, 0.28)
			rotation = lerp_angle(rotation, target_angle, rotation_smoothing_speed * delta)
		else:
			# Sem deslocamento para a frente: mantém 0 radianos
			rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * delta)
	else:
		rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * delta)
	
	_last_position = global_position


func _aplicar_textura() -> void:
	var sprite: Sprite2D = _obter_sprite()
	if sprite:
		var tex_alvo: Texture2D = enemy_texture
		if tex_alvo == null:
			tex_alvo = preload("res://assets/sprites/entites/Racer_1.png")
		if sprite.texture != tex_alvo:
			sprite.texture = tex_alvo


func _aplicar_material() -> void:
	var sprite: Sprite2D = _obter_sprite()
	if sprite:
		sprite.material = enemy_material


func _aplicar_modulate() -> void:
	var sprite: Sprite2D = _obter_sprite()
	if sprite:
		sprite.self_modulate = enemy_modulate


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


## Retorna se o bot concluiu todo o percurso da trilha
func is_percurso_finalizado() -> bool:
	return percurso_finalizado


## Inicia a desaceleração do bot ao atingir a reta pós-chegada
func iniciar_desaceleracao_automatica(_x_alvo: float = 0.0) -> void:
	em_desaceleracao = true
