class_name Sounds
extends Node2D

## Gerenciador de sons de interface (UI)
## Conecta automaticamente os botões da cena pertencentes ao grupo "botoes_interface"
## para tocar os efeitos sonoros de seleção e confirmação.
## Configurado com PROCESS_MODE_ALWAYS para funcionar durante pausas do jogo.

@onready var select: AudioStreamPlayer = $Select
@onready var choice: AudioStreamPlayer = $Choice

var _pode_tocar_som: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if select:
		select.process_mode = Node.PROCESS_MODE_ALWAYS
	if choice:
		choice.process_mode = Node.PROCESS_MODE_ALWAYS

	call_deferred("_inicializar")


func _inicializar() -> void:
	_configurar_botoes_da_cena()
	# Aguarda a tela estabilizar para liberar sons de hover/foco
	await get_tree().process_frame
	_pode_tocar_som = true


## Localiza os botões registrados nos grupos de interface e vincula os eventos
func _configurar_botoes_da_cena() -> void:
	for grupo_nome in ["botoes_interface", "ui_buttons"]:
		for no_generico in get_tree().get_nodes_in_group(grupo_nome):
			var botao: Button = no_generico as Button
			if botao:
				_vincular_botao(botao)


## Vincula os sinais de foco e mouse do botão
func _vincular_botao(btn: Button) -> void:
	if btn.has_meta("_sounds_conectado"):
		return
	btn.set_meta("_sounds_conectado", true)

	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_entered.connect(_ao_entrar_mouse_botao.bind(btn))
	btn.focus_entered.connect(_ao_receber_foco_botao)


## Ao passar o mouse sobre o botão, ganha foco e toca som
func _ao_entrar_mouse_botao(btn: Button) -> void:
	if not _pode_tocar_som:
		return

	if btn and is_instance_valid(btn):
		if btn.has_focus():
			play_select()
		else:
			btn.grab_focus()


## Ao receber foco (via teclado/gamepad ou grab_focus), toca som
func _ao_receber_foco_botao() -> void:
	play_select()


## Toca o áudio de seleção
func play_select() -> void:
	if not _pode_tocar_som:
		return
	if select:
		select.play()


## Toca o áudio de confirmação / escolha com corte de duração configurável (padrão 0.25s)
## process_always = true no timer garante que funcione mesmo durante o pause
func choice_select(duracao: float = 0.25) -> void:
	if choice:
		choice.play()
		if duracao > 0.0:
			await get_tree().create_timer(duracao, true, false, true).timeout
			if choice and choice.playing:
				choice.stop()
