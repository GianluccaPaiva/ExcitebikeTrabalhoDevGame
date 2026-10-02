extends Control

## Cenário de Derrota por Tempo Esgotado (Timeout / Desqualificação)

@onready var label_titulo: Label = $UI/Header/LabelTitulo
@onready var label_subtitulo: Label = $UI/Header/LabelSubtitulo
@onready var btn_restart: Button = $UI/Botoes/Restart
@onready var btn_menu: Button = $UI/Botoes/Menu
@onready var sounds: Sounds = get_node_or_null("Sounds")
@onready var fumaca_sprite: ColorRect = $Cenario/FumacaMotor
@onready var luz_alerta: PointLight2D = get_node_or_null("Cenario/LuzAlerta")

var _tempo_anim: float = 0.0


func _ready() -> void:
	AudioManager.parar_audios_corrida()
	AudioManager.tocar_game_over()
	get_tree().paused = false

	if btn_restart:
		btn_restart.grab_focus()

	_iniciar_animacao_alerta()


func _process(delta: float) -> void:
	_tempo_anim += delta
	
	# Efeito de fumaça saindo do escapamento
	if fumaca_sprite:
		fumaca_sprite.position.y = 150.0 - fmod(_tempo_anim * 18.0, 14.0)
		fumaca_sprite.modulate.a = maxf(0.0, 0.8 - (fmod(_tempo_anim * 18.0, 14.0) / 14.0))


func _iniciar_animacao_alerta() -> void:
	if label_titulo:
		label_titulo.scale = Vector2(1.3, 1.3)
		var tween: Tween = create_tween()
		tween.tween_property(label_titulo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Reinicia a corrida recarregando a fase
func _on_restart_pressed() -> void:
	btn_restart.disabled = true
	btn_menu.disabled = true
	AudioManager.parar_game_over()
	if sounds and sounds.has_method("choice_select"):
		await sounds.choice_select(0.25)
	get_tree().change_scene_to_file("res://scenes/levels/main_game.tscn")


## Retorna ao Menu Principal
func _on_menu_pressed() -> void:
	btn_restart.disabled = true
	btn_menu.disabled = true
	AudioManager.parar_game_over()
	if sounds and sounds.has_method("choice_select"):
		await sounds.choice_select(0.25)
	get_tree().change_scene_to_file("res://scenes/ui/menu_game.tscn")
