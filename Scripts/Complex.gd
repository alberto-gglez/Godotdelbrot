class_name Complex

var r : float
var i : float

func _init(r: float, i: float) -> void:
	self.r = r
	self.i = i

func add(other: Complex) -> void:
	r += other.r
	i += other.i

func pow(p: int) -> void:
	if p == 0:
		r = 1
		i = 0
	else:
		var cur_r := r
		var cur_i := i
		
		for n in range(p - 1):
			var new_r := r * cur_r - i * cur_i
			var new_i := r * cur_i + cur_r * i
			r = new_r
			i = new_i

func _to_string() -> String:
	return "(" + str(r) + ", " + str(i) + " i)"
