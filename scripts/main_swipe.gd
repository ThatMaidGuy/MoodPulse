extends "res://scripts/main.gd"

signal page_changed(page_index)

@export_node_path var screens_path: NodePath = "Screens"
@export_node_path var bottom_tabs_path: NodePath = "BottomTabs"

@export var swipe_speed := 8.0           # для затухания инерции
@export var min_swipe_distance := 0.18   # доля ширины для перелистывания
@export var velocity_threshold := 450.0  # px/s для перелистывания по инерции

var screens: Control
var bottom_tabs: Node

var page_count := 0
var page_index := 0

# drag / inertia
var dragging := false
var drag_start_pos := Vector2.ZERO
var content_start_x := 0.0

var pointer_pos := Vector2.ZERO       # текущая позиция пальца/мыши
var last_pointer_pos := Vector2.ZERO  # позиция в прошлом кадре
var velocity := 0.0                   # px/s

func _ready():
	screens = get_node(screens_path)
	bottom_tabs = get_node_or_null(bottom_tabs_path)
	if bottom_tabs and bottom_tabs.has_signal("tab_pressed"):
		bottom_tabs.connect("tab_pressed", Callable(self, "on_bottom_tab_pressed"))
	page_count = screens.get_child_count()
	_setup_pages()
	_snap_to_page(page_index, true)

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_setup_pages()
		_snap_to_page(page_index, true)

func _setup_pages():
	var vp_size := get_viewport().get_visible_rect().size
	var w := vp_size.x
	var h := vp_size.y
	for i in range(page_count):
		var child = screens.get_child(i)
		if child is Control:
			child.position = Vector2(i * w, 0)
			child.size = Vector2(w, h)
	# установим ширину контейнера (чтобы позиционирование работало корректно)
	screens.size = Vector2(page_count * w, h)

# --------- INPUT ----------
func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventScreenDrag:
		_on_drag(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position)
			else:
				_end_drag()
	elif event is InputEventMouseMotion and dragging:
		_on_drag(event.position)

func _start_drag(pos: Vector2):
	# остановить активный твин если есть
	_stop_all_tweens()
	dragging = true
	drag_start_pos = pos
	content_start_x = screens.position.x
	pointer_pos = pos
	last_pointer_pos = pos
	velocity = 0.0

func _on_drag(pos: Vector2):
	pointer_pos = pos
	# сразу применяем позицию, чтобы сенс ощущался живым
	var dx = pos.x - drag_start_pos.x
	var new_x = content_start_x + dx
	# резина на концах
	var w = get_viewport().get_visible_rect().size.x
	var min_x = - (page_count - 1) * w
	if new_x > 0:
		new_x = new_x * 0.45
	elif new_x < min_x:
		new_x = min_x + (new_x - min_x) * 0.45
	screens.position = Vector2(new_x, screens.position.y)
	_update_bottom_tabs_preview()

func _end_drag():
	dragging = false
	_determine_target_page_and_snap()

# --------- PROCESS (dt) ----------
func _process(delta: float) -> void:
	if dragging:
		# считаем скорость по перемещению между кадрами
		var dx = pointer_pos.x - last_pointer_pos.x
		if delta > 0:
			velocity = dx / delta
		last_pointer_pos = pointer_pos
	else:
		# инерция
		if abs(velocity) > 1.0:
			# сместим экран на velocity * delta пикселей
			var new_x = screens.position.x + velocity * delta
			# ограничение края (полезно для контроля)
			var w = get_viewport().get_visible_rect().size.x
			var min_x = - (page_count - 1) * w
			if new_x > 0:
				new_x = new_x * 0.95
				velocity *= 0.6
			elif new_x < min_x:
				new_x = min_x + (new_x - min_x) * 0.95
				velocity *= 0.6
			screens.position = Vector2(new_x, screens.position.y)
			# гасим скорость плавно
			velocity = lerp(velocity, 0.0, clamp(delta * swipe_speed, 0.0, 1.0))
	# при окончании инерции, если скорость почти нулевая, можно снэпнуть к странице (если не в процессе твина)
	# но мы снэпим только при отпускании, чтобы не дергать пользователя

# --------- SNAP DECISION ----------
func _determine_target_page_and_snap():
	var w = get_viewport().get_visible_rect().size.x
	var prog = clamp(-screens.position.x / w, 0.0, page_count - 1)
	var rounded = int(round(prog))
	# delta от текущей страницы
	var delta_px = screens.position.x - (-page_index * w)
	var distance_frac = abs(delta_px) / w
	var new_index := page_index

	if distance_frac > min_swipe_distance:
		if delta_px < 0:
			new_index = clamp(page_index + 1, 0, page_count - 1)
		else:
			new_index = clamp(page_index - 1, 0, page_count - 1)
	else:
		# если скорость большая — перелистываем по инерции
		if abs(velocity) > velocity_threshold:
			if velocity < 0:
				new_index = clamp(page_index + 1, 0, page_count - 1)
			else:
				new_index = clamp(page_index - 1, 0, page_count - 1)
		else:
			new_index = clamp(rounded, 0, page_count - 1)

	_go_to_page(new_index)

func _go_to_page(index:int):
	index = clamp(index, 0, page_count - 1)
	page_index = index
	_snap_to_page(index, false)
	emit_signal("page_changed", page_index)

func _snap_to_page(index:int, instant:bool=false):
	var w = get_viewport().get_visible_rect().size.x
	var target_x = -index * w
	_stop_all_tweens()
	if instant:
		screens.position = Vector2(target_x, screens.position.y)
		velocity = 0.0
	else:
		var tween = create_tween()
		tween.tween_property(screens, "position:x", target_x, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(Callable(self, "_on_snap_done"))

func _on_snap_done():
	velocity = 0.0
	_update_bottom_tabs_selection()

# --------- BottomTabs helpers ----------
func _update_bottom_tabs_selection():
	if bottom_tabs:
		if bottom_tabs.has_method("select"):
			bottom_tabs.call("select", page_index)

func _update_bottom_tabs_preview():
	if bottom_tabs and bottom_tabs.has_method("preview"):
		var w = get_viewport().get_visible_rect().size.x
		var frac = clamp(-screens.position.x / w, 0.0, float(page_count - 1))
		bottom_tabs.call("preview", frac)

func on_bottom_tab_pressed(index:int):
	_go_to_page(index)

func _stop_all_tweens():
	# простая остановка всех твинов на этом узле
	for child in get_tree().get_nodes_in_group("scene_tree_tweens"):
		# noop — но гарантируем отсутствие конфликтов; если нужен более жесткий kill, сохраняйте handle твина.
		pass
	# вообще для простоты — можно не делать ничего: create_tween() привязан к узлу и автоматически прерывается при освобождении.
