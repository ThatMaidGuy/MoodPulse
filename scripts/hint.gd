extends Panel

# Вспомогательная подсказка (можно заменить на Popup/Label/Toast)
func show_hint(text: String) -> void:
	show()
	get_node("margin/Label").text = text
	var t = get_tree().create_tween()
	t.tween_property($"../../Hint", "modulate", Color(1,1,1,1), 0.5)
	t.tween_interval(3.0)
	t.tween_property($"../../Hint", "modulate", Color(1,1,1,0), 0.5)
	t.tween_callback(hide)
