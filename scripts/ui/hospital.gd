extends Control

## Lista de frases bem-humoradas sorteadas aleatoriamente a cada Game Over
const FRASES_GAME_OVER: Array[String] = [
	"FIM DE JOGO!",
	"SE FODEU!",
	"JÁ ERA!",
	"TÁ EM COMA!",
	"MORREU!",
	"FOI DE VASCO!",
	"RIP"
]

@onready var label_status: Label = $Label
@onready var ambulance: Sprite2D = $Ambulance
@onready var btn_restart: Button = $Restart
@onready var btn_menu: Button = $Menu

var _vibration_timer: float = 0.0
var _ambulance_base_y: float = 98.0


func _ready() -> void:
	if ambulance:
		_ambulance_base_y = ambulance.position.y

	if btn_restart:
		btn_restart.grab_focus()

	_sortear_frase()


func _process(delta: float) -> void:
	# Vibração sutil simulando o motor da ambulância em alta velocidade no asfalto
	if ambulance:
		_vibration_timer += delta * 24.0
		ambulance.position.y = _ambulance_base_y + sin(_vibration_timer) * 0.7


## Sorteia uma frase aleatória da lista a cada exibição da tela
func _sortear_frase() -> void:
	if label_status:
		label_status.text = FRASES_GAME_OVER.pick_random()


## Reinicia a corrida recarregando o circuito
func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/main_game.tscn")


## Botão de menu: transiciona para a cena de Menu Principal
func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/menu_game.tscn")


## Mantido por segurança para conexões herdadas
func _on_button_pressed() -> void:
	_on_restart_pressed()
