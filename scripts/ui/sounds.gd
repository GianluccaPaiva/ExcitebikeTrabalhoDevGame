class_name Sounds
extends Node2D

# --- REFERENCIAS A NODES ---
@onready var select: AudioStreamPlayer = $Select
@onready var choice: AudioStreamPlayer = $Choice

# --- ESTADO DO AUDIO DA UI ---
var pode_tocar_som: bool = false


# --- INICIALIZACAO E LIGACAO DOS BOTOES ---
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if select:
		select.process_mode = Node.PROCESS_MODE_ALWAYS
	if choice:
		choice.process_mode = Node.PROCESS_MODE_ALWAYS

	call_deferred("_inicializar")


func _inicializar() -> void:
	_configurar_botoes_da_cena()
	await get_tree().process_frame
	pode_tocar_som = true


# --- FOCO E HOVER DOS BOTOES ---
func _configurar_botoes_da_cena() -> void:
	for grupo_nome in ["botoes_interface", "ui_buttons"]:
		for no_generico in get_tree().get_nodes_in_group(grupo_nome):
			var botao: Button = no_generico as Button
			if botao:
				_vincular_botao(botao)


func _vincular_botao(btn: Button) -> void:
	if btn.has_meta("_sounds_conectado"):
		return
	btn.set_meta("_sounds_conectado", true)

	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_entered.connect(_ao_entrar_mouse_botao.bind(btn))
	btn.focus_entered.connect(_ao_receber_foco_botao)


func _ao_entrar_mouse_botao(btn: Button) -> void:
	if not pode_tocar_som:
		return

	if btn and is_instance_valid(btn):
		if btn.has_focus():
			play_select()
		else:
			btn.grab_focus()


func _ao_receber_foco_botao() -> void:
	play_select()


# --- REPRODUCAO DOS SONS DA UI ---
func play_select() -> void:
	if not pode_tocar_som:
		return
	if select:
		select.play()


func choice_select(duracao: float = 0.25) -> void:
	if choice:
		choice.play()
		if duracao > 0.0:
			await get_tree().create_timer(duracao, true, false, true).timeout
			if choice and choice.playing:
				choice.stop()
