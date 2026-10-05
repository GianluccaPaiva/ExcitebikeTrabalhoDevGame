class_name Player
extends CharacterBody2D

## Entidade principal do Jogador
## Controla aceleração, física de solo e rampa, rotação angular procedural em voo
## e transições reativas de estado com temporizadores nativos.

enum Estado {
	NO_CHAO,
	NO_AR,
	ACIDENTE
}

signal hospital
signal desaceleracao_concluida
signal manobra_sucesso(quantidade_giros: int)
signal queda_ocorreu(quantidade: int)

# --- CONSTANTES DE FÍSICA E MANOBRA (PT-BR) ---
const PX_PARA_KMH: float = 0.36
const ANGULO_PLANEIO_MIN: float = -0.62
const ANGULO_PLANEIO_MAX: float = -0.12
const ANGULO_MERGULHO_MIN: float = 0.18
const FATOR_PLANEIO: float = 0.85
const FATOR_MERGULHO: float = 1.15
const TEMPO_MINIMO_MANOBRA: float = 0.4

# --- CONFIGURAÇÕES DE FÍSICA (Ajustáveis no Inspetor) ---
@export_group("Movimento no Solo")
@export var max_speed: float = 260.0
@export var acceleration: float = 200.0
@export var friction: float = 100.0
@export var brake_force: float = 320.0

@export_group("Física Aérea e Flips")
@export var gravity: float = 580.0
@export var max_fall_speed: float = 480.0
@export var air_rotation_speed: float = 12.5 # ~716 graus/s
@export var ramp_inertia_multiplier: float = 1.18

@export_group("Pouso e Acidente")
@export var max_safe_angle_back_degrees: float = 75.0
@export var max_safe_angle_front_degrees: float = 60.0
@export var crash_duration: float = 1.6
@export var limite_acidentes_hospital: int = 3

# --- REFERÊNCIAS DE NÓS ---
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var moto_caida_sprite: Sprite2D = $MotoCaidaSprite
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var hub_ui: Node = get_node_or_null("Hub")
@onready var player_audio: Node2D = get_node_or_null("PlayerAudio")
@onready var temporizador_queda: Timer = $CrashTimer
@onready var temporizador_efeito: Timer = $EfeitoTimer

# --- VARIÁVEIS DE CONTROLE E ESTADO ---
@export var controles_bloqueados: bool = true
var estado: Estado = Estado.NO_CHAO
var estava_no_chao: bool = true
var velocidade_atual: float = 0.0
var em_desaceleracao_automatica: bool = false
var limite_x_parada: float = 0.0
var taxa_freio_automatico: float = 350.0
var qtd_acidentes: int = 0
var ultimo_vetor_rampa: Vector2 = Vector2.RIGHT
var ultima_velocidade_rampa: float = 0.0
var temporizador_salto_rampa: float = 0.0
var velocidade_maxima_base: float = 0.0
var rotacao_inicio_salto: float = 0.0
var tempo_no_ar: float = 0.0

# Aliases para retrocompatibilidade
var current_speed: float:
	get: return velocidade_atual
	set(v): velocidade_atual = v

var was_on_floor: bool:
	get: return estava_no_chao
	set(v): estava_no_chao = v

var state: Estado:
	get: return estado
	set(v): estado = v


func _ready() -> void:
	floor_snap_length = 8.0
	velocidade_maxima_base = max_speed

	if temporizador_queda:
		temporizador_queda.one_shot = true
		temporizador_queda.timeout.connect(_recuperar_de_acidente)

	if temporizador_efeito:
		temporizador_efeito.one_shot = true
		temporizador_efeito.timeout.connect(_ao_expirar_efeito)

	if moto_caida_sprite:
		moto_caida_sprite.visible = false
	if animation_player:
		animation_player.play("parado")

	update_hub_ui()


func _physics_process(delta: float) -> void:
	# Enquanto a contagem regressiva estiver rodando, mantém estático no grid
	if controles_bloqueados and not em_desaceleracao_automatica:
		velocity = Vector2.ZERO
		velocidade_atual = 0.0
		if player_audio:
			player_audio.parar_motor()
		if animation_player and animation_player.current_animation != "parado":
			animation_player.play("parado")
		update_hub_ui()
		return

	match estado:
		Estado.NO_CHAO:
			_processar_chao(delta)
		Estado.NO_AR:
			_processar_ar(delta)
		Estado.ACIDENTE:
			_processar_acidente(delta)

	move_and_slide()

	_verificar_transicoes_piso()
	update_hub_ui()

	if player_audio:
		var impedido: bool = (estado == Estado.ACIDENTE or em_desaceleracao_automatica or controles_bloqueados)
		player_audio.atualizar_motor(Input.is_action_pressed("acelerar"), velocidade_atual, max_speed, impedido)


# ==============================================================================
# --- PROCESSADORES DE ESTADO FÍSICO ---
# ==============================================================================

## Estado: NO CHÃO (Deslocamento vetorial alinhado ao relevo)
func _processar_chao(delta: float) -> void:
	var geom: Dictionary = _calcular_geometria_solo()
	var angulo_solo: float = geom.angulo
	var direcao_solo: Vector2 = geom.direcao

	# Inviolabilidade: rotação puramente vetorial/procedural
	rotation = angulo_solo

	# Aceleração, freio e atrito
	if em_desaceleracao_automatica:
		velocidade_atual = move_toward(velocidade_atual, 0.0, taxa_freio_automatico * delta)
		if limite_x_parada > 0.0 and global_position.x >= (limite_x_parada - 25.0):
			velocidade_atual = move_toward(velocidade_atual, 0.0, brake_force * delta)
		if velocidade_atual <= 1.0:
			velocidade_atual = 0.0
			velocity = Vector2.ZERO
			em_desaceleracao_automatica = false
			controles_bloqueados = true
			if player_audio:
				player_audio.parar_parando()
			if animation_player:
				animation_player.play("parado")
				animation_player.speed_scale = 1.0
			desaceleracao_concluida.emit()
			return
	elif controles_bloqueados:
		velocidade_atual = move_toward(velocidade_atual, 0.0, friction * delta)
	elif Input.is_action_pressed("acelerar"):
		velocidade_atual = move_toward(velocidade_atual, max_speed, acceleration * delta)
	elif Input.is_action_pressed("frear"):
		velocidade_atual = move_toward(velocidade_atual, 0.0, brake_force * delta)
	else:
		velocidade_atual = move_toward(velocidade_atual, 0.0, friction * delta)

	# Vetor segue integralmente a tangente da rampa/chão
	velocity = direcao_solo * velocidade_atual

	# Registra inércia de subida de rampa
	if direcao_solo.y < -0.08:
		ultimo_vetor_rampa = direcao_solo
		ultima_velocidade_rampa = velocidade_atual
		temporizador_salto_rampa = 0.2
	elif temporizador_salto_rampa > 0.0:
		temporizador_salto_rampa -= delta

	if not is_on_floor():
		velocity.y += gravity * delta

	# Animações de corrida
	_atualizar_animacao_movimento()


## Estado: NO AR (Manobras, flips e rotação procedural)
func _processar_ar(delta: float) -> void:
	tempo_no_ar += delta

	# Efeito aerodinâmico por inclinação
	var gravidade_efetiva: float = gravity
	if rotation < ANGULO_PLANEIO_MAX and rotation > ANGULO_PLANEIO_MIN:
		gravidade_efetiva = gravity * FATOR_PLANEIO
	elif rotation > ANGULO_MERGULHO_MIN:
		gravidade_efetiva = gravity * FATOR_MERGULHO

	velocity.y += gravidade_efetiva * delta
	velocity.y = minf(velocity.y, max_fall_speed)

	if not em_desaceleracao_automatica and velocity.x > max_speed:
		velocity.x = move_toward(velocity.x, max_speed, 50.0 * delta)

	if em_desaceleracao_automatica:
		velocity.x = move_toward(velocity.x, 0.0, (taxa_freio_automatico * 0.5) * delta)
		velocidade_atual = move_toward(velocidade_atual, 0.0, (taxa_freio_automatico * 0.5) * delta)

	# Input de rotação procedural (W / S)
	var input_rotacao: float = 0.0
	if not em_desaceleracao_automatica:
		if Input.is_action_pressed("inclinar_tras"):
			input_rotacao -= 1.0
		if Input.is_action_pressed("inclinar_frente"):
			input_rotacao += 1.0

	rotation += input_rotacao * air_rotation_speed * delta

	if animation_player and animation_player.is_playing() and animation_player.current_animation != "RESET":
		animation_player.pause()


## Estado: ACIDENTE (Crash)
func _processar_acidente(delta: float) -> void:
	velocidade_atual = 0.0
	velocity.x = 0.0

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0


# ==============================================================================
# --- TRANSIÇÕES DE PISO E MECÂNICAS DE SALTO / POUSO ---
# ==============================================================================

func _verificar_transicoes_piso() -> void:
	var no_piso_agora: bool = is_on_floor()

	if not estava_no_chao and no_piso_agora and estado == Estado.NO_AR:
		_processar_aterrissagem()
	elif estava_no_chao and not no_piso_agora and estado == Estado.NO_CHAO:
		_decolar_da_rampa()

	estava_no_chao = no_piso_agora


func _decolar_da_rampa() -> void:
	_mudar_estado(Estado.NO_AR)
	rotacao_inicio_salto = rotation
	tempo_no_ar = 0.0

	if temporizador_salto_rampa > 0.0 and ultimo_vetor_rampa.y < -0.08:
		var velocidade_impulso: float = maxf(velocidade_atual, ultima_velocidade_rampa)
		velocity.x = absf(ultimo_vetor_rampa.x) * velocidade_impulso * ramp_inertia_multiplier
		velocity.y = ultimo_vetor_rampa.y * velocidade_impulso * ramp_inertia_multiplier
	else:
		velocity.x = velocidade_atual
		if velocity.y > 0.0:
			velocity.y = 0.0


func _processar_aterrissagem() -> void:
	var geom: Dictionary = _calcular_geometria_solo()
	var angulo_solo: float = geom.angulo
	var direcao_solo: Vector2 = geom.direcao

	var diferenca_relativa: float = angle_difference(angulo_solo, rotation)
	var diferenca_absoluta: float = absf(diferenca_relativa)
	var limite_seguro_graus: float = max_safe_angle_back_degrees if diferenca_relativa < 0.0 else max_safe_angle_front_degrees
	var limite_seguro_rad: float = deg_to_rad(limite_seguro_graus)

	if diferenca_absoluta <= limite_seguro_rad:
		# Pouso seguro com bônus de manobra (360° / acrobacia)
		if tempo_no_ar >= TEMPO_MINIMO_MANOBRA:
			manobra_sucesso.emit(1)

		_mudar_estado(Estado.NO_CHAO)
		rotation = angulo_solo

		var velocidade_projetada: float = velocity.dot(direcao_solo)
		if controles_bloqueados and not em_desaceleracao_automatica:
			velocidade_atual = 0.0
		else:
			velocidade_atual = clampf(velocidade_projetada, 0.0, max_speed * 1.1)

		if em_desaceleracao_automatica:
			_calcular_taxa_freio_automatico()

		if controles_bloqueados and not em_desaceleracao_automatica:
			if animation_player:
				animation_player.play("parado")
		else:
			_atualizar_animacao_movimento()
	else:
		qtd_acidentes += 1
		queda_ocorreu.emit(qtd_acidentes)
		update_hub_ui()
		_disparar_acidente()
		if qtd_acidentes >= limite_acidentes_hospital:
			hospital.emit()


func _disparar_acidente() -> void:
	_mudar_estado(Estado.ACIDENTE)
	velocidade_atual = 0.0
	velocity = Vector2.ZERO
	rotation = 0.0

	if temporizador_queda:
		temporizador_queda.start(crash_duration)

	if player_audio:
		player_audio.parar_motor()
		if qtd_acidentes >= limite_acidentes_hospital:
			player_audio.tocar_morte()
		else:
			player_audio.tocar_queda()

	AudioManager.tocar_torcida_queda()

	if animation_player:
		animation_player.play("acidente")
		animation_player.speed_scale = 1.0


func _recuperar_de_acidente() -> void:
	_mudar_estado(Estado.NO_CHAO)
	rotation = 0.0
	velocidade_atual = 0.0
	velocity = Vector2.ZERO

	if moto_caida_sprite:
		moto_caida_sprite.visible = false
	if sprite_2d:
		sprite_2d.frame = 0
	if animation_player:
		animation_player.play("parado")
		animation_player.speed_scale = 1.0


func _mudar_estado(novo_estado: Estado) -> void:
	estado = novo_estado
	floor_snap_length = 0.0 if novo_estado == Estado.NO_AR else 8.0
	if novo_estado != Estado.NO_AR:
		temporizador_salto_rampa = 0.0


# ==============================================================================
# --- API PÚBLICA (CONTROLE DE CORRIDA E EFEITOS) ---
# ==============================================================================

## Chamado para liberar os controles no sinal "VAI!"
func liberar_controles() -> void:
	controles_bloqueados = false


## Chamado por grupos de corrida
func iniciar_corrida() -> void:
	liberar_controles()


## Inicia a desaceleração automática suave pós-chegada
func iniciar_desaceleracao_automatica(x_alvo: float = 17855.0) -> void:
	if em_desaceleracao_automatica:
		return
	em_desaceleracao_automatica = true
	controles_bloqueados = true
	limite_x_parada = x_alvo

	if player_audio:
		player_audio.parar_motor()
		player_audio.tocar_parando()

	_calcular_taxa_freio_automatico()


func travar_controles() -> void:
	iniciar_desaceleracao_automatica()


func aplicar_efeito_pista(fator: float, duracao: float, _saltos_de_frame: int = 0) -> void:
	max_speed = velocidade_maxima_base * fator
	if temporizador_efeito:
		temporizador_efeito.start(duracao)

	if fator > 1.0:
		velocidade_atual = max_speed
	elif fator < 1.0:
		velocidade_atual *= fator


func _ao_expirar_efeito() -> void:
	max_speed = velocidade_maxima_base


# ==============================================================================
# --- MÉTODOS AUXILIARES, GEOMETRIA E TELEMETRIA ---
# ==============================================================================

## Calcula a inclinação angular e o vetor diretor tangente ao solo
func _calcular_geometria_solo() -> Dictionary:
	var normal_piso: Vector2 = get_floor_normal()
	if normal_piso.length_squared() < 0.01:
		normal_piso = up_direction
	var angulo: float = normal_piso.angle() + (PI / 2.0)
	return {
		"angulo": angulo,
		"direcao": Vector2.RIGHT.rotated(angulo)
	}


## Atualiza os frames de rotação de rodas e animações de movimento no solo
func _atualizar_animacao_movimento() -> void:
	if not animation_player:
		return
	if velocidade_atual > 5.0:
		if animation_player.current_animation != "andar":
			animation_player.play("andar")
		animation_player.speed_scale = clampf(velocidade_atual / max_speed, 0.3, 1.3)
	else:
		if animation_player.current_animation != "parado":
			animation_player.play("parado")
		animation_player.speed_scale = 1.0


## Calcula cinematicamente a desaceleração suave após cruzar a linha de chegada
func _calcular_taxa_freio_automatico() -> void:
	var margem_seguranca: float = 65.0
	var dist_disponivel: float = maxf((limite_x_parada - margem_seguranca) - global_position.x, 20.0)
	if velocidade_atual > 10.0:
		taxa_freio_automatico = clampf((velocidade_atual * velocidade_atual) / (2.0 * dist_disponivel), 100.0, 450.0)
	else:
		taxa_freio_automatico = friction


## Retorna a velocidade escalar real calculada pelo motor de física
func obter_velocidade_real() -> float:
	return get_real_velocity().length()


## Converte a velocidade física para km/h exibida no velocímetro do HUD
func obter_velocidade_kmh() -> float:
	var vel: float = obter_velocidade_real() if not is_zero_approx(velocidade_atual) else 0.0
	return vel * PX_PARA_KMH


func velocity_to_km_h(vel: float) -> float:
	return vel * PX_PARA_KMH


func update_hub_ui() -> void:
	if hub_ui:
		if hub_ui.has_method("set_km_h"):
			hub_ui.set_km_h(obter_velocidade_kmh())
		if hub_ui.has_method("set_quedas"):
			hub_ui.set_quedas(qtd_acidentes)
