extends HBoxContainer

var current_screen = 0

func _ready() -> void:
	$Today.pressed.connect(Callable(func():
		$Today.button_pressed = true
		$Journal.button_pressed = false
		$Report.button_pressed = false
		$Profile.button_pressed = false
		
		current_screen = 0
		))
	$Journal.pressed.connect(Callable(func():
		$Today.button_pressed = false
		$Journal.button_pressed = true
		$Report.button_pressed = false
		$Profile.button_pressed = false
		
		current_screen = 1
		))
	$Report.pressed.connect(Callable(func():
		$Today.button_pressed = false
		$Journal.button_pressed = false
		$Report.button_pressed = true
		$Profile.button_pressed = false
		
		current_screen = 2
		))
	$Profile.pressed.connect(Callable(func():
		$Today.button_pressed = false
		$Journal.button_pressed = false
		$Report.button_pressed = false
		$Profile.button_pressed = true
		
		current_screen = 3
		))

func _process(delta: float) -> void:
	$"../Screens".position.x = lerp($"../Screens".position.x, float(-480 * current_screen), 0.3*delta*60)
