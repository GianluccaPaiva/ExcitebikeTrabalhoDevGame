extends CanvasLayer

signal corrida_iniciada

@onready var label_contagem: Label = $Control/LabelContagem

@export var tempo_por_numero: float = 1.0
@export var tempo_exibicao_vai: float = 0.8

func _ready() -> void:
	iniciar_contagem()


func iniciar_contagem() -> void:
	if not label_contagem:
		return
	
	label_contagem.visible = true
	label_contagem.modulate.a = 1.0

	for i in range(3):
		# "3"
		label_contagem.text = str(3 - i)
		_animar_texto(1.3)
		await get_tree().create_timer(tempo_por_numero).timeout
	
	
	# "VAI!"
	label_contagem.text = "VAI!"
	_animar_texto(1.5)
	corrida_iniciada.emit()
	
	await get_tree().create_timer(tempo_exibicao_vai).timeout
	
	# Desaparece suavemente
	var tween: Tween = create_tween()
	tween.tween_property(label_contagem, "modulate:a", 0.0, 0.3)
	await tween.finished
	label_contagem.visible = false


func _animar_texto(fator_escala: float) -> void:
	label_contagem.scale = Vector2(fator_escala, fator_escala)
	var tween: Tween = create_tween()
	tween.tween_property(label_contagem, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
