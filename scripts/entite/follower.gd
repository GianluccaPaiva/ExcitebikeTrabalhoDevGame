@tool
class_name Follower
extends PathFollow2D

signal percurso_concluido(bot: Node2D)

@export var speed: float = 140.0:
	set(val):
		speed = val
		velocidade_base = val

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
@export var taxa_desaceleracao: float = 215.0

# Variáveis em PT-BR
var velocidade_base: float = 140.0
var velocidade_atual: float = -1.0
var percurso_finalizado: bool = false
var em_desaceleracao: bool = false
var tempo_efeito_restante: float = 0.0

var _posicao_anterior: Vector2 = Vector2.ZERO
var _pulos_de_quadro_ativo: int = 0
var _contador_quadros: int = 0
var _delta_acumulado: float = 0.0

@onready var _sprite_cache: Sprite2D = get_node_or_null("Enemy/Sprite2D")
@onready var _animacao_cache: AnimationPlayer = get_node_or_null("Enemy/AnimationPlayer")


func _ready() -> void:
	velocidade_base = speed
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

	_posicao_anterior = global_position

	# Se a corrida ainda não começou, pausa a animação das rodas no grid
	if not corrida_iniciada:
		var anim: AnimationPlayer = _obter_animation_player()
		if anim:
			anim.pause()


func aplicar_efeito_pista(fator: float, duracao: float, saltos_de_frame: int = 0) -> void:
	velocidade_atual = velocidade_base * fator
	tempo_efeito_restante = duracao
	_pulos_de_quadro_ativo = saltos_de_frame


## Movimento físico executado em taxa fixa de quadros (60Hz)
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		_aplicar_textura()
		_aplicar_material()
		_aplicar_modulate()
		rotates = false
		rotation = 0.0
		return

	if not corrida_iniciada:
		_posicao_anterior = global_position
		rotation = 0.0
		return

	if velocidade_atual < 0.0:
		velocidade_atual = velocidade_base

	# Temporizador do efeito da pista (boost ou lama)
	if tempo_efeito_restante > 0.0 and not em_desaceleracao:
		tempo_efeito_restante -= delta

	# Ponto pós-chegada para desaceleração
	if global_position.x >= 17640.0:
		em_desaceleracao = true

	if em_desaceleracao:
		velocidade_atual = move_toward(velocidade_atual, 0.0, taxa_desaceleracao * delta)
		if velocidade_atual <= 1.0:
			velocidade_atual = 0.0
			var anim: AnimationPlayer = _obter_animation_player()
			if anim and anim.is_playing() and anim.current_animation != "RESET":
				anim.pause()
			rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * delta)
			_posicao_anterior = global_position
			if not percurso_finalizado:
				percurso_finalizado = true
				percurso_concluido.emit(self)
			return
	else:
		if tempo_efeito_restante <= 0.0:
			velocidade_atual = move_toward(velocidade_atual, velocidade_base, 120.0 * delta)
			_pulos_de_quadro_ativo = 0

	# Lógica visual de frame skip na lama
	var passo_delta: float = delta
	if _pulos_de_quadro_ativo > 0 and tempo_efeito_restante > 0.0:
		_delta_acumulado += delta
		_contador_quadros += 1
		if _contador_quadros <= _pulos_de_quadro_ativo:
			return
		passo_delta = _delta_acumulado
		_delta_acumulado = 0.0
		_contador_quadros = 0
	else:
		_delta_acumulado = 0.0
		_contador_quadros = 0

	# Checa se atingiu o fim da curva da trilha
	if get_parent() is Path2D and get_parent().curve:
		var comprimento_total: float = get_parent().curve.get_baked_length()
		if progress >= comprimento_total - 2.0:
			var anim: AnimationPlayer = _obter_animation_player()
			if anim and anim.is_playing() and anim.current_animation != "RESET":
				anim.pause()
			rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * passo_delta)
			_posicao_anterior = global_position
			if not percurso_finalizado:
				percurso_finalizado = true
				percurso_concluido.emit(self)
			return

	progress += velocidade_atual * passo_delta

	var deslocamento: Vector2 = global_position - _posicao_anterior
	if deslocamento.length_squared() > 0.0001:
		if deslocamento.x > 0.001:
			var angulo_alvo: float = deslocamento.angle()
			angulo_alvo = clampf(angulo_alvo, -0.28, 0.28)
			rotation = lerp_angle(rotation, angulo_alvo, rotation_smoothing_speed * passo_delta)
		else:
			rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * passo_delta)
	else:
		rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * passo_delta)

	_posicao_anterior = global_position


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
	if is_instance_valid(_sprite_cache):
		return _sprite_cache
	_sprite_cache = get_node_or_null("Enemy/Sprite2D")
	if not _sprite_cache:
		_sprite_cache = find_child("Sprite2D", true, false) as Sprite2D
	return _sprite_cache


func _obter_animation_player() -> AnimationPlayer:
	if is_instance_valid(_animacao_cache):
		return _animacao_cache
	_animacao_cache = get_node_or_null("Enemy/AnimationPlayer")
	if not _animacao_cache:
		_animacao_cache = find_child("AnimationPlayer", true, false) as AnimationPlayer
	return _animacao_cache


## Chamado pelo CountdownUI ao exibir "VAI!" para iniciar a corrida
func iniciar_corrida() -> void:
	corrida_iniciada = true
	_posicao_anterior = global_position
	var anim: AnimationPlayer = _obter_animation_player()
	if anim:
		anim.play("andar")


## Retorna se o bot concluiu todo o percurso da trilha
func is_percurso_finalizado() -> bool:
	return percurso_finalizado


## Inicia a desaceleração do bot ao atingir a reta pós-chegada
func iniciar_desaceleracao_automatica(_x_alvo: float = 0.0) -> void:
	em_desaceleracao = true
