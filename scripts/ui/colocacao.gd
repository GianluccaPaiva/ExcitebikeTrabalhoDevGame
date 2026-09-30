class_name Colocacao
extends CanvasLayer

## Controlador da Tela de Pódio e Colocação
## Trabalho 1 - DCC148 (UFJF) | Gabriel Lineker & Gianlucca Paiva

## Armazena os dados dos competidores e o resultado da última corrida
## Cada item é um Dictionary: { "is_player": bool, "texture": Texture2D, "name": String, "colocacao": int }
static var dados_corrida: Array[Dictionary] = []
static var posicao_player: int = 1

## Configurações das medalhas no pódio: recorte exato no medals.png (152x216) e cor temática
const CONFIG_MEDALHAS: Dictionary = {
	1: { "regiao": Rect2(128, 36, 152, 216), "cor": Color(1.0, 0.9, 0.2) },   # Ouro / 1º Lugar
	2: { "regiao": Rect2(352, 36, 152, 216), "cor": Color(0.85, 0.9, 1.0) },  # Prata / 2º Lugar
	3: { "regiao": Rect2(580, 36, 152, 216), "cor": Color(0.95, 0.7, 0.4) }   # Bronze / 3º Lugar
}

@onready var header_resultado: HBoxContainer = $Control/HeaderResultado
@onready var label_prefixo: Label = $Control/HeaderResultado/LabelPrefixo
@onready var icone_medalha: TextureRect = $Control/HeaderResultado/IconeMedalha
@onready var label_sufixo: Label = $Control/HeaderResultado/LabelSufixo

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
	_atualizar_resultado_e_medalha()


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


## Atualiza a mensagem e a medalha integrada ao texto (Opção A)
func _atualizar_resultado_e_medalha() -> void:
	if not header_resultado:
		return

	if CONFIG_MEDALHAS.has(posicao_player):
		_configurar_estado_podio(CONFIG_MEDALHAS[posicao_player])
	else:
		_configurar_estado_fora_podio()


## Define o estado visual padronizado para as posições no pódio (1º, 2º e 3º com medalha)
func _configurar_estado_podio(config: Dictionary) -> void:
	label_prefixo.text = "VOCÊ FICOU EM"
	label_prefixo.visible = true
	label_sufixo.text = "LUGAR!"
	label_sufixo.visible = true
	icone_medalha.visible = true
	icone_medalha.texture = _obter_atlas_medalha(config.regiao)
	header_resultado.modulate = config.cor
	_animar_medalha()


## Define o estado para quem ficou fora do pódio (4º colocado, frase completa sem medalha)
func _configurar_estado_fora_podio() -> void:
	label_prefixo.text = "VOCÊ FICOU EM %dº LUGAR!" % posicao_player
	label_prefixo.visible = true
	label_sufixo.visible = false
	icone_medalha.visible = false
	header_resultado.modulate = Color(0.9, 0.4, 0.4)


## Cria um AtlasTexture fatiando precisamente a medalha solicitada
func _obter_atlas_medalha(regiao: Rect2) -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = preload("res://assets/ui/medals.png")
	atlas.region = regiao
	return atlas


## Animação pop-in da medalha ao carregar a tela
func _animar_medalha() -> void:
	if not icone_medalha:
		return
	icone_medalha.pivot_offset = Vector2(8.0, 10.0)
	icone_medalha.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(icone_medalha, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


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
