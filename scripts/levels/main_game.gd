extends Node2D

## Sinal disparado quando qualquer competidor cruza a linha de chegada
signal corredor_chegou(corredor: Node2D, colocacao: int)

## Sinal disparado quando o jogador colide com o barramento do fim da pista
signal barramento_atingido(corredor: Node2D)

## Vetor dinâmico que armazena os competidores na ordem exata de chegada
var colocacoes: Array[Node2D] = []

## Rastreamento de conclusão do percurso e transição de cena
var bots: Array[Node2D] = []
var bots_concluidos: Array[Node2D] = []
var player_desacelerou: bool = false
var transicao_em_andamento: bool = false

# --- CRONÔMETRO E LIMITES ---
@export_group("Cronômetro & Limites")
@export var tempo_limite: float = 110.0
@export var bonus_tempo_manobra: float = 2.0

@export_group("Efeitos da Pista")
@export var duracao_efeitos_pista: float = 1.5
@export var fator_boost: float = 1.4
@export var fator_slower: float = 0.6
@export var saltos_de_frame_bots: int = 2

var cronometro_ativo: bool = false
var tempo_decorrido: float = 0.0
var tempo_real_decorrido: float = 0.0
var total_tempo_descontado_manobras: float = 0.0
var corrida_ativa_geral: bool = false
var tempo_ultimo_log: float = 0.0
var chegada_registrada_player: bool = false

@onready var player: CharacterBody2D = get_node_or_null("Entities/Player")
@onready var sensor_chegada: Area2D = get_node_or_null("PistaVisual/Chegada/SensorChegada")
@onready var sensor_barramento: Area2D = get_node_or_null("PistaVisual/Barramento/SensorBarramento")
@onready var countdown_ui: CanvasLayer = get_node_or_null("CountdownUI")
@onready var hub_ui: CanvasLayer = get_node_or_null("Entities/Player/Hub")
@onready var temporizador_corrida: Timer = get_node_or_null("RaceTimer")


func _ready() -> void:
	AudioManager.iniciar_estadio_largada()
	if not hub_ui and player:
		hub_ui = player.get_node_or_null("Hub") as CanvasLayer

	colocacoes.clear()
	bots.clear()
	bots_concluidos.clear()
	player_desacelerou = false
	transicao_em_andamento = false
	cronometro_ativo = false
	corrida_ativa_geral = false
	tempo_decorrido = 0.0
	tempo_real_decorrido = 0.0
	total_tempo_descontado_manobras = 0.0
	tempo_ultimo_log = 0.0
	chegada_registrada_player = false

	if hub_ui:
		if hub_ui.has_method("set_temp_atual"):
			hub_ui.set_temp_atual(0.0)
		if hub_ui.has_method("set_temp_limite"):
			hub_ui.set_temp_limite(tempo_limite)

	TempoEsgotado.definir_tempo_limite(tempo_limite)

	if temporizador_corrida:
		temporizador_corrida.one_shot = true
		if not temporizador_corrida.timeout.is_connected(_on_tempo_esgotado):
			temporizador_corrida.timeout.connect(_on_tempo_esgotado)

	_conectar_sensores()
	_conectar_sensores_efeitos()
	_conectar_player()
	_conectar_bots()
	_conectar_countdown()


func _conectar_countdown() -> void:
	if countdown_ui and countdown_ui.has_signal("corrida_iniciada"):
		if not countdown_ui.corrida_iniciada.is_connected(_on_corrida_iniciada):
			countdown_ui.corrida_iniciada.connect(_on_corrida_iniciada)


func _on_corrida_iniciada() -> void:
	AudioManager.elevar_estadio_corrida()
	corrida_ativa_geral = true
	if not cronometro_ativo and not chegada_registrada_player:
		cronometro_ativo = true
		tempo_decorrido = 0.0
		tempo_real_decorrido = 0.0
		total_tempo_descontado_manobras = 0.0
		tempo_ultimo_log = 0.0
		if temporizador_corrida and tempo_limite > 0.0:
			temporizador_corrida.start(tempo_limite)

		if OS.is_debug_build():
			print("==================================================")
			print("🟢 [Cronômetro] CORRIDA INICIADA! Cronômetro iniciado.")
			print("==================================================")


func _process(delta: float) -> void:
	if not cronometro_ativo and not chegada_registrada_player:
		if player and player.velocity.x > 10.0 and not player_desacelerou and not transicao_em_andamento:
			_on_corrida_iniciada()
		return

	if corrida_ativa_geral and not transicao_em_andamento:
		tempo_real_decorrido += delta

	if cronometro_ativo:
		tempo_decorrido += delta
		var tempo_limite_restante: float = maxf(tempo_limite - tempo_decorrido, 0.0)

		if hub_ui:
			if hub_ui.has_method("set_temp_atual"):
				hub_ui.set_temp_atual(tempo_decorrido)
			if hub_ui.has_method("set_temp_limite"):
				hub_ui.set_temp_limite(tempo_limite_restante)

		# Quando o tempo limite reduz até zerar
		if tempo_limite > 0.0 and tempo_limite_restante <= 0.0 and not transicao_em_andamento and not chegada_registrada_player:
			_on_tempo_esgotado()
			return

		if tempo_real_decorrido - tempo_ultimo_log >= 1.0:
			tempo_ultimo_log = tempo_real_decorrido
			var px: float = player.global_position.x if player else 0.0
			var pos_fim_x: float = _obter_posicao_fim_pista()
			var pct: float = clampf((px / pos_fim_x) * 100.0, 0.0, 100.0)
			if OS.is_debug_build():
				print("[Cronômetro] ⏱️ Real: %05.1fs | HUD: %05.1fs | Restante: %05.1fs | X: %5.0f / %.0f px (%4.1f%%)" % [
					tempo_real_decorrido, tempo_decorrido, tempo_limite_restante, px, pos_fim_x, pct
				])


## Callback executado quando o tempo limite do hub zera
func _on_tempo_esgotado() -> void:
	if transicao_em_andamento or chegada_registrada_player:
		return
	transicao_em_andamento = true
	cronometro_ativo = false
	AudioManager.parar_audios_corrida()
	TempoEsgotado.definir_tempo_limite(tempo_limite)
	var tempo_str: String = TempoEsgotado.formatar_tempo(tempo_limite)
	if OS.is_debug_build():
		print("==================================================")
		print("⌛ [MainGame] TEMPO ESGOTADO! O tempo limite zerou (%s)." % tempo_str)
		print("==================================================")
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/ui/tempo_esgotado.tscn")


## Conecta sinais emitidos pelo Player
func _conectar_player() -> void:
	if player:
		if player.has_signal("hospital") and not player.hospital.is_connected(_on_hospital):
			player.hospital.connect(_on_hospital)
		if player.has_signal("desaceleracao_concluida") and not player.desaceleracao_concluida.is_connected(_on_player_desaceleracao_concluida):
			player.desaceleracao_concluida.connect(_on_player_desaceleracao_concluida)
		if player.has_signal("manobra_sucesso") and not player.manobra_sucesso.is_connected(_on_player_manobra_sucesso):
			player.manobra_sucesso.connect(_on_player_manobra_sucesso)


func _on_player_manobra_sucesso(giros: int) -> void:
	var tempo_reduzido: float = bonus_tempo_manobra * giros
	total_tempo_descontado_manobras += tempo_reduzido
	tempo_decorrido = maxf(0.0, tempo_decorrido - tempo_reduzido)
	if OS.is_debug_build():
		print("🤸 [Manobra] Giro 360° x%d! Bônus aplicado: -%.1fs (Total abatido: -%.1fs) | HUD: %.2fs | Tempo Real: %.2fs" % [
			giros, tempo_reduzido, total_tempo_descontado_manobras, tempo_decorrido, tempo_real_decorrido
		])


## Mapeia e conecta os adversários autônomos na pista utilizando Grupos
func _conectar_bots() -> void:
	bots.clear()
	bots_concluidos.clear()

	var lista_bots: Array[Node] = get_tree().get_nodes_in_group("bots")
	if lista_bots.is_empty():
		# Fallback para busca hierárquica caso a cena seja instanciada sem grupos
		var pistas: Node = get_node_or_null("Entities/PistasInimigos")
		if pistas:
			for trilha in pistas.get_children():
				for child in trilha.get_children():
					if child is PathFollow2D:
						lista_bots.append(child)

	for bot_node in lista_bots:
		var bot_2d: Node2D = bot_node as Node2D
		if bot_2d and not bots.has(bot_2d):
			bots.append(bot_2d)
			if bot_2d.has_signal("percurso_concluido") and not bot_2d.percurso_concluido.is_connected(_on_bot_percurso_concluido):
				bot_2d.percurso_concluido.connect(_on_bot_percurso_concluido)


## Callback executado quando um bot conclui seu percurso na trilha
func _on_bot_percurso_concluido(bot: Node2D) -> void:
	if bot and not bots_concluidos.has(bot):
		bots_concluidos.append(bot)
	_verificar_condicao_transicao()


## Callback executado quando o jogador conclui a desaceleração após cruzar a chegada
func _on_player_desaceleracao_concluida() -> void:
	player_desacelerou = true
	_verificar_condicao_transicao()


## Verifica se todos os bots concluíram o percurso da pista
func _todos_bots_concluiram() -> bool:
	if bots.is_empty():
		return true
	for bot in bots:
		if bot.has_method("is_percurso_finalizado"):
			if not bot.is_percurso_finalizado():
				return false
		elif not bots_concluidos.has(bot):
			return false
	return true


## Verifica se as condições da transição foram simultaneamente atendidas:
## 1) Player concluiu a desaceleração
## 2) Todos os bots concluíram o percurso
func _verificar_condicao_transicao() -> void:
	if transicao_em_andamento:
		return
	if not player_desacelerou:
		return
	if not _todos_bots_concluiram():
		return

	transicao_em_andamento = true
	_enviar_dados_para_colocacao()
	AudioManager.parar_audios_corrida()
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/ui/colocacao.tscn")


## Callback executado quando o jogador atinge o limite de acidentes
func _on_hospital() -> void:
	transicao_em_andamento = true
	AudioManager.parar_audios_corrida()
	await get_tree().create_timer(1.4).timeout
	get_tree().change_scene_to_file("res://scenes/ui/hospital.tscn")


## Conecta os sensores de Boost e Slower utilizando Grupos
func _conectar_sensores_efeitos() -> void:
	var sensores_b: Array[Node] = get_tree().get_nodes_in_group("sensores_boost")
	if sensores_b.is_empty():
		sensores_b = get_tree().get_nodes_in_group("boost_sensors")
	for sensor_node in sensores_b:
		var sensor: Area2D = sensor_node as Area2D
		if sensor:
			if not sensor.body_entered.is_connected(_on_sensor_efeito_entered):
				sensor.body_entered.connect(_on_sensor_efeito_entered.bind(fator_boost))
			if not sensor.area_entered.is_connected(_on_sensor_efeito_entered):
				sensor.area_entered.connect(_on_sensor_efeito_entered.bind(fator_boost))

	var sensores_s: Array[Node] = get_tree().get_nodes_in_group("sensores_slower")
	if sensores_s.is_empty():
		sensores_s = get_tree().get_nodes_in_group("slower_sensors")
	for sensor_node in sensores_s:
		var sensor: Area2D = sensor_node as Area2D
		if sensor:
			if not sensor.body_entered.is_connected(_on_sensor_efeito_entered):
				sensor.body_entered.connect(_on_sensor_efeito_entered.bind(fator_slower))
			if not sensor.area_entered.is_connected(_on_sensor_efeito_entered):
				sensor.area_entered.connect(_on_sensor_efeito_entered.bind(fator_slower))


func _on_sensor_efeito_entered(corpo_ou_area: Node, fator: float) -> void:
	var corredor: Node2D = _resolver_corredor(corpo_ou_area)
	if corredor and corredor.has_method("aplicar_efeito_pista"):
		var saltos: int = saltos_de_frame_bots if corredor != player else 0
		corredor.aplicar_efeito_pista(fator, duracao_efeitos_pista, saltos)


## Conecta os sinais de colisão dos sensores principais da pista
func _conectar_sensores() -> void:
	if sensor_chegada:
		if not sensor_chegada.body_entered.is_connected(_on_sensor_chegada_body_entered):
			sensor_chegada.body_entered.connect(_on_sensor_chegada_body_entered)
		if not sensor_chegada.area_entered.is_connected(_on_sensor_chegada_area_entered):
			sensor_chegada.area_entered.connect(_on_sensor_chegada_area_entered)
	else:
		push_warning("[MainGame] SensorChegada não encontrado em PistaVisual/Chegada/SensorChegada.")

	if sensor_barramento:
		if not sensor_barramento.body_entered.is_connected(_on_sensor_barramento_body_entered):
			sensor_barramento.body_entered.connect(_on_sensor_barramento_body_entered)
	else:
		push_warning("[MainGame] SensorBarramento não encontrado em PistaVisual/Barramento/SensorBarramento.")


func _on_sensor_chegada_body_entered(body: Node2D) -> void:
	var corredor: Node2D = _resolver_corredor(body)
	if corredor:
		_registrar_chegada(corredor)


func _on_sensor_chegada_area_entered(area: Area2D) -> void:
	var corredor: Node2D = _resolver_corredor(area)
	if corredor:
		_registrar_chegada(corredor)


func _on_sensor_barramento_body_entered(body: Node2D) -> void:
	if body == null:
		return

	if body is CharacterBody2D or body.name == "Player":
		var pos_filmers_x: float = _obter_posicao_filmers()

		if body.has_method("iniciar_desaceleracao_automatica"):
			body.iniciar_desaceleracao_automatica(pos_filmers_x)
		elif body.has_method("travar_controles"):
			body.travar_controles()

		if not chegada_registrada_player:
			chegada_registrada_player = true
			cronometro_ativo = false
			if OS.is_debug_build():
				print("==================================================")
				print("🛑 [Cronômetro] BARRAMENTO ATINGIDO PELO PLAYER!")
				print("⏱️ TEMPO TOTAL: %.3f s" % tempo_decorrido)
				print("📍 Posição X Final: %.1f px" % body.global_position.x)
				print("==================================================")

		barramento_atingido.emit(body)


## Registra a chegada da entidade de forma única e emite o sinal com a colocação
func _registrar_chegada(corredor: Node2D) -> void:
	if corredor == null:
		return

	# Evita que o mesmo competidor seja computado múltiplas vezes
	if colocacoes.has(corredor):
		return

	colocacoes.append(corredor)
	var colocacao: int = colocacoes.size()

	# Dispara a comemoração da torcida na chegada através do AudioManager
	if not transicao_em_andamento:
		AudioManager.tocar_linha_chegada()

	var nome_corredor: String = corredor.name
	if corredor is CharacterBody2D or corredor.name == "Player":
		nome_corredor = "Player"
		chegada_registrada_player = true
		cronometro_ativo = false
		if OS.is_debug_build():
			print("==================================================")
			print("🏁 [MainGame] %dº LUGAR: PLAYER cruzou a linha de chegada!" % colocacao)
			print("⏱️ TEMPO REAL FÍSICO: %.3f s" % tempo_real_decorrido)
			print("🎮 TEMPO COM BÔNUS DE MANOBRAS: %.3f s (Total abatido por flips: -%.1f s)" % [tempo_decorrido, total_tempo_descontado_manobras])
			print("📍 Posição X Final: %.1f px" % corredor.global_position.x)
			print("==================================================")
	else:
		if OS.is_debug_build():
			print("🏁 [MainGame] %dº LUGAR: %s cruzou a linha de chegada | ⏱️ TEMPO REAL: %.3f s" % [colocacao, nome_corredor, tempo_real_decorrido])

	corredor_chegou.emit(corredor, colocacao)


## Localiza o competidor a partir do corpo ou área disparadora
func _resolver_corredor(origem: Node) -> Node2D:
	if origem == null:
		return null

	if origem is StaticBody2D or origem.name == "FisicaPista":
		return null

	if origem is CharacterBody2D:
		return origem as Node2D

	if origem is Area2D:
		var parent: Node = origem.get_parent()
		if parent:
			if parent.get_parent() is PathFollow2D:
				return parent.get_parent() as Node2D
			if parent is Node2D and (parent.name.begins_with("Enemy") or parent.is_in_group("inimigos")):
				return parent as Node2D

	return null


func _obter_posicao_fim_pista() -> float:
	var marker: Marker2D = get_node_or_null("Markers/MarkerFimPista")
	if marker:
		return marker.global_position.x
	return 17850.0


func _obter_posicao_filmers() -> float:
	var marker: Marker2D = get_node_or_null("Markers/MarkerFilmers")
	if marker:
		return marker.global_position.x

	var filmers_node: Node2D = get_node_or_null("Entities/Filmers")
	if filmers_node:
		var min_x: float = 0.0
		for child in filmers_node.get_children():
			if child is Sprite2D and child.global_position.x > 17700.0:
				if min_x == 0.0 or child.global_position.x < min_x:
					min_x = child.global_position.x
		if min_x > 0.0:
			return min_x
	return 17855.0


func obter_colocacoes() -> Array[Node2D]:
	return colocacoes


## Prepara os dados de classificação e textura dos competidores e envia para a tela de colocação
func _enviar_dados_para_colocacao() -> void:
	var todos_competidores: Array[Node2D] = []
	if player and is_instance_valid(player):
		todos_competidores.append(player)
	for bot in bots:
		if bot and is_instance_valid(bot) and not todos_competidores.has(bot):
			todos_competidores.append(bot)

	for comp in todos_competidores:
		if not colocacoes.has(comp):
			colocacoes.append(comp)

	var dados: Array[Dictionary] = []
	var pos_player: int = 1

	for i in range(colocacoes.size()):
		var c: Node2D = colocacoes[i]
		var eh_player: bool = _is_player_corredor(c)
		if eh_player:
			pos_player = i + 1

		var tex: Texture2D = _extrair_textura_corredor(c)
		var mat: Material = _extrair_material_corredor(c)
		var mod_cor: Color = _extrair_modulate_corredor(c)
		var nome: String = String(c.name) if c else ("Corredor %d" % (i + 1))
		dados.append({
			"is_player": eh_player,
			"texture": tex,
			"material": mat,
			"modulate": mod_cor,
			"name": nome,
			"colocacao": i + 1
		})

	const ColocacaoScript = preload("res://scripts/ui/colocacao.gd")
	ColocacaoScript.definir_resultado(dados, pos_player)


func _is_player_corredor(corredor: Node2D) -> bool:
	if corredor == null:
		return false
	return corredor == player or corredor is CharacterBody2D or corredor.name == "Player"


func _extrair_textura_corredor(corredor: Node2D) -> Texture2D:
	if corredor == null:
		return preload("res://assets/sprites/entites/Racer_1.png")

	if _is_player_corredor(corredor):
		var sp_player: Sprite2D = corredor.get_node_or_null("Sprite2D")
		if sp_player and sp_player.texture:
			return sp_player.texture
		return preload("res://assets/sprites/entites/Player.png")

	if "enemy_texture" in corredor and corredor.enemy_texture != null:
		return corredor.enemy_texture

	var sp_bot: Sprite2D = corredor.find_child("Sprite2D", true, false) as Sprite2D
	if sp_bot and sp_bot.texture:
		return sp_bot.texture

	return preload("res://assets/sprites/entites/Racer_1.png")


func _extrair_material_corredor(corredor: Node2D) -> Material:
	if corredor == null:
		return null
	if "enemy_material" in corredor and corredor.enemy_material != null:
		return corredor.enemy_material
	var sp: Sprite2D = corredor.find_child("Sprite2D", true, false) as Sprite2D
	if sp and sp.material:
		return sp.material
	return null


func _extrair_modulate_corredor(corredor: Node2D) -> Color:
	if corredor == null:
		return Color.WHITE
	if "enemy_modulate" in corredor and corredor.enemy_modulate != Color.WHITE:
		return corredor.enemy_modulate
	var sp: Sprite2D = corredor.find_child("Sprite2D", true, false) as Sprite2D
	if sp:
		return sp.self_modulate
	return Color.WHITE
