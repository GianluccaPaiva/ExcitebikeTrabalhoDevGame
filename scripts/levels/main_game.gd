extends Node2D

## Controlador Principal da Pista / Nível
## Trabalho 1 - DCC148 (UFJF) | Gabriel Lineker & Gianlucca Paiva
## Responsável pelo gerenciamento da corrida, detecção de chegada e classificação.

## Sinal disparado quando qualquer competidor cruza a linha de chegada
signal corredor_chegou(corredor: Node2D, colocacao: int)

## Vetor dinâmico que armazena os competidores na exata ordem de chegada (1º, 2º, 3º...)
var colocacoes: Array[Node2D] = []

@onready var sensor_chegada: Area2D = get_node_or_null("PistaVisual/Chegada/SensorChegada")


func _ready() -> void:
	colocacoes.clear()
	_conectar_sensor_chegada()


## Conecta os sinais de colisão do sensor de chegada de forma segura
func _conectar_sensor_chegada() -> void:
	if not sensor_chegada:
		push_warning("[MainGame] SensorChegada não encontrado em PistaVisual/Chegada/SensorChegada.")
		return

	if not sensor_chegada.body_entered.is_connected(_on_sensor_chegada_body_entered):
		sensor_chegada.body_entered.connect(_on_sensor_chegada_body_entered)

	if not sensor_chegada.area_entered.is_connected(_on_sensor_chegada_area_entered):
		sensor_chegada.area_entered.connect(_on_sensor_chegada_area_entered)


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


## Registra a chegada da entidade de forma única e emite o sinal com a colocação
func _registrar_chegada(corredor: Node2D) -> void:
	if corredor == null:
		return

	# Evita que o mesmo competidor seja computado múltiplas vezes
	if colocacoes.has(corredor):
		return

	colocacoes.append(corredor)
	var colocacao: int = colocacoes.size()

	print("[MainGame] 🏁 %dº LUGAR: %s cruzou a linha de chegada!" % [colocacao, corredor.name])
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
