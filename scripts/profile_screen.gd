extends Control

const CONFIG_PATH := "user://settings.cfg"
const MORNING_ID := 2001
const EVENING_ID := 2002

var cfg := ConfigFile.new()
var notifications_enabled := false
var permission_requested := false

@onready var notify_btn = $body/VBoxContainer/VBoxContainer/Notifications/Panel/Padding/VBoxContainer/NotifyEnable
@onready var scheduler: NotificationScheduler = $"../../NotificationScheduler"
@onready var hint_label := $"../../Hint"

func _ready() -> void:
	# загрузить настройки (если есть)
	var err = cfg.load(CONFIG_PATH)
	if err == OK:
		notifications_enabled = bool(cfg.get_value("notifications", "enabled", false))
		permission_requested = bool(cfg.get_value("notifications", "permission_requested", false))
	else:
		notifications_enabled = false
		permission_requested = false

	# установить состояние переключателя (не трогаем разрешение здесь)
	notify_btn.button_pressed = notifications_enabled

	# подключаем сигналы плагина/кнопки
	scheduler.connect("initialization_completed", Callable(self, "_on_scheduler_init"))
	scheduler.connect("post_notifications_permission_granted", Callable(self, "_on_perm_granted"))
	scheduler.connect("post_notifications_permission_denied", Callable(self, "_on_perm_denied"))
	notify_btn.connect("toggled", Callable(self, "_on_toggle_toggled"))

	# Инициализировать плагин (не вызывает запрос разрешений сам по себе)
	scheduler.initialize()


func _on_scheduler_init() -> void:
	print("!!!!!!!!!!! Initilized !!!!!!!!!!!")
	# можно здесь заранее создать канал для Android (необязательно)
	# пример:
	# var ch = NotificationChannel.new().set_id("reminders").set_name("Reminders").set_description("Reminders").set_importance(NotificationChannel.Importance.DEFAULT)
	# scheduler.create_notification_channel(ch)
	

func _on_toggle_toggled(pressed: bool) -> void:
	if pressed:
		# юзер хочет включить уведомления
		if scheduler.has_post_notifications_permission():
			_enable_notifications()
		else:
			if not permission_requested:
				# первый раз — запрашиваем разрешение
				permission_requested = true
				_save_config()
				# показываем пользователю короткое сообщение (опционально)
				hint_label.show_hint("Запрашиваем разрешение на отправку уведомлений...")
				scheduler.request_post_notifications_permission()
				# после результата (grant/deny) придут соответствующие сигналы
			else:
				# Разрешение уже запрашивали ранее и его, очевидно, нет -> вернуть тумблер в OFF и подсказать
				notify_btn.button_pressed = false
				hint_label.show_hint("Уведомления заблокированы системой. Разрешите их в настройках приложения.")
	else:
		# юзер выключил — отменяем запланированные уведомления и сохраняем
		_disable_notifications()

# Сигналы от плагина
func _on_perm_granted(permission_name: String) -> void:
	hint_label.show_hint("Разрешение на уведомления получено.")
	_enable_notifications()

func _on_perm_denied(permission_name: String) -> void:
	# если отказали — возвращаем переключатель в OFF и сохраняем
	notify_btn.button_pressed = false
	notifications_enabled = false
	_save_config()
	hint_label.show_hint("Разрешение на уведомления отклонено. Чтобы включить — разрешите в настройках устройства.")

# Включение/отключение — адаптируйте логику под своё приложение
func _enable_notifications() -> void:
	notifications_enabled = true
	_save_config()
	hint_label.show_hint("Уведомления включены.")
	schedule_daily_notifications()

func _disable_notifications() -> void:
	notifications_enabled = false
	_save_config()
	hint_label.show_hint("Уведомления отключены.")
	# пример отмены тестового уведомления (если вы используете отдельные id — отменяйте их)
	cancel_daily_notifications()


func cancel_daily_notifications():
	scheduler.cancel(MORNING_ID)
	scheduler.cancel(EVENING_ID)


func schedule_daily_notifications():
	# УТРО
	var morning_delay := get_next_time(9, 0)
	var morning = NotificationData.new() \
		.set_id(MORNING_ID) \
		.set_channel_id("reminders") \
		.set_title("Доброе утро ☀️") \
		.set_content("Как ты себя чувствуешь сегодня?") \
		.set_delay(morning_delay) \
		.set_interval(24 * 60 * 60) # <- вот правильный метод
	var r1 = scheduler.schedule(morning)
	if r1 != OK:
		push_warning("schedule(morning) вернул: %s" % str(r1))
	
	# ВЕЧЕР
	var evening_delay := get_next_time(21, 0)
	var evening = NotificationData.new() \
		.set_id(EVENING_ID) \
		.set_channel_id("reminders") \
		.set_title("Добрый вечер 🌙") \
		.set_content("Как прошёл день?") \
		.set_delay(evening_delay) \
		.set_interval(24 * 60 * 60) # <- тоже
	var r2 = scheduler.schedule(evening)
	if r2 != OK:
		push_warning("schedule(evening) вернул: %s" % str(r2))


# Вспомогательные: сохраняем конфиг
func _save_config() -> void:
	cfg.set_value("notifications", "enabled", notifications_enabled)
	cfg.set_value("notifications", "permission_requested", permission_requested)
	var err = cfg.save(CONFIG_PATH)
	if err != OK:
		push_error("Не удалось сохранить конфиг: %s" % str(err))


func get_next_time(hour: int, minute: int) -> int:
	var now := Time.get_datetime_dict_from_system()
	var target := now.duplicate()
	
	target.hour = hour
	target.minute = minute
	target.second = 0
	
	var now_unix := Time.get_unix_time_from_datetime_dict(now)
	var target_unix := Time.get_unix_time_from_datetime_dict(target)
	
	# если время сегодня уже прошло — берём завтра
	if target_unix <= now_unix:
		target_unix += 24 * 60 * 60
	
	return int(target_unix - now_unix) # задержка в секундах
