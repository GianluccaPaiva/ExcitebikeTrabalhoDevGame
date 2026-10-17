class_name Hub
extends CanvasLayer

# --- ENUMS DO HUD ---
enum TipoTempo {
	ATUAL,
	LIMITE
}

# --- REFERENCIAS A NODES ---
@onready var temp_atual: Label = $Control/TempAtual
@onready var km_h: Label = $Control/KmH
@onready var temp_limite: Label = $Control/TempLimite

@onready var moto_vida_1: Sprite2D = get_node_or_null("Control/Vidas/MotoVida1")
@onready var moto_vida_2: Sprite2D = get_node_or_null("Control/Vidas/MotoVida2")
@onready var moto_vida_3: Sprite2D = get_node_or_null("Control/Vidas/MotoVida3")

# --- ESTADO DO HUD ---
var vidas_sprites: Array[Sprite2D] = []
var posicoes_originais_y: Dictionary = {}
var vidas_ativas: int = 3

# --- INICIALIZACAO ---
func _ready() -> void:
	vidas_sprites = [moto_vida_1, moto_vida_2, moto_vida_3]
	for sp in vidas_sprites:
		if is_instance_valid(sp):
			posicoes_originais_y[sp] = sp.position.y
	resetar_vidas()

# --- CRONOMETRO MM:SS:CC ---
static func formatar_tempo(tempo: float) -> String:
	var minutos: int = int(tempo / 60.0)
	var segundos: int = int(fmod(tempo, 60.0))
	var centesimos: int = int(fmod(tempo * 100.0, 100.0))
	return "%02d:%02d:%02d" % [minutos, segundos, centesimos]


func _set_timer(tempo: float, tipo: TipoTempo) -> void:
	var tempo_formatado: String = formatar_tempo(tempo)
	match tipo:
		TipoTempo.ATUAL:
			if temp_atual:
				temp_atual.text = tempo_formatado
		TipoTempo.LIMITE:
			if temp_limite:
				temp_limite.text = tempo_formatado


func set_temp_atual(tempo: float) -> void:
	_set_timer(tempo, TipoTempo.ATUAL)


func set_timer_atual(tempo: float) -> void:
	set_temp_atual(tempo)


func set_temp_limite(temp: float) -> void:
	_set_timer(temp, TipoTempo.LIMITE)

# --- VELOCIMETRO ---
func set_km_h(km: Variant) -> void:
	if km_h:
		if km is float or km is int:
			km_h.text = "%.1f" % km
		else:
			km_h.text = str(km)

# --- VIDAS E EXPRESSOES ---
func resetar_vidas() -> void:
	vidas_ativas = 3
	for sp in vidas_sprites:
		if is_instance_valid(sp):
			sp.visible = true
			sp.modulate = Color.WHITE
			if posicoes_originais_y.has(sp):
				sp.position.y = posicoes_originais_y[sp]


func set_quedas(qtd: int) -> void:
	var vidas_alvo: int = clampi(3 - qtd, 0, 3)

	if vidas_alvo < vidas_ativas:
		for v in range(vidas_ativas - 1, vidas_alvo - 1, -1):
			if v >= 0 and v < vidas_sprites.size():
				_animar_perda_vida(vidas_sprites[v])
		vidas_ativas = vidas_alvo
	elif vidas_alvo > vidas_ativas:
		resetar_vidas()


func set_acidentes(qtd: int) -> void:
	set_quedas(qtd)


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