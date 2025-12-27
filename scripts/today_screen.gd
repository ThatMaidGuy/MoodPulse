extends Control

@onready var mood = $body/VBoxContainer/Card/Panel/Padding/VBoxContainer/mood
@onready var notes = $body/VBoxContainer/Card/Panel/Padding/VBoxContainer/Notes
@onready var save_btn = $body/VBoxContainer/Card/Panel/Padding/VBoxContainer/Save
@onready var trigger_list = $body/VBoxContainer/Card/Panel/Padding/VBoxContainer/triggers

var trigger_btn_prld = preload("res://objects/trigger.tscn")
var current_entry_id = -1

func _on_main_db_initilized() -> void:
	get_todays_entry()

## Получает сегодняшнюю запись
func get_todays_entry():
	var big_query = "
		SELECT
			e.id,
			e.mood,
			e.note,
			e.created_at
		FROM entries e
		WHERE e.created_at = (date('now','localtime'))
		ORDER BY e.created_at DESC"
	$"../..".db.query(big_query)
	var res: Array[Dictionary] = $"../..".db.query_result
	if res.size() == 0:
		notes.text = ""
		mood.reset()
		save_btn.text = "Сохранить"
		for t in trigger_list.get_children():
			t.queue_free()
		return
	current_entry_id = res[0]["id"]
	notes.text = res[0]["note"]
	mood.set_mood(res[0]["mood"])
	save_btn.text = "Изменить"
	
	var triggers_query = "
		SELECT
			t.id,
			t.name
		FROM entries e
		LEFT JOIN entry_triggers et ON et.entry_id = e.id
		LEFT JOIN triggers t ON t.id = et.trigger_id
		WHERE e.created_at = (date('now','localtime'))
		ORDER BY e.created_at DESC"
	$"../..".db.query(triggers_query)
	var triggers: Array[Dictionary] = $"../..".db.query_result
	for t in trigger_list.get_children():
		t.queue_free()
		
	if triggers.size() == 0:
		return
	for t in triggers:
		add_trigger_button(t["name"], Callable(func ():
			var id = t["id"]
			$"../..".db.query_with_bindings("DELETE FROM entry_triggers WHERE entry_id = ? AND trigger_id = ?", [current_entry_id, id])
			$"../..".emit_signal("update_entries")
		))


func _ready() -> void:
	$body/VBoxContainer/Header/HBoxContainer/date.text = \
		str(Time.get_date_dict_from_system()["day"]) \
		+ " " + \
		($"../..".MONTHS[Time.get_date_dict_from_system()["month"] -1] as String).substr(0, 3)


func _process(_delta: float) -> void:
	save_btn.disabled = not (mood.curr_mood != -1 and notes.text.strip_edges().length() > 5)


func _on_add_trigger_pressed() -> void:
	var prompt: TextEdit = $body/VBoxContainer/Card/Panel/Padding/VBoxContainer/TriggerPrompt/TextEdit
	if prompt.text.strip_edges().is_empty():
		return
	
	if save_btn.text == "Изменить":
		var data_trigger = "INSERT INTO triggers (name) VALUES (?) ON CONFLICT(name) DO NOTHING;"
		$"../..".db.query_with_bindings(data_trigger, [prompt.text.strip_edges()])
		var data_link = "
		INSERT INTO entry_triggers (entry_id, trigger_id)
			VALUES (%s, (SELECT id FROM triggers WHERE name = ?))
				ON CONFLICT(entry_id, trigger_id) DO NOTHING;" % [current_entry_id]
		$"../..".db.query_with_bindings(data_link, [prompt.text.strip_edges()])
		
		$"../..".emit_signal("update_entries")
	
	add_trigger_button(prompt.text.strip_edges(), Callable(func ():
		print("new")
	))
	prompt.text = ""


func add_trigger_button(tname: String, on_click: Callable):
	var trigger: Button = trigger_btn_prld.instantiate()
	trigger.text = tname
	trigger.pressed.connect(Callable(func():
		on_click.call()
		trigger.queue_free()
	))
	trigger_list.add_child(trigger)


func _on_save_today_pressed() -> void:
	if save_btn.text == "Изменить":
		var update_query = "
			UPDATE entries
			SET mood = ?, note = ?
			WHERE created_at = (date('now','localtime'))"
		$"../..".db.query_with_bindings(update_query, [mood.curr_mood, notes.text])
		$"../..".emit_signal("update_entries")
		get_todays_entry()
		return
	
	var data_entry = {"mood": mood.curr_mood, "note": notes.text}
	$"../..".db.insert_row("entries",data_entry)
	current_entry_id = $"../..".db.last_insert_rowid
	
	for trig: Button in $body/VBoxContainer/Card/Panel/Padding/VBoxContainer/triggers.get_children():
		var data_trigger = "INSERT INTO triggers (name) VALUES (?) ON CONFLICT(name) DO NOTHING;"
		$"../..".db.query_with_bindings(data_trigger, [trig.text])
		var data_link = "
		INSERT INTO entry_triggers (entry_id, trigger_id)
			VALUES (%s, (SELECT id FROM triggers WHERE name = ?))
				ON CONFLICT(entry_id, trigger_id) DO NOTHING;" % [current_entry_id]
		$"../..".db.query_with_bindings(data_link, [trig.text])
	
	save_btn.text = "Изменить"
	
	$"../..".emit_signal("update_entries")
