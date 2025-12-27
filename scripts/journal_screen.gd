extends Control

@onready var list = $body/VBoxContainer/ScrollContainer/VBoxContainer

var entry_card_prld = preload("res://objects/journal_card.tscn")

func update_journal() -> void:
	for c in list.get_children():
		c.queue_free()
	
	var big_query = "
	SELECT
		e.id,
		e.mood,
		e.note,
		e.created_at,
		GROUP_CONCAT(t.name, ', ') AS triggers
	FROM entries e
	LEFT JOIN entry_triggers et ON et.entry_id = e.id
	LEFT JOIN triggers t ON t.id = et.trigger_id
	GROUP BY e.id
	ORDER BY e.created_at DESC
	LIMIT 20 OFFSET 0;
	"
	
	$"../..".db.query(big_query)
	for i in $"../..".db.query_result:
		var entry_date = Time.get_datetime_dict_from_datetime_string(i["created_at"], false)
		var entry_date_text = "{0} {1} {2}".format([
			entry_date["day"],
			$"../..".MONTHS[entry_date["month"] -1],
			entry_date["year"],
			])
		
		var entry_card = entry_card_prld.instantiate()
		entry_card.get_node("Panel/Padding/VBoxContainer/Title").text = entry_date_text
		entry_card.get_node("Panel/Padding/VBoxContainer/Mood").text = entry_card.get_node("Panel/Padding/VBoxContainer/Mood").text.format([i["mood"]])
		entry_card.get_node("Panel/Padding/VBoxContainer/Triggers").text = entry_card.get_node("Panel/Padding/VBoxContainer/Triggers").text.format([i["triggers"]])
		entry_card.get_node("Panel/Padding/VBoxContainer/Notes").text = i["note"]
		list.add_child(entry_card)

func _on_main_update_entries() -> void:
	update_journal()
