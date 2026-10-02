extends Node2D

## Sinal disparado quando qualquer competidor cruza a linha de chegada
signal corredor_chegou(corredor: Node2D, colocacao: int)

## Sinal disparado quando o jogador colide com o barramento do fim da pista
signal barramento_atingido(corredor: Node2D)

## Vetor dinâmico que armazena os competidores na exata ordem de chegada (1º, 2º, 3º...)
var colocacoes: Array[Node2D] = []

## Rastreamento de conclusão do percurso e transição de cena
var bots: Array[Node2D] = []
var bots_concluidos: Array[Node2D] = []
var player_desacelerou: bool = false
var transicao_em_andamento: bool = false

## Cronômetro para medição e registro de tempo do percurso
@export_group("Cronômetro & Limites")
## Tempo limite / tempo final da corrida em segundos (110.0s = 01:50:00). Vai reduzindo no _process até zerar.
@export var tempo_limite: float = 110.0
## Porcentagem de chance (0 a 100%) de exibir a cena de referência do Beta quando o tempo esgotar.
@export_range(0.0, 100.0, 1.0, "suffix:%") var chance_referencia_beta: float = 50.0

@export_group("Efeitos da Pista")
## Tempo de duração do efeito de velocidade (em segundos)
@export var duracao_efeitos_pista: float = 1.5
## Fator multiplicador de velocidade no Boost (ex: 1.4 = +40%)
@export var fator_boost: float = 1.4
## Fator multiplicador de velocidade no Slower (ex: 0.6 = -40%)
@export var fator_slower: float = 0.6

var cronometro_ativo: bool = false
var tempo_decorrido: float = 0.0
var _tempo_ultimo_log: float = 0.0
var _chegada_registrada_player: bool = false

@onready var player: CharacterBody2D = get_node_or_null("Entities/Player")
@onready var sensor_chegada: Area2D = get_node_or_null("PistaVisual/Chegada/SensorChegada")
@onready var sensor_barramento: Area2D = get_node_or_null("PistaVisual/Barramento/SensorBarramento")
@onready var countdown_ui: CanvasLayer = get_node_or_null("CountdownUI")
@onready var hub_ui: CanvasLayer = get_node_or_null("Entities/Player/Hub")

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
	tempo_decorrido = 0.0
	_tempo_ultimo_log = 0.0
	_chegada_registrada_player = false
	if hub_ui:
		if hub_ui.has_method("set_temp_atual"):
			hub_ui.set_temp_atual(0.0)
		if hub_ui.has_method("set_temp_limite"):
			hub_ui.set_temp_limite(tempo_limite)
	TempoEsgotado.definir_tempo_limite(tempo_limite)
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
	if not cronometro_ativo and not _chegada_registrada_player:
		cronometro_ativo = true
		tempo_decorrido = 0.0
		_tempo_ultimo_log = 0.0
		print("==================================================")
		print("🟢 [Cronômetro] CORRIDA INICIADA! Cronômetro iniciado.")
		print("==================================================")


func _process(delta: float) -> void:
	if not cronometro_ativo and not _chegada_registrada_player:
		if player and player.velocity.x > 10.0 and not player_desacelerou and not transicao_em_andamento:
			_on_corrida_iniciada()
		return

	if cronometro_ativo:
		tempo_decorrido += delta
		var tempo_limite_restante: float = maxf(tempo_limite - tempo_decorrido, 0.0)

		if hub_ui:
			if hub_ui.has_method("set_temp_atual"):
				hub_ui.set_temp_atual(tempo_decorrido)
			if hub_ui.has_method("set_temp_limite"):
				hub_ui.set_temp_limite(tempo_limite_restante)

		# Quando o tempo limite reduz até zerar
		if tempo_limite > 0.0 and tempo_limite_restante <= 0.0 and not transicao_em_andamento and not _chegada_registrada_player:
			_on_tempo_esgotado()
			return

		if tempo_decorrido - _tempo_ultimo_log >= 1.0:
			_tempo_ultimo_log = tempo_decorrido
			var px: float = player.global_position.x if player else 0.0
			var pct: float = clampf((px / 17850.0) * 100.0, 0.0, 100.0)
			print("[Cronômetro] ⏱️ %05.1fs | Restante: %05.1fs | X: %5.0f / 17850 px (%4.1f%%)" % [tempo_decorrido, tempo_limite_restante, px, pct])


## Callback executado quando o tempo limite do hub zera (1:50)
func _on_tempo_esgotado() -> void:
	if transicao_em_andamento or _chegada_registrada_player:
		return
	transicao_em_andamento = true
	cronometro_ativo = false
	AudioManager.parar_audios_corrida()
	TempoEsgotado.definir_tempo_limite(tempo_limite)
	var tempo_str: String = TempoEsgotado.formatar_tempo(tempo_limite)
	print("==================================================")
	print("⌛ [MainGame] TEMPO ESGOTADO! O tempo limite zerou (%s)." % tempo_str)
	print("==================================================")
	await get_tree().create_timer(1.2).timeout

	var sorteio: float = randf_range(0.0, 100.0)
	if sorteio < chance_referencia_beta:
		print("🎭 [MainGame] Referência Beta ativada (sorteio: %.1f%% / chance: %.1f%%)" % [sorteio, chance_referencia_beta])
		get_tree().change_scene_to_file("res://scenes/referencia/beta.tscn")
	else:
		print("🛑 [MainGame] Indo direto para Tempo Esgotado (sorteio: %.1f%% / chance: %.1f%%)" % [sorteio, chance_referencia_beta])
		get_tree().change_scene_to_file("res://scenes/ui/tempo_esgotado.tscn")


## Conecta sinais emitidos pelo Player
func _conectar_player() -> void:
	if player:
		if player.has_signal("hospital") and not player.hospital.is_connected(_on_hospital):
			player.hospital.connect(_on_hospital)
		if player.has_signal("desaceleracao_concluida") and not player.desaceleracao_concluida.is_connected(_on_player_desaceleracao_concluida):
			player.desaceleracao_concluida.connect(_on_player_desaceleracao_concluida)


## Mapeia e conecta os adversários autônomos na pista
func _conectar_bots() -> void:
	bots.clear()
	bots_concluidos.clear()
	var pistas: Node = get_node_or_null("Entities/PistasInimigos")
	if pistas:
		for trilha in pistas.get_children():
			for child in trilha.get_children():
				if child is PathFollow2D:
					var bot_node: Node2D = child as Node2D
					bots.append(bot_node)
					if bot_node.has_signal("percurso_concluido"):
						if not bot_node.percurso_concluido.is_connected(_on_bot_percurso_concluido):
							bot_node.percurso_concluido.connect(_on_bot_percurso_concluido)


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


func _conectar_sensores_efeitos() -> void:
	var pista = get_node_or_null("PistaVisual")
	if not pista: return
	
	for node in pista.get_children():
		if node.name.begins_with("Boost"):
			var sensor = node.get_node_or_null("SensorBoost")
			if sensor:
				if not sensor.body_entered.is_connected(_on_sensor_efeito_entered):
					sensor.body_entered.connect(_on_sensor_efeito_entered.bind(fator_boost))
				if not sensor.area_entered.is_connected(_on_sensor_efeito_entered):
					sensor.area_entered.connect(_on_sensor_efeito_entered.bind(fator_boost))
		
		elif node.name.begins_with("Slower"):
			var sensor = node.get_node_or_null("SensorSlower")
			if sensor:
				if not sensor.body_entered.is_connected(_on_sensor_efeito_entered):
					sensor.body_entered.connect(_on_sensor_efeito_entered.bind(fator_slower))
				if not sensor.area_entered.is_connected(_on_sensor_efeito_entered):
					sensor.area_entered.connect(_on_sensor_efeito_entered.bind(fator_slower))

func _on_sensor_efeito_entered(corpo_ou_area: Node, fator: float) -> void:
	var corredor = _resolver_corredor(corpo_ou_area)
	if corredor and corredor.has_method("aplicar_efeito_pista"):
		corredor.aplicar_efeito_pista(fator, duracao_efeitos_pista)


## Conecta os sinais de colisão dos sensores da pista
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


## Callback disparado quando um corpo físico (ex: Player) entra no sensor
func _on_sensor_chegada_body_entered(body: Node2D) -> void:
	var corredor: Node2D = _resolver_corredor(body)
	if corredor:
		_registrar_chegada(corredor)


## Callback disparado quando uma área (ex: Inimigo com Area2D) entra no sensor
func _on_sensor_chegada_area_entered(area: Area2D) -> void:
	var corredor: Node2D = _resolver_corredor(area)
	if corredor:
		_registrar_chegada(corredor)


## Callback disparado quando o jogador colide com o barramento do fim da pista
func _on_sensor_barramento_body_entered(body: Node2D) -> void:
	if body == null:
		return

	if body is CharacterBody2D or body.name == "Player":
		var pos_filmers_x: float = 0.0
		var filmers_node: Node2D = get_node_or_null("Entities/Filmers")
		if filmers_node:
			for child in filmers_node.get_children():
				if child is Sprite2D and child.global_position.x > 17700.0:
					if pos_filmers_x == 0.0 or child.global_position.x < pos_filmers_x:
						pos_filmers_x = child.global_position.x
		if pos_filmers_x == 0.0:
			pos_filmers_x = 17855.0

		if body.has_method("iniciar_desaceleracao_automatica"):
			body.iniciar_desaceleracao_automatica(pos_filmers_x)
		elif body.has_method("travar_controles"):
			body.travar_controles()

		if not _chegada_registrada_player:
			_chegada_registrada_player = true
			cronometro_ativo = false
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

	# Dispara a comemoração da torcida na chegada através do AudioManager (cooldown embutido)
	if not transicao_em_andamento:
		AudioManager.tocar_linha_chegada()

	print("[MainGame] 🏁 %dº LUGAR: %s cruzou a linha de chegada!" % [colocacao, corredor.name])
	if corredor is CharacterBody2D or corredor.name == "Player":
		_chegada_registrada_player = true
		cronometro_ativo = false
		print("==================================================")
		print("🏁 [Cronômetro] CHEGADA! O Player cruzou a linha de chegada!")
		print("⏱️ TEMPO TOTAL DO PERCURSO: %.3f s (%.2f segundos)" % [tempo_decorrido, tempo_decorrido])
		print("📍 Posição X Final: %.1f px" % corredor.global_position.x)
		print("==================================================")
	corredor_chegou.emit(corredor, colocacao)


## Identifica o nó raiz representativo do competidor (Player ou Seguidor/Inimigo)
func _resolver_corredor(origem: Node) -> Node2D:
	if origem == null:
		return null

	# Ignora explicitamente corpos estáticos de cenário (como FisicaPista)
	if origem is StaticBody2D or origem.name == "FisicaPista":
		return null

	# Caso 1: O próprio nó é o CharacterBody2D (Player)
	if origem is CharacterBody2D:
		return origem as Node2D

	# Caso 2: Origem é uma Area2D (ex: nó filho do Enemy nos PathFollow2D)
	if origem is Area2D:
		var parent: Node = origem.get_parent()
		if parent:
			# Se o pai está dentro de um PathFollow2D, o competidor é o seguidor da trilha
			if parent.get_parent() is PathFollow2D:
				return parent.get_parent() as Node2D
			# Se for a entidade Enemy isolada
			if parent is Node2D and (parent.name.begins_with("Enemy") or parent.is_in_group("inimigos")):
				return parent as Node2D

	return null


## Retorna a lista atual de colocações
func obter_colocacoes() -> Array[Node2D]:
	return colocacoes


## Prepara os dados de classificação e textura dos competidores e envia para a tela de colocação
func _enviar_dados_para_colocacao() -> void:
	# Coleta todos os competidores existentes na corrida (Player + Bots)
	var todos_competidores: Array[Node2D] = []
	if player and is_instance_valid(player):
		todos_competidores.append(player)
	for bot in bots:
		if bot and is_instance_valid(bot) and not todos_competidores.has(bot):
			todos_competidores.append(bot)

	# Assegura que competidores que porventura não cruzaram o sensor fiquem no fim da fila
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


## Verifica se o nó representa o jogador
func _is_player_corredor(corredor: Node2D) -> bool:
	if corredor == null:
		return false
	return corredor == player or corredor is CharacterBody2D or corredor.name == "Player"


## Extrai a textura representativa do competidor para exibição no pódio
func _extrair_textura_corredor(corredor: Node2D) -> Texture2D:
	if corredor == null:
		return preload("res://assets/sprites/entites/Racer_1.png")

	# Se for o Player
	if _is_player_corredor(corredor):
		var sp_player: Sprite2D = corredor.get_node_or_null("Sprite2D")
		if sp_player and sp_player.texture:
			return sp_player.texture
		return preload("res://assets/sprites/entites/Player.png")

	# Se for um Seguidor/Bot com enemy_texture exportada
	if "enemy_texture" in corredor and corredor.enemy_texture != null:
		return corredor.enemy_texture

	# Busca Sprite2D interno no bot
	var sp_bot: Sprite2D = corredor.find_child("Sprite2D", true, false) as Sprite2D
	if sp_bot and sp_bot.texture:
		return sp_bot.texture

	return preload("res://assets/sprites/entites/Racer_1.png")


## Extrai o material visual do competidor (caso utilize shader de palette swap)
func _extrair_material_corredor(corredor: Node2D) -> Material:
	if corredor == null:
		return null
	if "enemy_material" in corredor and corredor.enemy_material != null:
		return corredor.enemy_material
	var sp: Sprite2D = corredor.find_child("Sprite2D", true, false) as Sprite2D
	if sp and sp.material:
		return sp.material
	return null


## Extrai a cor de modulação do competidor
func _extrair_modulate_corredor(corredor: Node2D) -> Color:
	if corredor == null:
		return Color.WHITE
	if "enemy_modulate" in corredor and corredor.enemy_modulate != Color.WHITE:
		return corredor.enemy_modulate
	var sp: Sprite2D = corredor.find_child("Sprite2D", true, false) as Sprite2D
	if sp:
		return sp.self_modulate
	return Color.WHITE
