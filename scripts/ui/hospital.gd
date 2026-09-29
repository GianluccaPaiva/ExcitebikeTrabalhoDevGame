extends Control

## Controlador da Tela de Hospital / Game Over
## Trabalho 1 - DCC148 (UFJF) | Gabriel Lineker & Gianlucca Paiva

@onready var ambulance: Sprite2D = $Ambulance
@onready var btn_restart: Button = $Button

var _vibration_timer: float = 0.0
var _ambulance_base_y: float = 98.0


func _ready() -> void:
	if ambulance:
		_ambulance_base_y = ambulance.position.y
	
	if btn_restart:
		btn_restart.grab_focus()


func _process(delta: float) -> void:
	# Vibração sutil simulando o motor da ambulância em alta velocidade no asfalto
	if ambulance:
		_vibration_timer += delta * 24.0
		ambulance.position.y = _ambulance_base_y + sin(_vibration_timer) * 0.7


func _on_button_pressed() -> void:
	# Reinicia o circuito da corrida
	get_tree().change_scene_to_file("res://scenes/levels/main_game.tscn")
