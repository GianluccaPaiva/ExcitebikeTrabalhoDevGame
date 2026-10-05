extends Control

## Cena de Referência / Consultório: Easter Egg do Hospital
## Exibe diálogo temático dos médicos com o jogador acidentado.

@onready var balao_doc: PanelContainer = $UI/BalaoDoc
@onready var label_doc: Label = $UI/BalaoDoc/Margin/LabelDoc
@onready var balao_tigreso: PanelContainer = $UI/BalaoTigreso
@onready var label_tigreso: Label = $UI/BalaoTigreso/Margin/LabelTigreso
@onready var btn_restart: Button = get_node_or_null("UI/Botoes/Restart")
@onready var btn_menu: Button = get_node_or_null("UI/Botoes/Menu")
@onready var doc_girl: Sprite2D = $Cenario/DocGirl
@onready var tigreso: Sprite2D = $Cenario/AbsoluteTigreso
@onready var player_sprite: Sprite2D = $Cenario/Maca/PlayerAcidentado
@onready var sounds: Sounds = get_node_or_null("Sounds")
@onready var falcao: Sprite2D = $Cenario/Quadro/Falcao

@export var lista_png_falcao: Array[Texture2D] = []

var tempo_anim: float = 0.0
var doc_base_y: float = 0.0
var tigreso_base_y: float = 0.0
var player_base_pos: Vector2 = Vector2.ZERO
var player_base_rot: float = 0.0


func _aleatoriza_falcao() -> void:
	if falcao and lista_png_falcao.size() > 0:
		falcao.texture = lista_png_falcao.pick_random()


func _ready() -> void:
	if doc_girl:
		doc_base_y = doc_girl.position.y
	if tigreso:
		tigreso_base_y = tigreso.position.y
	if player_sprite:
		player_base_pos = player_sprite.position
		player_base_rot = player_sprite.rotation_degrees

	AudioManager.parar_audios_corrida()

	if balao_doc:
		balao_doc.scale = Vector2.ONE
		balao_doc.modulate.a = 0.0
	if balao_tigreso:
		balao_tigreso.scale = Vector2.ONE
		balao_tigreso.modulate.a = 0.0

	if btn_restart:
		btn_restart.grab_focus()

	_aleatoriza_falcao()
	_executar_dialogo()


func _process(delta: float) -> void:
	tempo_anim += delta
	# Respiração sutil dos médicos
	if doc_girl:
		doc_girl.position.y = doc_base_y + sin(tempo_anim * 2.5) * 1.0
	if tigreso:
		tigreso.position.y = tigreso_base_y + cos(tempo_anim * 2.0) * 0.8
	# Tremedeira leve do paciente preservando a posição exata
	if player_sprite:
		player_sprite.position.x = player_base_pos.x + (randf() - 0.5) * 0.5
		player_sprite.position.y = player_base_pos.y


func _executar_dialogo() -> void:
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return

	# Fala da Doc Girl
	if balao_doc:
		balao_doc.scale = Vector2.ONE
		var tween_doc: Tween = create_tween()
		tween_doc.tween_property(balao_doc, "modulate:a", 1.0, 0.2)

	await get_tree().create_timer(1.8).timeout
	if not is_inside_tree():
		return

	# Resposta do Absolute Tigreso
	if balao_tigreso:
		balao_tigreso.scale = Vector2.ONE
		var tween_tigreso: Tween = create_tween()
		tween_tigreso.tween_property(balao_tigreso, "modulate:a", 1.0, 0.2)

	# Efeito de tremor dramático no paciente
	if player_sprite:
		var tween_p: Tween = create_tween()
		tween_p.tween_property(player_sprite, "rotation_degrees", player_base_rot + 4.0, 0.08)
		tween_p.tween_property(player_sprite, "rotation_degrees", player_base_rot - 4.0, 0.08)
		tween_p.tween_property(player_sprite, "rotation_degrees", player_base_rot, 0.08)


## Botão Reiniciar: recarrega a fase principal
func _on_restart_pressed() -> void:
	_transicionar_para("res://scenes/levels/main_game.tscn")


## Botão Menu: retorna ao menu principal
func _on_menu_pressed() -> void:
	_transicionar_para("res://scenes/ui/menu_game.tscn")


func _transicionar_para(caminho_cena: String) -> void:
	if btn_restart:
		btn_restart.disabled = true
	if btn_menu:
		btn_menu.disabled = true
	if sounds and sounds.has_method("choice_select"):
		await sounds.choice_select(0.25)
	get_tree().change_scene_to_file(caminho_cena)
