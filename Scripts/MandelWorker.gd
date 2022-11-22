class_name MandelWorker

var iterations : int
var image_side: int
var range_start: int
var range_end: int
var h_lower_limit : float
var h_step: float
var v_lower_limit : float
var v_step: float
var color_list : Array[String]
var subdivide_work : bool
var get_stop_flag_fn: Callable
var draw_fn : Callable
var request_work_fn : Callable
var get_work_request_flag_fn : Callable
var give_work_fn : Callable

var last_start : int
var last_end : int

func start() -> void:
	if range_start == WorkerLauncher.INVALID_JOB.x || range_end == WorkerLauncher.INVALID_JOB.y:
		return
	if range_start == last_start && range_end == last_end:
		print_debug("!!!! NOPE")
		return
	
	print_debug("Worker starting with range [%d, %d)" % [range_start, range_end])
	var im := range_start
	while im < range_end:
		if get_stop_flag_fn.call():
			break
		
		for r in range(image_side):
			if get_stop_flag_fn.call():
				break
			
			var c := Complex.new(h_lower_limit + r * h_step, v_lower_limit + im * v_step)
			var temp := Complex.new(0, 0)
#			
			var i := 0
			while temp.r * temp.r + temp.i * temp.i < 4 && i < iterations:
				temp.pow(2)
				temp.add(c)
				i += 1
			
			if i == iterations:
				i -= 1
			
			draw_fn.call_deferred(r, im, Color(color_list[i]))
			
			if subdivide_work && range_end - im > 4 && get_work_request_flag_fn.call():
				var first_half := im + (range_end - im) / 2
				if give_work_fn.call(Vector2i(first_half, range_end)):
					range_end = first_half
		
		im += 1
	
	if subdivide_work && !get_stop_flag_fn.call():
		last_start = range_start
		last_end = range_end
		var new_range : Vector2i = request_work_fn.call()
		range_start = new_range.x
		range_end = new_range.y
		start()
	
	print_debug("Worker exiting")
