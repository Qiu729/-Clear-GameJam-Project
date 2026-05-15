extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("focus_entered", Callable(SoundManager, "play_button_grab"))
	connect("pressed", Callable(SoundManager, "play_button_click"))
	
