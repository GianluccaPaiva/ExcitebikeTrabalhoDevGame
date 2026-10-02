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

@onready var _sprite: Sprite2D = $Enemy/Sprite2D
@onready var _anim: AnimationPlayer = $Enemy/AnimationPlayer

@export var corrida_iniciada: bool = false

var _last_position: Vector2 = Vector2.ZERO
var percurso_finalizado: bool = false
var current_speed: float = -1.0
var em_desaceleracao: bool = false
@export var taxa_desaceleracao: float = 215.0
@onready var efeito_timer: Timer = $Enemy/EfeitoTimer


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
		var anim: AnimationPlayer = _anim
		if anim:
			anim.pause()


var _frame_skip_ativo: int = 0
var _frame_count: int = 0
var _delta_acumulado: float = 0.0

func aplicar_efeito_pista(fator: float, duracao: float, saltos_de_frame: int = 0) -> void:
	current_speed = speed * fator
	efeito_timer.start(duracao)
	_frame_skip_ativo = saltos_de_frame


func _physics_process(delta: float) -> void:
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

	# Removido decréscimo manual (efeito_timer gerencia sozinho)

	# Zona de desaceleração pós-chegada
	var marker_desaceleracao: Marker2D = get_tree().current_scene.get_node_or_null("Markers/MarkerDesaceleracao")
	var pos_x: float = marker_desaceleracao.global_position.x if marker_desaceleracao else 17640.0
	if global_position.x >= pos_x:
		em_desaceleracao = true

	if em_desaceleracao:
		current_speed = move_toward(current_speed, 0.0, taxa_desaceleracao * delta)
		if current_speed <= 1.0:
			current_speed = 0.0
			var anim: AnimationPlayer = _anim
			if anim and anim.is_playing() and anim.current_animation != "RESET":
				anim.pause()
			rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * delta)
			_last_position = global_position
			if not percurso_finalizado:
				percurso_finalizado = true
				percurso_concluido.emit(self)
			return
	else:
		# Se o timer parou, suaviza o retorno à velocidade original (igual inércia do Player!)
		if efeito_timer.is_stopped():
			current_speed = move_toward(current_speed, speed, 120.0 * delta)
			_frame_skip_ativo = 0

	# Lógica do Frame Skip (salto de frames/stuttering)
	var passo_delta: float = delta
	if _frame_skip_ativo > 0 and not efeito_timer.is_stopped():
		_delta_acumulado += delta
		_frame_count += 1
		if _frame_count <= _frame_skip_ativo:
			return # Pula o avanço neste frame para dar o efeito visual
		passo_delta = _delta_acumulado
		_delta_acumulado = 0.0
		_frame_count = 0
	else:
		_delta_acumulado = 0.0
		_frame_count = 0

	# Checa se atingiu o fim da trilha após a rampa final
	if get_parent() is Path2D and get_parent().curve:
		var total_length: float = get_parent().curve.get_baked_length()
		if progress >= total_length - 2.0:
			var anim: AnimationPlayer = _anim
			if anim and anim.is_playing() and anim.current_animation != "RESET":
				anim.pause()
			rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * passo_delta)
			_last_position = global_position
			if not percurso_finalizado:
				percurso_finalizado = true
				percurso_concluido.emit(self)
			return

	progress += current_speed * passo_delta
	
	var move_delta: Vector2 = global_position - _last_position
	if move_delta.length_squared() > 0.0001:
		if move_delta.x > 0.001:
			var target_angle: float = move_delta.angle()
			target_angle = clampf(target_angle, -0.28, 0.28)
			rotation = lerp_angle(rotation, target_angle, rotation_smoothing_speed * passo_delta)
		else:
			rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * passo_delta)
	else:
		rotation = lerp_angle(rotation, 0.0, rotation_smoothing_speed * passo_delta)
	
	_last_position = global_position


func _aplicar_textura() -> void:
	var sprite: Sprite2D = _sprite
	if sprite:
		var tex_alvo: Texture2D = enemy_texture
		if tex_alvo == null:
			tex_alvo = preload("res://assets/sprites/entites/Racer_1.png")
		if sprite.texture != tex_alvo:
			sprite.texture = tex_alvo


func _aplicar_material() -> void:
	var sprite: Sprite2D = _sprite
	if sprite:
		sprite.material = enemy_material


func _aplicar_modulate() -> void:
	var sprite: Sprite2D = _sprite
	if sprite:
		sprite.self_modulate = enemy_modulate


## Chamado pelo CountdownUI ao exibir "VAI!" para iniciar a corrida
func iniciar_corrida() -> void:
	corrida_iniciada = true
	_last_position = global_position
	var anim: AnimationPlayer = _anim
	if anim:
		anim.play("andar")


## Retorna se o bot concluiu todo o percurso da trilha
func is_percurso_finalizado() -> bool:
	return percurso_finalizado


## Inicia a desaceleração do bot ao atingir a reta pós-chegada
func iniciar_desaceleracao_automatica(_x_alvo: float = 0.0) -> void:
	em_desaceleracao = true
