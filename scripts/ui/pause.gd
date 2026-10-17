extends CanvasLayer

# --- PARAMETROS CONFIGURAVEIS ---
@export var pausar_ao_iniciar: bool = false

# --- REFERENCIAS A NODES ---
@onready var sounds: Sounds = $Sounds
@onready var control: Control = $Control
@onready var btn_continue: Button = $Control/Continue
@onready var btn_restart: Button = $Control/Restart
@onready var btn_menu: Button = $Control/Menu

# --- INICIALIZACAO ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

# --- ABRIR E FECHAR PAUSA ---
func pausar() -> void:
	visible = true
	get_tree().paused = true
	AudioManager.pausar_audio_jogo(true)
	_ativar_botoes(true)


func despausar() -> void:
	get_tree().paused = false
	visible = false
	AudioManager.pausar_audio_jogo(false)
	_ativar_botoes(true)


func _ativar_botoes(ativo: bool) -> void:
	if btn_continue:
		btn_continue.disabled = not ativo
	if btn_restart:
		btn_restart.disabled = not ativo
	if btn_menu:
		btn_menu.disabled = not ativo

# --- BOTOES E TRANSICAO DE CENA ---
func _on_continue_pressed() -> void:
	_ativar_botoes(false)
	if sounds:
		await sounds.choice_select(0.25)
	despausar()


func _on_restart_pressed() -> void:
	_transicionar_para("res://scenes/levels/main_game.tscn")


func _on_menu_pressed() -> void:
	_transicionar_para("res://scenes/ui/menu_game.tscn")


func _transicionar_para(caminho_cena: String) -> void:
	_ativar_botoes(false)
	if sounds:
		await sounds.choice_select(0.25)
	AudioManager.pausar_audio_jogo(false)
	AudioManager.parar_todos()
	get_tree().paused = false
	get_tree().change_scene_to_file(caminho_cena)
