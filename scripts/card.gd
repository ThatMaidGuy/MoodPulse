@tool
extends MarginContainer

func _process(_delta: float) -> void:
	custom_minimum_size.y = $Panel/Padding.size.y
