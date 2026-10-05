extends Control

## Tela de Hospital (Game Over após 3 acidentes)
## Apresenta frases bem-humoradas e gerencia o Easter Egg da tela Extra.

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

var temporizador_vibracao: float = 0.0
var posicao_base_ambulancia_y: float = 98.0
var transicionando: bool = false


func _ready() -> void:
	AudioManager.parar_audios_corrida()
	AudioManager.tocar_game_over()
	AudioManager.tocar_ambulancia()
	if ambulance:
		posicao_base_ambulancia_y = ambulance.position.y
	get_tree().paused = false

	_sortear_frase()
	_iniciar_timer_extra()


## Timer de 10 segundos com 30% de chance de abrir a tela Extra
func _iniciar_timer_extra() -> void:
	await get_tree().create_timer(10.0).timeout
	if not is_inside_tree() or transicionando:
		return

	var sorteio: float = randf_range(0.0, 100.0)
	if sorteio <= 30.0:
		transicionando = true
		if btn_restart:
			btn_restart.disabled = true
		if btn_menu:
			btn_menu.disabled = true
		AudioManager.parar_game_over()
		AudioManager.parar_ambulancia()
		if OS.is_debug_build():
			print("🚑 [Hospital] 10s decorridos! Sorteio bem-sucedido (%.1f%% <= 30%%): abrindo tela Extra..." % sorteio)
		get_tree().change_scene_to_file("res://scenes/referencia/extra.tscn")
	else:
		if OS.is_debug_build():
			print("🚑 [Hospital] 10s decorridos! Sorteio não contemplado (%.1f%% > 30%%): permanecendo no Hospital." % sorteio)


func _process(delta: float) -> void:
	if ambulance:
		temporizador_vibracao += delta * 24.0
		ambulance.position.y = posicao_base_ambulancia_y + sin(temporizador_vibracao) * 0.7


func _sortear_frase() -> void:
	if label_status:
		label_status.text = FRASES_GAME_OVER.pick_random()


func _on_restart_pressed() -> void:
	transicionando = true
	btn_restart.disabled = true
	btn_menu.disabled = true
	AudioManager.parar_game_over()
	AudioManager.parar_ambulancia()
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().change_scene_to_file("res://scenes/levels/main_game.tscn")


func _on_menu_pressed() -> void:
	transicionando = true
	btn_restart.disabled = true
	btn_menu.disabled = true
	AudioManager.parar_game_over()
	AudioManager.parar_ambulancia()
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().change_scene_to_file("res://scenes/ui/menu_game.tscn")
