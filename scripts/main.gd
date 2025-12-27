extends Control

@onready var import_dialog: FileDialog = $ImportDB
@onready var export_dialog: FileDialog = $ExportDB

const MONTHS = [ "январь", "февраль", "март", "апрель", "май",
	"июнь", "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"]
var db: SQLite

signal db_initilized
signal update_entries

func _ready() -> void:
	import_dialog.file_selected.connect(func(src_path):
		var dst_path = "user://data.db"

		var src := FileAccess.open(src_path, FileAccess.READ)
		if src == null:
			$Hint.show_hint("Не удалось открыть исходный файл")
			return
		
		db.close_db()

		var dst := FileAccess.open(dst_path, FileAccess.WRITE)
		if dst == null:
			$Hint.show_hint("Не удалось создать файл в user://")
			return

		dst.store_buffer(src.get_buffer(src.get_length()))

		src.close()
		dst.close()

		$Hint.show_hint("Данные импортированы!")
		
		init_db()
	)
	export_dialog.file_selected.connect(func(dst_path):
		var src := FileAccess.open("user://data.db", FileAccess.READ)
		if src == null:
			$Hint.show_hint("Не удалось открыть data.db")
			return

		var dst := FileAccess.open(dst_path, FileAccess.WRITE)
		if dst == null:
			$Hint.show_hint("Не удалось сохранить файл")
			return

		dst.store_buffer(src.get_buffer(src.get_length()))

		src.close()
		dst.close()

		$Hint.show_hint("Экспорт завершён:", dst_path)
	)
	init_db()

func init_db():
	db = SQLite.new()
	db.path = "user://data.db"
	db.open_db()
	first_run_create_all()
	emit_signal("db_initilized")
	emit_signal("update_entries")

func first_run_create_all():
	var query_string = "-- Записи
		CREATE TABLE IF NOT EXISTS entries (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			mood INTEGER NOT NULL,
			note TEXT NOT NULL,
			created_at DATE DEFAULT (date('now','localtime')) UNIQUE
		);

		-- Уникальные триггеры (с нечувствительностью к регистру)
		CREATE TABLE IF NOT EXISTS triggers (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL COLLATE NOCASE UNIQUE
		);

		-- Связь многие-ко-многим
		CREATE TABLE IF NOT EXISTS entry_triggers (
		  entry_id INTEGER NOT NULL,
		  trigger_id  INTEGER NOT NULL,
		  PRIMARY KEY (entry_id, trigger_id),
		  FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE,
		  FOREIGN KEY (trigger_id)  REFERENCES triggers(id)  ON DELETE CASCADE
		);

		-- Индексы для быстрого поиска
		CREATE INDEX IF NOT EXISTS idx_entry_trigger_tag_id  ON entry_triggers(trigger_id);
		CREATE INDEX IF NOT EXISTS idx_entry_triggers_entry_id ON entry_triggers(entry_id);
		CREATE INDEX IF NOT EXISTS idx_entries_created_at    ON entries(created_at);
	"
	db.query(query_string)


func _on_import_pressed() -> void:
	import_dialog.popup_centered()


func _on_export_pressed() -> void:
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.popup_centered()
