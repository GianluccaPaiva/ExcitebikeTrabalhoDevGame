class_name Sounds
extends Node2D

## Gerenciador de som da cena Sounds
## Conecta automaticamente os botões da cena para focar e tocar o som Select ao passar o mouse ou focar
## Configurado com PROCESS_MODE_ALWAYS para que continue funcionando perfeitamente mesmo com o jogo pausado (freeze)

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
	_remover_foco_ativo()

	# Aguarda a tela estabilizar para não tocar som nem deixar botão focado na inicialização
	await get_tree().process_frame
	_remover_foco_ativo()
	_pode_tocar_som = true


## Vincula todos os botões no grupo "ui_buttons"
func _configurar_botoes_da_cena() -> void:
	for btn_untyped in get_tree().get_nodes_in_group("ui_buttons"):
		var btn: Button = btn_untyped as Button
		if btn:
			_vincular_botao(btn)


## Vincula os sinais de foco e mouse do botão
func _vincular_botao(btn: Button) -> void:
	if btn.has_meta("_sounds_conectado"):
		return
	btn.set_meta("_sounds_conectado", true)

	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_entered.connect(_on_botao_mouse_entered.bind(btn))
	btn.focus_entered.connect(_on_botao_focus_entered)


## Remove o foco de qualquer controle que tenha recebido foco na inicialização da cena
func _remover_foco_ativo() -> void:
	var viewport: Viewport = get_viewport()
	if viewport:
		var foco_atual: Control = viewport.gui_get_focus_owner()
		if foco_atual:
			foco_atual.release_focus()


## Ao passar o mouse sobre o botão, ganha foco e toca som
func _on_botao_mouse_entered(btn: Button) -> void:
	if not _pode_tocar_som:
		return

	if btn and is_instance_valid(btn):
		if btn.has_focus():
			play_select()
		else:
			btn.grab_focus()


## Ao receber foco (via teclado/gamepad ou grab_focus), toca som
func _on_botao_focus_entered() -> void:
	play_select()


## Toca o áudio de seleção
func play_select() -> void:
	if not _pode_tocar_som:
		return
	if select:
		select.play()


## Toca o áudio de confirmação / escolha com corte de duração configurável (padrão 0.25s)
## process_always = true no timer garante que o corte e retorno funcionem mesmo durante o pause/freeze
func choice_select(duracao: float = 0.25) -> void:
	if choice:
		choice.play()
		if duracao > 0.0:
			await get_tree().create_timer(duracao, true, false, true).timeout
			if choice and choice.playing:
				choice.stop()
