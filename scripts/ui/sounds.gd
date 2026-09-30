class_name Sounds
extends Node2D

## Gerenciador de som da cena Sounds
## Conecta automaticamente os botões da cena para focar e tocar o som Select ao passar o mouse ou focar

@onready var select: AudioStreamPlayer2D = $Select
@onready var choice: AudioStreamPlayer2D = $Choice

var _pode_tocar_som: bool = false


func _ready() -> void:
	if select:
		select.panning_strength = 0.0
		select.max_distance = 100000.0
	if choice:
		choice.panning_strength = 0.0
		choice.max_distance = 100000.0

	call_deferred("_inicializar")


func _inicializar() -> void:
	_configurar_botoes_da_cena()
	_remover_foco_ativo()

	# Aguarda a tela estabilizar para não tocar som nem deixar botão focado na inicialização
	await get_tree().process_frame
	_remover_foco_ativo()
	_pode_tocar_som = true


## Localiza a raiz da cena ativa e vincula todos os botões filhos
func _configurar_botoes_da_cena() -> void:
	var raiz: Node = owner
	if raiz == null:
		raiz = get_tree().current_scene
	if raiz == null:
		raiz = self
		while raiz.get_parent() != null and not (raiz.get_parent() is Window):
			raiz = raiz.get_parent()

	if raiz:
		_conectar_botoes_recursivo(raiz)


## Percorre recursivamente a árvore conectando mouse_entered e focus_entered
func _conectar_botoes_recursivo(nodo: Node) -> void:
	if nodo == null:
		return

	for filho in nodo.get_children():
		if filho is Button:
			_vincular_botao(filho)
		_conectar_botoes_recursivo(filho)


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
func choice_select(duracao: float = 0.25) -> void:
	if choice:
		choice.play()
		if duracao > 0.0:
			await get_tree().create_timer(duracao).timeout
			if choice and choice.playing:
				choice.stop()


