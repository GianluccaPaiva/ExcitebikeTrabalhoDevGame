extends CanvasLayer

## Hub / HUD do Player com telemetria e contador visual de vidas (mini-motos empinadas)

@onready var temp_atual: Label = $Control/TempAtual
@onready var km_h: Label = $Control/KmH
@onready var temp_limite: Label = $Control/TempLimite

@onready var moto_vida_1: Sprite2D = get_node_or_null("Control/Vidas/MotoVida1")
@onready var moto_vida_2: Sprite2D = get_node_or_null("Control/Vidas/MotoVida2")
@onready var moto_vida_3: Sprite2D = get_node_or_null("Control/Vidas/MotoVida3")

var _vidas_sprites: Array[Sprite2D] = []
var _posicoes_originais_y: Dictionary = {}
var _vidas_ativas: int = 3


func _ready() -> void:
	_vidas_sprites = [moto_vida_1, moto_vida_2, moto_vida_3]
	for sp in _vidas_sprites:
		if is_instance_valid(sp):
			_posicoes_originais_y[sp] = sp.position.y
	resetar_vidas()


## Restaura todas as mini-motos para o estado pleno
func resetar_vidas() -> void:
	_vidas_ativas = 3
	for sp in _vidas_sprites:
		if is_instance_valid(sp):
			sp.visible = true
			sp.modulate = Color.WHITE
			if _posicoes_originais_y.has(sp):
				sp.position.y = _posicoes_originais_y[sp]


func set_temp_atual(temp: float) -> void:
	if temp_atual:
		temp_atual.text = str(temp)


func set_km_h(km: Variant) -> void:
	if km_h:
		if km is float or km is int:
			km_h.text = "%.1f" % km
		else:
			km_h.text = str(km)


func set_temp_limite(temp: float) -> void:
	if temp_limite:
		temp_limite.text = str(temp)


## Atualiza as vidas restantes com base na quantidade de acidentes (0, 1, 2, 3)
func set_quedas(qtd: int) -> void:
	# 3 vidas totais:
	# 0 quedas -> 3 vidas restantes (todas ativas)
	# 1 queda  -> 2 vidas restantes (perde moto 3)
	# 2 quedas -> 1 vida restante  (perde moto 2)
	# 3 quedas -> 0 vidas restantes (perde moto 1, hospital)
	var vidas_alvo: int = clampi(3 - qtd, 0, 3)

	# Se a quantidade de vidas caiu, anima a perda de cada vida consumida
	if vidas_alvo < _vidas_ativas:
		for v in range(_vidas_ativas - 1, vidas_alvo - 1, -1):
			if v >= 0 and v < _vidas_sprites.size():
				_animar_perda_vida(_vidas_sprites[v])
		_vidas_ativas = vidas_alvo
	elif vidas_alvo > _vidas_ativas:
		# Em caso de reset ou recuperação
		resetar_vidas()


## Anima a perda de uma mini-moto (pisca em alerta vermelho e sobe com fade-out)
func _animar_perda_vida(sp: Sprite2D) -> void:
	if not is_instance_valid(sp):
		return

	var tween: Tween = create_tween().set_parallel(false)
	tween.tween_property(sp, "modulate", Color(1.0, 0.25, 0.25, 1.0), 0.08)
	tween.tween_property(sp, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
	tween.tween_property(sp, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.08)

	var tween_sumir: Tween = create_tween().set_parallel(true)
	tween_sumir.tween_property(sp, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_sumir.tween_property(sp, "position:y", sp.position.y - 3.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Alias para compatibilidade
func set_acidentes(qtd: int) -> void:
	set_quedas(qtd)