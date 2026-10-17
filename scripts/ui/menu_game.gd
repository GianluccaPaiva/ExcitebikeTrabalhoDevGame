class_name MenuGame
extends Control

# --- REFERENCIAS A NODES ---
@onready var btn_jogar: Button = $UI/BotoesContainer/Jogar
@onready var btn_sair: Button = $UI/BotoesContainer/Sair
@onready var animation_player: AnimationPlayer = $ShowcasePlayer/AnimationPlayer
@onready var sounds: Sounds = $Sounds

# --- INICIALIZACAO ---
func _ready() -> void:
	AudioManager.parar_todos()
	if btn_jogar:
		btn_jogar.grab_focus()

	if animation_player and animation_player.has_animation("showcase_manobras"):
		animation_player.play("showcase_manobras")

# --- BOTOES DO MENU ---
func _on_jogar_pressed() -> void:
	btn_jogar.disabled = true
	btn_sair.disabled = true
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().change_scene_to_file("res://scenes/levels/main_game.tscn")


func _on_sair_pressed() -> void:
	btn_jogar.disabled = true
	btn_sair.disabled = true
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().quit()
