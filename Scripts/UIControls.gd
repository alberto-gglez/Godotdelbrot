extends VBoxContainer
class_name UIControls

enum DrawState { CLEARED, STARTED, STOPPED }
enum Orientation { DRAW_HORIZONTAL, DRAW_VERTICAL }

var processor_count := OS.get_processor_count()
var start_time : int
var current_state := DrawState.CLEARED
var ui_enabled := true

@onready var color_list := preload("res://Scripts/Palettes.gd").new().palettes

@onready var thread_number_button := %ThreadNumberOptionButton
@onready var thread_priority_button := %PriorityOptionButton
@onready var work_subdivision_checkbox := %WorkSubdivisionCheckBox

@onready var iterations_slider := %IterationsHSlider
@onready var iterations_label := %IterationsLabel
@onready var iterations_label_text : String = iterations_label.text
@onready var orientation_button := %OrientationOptionButton
@onready var refresh_checkbox := %EnableRefreshCheckBox
@onready var refresh_slider := %RefreshHSlider
@onready var refresh_label := %RefreshLabel
@onready var refresh_label_text : String = refresh_label.text
@onready var time_label := %TimeLabel
@onready var time_label_text : String = time_label.text
@onready var image_side_button := %ImageSideOptionButton
@onready var dynamic_side_item_id : int = image_side_button.get_item_id(0)
@onready var image_side_button_text : String = \
	image_side_button.get_item_text(dynamic_side_item_id)

@onready var start_button := %StartButton
@onready var time_timer := $TimeTimer

signal start_pressed(action: DrawState)
signal refresh_changed(value: float)

func _ready() -> void:
	iterations_slider.value = iterations_slider.min_value
	iterations_label.text = iterations_label_text % iterations_slider.value
	iterations_slider.value_changed.connect(
		func(value: float) -> void:
			iterations_label.text = iterations_label_text % value
			)
	iterations_slider.drag_ended.connect(
		func(value_changed: bool) -> void:
			if value_changed:
				refresh_changed.emit(iterations_slider.value)
			)
	
	orientation_button.add_item("Horizontal", Orientation.DRAW_HORIZONTAL)
	orientation_button.add_item("Vertical", Orientation.DRAW_VERTICAL)
	orientation_button.selected = Orientation.DRAW_HORIZONTAL
	
	refresh_checkbox.toggled.connect(
		func(is_checked: bool) -> void:
			refresh_slider.editable = is_checked
			refresh_label.modulate = Color.WHITE if is_checked else Color(1, 1, 1, 0.5)
			)
	
	for i in range(processor_count):
		thread_number_button.add_item(str(i + 1))
	thread_number_button.select(processor_count - 1)
	
	thread_priority_button.add_item("Low", Thread.PRIORITY_LOW)
	thread_priority_button.add_item("Normal", Thread.PRIORITY_NORMAL)
	thread_priority_button.add_item("High", Thread.PRIORITY_HIGH)
	thread_priority_button.selected = Thread.PRIORITY_NORMAL
	
	refresh_slider.value = refresh_slider.min_value
	refresh_label.text = refresh_label_text % refresh_slider.value
	refresh_slider.value_changed.connect(
		func(value: float) -> void:
			refresh_label.text = refresh_label_text % value
			)
	refresh_slider.drag_ended.connect(
		func(value_changed: bool) -> void:
			if value_changed:
				refresh_changed.emit(refresh_slider.value)
			)
	
	image_side_button.select(dynamic_side_item_id)
	
	time_label.text = time_label_text % get_time_parts(0)
	start_button.button_down.connect(next_state)
	time_timer.timeout.connect(update_timer)
	time_timer.paused = true

func next_state() -> void:
	match current_state:
		DrawState.CLEARED:
			disable()
			start()
			current_state = DrawState.STARTED
		DrawState.STARTED:
			enable()
			stop()
			current_state = DrawState.STOPPED
		DrawState.STOPPED:
			start_button.text = "Restart"
			time_label.text = time_label_text % get_time_parts(0)
			current_state = DrawState.CLEARED
	start_pressed.emit(current_state)

func update_timer() -> void:
	time_label.text = time_label_text % get_time_parts(Time.get_ticks_msec() - start_time)
	start_button.text = "Stop"

func start() -> void:
	start_time = Time.get_ticks_msec()
	start_button.text = "Stop"
	time_label.text = time_label_text % get_time_parts(0)
	time_timer.paused = false
	time_timer.start()

func stop() -> void:
	time_timer.stop()
	time_label.text = time_label_text % get_time_parts(Time.get_ticks_msec() - start_time)
	start_button.text = "Clear"
	start_button.disabled = false

func image_side_changed(imageSide: int) -> void:
	image_side_button.set_item_text(dynamic_side_item_id, image_side_button_text % imageSide)

func get_current_state() -> int:
	return current_state

func enable() -> void:
	for node in find_children("*", "BaseButton"):
		if node != start_button:
			(node as BaseButton).disabled = false
	ui_enabled = true

func disable() -> void:
	for node in find_children("*", "BaseButton"):
		if node != start_button:
			(node as BaseButton).disabled = true
	ui_enabled = false

static func get_time_parts(duration: int) -> Array[int]:
	var milis := duration % 1000
	var rest := duration / 1000
	var seconds := rest % 60
	rest /= 60
	var minutes := rest % 60
	return [rest / 60, minutes, seconds, milis]
