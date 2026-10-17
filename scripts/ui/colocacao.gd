class_name Colocacao
extends CanvasLayer

# --- CONSTANTES DE EXIBICAO ---
const CONFIG_MEDALHAS: Dictionary = {
	1: { "regiao": Rect2(128, 36, 152, 216), "cor": Color(1.0, 0.9, 0.2) },
	2: { "regiao": Rect2(352, 36, 152, 216), "cor": Color(0.85, 0.9, 1.0) },
	3: { "regiao": Rect2(580, 36, 152, 216), "cor": Color(0.95, 0.7, 0.4) }
}

# --- ESTADO DA TELA ---
static var dados_corrida: Array[Dictionary] = []
static var posicao_player: int = 1

# --- REFERENCIAS A NODES ---
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
@onready var sounds: Sounds = $Control/Sounds


# --- DADOS DA CORRIDA ---
static func definir_resultado(dados: Array[Dictionary], pos_player: int) -> void:
	dados_corrida = dados
	posicao_player = pos_player


func _carregar_dados_padrao_teste() -> void:
	dados_corrida = [
		{
			"is_player": true,
			"texture": preload("res://assets/sprites/entites/Player.png"),
			"name": "Player",
			"colocacao": 1
		},
		{
			"is_player": false,
			"texture": preload("res://assets/sprites/entites/Racer_1.png"),
			"name": "Inimigo1",
			"colocacao": 2
		},
		{
			"is_player": false,
			"texture": preload("res://assets/sprites/entites/Racer_2.png"),
			"name": "Inimigo2",
			"colocacao": 3
		},
		{
			"is_player": false,
			"texture": preload("res://assets/sprites/entites/Racer_2.png"),
			"material": preload("res://assets/shaders/racer_yellow.tres"),
			"name": "Inimigo3",
			"colocacao": 4
		}
	]
	posicao_player = 1


# --- INICIALIZACAO ---
func _ready() -> void:
	if dados_corrida.is_empty():
		_carregar_dados_padrao_teste()

	get_tree().paused = false
	AudioManager.parar_audios_corrida()
	_atualizar_sprites_podio()
	_atualizar_resultado_e_medalha()
	_tocar_som_resultado()


# --- EXIBICAO DO PODIO ---
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
			sp.material = info.get("material", null)
			sp.self_modulate = info.get("modulate", Color.WHITE)

		sp.hframes = 6
		sp.vframes = 6
		sp.frame = 0


# --- RESULTADO E MEDALHA DO PLAYER ---
func _atualizar_resultado_e_medalha() -> void:
	if not header_resultado:
		return

	if CONFIG_MEDALHAS.has(posicao_player):
		_configurar_estado_podio(CONFIG_MEDALHAS[posicao_player])
	else:
		_configurar_estado_fora_podio()


func _configurar_estado_podio(config: Dictionary) -> void:
	label_prefixo.text = "VOCÊ FICOU EM"
	label_prefixo.visible = true
	label_sufixo.text = "LUGAR!"
	label_sufixo.visible = true
	icone_medalha.visible = true
	icone_medalha.texture = _obter_atlas_medalha(config.regiao)
	header_resultado.modulate = config.cor
	_animar_medalha()


func _configurar_estado_fora_podio() -> void:
	label_prefixo.text = "VOCÊ FICOU EM %dº LUGAR!" % posicao_player
	label_prefixo.visible = true
	label_sufixo.visible = false
	icone_medalha.visible = false
	header_resultado.modulate = Color(0.9, 0.4, 0.4)


func _obter_atlas_medalha(regiao: Rect2) -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = preload("res://assets/ui/medals.png")
	atlas.region = regiao
	return atlas


func _animar_medalha() -> void:
	if not icone_medalha:
		return
	icone_medalha.pivot_offset = Vector2(8.0, 10.0)
	icone_medalha.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(icone_medalha, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


# --- SOM DA TELA DE COLOCACAO ---
func _tocar_som_resultado() -> void:
	if posicao_player <= 3:
		AudioManager.tocar_podio()
	else:
		AudioManager.tocar_quarto_lugar()


func _parar_sons() -> void:
	AudioManager.parar_audios_colocacao()


# --- NAVEGACAO E BOTOES ---
func _on_restart_pressed() -> void:
	_transicionar_para("res://scenes/levels/main_game.tscn")


func _on_menu_pressed() -> void:
	_transicionar_para("res://scenes/ui/menu_game.tscn")


func _transicionar_para(caminho_cena: String) -> void:
	if btn_restart:
		btn_restart.disabled = true
	if btn_menu:
		btn_menu.disabled = true
	_parar_sons()
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().change_scene_to_file(caminho_cena)
