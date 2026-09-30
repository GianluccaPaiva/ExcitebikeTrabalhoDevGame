extends CanvasLayer

@export var pausar_ao_iniciar: bool = false

@onready var sounds: Sounds = $Sounds
@onready var control: Control = $Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Se a cena for executada diretamente no editor (F6) ou pausar_ao_iniciar for true, abre pausada para teste.
	# Quando instanciada no jogo (main_game), inicia oculta para a corrida começar normalmente.
	if get_tree().current_scene == self or pausar_ao_iniciar:
		pausar()
	else:
		despausar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_on_continue_pressed()
		else:
			pausar()


func pausar() -> void:
	visible = true
	get_tree().paused = true


func despausar() -> void:
	get_tree().paused = false
	visible = false


func _on_continue_pressed() -> void:
	if sounds:
		await sounds.choice_select(0.25)
	despausar()


func _on_restart_pressed() -> void:
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/levels/main_game.tscn")


func _on_menu_pressed() -> void:
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/menu_game.tscn")
