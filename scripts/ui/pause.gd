extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_continue_pressed() -> void:
	get_tree().change_scene("res://scenes/game.tscn")

func _on_restart_pressed() -> void:
	get_tree().change_scene("res://scenes/game.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene("res://scenes/menu.tscn")
