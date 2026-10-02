extends CanvasLayer

signal corrida_iniciada

@onready var label_contagem: Label = $Control/LabelContagem
@onready var audio_player: AudioStreamPlayer = $Control/AudioStreamPlayer

@export var tempo_por_numero: float = 1.0
@export var tempo_exibicao_vai: float = 0.8

var _contagem_ativa: bool = false


func _ready() -> void:
	iniciar_contagem()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		if audio_player and audio_player.playing:
			audio_player.stream_paused = true
	elif what == NOTIFICATION_UNPAUSED:
		if audio_player and audio_player.stream_paused:
			audio_player.stream_paused = false


func iniciar_contagem() -> void:
	if not label_contagem:
		return
	
	_contagem_ativa = true
	label_contagem.visible = true
	label_contagem.modulate.a = 1.0

	if audio_player and not audio_player.playing:
		audio_player.play()
		if get_tree().paused:
			audio_player.stream_paused = true

	for i in range(3):
		# "3", "2", "1"
		label_contagem.text = str(3 - i)
		_animar_texto(1.3)
		await get_tree().create_timer(tempo_por_numero, false).timeout
		if not is_inside_tree() or not _contagem_ativa:
			return
	
	# "VAI!"
	label_contagem.text = "VAI!"
	_animar_texto(1.5)
	corrida_iniciada.emit()
	
	await get_tree().create_timer(tempo_exibicao_vai, false).timeout
	if not is_inside_tree() or not _contagem_ativa:
		return
	
	# Desaparece suavemente
	var tween: Tween = create_tween()
	tween.tween_property(label_contagem, "modulate:a", 0.0, 0.3)
	await tween.finished
	if is_inside_tree():
		label_contagem.visible = false
	_contagem_ativa = false


func _animar_texto(fator_escala: float) -> void:
	label_contagem.scale = Vector2(fator_escala, fator_escala)
	var tween: Tween = create_tween()
	tween.tween_property(label_contagem, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
