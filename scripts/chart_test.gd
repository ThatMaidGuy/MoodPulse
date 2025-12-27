extends MarginContainer

var current_chart: Control

func update_chart(data_dates: Array, data_mood: Array):
	if current_chart != null:
		current_chart.queue_free()
	
	if data_dates.size() <= 1:
		var label = Label.new()
		label.set("theme_override_colors/font_color", Color.BLACK)
		label.text = "Недостаточно данных!"
		current_chart = label
		$Panel/Padding/VBoxContainer.add_child(label)
		return
	
	var chart_scene: PackedScene = load("res://addons/easy_charts/control_charts/chart.tscn")
	var chart: Chart = chart_scene.instantiate()
	current_chart = chart
	$Panel/Padding/VBoxContainer.add_child(chart)
	
	var function := Function.new(
		data_dates,  # The function's X-values
		data_mood, # The function's Y-values
		"First function",       # The function's name
		{
			type = Function.Type.LINE,       # The function's type
			marker = Function.Marker.SQUARE, # Some function types have additional configuraiton
			color = Color("#36a2eb"),        # The color of the drawn function
		}
	)
	
	chart.plot([function])
