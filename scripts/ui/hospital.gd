extends Control

## Lista de frases bem-humoradas sorteadas aleatoriamente a cada Game Over
const FRASES_GAME_OVER: Array[String] = [
	"FIM DE JOGO!",
	"SE FODEU!",
	"JÁ ERA!",
	"TÁ EM COMA!",
	"MORREU!",
	"FOI DE VASCO!",
	"RIP",
	"ACABOU PRO BETA!",
	"CAIXÃO E VELA PRETA!",
	"FOI DE SUS!",
	"DETONADO!",
	"MORREU MAS PASSA BEM!",
]

@onready var label_status: Label = $Label
@onready var ambulance: Sprite2D = $Ambulance
@onready var btn_restart: Button = $Restart
@onready var btn_menu: Button = $Menu
@onready var sounds: Sounds = $Sounds

var _vibration_timer: float = 0.0
var _ambulance_base_y: float = 98.0
var _transicionando: bool = false


func _ready() -> void:
	AudioManager.parar_audios_corrida()
	AudioManager.tocar_game_over()
	AudioManager.tocar_ambulancia()
	if ambulance:
		_ambulance_base_y = ambulance.position.y
	get_tree().paused = false

	_sortear_frase()
	_iniciar_timer_extra()


## Timer de 10 segundos com 30% de chance de exibir a tela Extra
func _iniciar_timer_extra() -> void:
	await get_tree().create_timer(10.0).timeout
	if not is_inside_tree() or _transicionando:
		return

	var sorteio: float = randf_range(0.0, 100.0)
	if sorteio <= 30.0:
		_transicionando = true
		if btn_restart:
			btn_restart.disabled = true
		if btn_menu:
			btn_menu.disabled = true
		AudioManager.parar_game_over()
		AudioManager.parar_ambulancia()
		print("🚑 [Hospital] 10 segundos decorridos! Sorteio bem-sucedido (%.1f%% <= 30%%): exibindo tela Extra..." % sorteio)
		get_tree().change_scene_to_file("res://scenes/referencia/extra.tscn")
	else:
		print("🚑 [Hospital] 10 segundos decorridos! Sorteio não contemplado (%.1f%% > 30%%): permanecendo no Hospital." % sorteio)


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
	_transicionando = true
	btn_restart.disabled = true
	btn_menu.disabled = true
	AudioManager.parar_game_over()
	AudioManager.parar_ambulancia()
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().change_scene_to_file("res://scenes/levels/main_game.tscn")


## Botão de menu: transiciona para a cena de Menu Principal
func _on_menu_pressed() -> void:
	_transicionando = true
	btn_restart.disabled = true
	btn_menu.disabled = true
	AudioManager.parar_game_over()
	AudioManager.parar_ambulancia()
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().change_scene_to_file("res://scenes/ui/menu_game.tscn")
