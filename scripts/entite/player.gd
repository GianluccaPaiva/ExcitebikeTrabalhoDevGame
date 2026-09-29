extends CharacterBody2D

enum State {
	NO_CHAO,
	NO_AR,
	ACIDENTE
}
signal hospital 
signal desaceleracao_concluida

# --- CONFIGURAÇÕES DE FÍSICA E MOVIMENTO (Ajustáveis no Inspetor) ---
@export_group("Movimento no Solo")
@export var max_speed: float = 260.0
@export var acceleration: float = 200.0
@export var friction: float = 100.0
@export var brake_force: float = 320.0

@export_group("Física Aérea, Flips e Manobras Vetoriais")
@export var gravity: float = 580.0
@export var max_fall_speed: float = 480.0
@export var air_rotation_speed: float = 6.28 # ~360 graus/s: permite flips completos em saltos
@export var air_maneuver_influence: float = 1.8 # Intensidade com que a atitude da moto redireciona o vetor no ar
@export var air_thrust: float = 100.0 # Impulso vetorial ao acelerar na direção em que a moto aponta

@export_group("Pouso e Acidente")
@export var max_safe_angle_degrees: float = 32.0 # Tolerância máxima de desalinhamento (pouso perfeito pós-flip)
@export var crash_duration: float = 1.6 # Tempo bloqueado após queda
@export var limite_acidentes_hospital: int = 3 # Quantidade de acidentes para ir ao hospital

# --- REFERÊNCIAS DE NÓS ---
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var moto_caida_sprite: Sprite2D = $MotoCaidaSprite
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# --- VARIÁVEIS DE ESTADO E VELOCIDADE ESCALAR ---
@export var controles_bloqueados: bool = true
var state: State = State.NO_CHAO
var was_on_floor: bool = true
var crash_timer: float = 0.0
var current_speed: float = 0.0 # Magnitude da velocidade ao longo da pista
var em_desaceleracao_automatica: bool = false
var limite_x_parada: float = 0.0
var taxa_freio_automatico: float = 350.0
var qtd_acidentes: int = 0


func _ready() -> void:
	# Permite que rampas de até 60 graus sejam tratadas perfeitamente como piso
	floor_max_angle = deg_to_rad(60.0)
	floor_snap_length = 8.0
	
	if moto_caida_sprite:
		moto_caida_sprite.visible = false
	if animation_player:
		animation_player.play("parado")


func _physics_process(delta: float) -> void:
	# Enquanto a contagem regressiva estiver rodando, mantém o player perfeitamente estático no grid
	if controles_bloqueados and not em_desaceleracao_automatica:
		velocity = Vector2.ZERO
		current_speed = 0.0
		if animation_player and animation_player.current_animation != "parado":
			animation_player.play("parado")
		return

	match state:
		State.NO_CHAO:
			_process_chao(delta)
		State.NO_AR:
			_process_ar(delta)
		State.ACIDENTE:
			_process_acidente(delta)

	move_and_slide()

	_check_floor_transitions()


# --- ESTADO: NO CHÃO (DESLOCAMENTO VETORIAL ALINHADO AO RELEVO) ---
func _process_chao(delta: float) -> void:
	var floor_normal: Vector2 = get_floor_normal()
	# Se a normal for nula no primeiro frame, assume chão plano
	if floor_normal.length_squared() < 0.01:
		floor_normal = Vector2.UP

	# Calcula o ângulo e o vetor tangente unitário da superfície da pista
	var ground_angle: float = floor_normal.angle() + (PI / 2.0)
	var ground_dir: Vector2 = Vector2.RIGHT.rotated(ground_angle)
	
	# Alinha visualmente e fisicamente a moto com o ângulo do relevo
	rotation = ground_angle

	# Aceleração, freio e atrito na magnitude da velocidade
	if em_desaceleracao_automatica:
		current_speed = move_toward(current_speed, 0.0, taxa_freio_automatico * delta)
		if limite_x_parada > 0.0 and global_position.x >= (limite_x_parada - 18.0):
			current_speed = move_toward(current_speed, 0.0, brake_force * delta)
		if current_speed <= 1.0:
			current_speed = 0.0
			velocity = Vector2.ZERO
			em_desaceleracao_automatica = false
			controles_bloqueados = true
			if animation_player:
				animation_player.play("parado")
				animation_player.speed_scale = 1.0
			desaceleracao_concluida.emit()
			return
	elif controles_bloqueados:
		current_speed = move_toward(current_speed, 0.0, friction * delta)
	elif Input.is_action_pressed("acelerar"):
		current_speed = move_toward(current_speed, max_speed, acceleration * delta)
	elif Input.is_action_pressed("frear"):
		current_speed = move_toward(current_speed, 0.0, brake_force * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, friction * delta)

	# DESLOCAMENTO VETORIAL: A velocidade segue integralmente a tangente da rampa/chão
	# Isso garante que ao subir a rampa a moto tenha vetor Y negativo real (subida),
	# de modo que ao atingir a crista seja lançada em um arco balístico real!
	velocity = ground_dir * current_speed

	# Leve componente de atração ao solo para manter contato em irregularidades sutis
	if not is_on_floor():
		velocity.y += gravity * delta

	# Animações de solo
	if animation_player:
		if current_speed > 5.0:
			if animation_player.current_animation != "andar":
				animation_player.play("andar")
			animation_player.speed_scale = clampf(current_speed / max_speed, 0.4, 1.3)
		else:
			if animation_player.current_animation != "parado":
				animation_player.play("parado")
			animation_player.speed_scale = 1.0


# --- ESTADO: NO AR (MANOBRAS, FLIPS E ROTAÇÃO) ---
func _process_ar(delta: float) -> void:
	# 1. Aplicação contínua da gravidade no eixo Y
	velocity.y += gravity * delta
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed

	# 2. INPUT DE VELOCIDADE: ESTRITAMENTE DESABILITADO NO AR
	# No ar, a moto segue o momento/inércia balística adquirida na rampa.
	# Inputs como 'acelerar' e 'frear' não têm efeito de tração em voo.
	if em_desaceleracao_automatica:
		velocity.x = move_toward(velocity.x, 0.0, (taxa_freio_automatico * 0.5) * delta)
		current_speed = move_toward(current_speed, 0.0, (taxa_freio_automatico * 0.5) * delta)

	# 3. INPUT DE ROTAÇÃO: HABILITADO PARA CONTROLE DO ÂNGULO NO SALTO (W / S)
	var rot_input: float = 0.0
	if not em_desaceleracao_automatica:
		if Input.is_action_pressed("inclinar_tras"):
			# W: inclina para trás / sobe o nariz da moto (Backflip)
			rot_input -= 1.0
		if Input.is_action_pressed("inclinar_frente"):
			# S: inclina para frente / desce o nariz da moto (Frontflip)
			rot_input += 1.0

	# Aplica a rotação angular via transformação física (rotation)
	rotation += rot_input * air_rotation_speed * delta

	# Pausa a animação de corrida das rodas no ar
	if animation_player and animation_player.is_playing() and animation_player.current_animation != "RESET":
		animation_player.pause()


# --- ESTADO: ACIDENTE (CRASH) ---
func _process_acidente(delta: float) -> void:
	crash_timer -= delta
	current_speed = 0.0
	velocity.x = 0.0

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	if crash_timer <= 0.0:
		_recuperar_de_acidente()


# --- DETECÇÃO DE TRANSIÇÕES CHÃO / AR ---
func _check_floor_transitions() -> void:
	var on_floor_now: bool = is_on_floor()

	# Transição AR -> CHÃO (Frame exato do impacto/aterrissagem)
	if not was_on_floor and on_floor_now and state == State.NO_AR:
		_processar_aterrissagem()
	# Transição CHÃO -> AR (Saiu da rampa ou quebra-mola)
	elif was_on_floor and not on_floor_now and state == State.NO_CHAO:
		state = State.NO_AR

	was_on_floor = on_floor_now


# --- LÓGICA MATEMÁTICA DE POUSO (COMPATÍVEL COM FLIPS DE 360°) ---
func _processar_aterrissagem() -> void:
	var floor_normal: Vector2 = get_floor_normal()
	if floor_normal.length_squared() < 0.01:
		floor_normal = Vector2.UP

	var ground_angle: float = floor_normal.angle() + (PI / 2.0)
	var ground_dir: Vector2 = Vector2.RIGHT.rotated(ground_angle)

	# angle_difference calcula a menor distância angular (módulo 2*PI)
	# Se o jogador executou 1, 2 ou mais flips (360°, 720°) e alinhou a moto, o diff será mínimo!
	var diff: float = absf(angle_difference(rotation, ground_angle))
	var safe_limit: float = deg_to_rad(max_safe_angle_degrees)

	if diff <= safe_limit:
		# POUSO SEGURO / FLIP BEM SUCEDIDO:
		state = State.NO_CHAO
		rotation = ground_angle
		# Preserva a projeção da velocidade aérea ao longo da pista (conservação vetorial de momento)
		var projected_speed: float = velocity.dot(ground_dir)
		if controles_bloqueados and not em_desaceleracao_automatica:
			current_speed = 0.0
		else:
			current_speed = clampf(projected_speed, 0.0, max_speed * 1.1)
		
		# Se aterrissou já em desaceleração automática, recalcula a taxa para parar suavemente no alvo restante
		if em_desaceleracao_automatica:
			var dist_restante: float = maxf((limite_x_parada - 24.0) - global_position.x, 16.0)
			if current_speed > 10.0:
				taxa_freio_automatico = (current_speed * current_speed) / (2.0 * dist_restante)
				taxa_freio_automatico = clampf(taxa_freio_automatico, 100.0, 500.0)
		
		if animation_player:
			if controles_bloqueados and not em_desaceleracao_automatica:
				animation_player.play("parado")
			else:
				if current_speed > 5.0:
					animation_player.play("andar")
					animation_player.speed_scale = clampf(current_speed / max_speed, 0.3, 1.3)
				else:
					animation_player.play("parado")
					animation_player.speed_scale = 1.0
	else:
		# ACIDENTE: Aterrissou de cabeça para baixo ou desalinhado
		qtd_acidentes += 1
		_disparar_acidente()
		if qtd_acidentes >= limite_acidentes_hospital:
			hospital.emit()


# --- GATILHOS DE ACIDENTE E RECUPERAÇÃO ---
func _disparar_acidente() -> void:
	state = State.ACIDENTE
	current_speed = 0.0
	velocity = Vector2.ZERO
	rotation = 0.0
	crash_timer = crash_duration

	if animation_player:
		animation_player.play("acidente")
		animation_player.speed_scale = 1.0


func _recuperar_de_acidente() -> void:
	state = State.NO_CHAO
	rotation = 0.0
	current_speed = 0.0
	velocity = Vector2.ZERO

	if moto_caida_sprite:
		moto_caida_sprite.visible = false
	if sprite_2d:
		sprite_2d.frame = 0
	if animation_player:
		animation_player.play("parado")
		animation_player.speed_scale = 1.0


## Chamado pelo CountdownUI ao exibir "VAI!" para iniciar a corrida
func liberar_controles() -> void:
	controles_bloqueados = false


## Inicia a desaceleração automática e gradual após cruzar o barramento
func iniciar_desaceleracao_automatica(x_alvo: float = 1986.0) -> void:
	if em_desaceleracao_automatica:
		return
	em_desaceleracao_automatica = true
	controles_bloqueados = true
	limite_x_parada = x_alvo

	# Distância disponível até os filmers (com margem de 24px da frente da moto para folga estética)
	var margem_seguranca: float = 24.0
	var dist_disponivel: float = maxf((limite_x_parada - margem_seguranca) - global_position.x, 16.0)

	# Torricelli: calcula a desaceleração exata para parar suavemente antes dos filmers
	if current_speed > 10.0:
		taxa_freio_automatico = (current_speed * current_speed) / (2.0 * dist_disponivel)
		taxa_freio_automatico = clampf(taxa_freio_automatico, 100.0, 500.0)
	else:
		taxa_freio_automatico = friction


## Chamado ao atingir o fim da pista / barramento (aciona a desaceleração gradual)
func travar_controles() -> void:
	iniciar_desaceleracao_automatica()
