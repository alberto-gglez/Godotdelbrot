class_name WorkerLauncher

const ITERATIONS := 200
const H_LOWER_LIMIT := -2.0
const H_UPPER_LIMIT := 0.47
const V_LOWER_LIMIT := -1.3
const V_UPPER_LIMIT := 1.3
const INVALID_JOB := Vector2i(-999, -999)
const WORK_WAIT_DELTA := 0.05
const MAX_WAIT_FOR_WORK := 0.2

var threads : Array[Thread]
var threads_started := false
var stop_threads := false
var image_side : int
var thread_number : int
var thread_priority : Thread.Priority
var subdivide_work : bool
var color_list : Array[String]
var draw_fn : Callable
var finish_fn : Callable
var get_stop_flag_fn : Callable
var next_job := INVALID_JOB
var give_work_mutex := Mutex.new()
var request_work_mutex := Mutex.new()
var work_request_flag := false
var work_given_flag := false

func _init(
	imageSide: int,
	threadNumber: int,
	priority: Thread.Priority,
	subdivideWork: bool,
	colors: Array[String],
	drawFn: Callable,
	finishFn: Callable,
	getStopFlagFn: Callable
	) -> void:
		image_side = imageSide
		thread_number = threadNumber
		thread_priority = priority
		subdivide_work = subdivideWork
		color_list = colors
		draw_fn = drawFn
		finish_fn = finishFn
		get_stop_flag_fn = getStopFlagFn

func start() -> void:
	var rows_per_thread := image_side / thread_number
	var h_step = (V_UPPER_LIMIT - V_LOWER_LIMIT) / image_side
	var v_step = (H_UPPER_LIMIT - H_LOWER_LIMIT) / image_side
	
	print_debug("Starting all threads. thread_number: %s, rows_per_thread: %s"
		% [thread_number, rows_per_thread])
	
	# Workaround to avoid lost references
	var workers : Array[MandelWorker]
	
	for i in range(thread_number):
		var worker := MandelWorker.new()
		worker.iterations = ITERATIONS
		worker.image_side = image_side
		worker.range_start = i * rows_per_thread
		worker.range_end = image_side if i == thread_number - 1 else (i + 1) * rows_per_thread
		worker.h_lower_limit = H_LOWER_LIMIT
		worker.h_step = h_step
		worker.v_lower_limit = V_LOWER_LIMIT
		worker.v_step = v_step
		worker.color_list = color_list
		worker.subdivide_work = subdivide_work
		worker.get_stop_flag_fn = get_stop_flag_fn
		worker.draw_fn = draw_fn
		worker.request_work_fn = Callable(self, "request_work")
		worker.get_work_request_flag_fn = Callable(self, "get_work_request_flag")
		worker.give_work_fn = Callable(self, "give_work")
		workers.push_back(worker)
		
		var new_thread := Thread.new()
		threads.push_back(new_thread)
		new_thread.start(Callable(worker, "start"), thread_priority)

	print_debug("Calling join_threads")
	join_threads()

func join_threads() -> void:
	for thread in threads:
		thread.wait_to_finish()
	finish_fn.call_deferred()

func request_work() -> Vector2i:
	print_debug("Worker locking request_work_mutex")
	var elapsed := 0.0
	while request_work_mutex.try_lock() == ERR_BUSY:
		OS.delay_msec(1000 * WORK_WAIT_DELTA)
		elapsed += WORK_WAIT_DELTA
		if elapsed >= MAX_WAIT_FOR_WORK || get_stop_flag_fn.call():
			request_work_mutex.unlock()
			return INVALID_JOB
	print_debug("Worker requesting work")
	elapsed = 0.0
	var row_span : Vector2i
	
	work_given_flag = false
	work_request_flag = true
	
	print_debug("waiting for work_given_flag")
	while !work_given_flag:
		OS.delay_msec(1000 * WORK_WAIT_DELTA)
		elapsed += WORK_WAIT_DELTA
		if elapsed >= MAX_WAIT_FOR_WORK || get_stop_flag_fn.call():
			print("unlocking request_work_mutex")
			request_work_mutex.unlock()
			return INVALID_JOB
	print_debug("work received")
	
	row_span = next_job
	next_job = INVALID_JOB
	
	request_work_mutex.unlock()
	return row_span

func get_work_request_flag() -> bool:
	return work_request_flag

func give_work(rowSpan: Vector2i) -> bool:
	var result := false
	if give_work_mutex.try_lock() == OK:
		print_debug("Worker giving work")
		next_job = rowSpan
		work_request_flag = false
		work_given_flag = true
		give_work_mutex.unlock()
		result = true
		print_debug("Worker done giving work")
	return result
