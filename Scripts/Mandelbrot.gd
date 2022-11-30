#
# ToDo:
# - Reimplement thread signals
# - Disable UI on start
# - Implement state machine for DrawState
# - Generate color gradient and let the user select the number of iterations
# - Implement optimized complex number calculations (don't use the class; merge the operations) + UI
# - Replace timers with a thread (see the warning icon in the timer) ?
# - Zoom level
# - Keep top times
# - Refactor into some scenes (3/n)
#
# - Implement GPU rendering
#

extends Node2D
class_name Mandelbrot

const IMAGE_MARGIN := 20

var image_side : int
var stop_flag := false
var image : Image
var worker_launcher : WorkerLauncher
var worker_launcher_thread : Thread
var orientation : UIControls.Orientation

@onready var color_list : Array[String] = preload("res://Scripts/Colors.gd").new().colors
@onready var main_ui_control := %MainUIControl
@onready var ui_controls := %UIControls
@onready var paint_timer := $PaintTimer
@onready var texture_panel := %TexturePanel
@onready var image_texture : ImageTexture = %TextureRect.texture

signal finished
signal image_side_changed(imageSide: int)

func _ready() -> void:
	image_side = texture_panel.size[texture_panel.size.min_axis_index()] - IMAGE_MARGIN
	image = Image.create(image_side, image_side, false, Image.FORMAT_RGBA8)
	
	ui_controls.start_pressed.connect(set_state)
	ui_controls.refresh_changed.connect(
		func(value: float) -> void:
			paint_timer.start(value)
			)
	
	finished.connect(ui_controls.next_state)
	image_side_changed.connect(ui_controls.image_side_changed)
	
	get_tree().get_root().size_changed.connect(update_ui_size)
	update_ui_size()
	resize_image(true)
	
	paint_timer.timeout.connect(update_image)
	paint_timer.paused = true

func update_ui_size() -> void:
	main_ui_control.set_size(get_viewport_rect().size)
	if ui_controls.get_current_state() == UIControls.DrawState.CLEARED:
		resize_image(false, true)

func set_state(action: UIControls.DrawState) -> void:
	match action:
		UIControls.DrawState.STARTED:
			resize_image(true)
			draw_start()
		UIControls.DrawState.STOPPED:
			stop_flag = true
			clear_state()
		UIControls.DrawState.CLEARED:
			resize_image(true)

func resize_image(fill: bool = false, awaitTextureUpdate: bool = false) -> void:
	if awaitTextureUpdate:
		await texture_panel.resized
	image_side = texture_panel.size[texture_panel.size.min_axis_index()] - IMAGE_MARGIN
	image.resize(image_side, image_side)
	image_side_changed.emit(image_side)
	if fill:
		image.fill(Color.GRAY)
	update_image()

func draw_start() -> void:
	orientation = ui_controls.orientation_button.get_selected_id()
	
	print_debug("Starting with image_side = %d" % image_side)
	
	worker_launcher = WorkerLauncher.new(
		image_side,
		ui_controls.thread_number_button.get_selected_id() + 1,
		ui_controls.thread_priority_button.get_selected_id(),
		ui_controls.work_subdivision_checkbox.button_pressed,
		color_list,
		Callable(self, "draw_pixel_horizontal")
			if orientation == UIControls.Orientation.DRAW_HORIZONTAL
			else Callable(self, "draw_pixel_vertical"),
		Callable(self, "threads_finished"),
		Callable(self, "get_stop_flag")
		)
	worker_launcher_thread = Thread.new()
	worker_launcher_thread.start(Callable(worker_launcher, "start"))
	
	if ui_controls.refresh_checkbox.is_pressed():
		paint_timer.paused = false
		paint_timer.start(ui_controls.refresh_slider.value)

func get_stop_flag() -> bool:
	return stop_flag

func draw_pixel_horizontal(r: float, im: float, c: Color) -> void:
	image.set_pixel(r, im, c)

func draw_pixel_vertical(r: float, im: float, c: Color) -> void:
	image.set_pixel(im, r, c)

func update_image() -> void:
	image_texture.set_image(image)

func threads_finished() -> void:
	if ui_controls.get_current_state() == UIControls.DrawState.STARTED:
		finished.emit()

func clear_state() -> void:
	worker_launcher_thread.wait_to_finish()
	stop_flag = false
	paint_timer.stop()
	image_texture.set_image(image)
