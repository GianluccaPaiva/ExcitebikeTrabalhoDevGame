class_name Colocacao
extends CanvasLayer

## Cada item é um Dictionary: { "is_player": bool, "texture": Texture2D, "name": String, "colocacao": int }
static var dados_corrida: Array[Dictionary] = []
static var posicao_player: int = 1

@onready var label_resultado: Label = $Control/Resultado
@onready var sprite_primeiro: Sprite2D = $Control/PrimeiroColocado
@onready var sprite_segundo: Sprite2D = $Control/SegundoColocado
@onready var sprite_terceiro: Sprite2D = $Control/TerceiroColocado
@onready var sprite_quarto: Sprite2D = $Control/QuartoColocado
@onready var btn_restart: Button = $Control/Restart
@onready var btn_menu: Button = $Control/Menu


## Registra os dados da corrida antes de trocar para esta cena
static func definir_resultado(dados: Array[Dictionary], pos_player: int) -> void:
	dados_corrida = dados
	posicao_player = pos_player


func _ready() -> void:
	if btn_restart:
		btn_restart.grab_focus()

	# Se a cena for executada diretamente no editor (F6), usa dados de teste
	if dados_corrida.is_empty():
		_carregar_dados_padrao_teste()

	_atualizar_sprites_podio()
	_atualizar_texto_resultado()


## Atualiza dinamicamente as texturas e frames de cada degrau do pódio
func _atualizar_sprites_podio() -> void:
	var sprites: Array[Sprite2D] = [
		sprite_primeiro,
		sprite_segundo,
		sprite_terceiro,
		sprite_quarto
	]

	for i in range(sprites.size()):
		var sp: Sprite2D = sprites[i]
		if sp == null:
			continue

		if i < dados_corrida.size():
			var info: Dictionary = dados_corrida[i]
			var tex: Texture2D = info.get("texture", null)
			if tex:
				sp.texture = tex

		sp.hframes = 6
		sp.vframes = 6
		sp.frame = 0


## Atualiza a mensagem de colocação do jogador
func _atualizar_texto_resultado() -> void:
	if not label_resultado:
		return

	label_resultado.text = "VOCÊ FICOU EM %dº LUGAR!" % posicao_player

	# Realce visual sutil baseado na posição
	match posicao_player:
		1:
			label_resultado.modulate = Color(1.0, 0.9, 0.2) # Ouro / 1º Lugar
		2:
			label_resultado.modulate = Color(0.85, 0.9, 1.0) # Prata / 2º Lugar
		3:
			label_resultado.modulate = Color(0.95, 0.7, 0.4) # Bronze / 3º Lugar
		_:
			label_resultado.modulate = Color(0.9, 0.4, 0.4) # 4º Lugar


## Gera dados padrão de simulação quando a cena é aberta de forma independente
func _carregar_dados_padrao_teste() -> void:
	dados_corrida = [
		{
			"is_player": true,
			"texture": preload("res://assets/sprites/Player.png"),
			"name": "Player",
			"colocacao": 1
		},
		{
			"is_player": false,
			"texture": preload("res://assets/sprites/Racer_1.png"),
			"name": "Inimigo1",
			"colocacao": 2
		},
		{
			"is_player": false,
			"texture": preload("res://assets/sprites/Racer_2.png"),
			"name": "Inimigo2",
			"colocacao": 3
		},
		{
			"is_player": false,
			"texture": preload("res://assets/sprites/Racer_2.png"),
			"name": "Inimigo3",
			"colocacao": 4
		}
	]
	posicao_player = 1


## Reinicia a corrida recarregando o circuito
func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/main_game.tscn")


## Botão de menu: a ser integrado quando a cena de Menu for desenvolvida
func _on_menu_pressed() -> void:
	# TODO: Implementar a transição para a cena de Menu Principal quando ela for criada no projeto.
	pass


## Mantido por segurança para conexões herdadas
func _on_button_pressed() -> void:
	_on_restart_pressed()
