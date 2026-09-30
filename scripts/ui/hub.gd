extends CanvasLayer


@onready var temp_atual: Label = $Control/TempAtual
@onready var km_h: Label = $Control/KmH
@onready var temp_limite: Label = $Control/TempLimite

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


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