extends HBoxContainer

var curr_mood: int = -1

func _ready() -> void:
	for c in get_children():
		c.toggled.connect(Callable(func(toggled):
			if toggled:
				curr_mood = int(c.name)
				for btn in get_children():
					if btn.name == c.name:
						continue
					btn.set_pressed_no_signal(false)
			else:
				curr_mood = -1
			))

func set_mood(mood: int):
	curr_mood = mood
	get_child(mood-1).set_pressed_no_signal(true)

func reset():
	curr_mood = -1
	for btn in get_children():
		btn.set_pressed_no_signal(false)
