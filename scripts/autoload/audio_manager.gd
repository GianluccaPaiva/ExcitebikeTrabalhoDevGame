extends Node

## Gerenciador global de áudio (Singleton / Autoload)
## Centraliza a reprodução de trilhas, ambientes e efeitos sonoros globais (one-shots),
## incluindo controle automático e centralizado de pausa (stream_paused).

const STREAM_ESTADIO: AudioStream = preload("res://assets/sounds/somEstadio.mp3")
const STREAM_LINHA_CHEGADA: AudioStream = preload("res://assets/sounds/somLinhaChegada.mp3")
const STREAM_PODIO: AudioStream = preload("res://assets/sounds/podio.mp3")
const STREAM_4_LUGAR: AudioStream = preload("res://assets/sounds/som4lugar.mp3")
const STREAM_GAME_OVER: AudioStream = preload("res://assets/sounds/somGameOver.mp3")
const STREAM_AMBULANCIA: AudioStream = preload("res://assets/sounds/Ambulance.mp3")
const STREAM_TORCIDA_QUEDA: AudioStream = preload("res://assets/sounds/somTorcidaQueda.wav")

# Nós de reprodução dedicados
var _player_estadio: AudioStreamPlayer
var _player_linha_chegada: AudioStreamPlayer
var _player_podio: AudioStreamPlayer
var _player_4_lugar: AudioStreamPlayer
var _player_game_over: AudioStreamPlayer
var _player_ambulancia: AudioStreamPlayer
var _player_torcida_queda: AudioStreamPlayer

var _tween_ducking: Tween = null

# Lista de todos os reprodutores para operações em lote (ex: pausa)
var _todos_players: Array[AudioStreamPlayer] = []

# Controle de cooldown do som da linha de chegada
var _ultimo_tempo_chegada_ms: int = -999999
const COOLDOWN_CHEGADA_MS: int = 1500


func _ready() -> void:
	# Garante que o AudioManager receba notificações de pausa mesmo com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player_estadio = _criar_player("AudioEstadio", STREAM_ESTADIO, -8.0)
	_player_linha_chegada = _criar_player("AudioLinhaChegada", STREAM_LINHA_CHEGADA, -4.0)
	_player_podio = _criar_player("AudioPodio", STREAM_PODIO, -4.0)
	_player_4_lugar = _criar_player("Audio4Lugar", STREAM_4_LUGAR, -4.0)
	_player_game_over = _criar_player("AudioGameOver", STREAM_GAME_OVER, -2.0)
	_player_ambulancia = _criar_player("AudioAmbulancia", STREAM_AMBULANCIA, -4.0)
	_player_torcida_queda = _criar_player("AudioTorcidaQueda", STREAM_TORCIDA_QUEDA, -1.5)


func _criar_player(nome: String, stream: AudioStream, vol_db: float) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = nome
	p.stream = stream
	p.volume_db = vol_db
	add_child(p)
	_todos_players.append(p)
	return p


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		for p in _todos_players:
			if is_instance_valid(p) and p.playing:
				p.stream_paused = true
	elif what == NOTIFICATION_UNPAUSED:
		for p in _todos_players:
			if is_instance_valid(p) and p.stream_paused:
				p.stream_paused = false


# --- MÉTODOS DE CONTROLE DE ÁUDIO DO ESTÁDIO / CORRIDA ---

func tocar_estadio() -> void:
	if is_instance_valid(_player_estadio):
		_player_estadio.volume_db = -8.0
		if not _player_estadio.playing:
			_player_estadio.play()


func parar_estadio() -> void:
	if _tween_ducking and _tween_ducking.is_valid():
		_tween_ducking.kill()
	if is_instance_valid(_player_estadio):
		_player_estadio.volume_db = -8.0
		if _player_estadio.playing:
			_player_estadio.stop()
	parar_torcida_queda()


func tocar_torcida_queda() -> void:
	if is_instance_valid(_player_torcida_queda):
		_player_torcida_queda.stop()
		_player_torcida_queda.play()

	# Ducking dinâmico: atenua momentaneamente o fundo do estádio para dar destaque à reação
	if is_instance_valid(_player_estadio) and _player_estadio.playing:
		if _tween_ducking and _tween_ducking.is_valid():
			_tween_ducking.kill()
		_tween_ducking = create_tween()
		_tween_ducking.tween_property(_player_estadio, "volume_db", -14.0, 0.12)
		_tween_ducking.tween_property(_player_estadio, "volume_db", -8.0, 1.4).set_delay(0.35)


func parar_torcida_queda() -> void:
	if is_instance_valid(_player_torcida_queda) and _player_torcida_queda.playing:
		_player_torcida_queda.stop()


func tocar_linha_chegada() -> void:
	var tempo_atual_ms: int = Time.get_ticks_msec()
	if (tempo_atual_ms - _ultimo_tempo_chegada_ms) >= COOLDOWN_CHEGADA_MS:
		_ultimo_tempo_chegada_ms = tempo_atual_ms
		if is_instance_valid(_player_linha_chegada):
			_player_linha_chegada.stop()
			_player_linha_chegada.play()


# --- MÉTODOS DE CONTROLE DA TELA DE COLOCAÇÃO / PÓDIO ---

func tocar_podio() -> void:
	parar_audios_colocacao()
	if is_instance_valid(_player_podio):
		_player_podio.play()


func tocar_quarto_lugar() -> void:
	parar_audios_colocacao()
	if is_instance_valid(_player_4_lugar):
		_player_4_lugar.play()


func parar_audios_colocacao() -> void:
	if is_instance_valid(_player_podio) and _player_podio.playing:
		_player_podio.stop()
	if is_instance_valid(_player_4_lugar) and _player_4_lugar.playing:
		_player_4_lugar.stop()


# --- MÉTODOS DE CONTROLE DA TELA DE HOSPITAL / GAME OVER ---

func tocar_game_over() -> void:
	if is_instance_valid(_player_game_over) and not _player_game_over.playing:
		_player_game_over.play()


func parar_game_over() -> void:
	if is_instance_valid(_player_game_over) and _player_game_over.playing:
		_player_game_over.stop()


func tocar_ambulancia() -> void:
	if is_instance_valid(_player_ambulancia) and not _player_ambulancia.playing:
		_player_ambulancia.play()


func parar_ambulancia() -> void:
	if is_instance_valid(_player_ambulancia) and _player_ambulancia.playing:
		_player_ambulancia.stop()


# --- PARADA GERAL ---

func parar_todos() -> void:
	for p in _todos_players:
		if is_instance_valid(p) and p.playing:
			p.stop()
