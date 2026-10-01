extends CanvasLayer

## Hub / HUD do Player com exibição de telemetria e reação facial às quedas

@export_group("Expressões de Queda (Faces)")
@export var faces_quedas: Array[Texture2D] = [
	preload("res://assets/sprites/facesPlayer/face2.png"),
	preload("res://assets/sprites/facesPlayer/face3.png"),
	preload("res://assets/sprites/facesPlayer/face4.png")
]

# Dimensão local base para ajuste proporcional dentro da Moldura Neon
const TAMANHO_LOCAL_ALVO: Vector2 = Vector2(801.62, 679.65)

@onready var temp_atual: Label = $Control/TempAtual
@onready var km_h: Label = $Control/KmH
@onready var temp_limite: Label = $Control/TempLimite
@onready var face_sprite: Sprite2D = $Control/MolduraPerfil/Face


func _ready() -> void:
	set_quedas(0)


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


## Atualiza o sprite do rosto conforme a quantidade de quedas / acidentes
func set_quedas(qtd: int) -> void:
	if face_sprite == null:
		face_sprite = get_node_or_null("Control/MolduraPerfil/Face")
	if face_sprite == null or faces_quedas.is_empty():
		return

	var indice: int = clampi(qtd, 0, faces_quedas.size() - 1)
	var nova_textura: Texture2D = faces_quedas[indice]
	if nova_textura:
		face_sprite.texture = nova_textura
		_ajustar_escala_face(nova_textura)


## Ajusta a escala da face para caber com perfeição dentro da Moldura Neon
func _ajustar_escala_face(tex: Texture2D) -> void:
	if face_sprite and tex:
		var tex_size: Vector2 = tex.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			face_sprite.scale = TAMANHO_LOCAL_ALVO / tex_size


## Alias para compatibilidade
func set_acidentes(qtd: int) -> void:
	set_quedas(qtd)