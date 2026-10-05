extends Node

## Gerenciador global de áudio (Singleton / Autoload)
## Centraliza a reprodução de trilhas, ambientes e efeitos sonoros globais (one-shots),
## utilizando barramentos nativos de áudio (Audio Buses) para controle limpo e eficiente de pausa.

const STREAM_ESTADIO: AudioStream = preload("res://assets/sounds/somEstadio.mp3")
const STREAM_LINHA_CHEGADA: AudioStream = preload("res://assets/sounds/somLinhaChegada.mp3")
const STREAM_PODIO: AudioStream = preload("res://assets/sounds/podio.mp3")
const STREAM_4_LUGAR: AudioStream = preload("res://assets/sounds/som4lugar.mp3")
const STREAM_GAME_OVER: AudioStream = preload("res://assets/sounds/somGameOver.mp3")
const STREAM_AMBULANCIA: AudioStream = preload("res://assets/sounds/Ambulance.mp3")
const STREAM_TORCIDA_QUEDA: AudioStream = preload("res://assets/sounds/somTorcidaQueda.wav")
const STREAM_VAIA: AudioStream = preload("res://assets/sounds/somVaia.mp3")

# Nós de reprodução dedicados
var player_estadio: AudioStreamPlayer
var player_linha_chegada: AudioStreamPlayer
var player_podio: AudioStreamPlayer
var player_4_lugar: AudioStreamPlayer
var player_game_over: AudioStreamPlayer
var player_ambulancia: AudioStreamPlayer
var player_torcida_queda: AudioStreamPlayer
var player_vaia: AudioStreamPlayer

var tween_ducking: Tween = null
var estadio_ativo: bool = false
var vaia_ativa: bool = false
var audio_pausado: bool = false
var arvore_estava_pausada: bool = false

# Lista de todos os reprodutores nativos para operações em lote
var todos_players: Array[AudioStreamPlayer] = []

# Controle de cooldown do som da linha de chegada
var ultimo_tempo_chegada_ms: int = -999999
const COOLDOWN_CHEGADA_MS: int = 1500


func _ready() -> void:
	# Garante que o AudioManager receba notificações de pausa mesmo com a árvore pausada
	process_mode = Node.PROCESS_MODE_ALWAYS
	arvore_estava_pausada = get_tree().paused
	audio_pausado = arvore_estava_pausada

	player_estadio = _criar_player("AudioEstadio", STREAM_ESTADIO, -8.0, "Ambiente")
	player_linha_chegada = _criar_player("AudioLinhaChegada", STREAM_LINHA_CHEGADA, -4.0, "SFX")
	player_podio = _criar_player("AudioPodio", STREAM_PODIO, -4.0, "Music")
	player_4_lugar = _criar_player("Audio4Lugar", STREAM_4_LUGAR, -4.0, "Music")
	player_game_over = _criar_player("AudioGameOver", STREAM_GAME_OVER, -2.0, "Music")
	player_ambulancia = _criar_player("AudioAmbulancia", STREAM_AMBULANCIA, -4.0, "Ambiente")
	player_torcida_queda = _criar_player("AudioTorcidaQueda", STREAM_TORCIDA_QUEDA, -3.5, "Ambiente")

	player_vaia = _criar_player("AudioVaia", STREAM_VAIA, -5.0, "UI")
	player_vaia.finished.connect(func() -> void:
		if is_instance_valid(player_vaia) and vaia_ativa and not audio_pausado:
			player_vaia.play()
	)


func _criar_player(nome: String, stream: AudioStream, vol_db: float, nome_barramento: String = "Master") -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = nome
	p.stream = stream
	p.volume_db = vol_db
	p.bus = nome_barramento
	add_child(p)
	todos_players.append(p)
	return p


func _process(_delta: float) -> void:
	var arvore_pausada: bool = get_tree().paused
	if arvore_pausada != audio_pausado:
		pausar_audio_jogo(arvore_pausada)


## Pausa ou despausa os barramentos de jogo (SFX e Ambiente) durante a pausa,
## permitindo que os sons de interface (UI) continuem funcionando normalmente
func pausar_audio_jogo(pausar: bool) -> void:
	if pausar == audio_pausado:
		return
	audio_pausado = pausar
	arvore_estava_pausada = pausar

	var idx_sfx: int = AudioServer.get_bus_index("SFX")
	var idx_amb: int = AudioServer.get_bus_index("Ambiente")
	if idx_sfx >= 0:
		AudioServer.set_bus_mute(idx_sfx, pausar)
	if idx_amb >= 0:
		AudioServer.set_bus_mute(idx_amb, pausar)

	# Pausa fluxos dos reprodutores nativos do gerenciador
	for p in todos_players:
		if is_instance_valid(p):
			p.stream_paused = pausar

	if not pausar and estadio_ativo and is_instance_valid(player_estadio):
		if not player_estadio.playing:
			player_estadio.play()
		if not (tween_ducking and tween_ducking.is_valid()):
			player_estadio.volume_db = -8.0


# --- MÉTODOS DE CONTROLE DE ÁUDIO DO ESTÁDIO / CORRIDA ---

func tocar_estadio() -> void:
	estadio_ativo = true
	if is_instance_valid(player_estadio):
		player_estadio.volume_db = -8.0
		player_estadio.stream_paused = false
		if not player_estadio.playing:
			player_estadio.play()


## Inicia a torcida no grid de largada em volume atenuado (-16 dB) para não abafar o countdown
func iniciar_estadio_largada() -> void:
	parar_vaia()
	estadio_ativo = true
	if is_instance_valid(player_estadio):
		player_estadio.volume_db = -16.0
		player_estadio.stream_paused = false
		if not player_estadio.playing:
			player_estadio.play()


## Eleva o estádio para o volume habitual de corrida (-8 dB) ao sinal de largada (VAI!)
func elevar_estadio_corrida() -> void:
	estadio_ativo = true
	if is_instance_valid(player_estadio):
		if not player_estadio.playing:
			player_estadio.play()
		player_estadio.stream_paused = false
		if tween_ducking and tween_ducking.is_valid():
			tween_ducking.kill()
		tween_ducking = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		tween_ducking.tween_property(player_estadio, "volume_db", -8.0, 0.6)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)


func parar_estadio() -> void:
	estadio_ativo = false
	if tween_ducking and tween_ducking.is_valid():
		tween_ducking.kill()
	if is_instance_valid(player_estadio):
		player_estadio.volume_db = -8.0
		if player_estadio.playing:
			player_estadio.stop()
	parar_torcida_queda()
	parar_linha_chegada()


## Interrompe todos os sons relacionados ao percurso e torcida da corrida
func parar_audios_corrida() -> void:
	parar_estadio()
	parar_torcida_queda()
	parar_linha_chegada()
	parar_vaia()


func tocar_torcida_queda() -> void:
	# Micro-atraso de reação da torcida (110ms) para que o impacto da queda no chão
	# soe com total presença e clareza no primeiro plano antes do susto do público
	await get_tree().create_timer(0.11, false).timeout
	_executar_torcida_queda()


func _executar_torcida_queda() -> void:
	if is_instance_valid(player_torcida_queda):
		player_torcida_queda.stop()
		_tocar(player_torcida_queda)
		if audio_pausado:
			player_torcida_queda.stream_paused = true

	# Ducking dinâmico: atenua momentaneamente o fundo do estádio para dar destaque à reação
	if is_instance_valid(player_estadio) and estadio_ativo:
		_tocar(player_estadio)
		if not audio_pausado and player_estadio.stream_paused:
			player_estadio.stream_paused = false

		if tween_ducking and tween_ducking.is_valid():
			tween_ducking.kill()
		tween_ducking = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		tween_ducking.tween_property(player_estadio, "volume_db", -14.0, 0.12)
		tween_ducking.tween_property(player_estadio, "volume_db", -8.0, 1.4).set_delay(0.35)


func parar_torcida_queda() -> void:
	_parar(player_torcida_queda)


func tocar_linha_chegada() -> void:
	var tempo_atual_ms: int = Time.get_ticks_msec()
	if (tempo_atual_ms - ultimo_tempo_chegada_ms) >= COOLDOWN_CHEGADA_MS:
		ultimo_tempo_chegada_ms = tempo_atual_ms
		if is_instance_valid(player_linha_chegada):
			player_linha_chegada.stop()
			player_linha_chegada.play()


func parar_linha_chegada() -> void:
	_parar(player_linha_chegada)


# --- MÉTODOS DE CONTROLE DA TELA DE COLOCAÇÃO / PÓDIO ---

func tocar_podio() -> void:
	parar_audios_corrida()
	parar_audios_colocacao()
	_tocar(player_podio)


func tocar_quarto_lugar() -> void:
	parar_audios_corrida()
	parar_audios_colocacao()
	_tocar(player_4_lugar)


func parar_audios_colocacao() -> void:
	_parar(player_podio)
	_parar(player_4_lugar)


# --- MÉTODOS DE CONTROLE DA TELA DE HOSPITAL / GAME OVER ---

func tocar_game_over() -> void:
	_tocar(player_game_over)


func parar_game_over() -> void:
	_parar(player_game_over)


func tocar_ambulancia() -> void:
	_tocar(player_ambulancia)


func parar_ambulancia() -> void:
	_parar(player_ambulancia)


# --- MÉTODOS DE CONTROLE DA TELA DE TEMPO ESGOTADO / VAIA ---

func tocar_vaia() -> void:
	parar_audios_corrida()
	vaia_ativa = true
	if is_instance_valid(player_vaia) and not player_vaia.playing:
		player_vaia.play()


func parar_vaia() -> void:
	vaia_ativa = false
	if is_instance_valid(player_vaia) and player_vaia.playing:
		player_vaia.stop()


# --- PARADA GERAL E MÉTODOS AUXILIARES ---

func parar_todos() -> void:
	estadio_ativo = false
	vaia_ativa = false
	for p in todos_players:
		if is_instance_valid(p) and p.playing:
			p.stop()


func _tocar(p: AudioStreamPlayer) -> void:
	if is_instance_valid(p) and not p.playing:
		p.play()


func _parar(p: AudioStreamPlayer) -> void:
	if is_instance_valid(p) and p.playing:
		p.stop()
