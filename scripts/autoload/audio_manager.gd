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
var _estadio_ativo: bool = false
var _audio_pausado: bool = false
var _arvore_estava_pausada: bool = false

# Lista de todos os reprodutores nativos para operações em lote
var _todos_players: Array[AudioStreamPlayer] = []
var _players_pausados: Array[AudioStreamPlayer] = []
var _players2d_pausados: Array[AudioStreamPlayer2D] = []

# Controle de cooldown do som da linha de chegada
var _ultimo_tempo_chegada_ms: int = -999999
const COOLDOWN_CHEGADA_MS: int = 1500


func _ready() -> void:
	# Garante que o AudioManager receba notificações de pausa mesmo com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arvore_estava_pausada = get_tree().paused
	_audio_pausado = _arvore_estava_pausada

	_player_estadio = _criar_player("AudioEstadio", STREAM_ESTADIO, -8.0)
	_player_linha_chegada = _criar_player("AudioLinhaChegada", STREAM_LINHA_CHEGADA, -4.0)
	_player_podio = _criar_player("AudioPodio", STREAM_PODIO, -4.0)
	_player_4_lugar = _criar_player("Audio4Lugar", STREAM_4_LUGAR, -4.0)
	_player_game_over = _criar_player("AudioGameOver", STREAM_GAME_OVER, -2.0)
	_player_ambulancia = _criar_player("AudioAmbulancia", STREAM_AMBULANCIA, -4.0)
	_player_torcida_queda = _criar_player("AudioTorcidaQueda", STREAM_TORCIDA_QUEDA, -3.5)


func _criar_player(nome: String, stream: AudioStream, vol_db: float) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = nome
	p.stream = stream
	p.volume_db = vol_db
	add_child(p)
	_todos_players.append(p)
	return p


func _process(_delta: float) -> void:
	var arvore_pausada: bool = get_tree().paused
	if arvore_pausada != _audio_pausado:
		pausar_audio_jogo(arvore_pausada)


## Pausa ou despausa todos os reprodutores de áudio do jogo (moto, estádio, contagem, etc.) durante o Pause
func pausar_audio_jogo(pausar: bool) -> void:
	if pausar == _audio_pausado:
		return
	_audio_pausado = pausar
	_arvore_estava_pausada = pausar

	if pausar:
		_players_pausados.clear()
		_players2d_pausados.clear()

		# Pausa reprodutores nativos do AudioManager que estejam em execução
		for p in _todos_players:
			if is_instance_valid(p) and p.playing and not p.stream_paused:
				p.stream_paused = true
				if not _players_pausados.has(p):
					_players_pausados.append(p)

		# Coleta e congela demais nós de áudio pela árvore (ex: PlayerAudio, CountdownUI, etc.)
		var root: Window = get_tree().root
		if is_instance_valid(root):
			_coletar_e_pausar(root)
	else:
		# Descongela nós coletados
		for p in _players_pausados:
			if is_instance_valid(p) and p.stream_paused:
				p.stream_paused = false
		_players_pausados.clear()

		for p2 in _players2d_pausados:
			if is_instance_valid(p2) and p2.stream_paused:
				p2.stream_paused = false
		_players2d_pausados.clear()

		# Garantia explícita para os reprodutores nativos do AudioManager
		for p in _todos_players:
			if is_instance_valid(p) and p.stream_paused:
				p.stream_paused = false

		# Blindagem do som contínuo do estádio se ele estiver ativo durante a corrida
		if _estadio_ativo and is_instance_valid(_player_estadio):
			_player_estadio.stream_paused = false
			if not _player_estadio.playing:
				_player_estadio.play()
			if not (_tween_ducking and _tween_ducking.is_valid()):
				_player_estadio.volume_db = -8.0


func _coletar_e_pausar(no: Node) -> void:
	if not is_instance_valid(no):
		return

	# Não pausa sons pertencentes ao menu de Pause para que feedback de botões continue audível
	if no.name == "Pause" or (no.get_parent() and no.get_parent().name == "Pause"):
		return

	if no is AudioStreamPlayer:
		var p: AudioStreamPlayer = no as AudioStreamPlayer
		if p.playing and not p.stream_paused:
			p.stream_paused = true
			if not _players_pausados.has(p):
				_players_pausados.append(p)
	elif no is AudioStreamPlayer2D:
		var p2: AudioStreamPlayer2D = no as AudioStreamPlayer2D
		if p2.playing and not p2.stream_paused:
			p2.stream_paused = true
			if not _players2d_pausados.has(p2):
				_players2d_pausados.append(p2)

	for filho in no.get_children():
		_coletar_e_pausar(filho)



# --- MÉTODOS DE CONTROLE DE ÁUDIO DO ESTÁDIO / CORRIDA ---

func tocar_estadio() -> void:
	_estadio_ativo = true
	if is_instance_valid(_player_estadio):
		_player_estadio.volume_db = -8.0
		_player_estadio.stream_paused = false
		if not _player_estadio.playing:
			_player_estadio.play()


## Inicia a torcida no grid de largada em volume atenuado (-16 dB) para não abafar o countdown
func iniciar_estadio_largada() -> void:
	_estadio_ativo = true
	if is_instance_valid(_player_estadio):
		_player_estadio.volume_db = -16.0
		_player_estadio.stream_paused = false
		if not _player_estadio.playing:
			_player_estadio.play()


## Eleva o estádio para o volume habitual de corrida (-8 dB) ao sinal de largada (VAI!)
func elevar_estadio_corrida() -> void:
	_estadio_ativo = true
	if is_instance_valid(_player_estadio):
		if not _player_estadio.playing:
			_player_estadio.play()
		_player_estadio.stream_paused = false
		if _tween_ducking and _tween_ducking.is_valid():
			_tween_ducking.kill()
		_tween_ducking = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		_tween_ducking.tween_property(_player_estadio, "volume_db", -8.0, 0.6)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)


func parar_estadio() -> void:
	_estadio_ativo = false
	if _tween_ducking and _tween_ducking.is_valid():
		_tween_ducking.kill()
	if is_instance_valid(_player_estadio):
		_player_estadio.volume_db = -8.0
		if _player_estadio.playing:
			_player_estadio.stop()
	parar_torcida_queda()
	parar_linha_chegada()


## Interrompe todos os sons relacionados ao percurso e torcida da corrida
func parar_audios_corrida() -> void:
	parar_estadio()
	parar_torcida_queda()
	parar_linha_chegada()


func tocar_torcida_queda() -> void:
	# Micro-atraso de reação da torcida (110ms) para que o impacto da queda no chão
	# soe com total presença e clareza no primeiro plano antes do susto do público
	get_tree().create_timer(0.11, false).timeout.connect(func() -> void:
		if is_instance_valid(_player_torcida_queda):
			_player_torcida_queda.stop()
			_player_torcida_queda.play()
			if _audio_pausado:
				_player_torcida_queda.stream_paused = true

		# Ducking dinâmico: atenua momentaneamente o fundo do estádio para dar destaque à reação
		if is_instance_valid(_player_estadio) and _estadio_ativo:
			if not _player_estadio.playing:
				_player_estadio.play()
			if not _audio_pausado and _player_estadio.stream_paused:
				_player_estadio.stream_paused = false

			if _tween_ducking and _tween_ducking.is_valid():
				_tween_ducking.kill()
			_tween_ducking = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
			_tween_ducking.tween_property(_player_estadio, "volume_db", -14.0, 0.12)
			_tween_ducking.tween_property(_player_estadio, "volume_db", -8.0, 1.4).set_delay(0.35)
	, CONNECT_ONE_SHOT)


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


func parar_linha_chegada() -> void:
	if is_instance_valid(_player_linha_chegada) and _player_linha_chegada.playing:
		_player_linha_chegada.stop()


# --- MÉTODOS DE CONTROLE DA TELA DE COLOCAÇÃO / PÓDIO ---

func tocar_podio() -> void:
	parar_audios_corrida()
	parar_audios_colocacao()
	if is_instance_valid(_player_podio):
		_player_podio.play()


func tocar_quarto_lugar() -> void:
	parar_audios_corrida()
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
