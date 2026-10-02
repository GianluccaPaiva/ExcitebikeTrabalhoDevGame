extends Node2D

## Componente de áudio exclusivo do Player
## Encapsula os reprodutores de som da moto (motor, parada, quedas e morte)
## e isola todo o cálculo de pitch, decibéis e pausa local.

@export var volume_moto_db: float = -6.0
@export var volume_parando_db: float = -4.0
@export var volume_queda_db: float = 2.5
@export var volume_morte_db: float = 2.0

@onready var audio_moto: AudioStreamPlayer = get_node_or_null("AudioMoto")
@onready var audio_moto_parando: AudioStreamPlayer = get_node_or_null("AudioMotoParando")
@onready var audio_queda: AudioStreamPlayer = get_node_or_null("AudioQueda")
@onready var audio_morte: AudioStreamPlayer = get_node_or_null("AudioMorte")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if audio_moto:
		audio_moto.volume_db = volume_moto_db
	if audio_moto_parando:
		audio_moto_parando.volume_db = volume_parando_db
	if audio_queda:
		audio_queda.volume_db = volume_queda_db
	if audio_morte:
		audio_morte.volume_db = volume_morte_db


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_pausar_streams(true)
	elif what == NOTIFICATION_UNPAUSED:
		_pausar_streams(false)


func _pausar_streams(pausar: bool) -> void:
	var lista: Array[AudioStreamPlayer] = [audio_moto, audio_moto_parando, audio_queda, audio_morte]
	for a in lista:
		if is_instance_valid(a):
			if pausar and a.playing:
				a.stream_paused = true
			elif not pausar and a.stream_paused:
				a.stream_paused = false


## Atualiza o motor contínuo e a modulação de pitch de acordo com a velocidade do player
func atualizar_motor(acelerando: bool, current_speed: float, max_speed: float, impedido: bool) -> void:
	if not audio_moto:
		return

	if impedido:
		parar_motor()
		return

	var em_movimento: bool = current_speed > 10.0
	if not (acelerando or em_movimento):
		parar_motor()
		return

	# Modula dinamicamente o pitch do motor pela velocidade
	var fator_vel: float = clampf(current_speed / max_speed, 0.0, 1.0)
	audio_moto.pitch_scale = lerpf(0.85, 1.35, fator_vel)

	if not audio_moto.playing:
		audio_moto.volume_db = volume_moto_db
		audio_moto.play()


## Interrompe o som contínuo do motor
func parar_motor() -> void:
	if audio_moto and audio_moto.playing:
		audio_moto.stop()


## Dispara o som de derrapagem / desaceleração da moto
func tocar_parando() -> void:
	if audio_moto_parando and not audio_moto_parando.playing:
		audio_moto_parando.play()


## Interrompe o som de desaceleração
func parar_parando() -> void:
	if audio_moto_parando and audio_moto_parando.playing:
		audio_moto_parando.stop()


## Dispara o som de queda padrão (1ª e 2ª quedas)
func tocar_queda() -> void:
	if audio_queda:
		audio_queda.stop()
		audio_queda.play()


## Dispara o som de morte (3ª queda / hospital)
func tocar_morte() -> void:
	if audio_morte:
		audio_morte.stop()
		audio_morte.play()


## Interrompe todos os sons da moto
func parar_tudo() -> void:
	parar_motor()
	parar_parando()
	if audio_queda and audio_queda.playing:
		audio_queda.stop()
	if audio_morte and audio_morte.playing:
		audio_morte.stop()
