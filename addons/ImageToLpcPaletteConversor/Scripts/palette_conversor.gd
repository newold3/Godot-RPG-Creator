@tool
class_name PaletteConverter
extends Node

@export var color_palette: PackedColorArray = []

# LPC palette in hexadecimal
var palette_hex = [
	"#000000", "#0F1218", "#251F25", "#382B33", "#52414B", "#5B4F55", "#6F6464", "#958080", "#AD988E", "#C4B59F",
	"#D8D4C0", "#E3E7D3", "#1B192B", "#29253A", "#343043", "#4B4B60", "#595E70", "#6A7587", "#819097", "#A8B3B8",
	"#C7CFCC", "#FFFFFF", "#484152", "#726B7E", "#867E7F", "#2A1722", "#EBEDE9", "#99423C", "#CC8665", "#E4A47C",
	"#F9D5BA", "#FAECE7", "#1A1213", "#2E1F1C", "#442527", "#603429", "#6B3C2E", "#7F4C31", "#644133", "#965B38",
	"#AE6B3F", "#C07A4B", "#946B44", "#A2794B", "#AD844F", "#BF9D5B", "#CCAF64", "#8B7949", "#3E111A", "#591515",
	"#6A1D16", "#7B2008", "#642600", "#C7341B", "#95381C", "#B54936", "#CD543D", "#BF4000", "#E56010", "#FF8A00",
	"#C3511A", "#EB7127", "#E95A4D", "#EC7456", "#FF8C68", "#FFB186", "#5E3349", "#914D68", "#A1626B", "#AE7711",
	"#BE9694", "#D9ADA9", "#481945", "#792A53", "#BD5169", "#EF747E", "#F78F8A", "#FFAD97", "#5E2043", "#AA3A6A",
	"#4C3B64", "#655789", "#7C6EA6", "#988FBA", "#2C2452", "#3B4290", "#6370C7", "#838AD1", "#A4B0DC", "#D2D8EF",
	"#101025", "#181842", "#1D2560", "#293982", "#324F9A", "#4273C9", "#588DE2", "#6BB3F5", "#4F899D", "#6CA3B3",
	"#8AC0C9", "#A4DDDB", "#BDE6E5", "#D9F0F0", "#0D283E", "#173A55", "#174562", "#18506F", "#1D607B", "#217087",
	"#2A8598", "#3AAFCA", "#6CDCED", "#19332D", "#318229", "#456238", "#5F874D", "#8B6278", "#ADCBA6", "#C1DAC2",
	"#677831", "#A1A03D", "#C7C65A", "#D0DA91", "#D9F1D8", "#1C4525", "#25562E", "#30642F", "#3B732F", "#468232",
	"#3E6115", "#517610", "#5A9A2A", "#7CB82F", "#A8CA58", "#978C02", "#BCA51C", "#DBBD00", "#F0E059", "#F4E48D",
	"#FDF5CC", "#836331", "#AF8A35", "#BFA63F", "#FDD082", "#794117", "#A16018", "#D19428", "#F3C35F", "#CF6F30",
	"#E09C4C", "#F8BC76", "#EECC8C", "#F4D7A0"
]

var color_cache = {}
var palette_lab_cache = {}
var palette_lch_cache = {}
var palette_oklab_cache = {}
var color_tree = {}  # Para búsqueda espacial optimizada

const BUCKET_SIZE = 16  # Reducido para mejor granularidad
const THRESHOLD = 0.01  # Más preciso

# Métodos de conversión mejorados
enum DistanceMethod {
	EUCLIDEAN_RGB,
	WEIGHTED_RGB,       
	OKLAB,             
	LCH,               
	LAB,               
	DELTA_E_76,        
	DELTA_E_94,        
	PERCEPTUAL_HYBRID
}

var distance_method = DistanceMethod.PERCEPTUAL_HYBRID

signal conversion_completed(converted_image: Image)
signal conversion_progress(percentage: float)

var conversion_thread: Thread
var progress: float = 0.0

func _ready():
	if color_palette.is_empty():
		_initialize_palette()
	else:
		_pre_calculate_space_colors()

func clear():
	palette_lab_cache.clear()
	palette_lch_cache.clear()
	palette_oklab_cache.clear()

func set_distance_method(method: DistanceMethod):
	distance_method = method
	color_cache.clear()

func _initialize_palette():
	clear()
	color_palette.clear()
	for hex in palette_hex:
		var c = Color(hex)
		color_palette.append(c)
		
		# Pre-calcular todos los espacios de color
		_rgb_to_lab(c)
		_rgb_to_lch(c)
		_rgb_to_oklab(c)
	
	_build_color_tree()


func _pre_calculate_space_colors() -> void:
	clear()
	for color: Color in color_palette:
		_rgb_to_lab(color)
		_rgb_to_lch(color)
		_rgb_to_oklab(color)
	
	_build_color_tree()

# Construir árbol espacial para búsqueda rápida
func _build_color_tree():
	color_tree.clear()
	
	for i in range(color_palette.size()):
		var c = color_palette[i]
		var r_bucket = int(c.r * 15)  # 16 buckets por canal
		var g_bucket = int(c.g * 15)
		var b_bucket = int(c.b * 15)
		
		var key = "%d_%d_%d" % [r_bucket, g_bucket, b_bucket]
		if not color_tree.has(key):
			color_tree[key] = []
		color_tree[key].append(i)

func convert_image(input: Variant) -> Image:
	progress = 0.0
	var source_image = _get_image_from_input(input)
	if not source_image:
		return null
	
	var result = _process_image_conversion(source_image)
	progress = 1.0
	return result

func convert_image_async(input: Variant):
	if conversion_thread and conversion_thread.is_alive():
		return false
	
	progress = 0.0
	conversion_thread = Thread.new()
	conversion_thread.start(_convert_image_threaded.bind(input))
	return true

func _convert_image_threaded(input: Variant):
	var source_image = _get_image_from_input(input)
	if not source_image:
		call_deferred("_set_progress", 0.0)
		call_deferred("_emit_conversion_completed", null)
		return
	
	var converted_image = _process_image_conversion(source_image)
	call_deferred("_set_progress", 1.0)
	call_deferred("_emit_conversion_completed", converted_image)
	call_deferred("wait_for_conversion")

func _get_image_from_input(input: Variant) -> Image:
	var source_image: Image
	
	if input is String:
		var tex: CompressedTexture2D = load(input)
		if not tex:
			return null
		source_image = tex.get_image()
	elif input is Image:
		source_image = input
	elif input is Texture2D:
		source_image = input.get_image()
	else:
		return null
	
	if source_image.is_compressed():
		source_image.decompress()
	
	return source_image

func _process_image_conversion(source_image: Image) -> Image:
	var converted_image = source_image.duplicate()
	
	var total_pixels = converted_image.get_width() * converted_image.get_height()
	var processed_pixels = 0
	
	for y in converted_image.get_height():
		for x in converted_image.get_width():
			var orig = converted_image.get_pixel(x, y)
			var key = _rgb_key(orig)
			var closest: Color
			
			if color_cache.has(key):
				closest = color_cache[key]
			else:
				closest = _find_closest_color_fast(orig)
				color_cache[key] = closest
			
			converted_image.set_pixel(x, y, Color(closest.r, closest.g, closest.b, orig.a))
			
			processed_pixels += 1
			if processed_pixels % 500 == 0:  # Menos frecuencia de updates
				var current_progress = float(processed_pixels) / float(total_pixels)
				call_deferred("_set_progress", current_progress)
				if conversion_thread and conversion_thread.is_alive():
					call_deferred("_emit_conversion_progress", current_progress)
	
	return converted_image

# Método híbrido ultra-optimizado
func _find_closest_color_fast(c: Color) -> Color:
	match distance_method:
		DistanceMethod.PERCEPTUAL_HYBRID:
			return _find_closest_perceptual_hybrid(c)
		DistanceMethod.OKLAB:
			return _find_closest_oklab(c)
		DistanceMethod.LCH:
			return _find_closest_lch(c)
		DistanceMethod.DELTA_E_94:
			return _find_closest_delta_e94(c)
		_:
			return _find_closest_color_tree_search(c)

# Búsqueda híbrida perceptual - RECOMENDADO
func _find_closest_perceptual_hybrid(c: Color) -> Color:
	var candidates = _get_spatial_candidates(c, 2)  # Buscar en radio de 2 buckets
	
	if candidates.is_empty():
		candidates = range(color_palette.size())
	
	var min_dist = INF
	var closest_idx = 0
	
	# Primera pasada: filtro rápido con weighted RGB
	var pre_candidates = []
	var threshold = 0.15
	
	for idx in candidates:
		var p = color_palette[idx]
		var dist = _weighted_rgb_distance_fast(c, p)
		if dist < threshold:
			pre_candidates.append([idx, dist])
	
	# Si hay pocos candidatos, usar todos
	if pre_candidates.size() < 5:
		pre_candidates.clear()
		for idx in candidates:
			var p = color_palette[idx]
			var dist = _weighted_rgb_distance_fast(c, p)
			pre_candidates.append([idx, dist])
		pre_candidates.sort_custom(func(a, b): return a[1] < b[1])
		pre_candidates = pre_candidates.slice(0, min(15, pre_candidates.size()))
	
	# Segunda pasada: OKLab en mejores candidatos
	for candidate in pre_candidates:
		var idx = candidate[0]
		var p = color_palette[idx]
		var dist = _oklab_distance(c, p)
		if dist < min_dist:
			min_dist = dist
			closest_idx = idx
	
	return color_palette[closest_idx]

# Búsqueda espacial en árbol
func _get_spatial_candidates(c: Color, radius: int = 1) -> Array:
	var candidates = []
	var r_center = int(c.r * 15)
	var g_center = int(c.g * 15)
	var b_center = int(c.b * 15)
	
	for r in range(max(0, r_center - radius), min(16, r_center + radius + 1)):
		for g in range(max(0, g_center - radius), min(16, g_center + radius + 1)):
			for b in range(max(0, b_center - radius), min(16, b_center + radius + 1)):
				var key = "%d_%d_%d" % [r, g, b]
				if color_tree.has(key):
					candidates.append_array(color_tree[key])
	
	return candidates

func _find_closest_color_tree_search(c: Color) -> Color:
	var candidates = _get_spatial_candidates(c, 1)
	
	if candidates.is_empty():
		return _find_closest_color_bruteforce(c)
	
	var min_dist = INF
	var closest_idx = 0
	
	for idx in candidates:
		var p = color_palette[idx]
		var dist = _color_distance(c, p)
		if dist < min_dist:
			min_dist = dist
			closest_idx = idx
	
	return color_palette[closest_idx]

func _find_closest_color_bruteforce(c: Color) -> Color:
	var min_dist = INF
	var closest = color_palette[0]
	
	for p in color_palette:
		var d = _color_distance(c, p)
		if d < min_dist:
			min_dist = d
			closest = p
			if d < THRESHOLD:
				break
	
	return closest

func _find_closest_oklab(c: Color) -> Color:
	var candidates = _get_spatial_candidates(c, 1)
	if candidates.is_empty():
		candidates = range(color_palette.size())
	
	var min_dist = INF
	var closest_idx = 0
	
	for idx in candidates:
		var p = color_palette[idx]
		var dist = _oklab_distance(c, p)
		if dist < min_dist:
			min_dist = dist
			closest_idx = idx
	
	return color_palette[closest_idx]

func _find_closest_lch(c: Color) -> Color:
	var candidates = _get_spatial_candidates(c, 1)
	if candidates.is_empty():
		candidates = range(color_palette.size())
	
	var min_dist = INF
	var closest_idx = 0
	
	for idx in candidates:
		var p = color_palette[idx]
		var dist = _lch_distance(c, p)
		if dist < min_dist:
			min_dist = dist
			closest_idx = idx
	
	return color_palette[closest_idx]

func _find_closest_delta_e94(c: Color) -> Color:
	var candidates = _get_spatial_candidates(c, 1)
	if candidates.is_empty():
		candidates = range(color_palette.size())
	
	var min_dist = INF
	var closest_idx = 0
	
	for idx in candidates:
		var p = color_palette[idx]
		var dist = _delta_e_94(c, p)
		if dist < min_dist:
			min_dist = dist
			closest_idx = idx
	
	return color_palette[closest_idx]

# ==================== FUNCIONES DE DISTANCIA ====================

func _color_distance(c1: Color, c2: Color) -> float:
	match distance_method:
		DistanceMethod.EUCLIDEAN_RGB:
			return _euclidean_rgb_distance(c1, c2)
		DistanceMethod.WEIGHTED_RGB:
			return _weighted_rgb_distance_fast(c1, c2)
		DistanceMethod.LAB:
			return _lab_distance(c1, c2)
		DistanceMethod.LCH:
			return _lch_distance(c1, c2)
		DistanceMethod.OKLAB:
			return _oklab_distance(c1, c2)
		DistanceMethod.DELTA_E_76:
			return _delta_e_76(c1, c2)
		DistanceMethod.DELTA_E_94:
			return _delta_e_94(c1, c2)
		_:
			return _weighted_rgb_distance_fast(c1, c2)

func _euclidean_rgb_distance(c1: Color, c2: Color) -> float:
	var dr = c1.r - c2.r
	var dg = c1.g - c2.g
	var db = c1.b - c2.b
	return dr * dr + dg * dg + db * db

# RGB con pesos perceptuales optimizado
func _weighted_rgb_distance_fast(c1: Color, c2: Color) -> float:
	var dr = c1.r - c2.r
	var dg = c1.g - c2.g
	var db = c1.b - c2.b
	
	# Pesos optimizados para velocidad y precisión
	var r_weight = 0.299
	var g_weight = 0.587
	var b_weight = 0.114
	
	return r_weight * dr * dr + g_weight * dg * dg + b_weight * db * db

# OKLab - más preciso que LAB estándar
func _oklab_distance(c1: Color, c2: Color) -> float:
	var oklab1 = _rgb_to_oklab(c1)
	var oklab2 = _rgb_to_oklab(c2)
	
	var dl = oklab1.x - oklab2.x
	var da = oklab1.y - oklab2.y
	var db = oklab1.z - oklab2.z
	
	return dl * dl + da * da + db * db

func _lch_distance(c1: Color, c2: Color) -> float:
	var lch1 = _rgb_to_lch(c1)
	var lch2 = _rgb_to_lch(c2)
	
	var dl = lch1.x - lch2.x
	var dc = lch1.y - lch2.y
	var dh = lch1.z - lch2.z
	
	# Manejar circularidad del hue
	if abs(dh) > 180:
		dh = 360 - abs(dh)
	
	# Pesos para LCH
	return dl * dl + 0.5 * dc * dc + 0.25 * dh * dh

func _lab_distance(c1: Color, c2: Color) -> float:
	var lab1 = _rgb_to_lab(c1)
	var lab2 = _rgb_to_lab(c2)
	
	var dl = lab1.x - lab2.x
	var da = lab1.y - lab2.y
	var db = lab1.z - lab2.z
	
	return dl * dl + da * da + db * db

func _delta_e_76(c1: Color, c2: Color) -> float:
	return sqrt(_lab_distance(c1, c2))

func _delta_e_94(c1: Color, c2: Color) -> float:
	var lab1 = _rgb_to_lab(c1)
	var lab2 = _rgb_to_lab(c2)
	
	var dl = lab1.x - lab2.x
	var da = lab1.y - lab2.y
	var db = lab1.z - lab2.z
	
	var c1_ab = sqrt(lab1.y * lab1.y + lab1.z * lab1.z)
	var c2_ab = sqrt(lab2.y * lab2.y + lab2.z * lab2.z)
	var dc = c1_ab - c2_ab
	var dh = sqrt(da * da + db * db - dc * dc)
	
	var sl = 1.0
	var sc = 1.0 + 0.045 * c1_ab
	var sh = 1.0 + 0.015 * c1_ab
	
	return sqrt((dl/sl) * (dl/sl) + (dc/sc) * (dc/sc) + (dh/sh) * (dh/sh))

# ==================== CONVERSIONES DE COLOR ====================

func _rgb_to_oklab(c: Color) -> Vector3:
	var key = _rgb_key(c)
	if palette_oklab_cache.has(key):
		return palette_oklab_cache[key]
	
	# Conversión linear RGB
	var r = _gamma_to_linear_precise(c.r)
	var g = _gamma_to_linear_precise(c.g)
	var b = _gamma_to_linear_precise(c.b)
	
	# RGB to OKLab (matriz optimizada)
	var l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
	var m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
	var s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
	
	l = sign(l) * pow(abs(l), 1.0/3.0)
	m = sign(m) * pow(abs(m), 1.0/3.0)
	s = sign(s) * pow(abs(s), 1.0/3.0)
	
	var oklab_l = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
	var oklab_a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
	var oklab_b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	
	var result = Vector3(oklab_l, oklab_a, oklab_b)
	palette_oklab_cache[key] = result
	return result

func _rgb_to_lch(c: Color) -> Vector3:
	var key = _rgb_key(c)
	if palette_lch_cache.has(key):
		return palette_lch_cache[key]
	
	var lab = _rgb_to_lab(c)
	var l = lab.x
	var chroma = sqrt(lab.y * lab.y + lab.z * lab.z)
	var hue = atan2(lab.z, lab.y) * 180.0 / PI
	if hue < 0:
		hue += 360
	
	var result = Vector3(l, chroma, hue)
	palette_lch_cache[key] = result
	return result

func _rgb_to_lab(c: Color) -> Vector3:
	var key = _rgb_key(c)
	if palette_lab_cache.has(key):
		return palette_lab_cache[key]
	
	# Conversión gamma más precisa
	var r = _gamma_to_linear_precise(c.r)
	var g = _gamma_to_linear_precise(c.g)
	var b = _gamma_to_linear_precise(c.b)
	
	# Matriz sRGB D65 optimizada
	var x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
	var y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
	var z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041
	
	# Normalización D65
	x /= 0.95047
	z /= 1.08883
	
	# Función f de LAB optimizada
	x = _lab_f_precise(x)
	y = _lab_f_precise(y)
	z = _lab_f_precise(z)
	
	var l = 116.0 * y - 16.0
	var a = 500.0 * (x - y)
	var b_lab = 200.0 * (y - z)
	
	var result = Vector3(l, a, b_lab)
	palette_lab_cache[key] = result
	return result

func _gamma_to_linear_precise(c: float) -> float:
	if c <= 0.04045:
		return c / 12.92
	else:
		return pow((c + 0.055) / 1.055, 2.4)

func _lab_f_precise(t: float) -> float:
	var delta = 6.0/29.0
	if t > delta * delta * delta:
		return pow(t, 1.0/3.0)
	else:
		return t / (3.0 * delta * delta) + 4.0/29.0

# ==================== FUNCIONES AUXILIARES ====================

func _set_progress(value: float):
	progress = value

func _emit_conversion_completed(converted_image: Image):
	conversion_completed.emit(converted_image)

func _emit_conversion_progress(percentage: float):
	conversion_progress.emit(percentage)

func get_progress() -> float:
	return progress

func get_progress_percentage() -> float:
	return progress * 100.0

func wait_for_conversion():
	if conversion_thread:
		conversion_thread.wait_to_finish()
		conversion_thread = null

func _exit_tree():
	if conversion_thread and conversion_thread.is_alive():
		conversion_thread.wait_to_finish()

func _rgb_key(c: Color) -> String:
	return "%d_%d_%d" % [int(c.r*255), int(c.g*255), int(c.b*255)]

# Función para gamma correction original (compatibilidad)
func _gamma_correct(c: float) -> float:
	return _gamma_to_linear_precise(c)

func _lab_f(t: float) -> float:
	return _lab_f_precise(t)
