extends Control

@onready var sounds: Sounds = $Sounds

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().paused = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_continue_pressed() -> void:
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().paused = false

func _on_restart_pressed() -> void:
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().change_scene("res://scenes/levels/main_game.tscn")

func _on_menu_pressed() -> void:
	if sounds:
		await sounds.choice_select(0.25)
	get_tree().change_scene("res://scenes/menu.tscn")
