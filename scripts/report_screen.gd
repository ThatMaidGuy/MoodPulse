extends Control


func _on_main_update_entries() -> void:
	update_avg_mood()
	update_top()
	update_chart()


func update_chart():
	var last_mood_query = "
		SELECT e.mood, e.created_at FROM entries e
		ORDER BY e.created_at
		LIMIT 7"
	$"../..".db.query(last_mood_query)
	var data_dates = []
	var data_moods = []
	for i in $"../..".db.query_result:
		data_moods.append(i["mood"])
		var entry_date = Time.get_datetime_dict_from_datetime_string(i["created_at"], false)
		data_dates.append(entry_date["day"])
	data_dates.reverse()
	data_moods.reverse()
	$body/VBoxContainer/Card3.update_chart(data_dates, data_moods)


func update_avg_mood():
	var avg_query = "
		SELECT AVG(e.mood) AS avg_mood FROM entries e
		WHERE e.created_at >= datetime('now', '-7 days')
		LIMIT 8"
	$"../..".db.query(avg_query)
	$body/VBoxContainer/Card/Panel/Padding/VBoxContainer/avg.text = str($"../..".db.query_result[0]["avg_mood"])


func update_top():
	var top_query = "
		SELECT
			t.id,
			t.name,
			COUNT(DISTINCT e.id) AS entry_count
		FROM triggers t
		JOIN entry_triggers et ON et.trigger_id = t.id
		JOIN entries e ON e.id = et.entry_id
		GROUP BY t.id
		ORDER BY entry_count DESC, t.name
		LIMIT 5"
	$"../..".db.query(top_query)
	$body/VBoxContainer/Card2/Panel/Padding/VBoxContainer/triggers.text = ""
	for i in len($"../..".db.query_result):
		var trigger = $"../..".db.query_result[i]
		append_trigger("- " + trigger["name"] + " ("+ str(trigger["entry_count"]) +" дней)")
		if i != len($"../..".db.query_result)-1:
			append_trigger("\n")

func append_trigger(text: String):
	$body/VBoxContainer/Card2/Panel/Padding/VBoxContainer/triggers.text = \
	$body/VBoxContainer/Card2/Panel/Padding/VBoxContainer/triggers.text + \
	text
