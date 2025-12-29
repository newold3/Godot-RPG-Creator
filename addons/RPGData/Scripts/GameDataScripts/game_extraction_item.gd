class_name GameExtractionItem
extends Resource

@export var id: int = 0 # Real id in map
@export var current_uses: int = 3
@export var depleted_date: float = 0.0
@export var current_respawn_time: float = 0.0


func _init(p_id: int = 0) -> void:
	id = p_id
	var current_item = get_item()
	if current_item:
		current_uses = current_item.max_uses


func get_item() -> RPGExtractionItem:
	if GameManager.current_map:
		var data =  GameManager.current_map.extraction_events
		for event: RPGExtractionItem in data:
			if event.id == id:
				return event
	
	return null


func is_depleted() -> bool:
	return current_respawn_time > 0


# Calcular experiencia ganada basada en niveles
func calculate_experience(character_level: int) -> int:
	var current_item = get_item()
	if not current_item: return -1
		
	var experience_base = current_item.experience_base
	var level_difference = current_item.current_level - character_level
	
	# Caso 1: Ítem 10+ niveles menor → Sin experiencia
	if level_difference <= -10:
		return 0
	
	# Caso 2: Ítem 1-9 niveles menor → Experiencia reducida
	if level_difference >= -9 and level_difference <= -1:
		var penalty_percent = abs(level_difference) * 10  # 10%, 20%, 30%... 90%
		var experience = experience_base * (100 - penalty_percent) / 100
		return int(experience)
	
	# Caso 3: Ítem mismo nivel → Experiencia base completa
	if level_difference == 0:
		return experience_base
	
	# Caso 4: Ítem 1-9 niveles mayor → Experiencia aumentada
	if level_difference >= 1 and level_difference <= 9:
		var bonus_percent = level_difference * 15  # 15%, 30%, 45%... 135%
		var experience = experience_base * (100 + bonus_percent) / 100.0
		return int(experience)
	
	# Caso 5: Ítem 10+ niveles mayor → No se puede recolectar
	return -1  # Código para "no permitido"


# Calcular porcentaje de éxito
func calculate_success_rate(character_level: int) -> float:
	var current_item = get_item()
	if not current_item: return -1
	
	var level_difference = current_item.current_level - character_level
	
	# Ítem 10+ niveles mayor → No se puede recolectar
	if level_difference >= 10:
		return 0.0
	
	# Ítem mucho menor → 100% éxito
	if level_difference <= -5:
		return 100.0
	
	# Fórmula base: 85% cuando son del mismo nivel
	# Cada nivel de diferencia afecta ±5%
	var base_success = 85.0
	var success_rate = base_success - (level_difference * 5.0)
	
	# Limitar entre 10% y 100%
	return clamp(success_rate, 10.0, 100.0)


# Calcular porcentaje de fallo
func calculate_failure_rate(character_level: int) -> float:
	return 100.0 - calculate_success_rate(character_level)


# Verificar si se puede recolectar
func can_harvest(character_level: int) -> bool:
	var current_item = get_item()
	if not current_item: return -1
	
	var level_difference = current_item.current_level - character_level
	return level_difference < 10


func harvest(character_level: int) -> Dictionary:
	var result: Dictionary = {
		"final_success": false,
		"success_rate": 0.0,
		"failure_rate": 0.0,
		"steps": [],
		"total_success_steps": 0.0,
		"total_failure_steps": 0.0,
		"roll_count": 0,
		"finished_by": "",  # "success" o "failure"
		"experience": calculate_experience(character_level)
	}
	
	# Calcular las probabilidades base
	result.success_rate = calculate_success_rate(character_level)
	result.failure_rate = calculate_failure_rate(character_level)
	
	# No se puede recolectar si está fuera de rango
	if not can_harvest(character_level):
		result.finished_by = "impossible"
		return result
	
	var current_item = get_item()
	if not current_item: return result
	
	# Calcular los pasos según la diferencia de niveles
	var level_difference = current_item.current_level - character_level
	var success_step_size = calculate_success_step_size(level_difference)
	var failure_step_size = calculate_failure_step_size(level_difference)
	
	# Variables de acumulación
	var current_success_total = 0.0
	var current_failure_total = 0.0
	var max_rolls = 50  # Límite de seguridad para evitar bucles infinitos
	
	# Simulación paso a paso
	while current_success_total < 1.0 and current_failure_total < 1.0 and result.roll_count < max_rolls:
		result.roll_count += 1
		
		# Tirar el dado, primero comprobar criticos y si se da alguno, marcar la tirada como exitosa
		var is_success = false
		var is_critical = false
		var is_super_critical = false
		var critical_roll = randf() * 100.0
		if critical_roll <= 1.5:
			is_super_critical = true
		elif critical_roll <= 15.0:
			is_critical = true
		
		if is_critical or is_success:
			is_success = true
		else:
			var roll = randf() * 100.0
			is_success = roll <= result.success_rate
		
		if is_success:
			# Sumar al progreso de éxito
			current_success_total += success_step_size * (5 if is_super_critical else 2 if is_critical else 1)
			current_success_total = min(current_success_total, 1.0)  # No pasar de 1.0
			
			result.steps.append({
				"type": "success",
				"current_step": current_success_total,
				"is_critical": is_critical,
				"is_super_critical": is_super_critical,
				"step_size": success_step_size
			})
			
			# Verificar si completamos el éxito
			if current_success_total >= 1.0:
				result.final_success = true
				result.finished_by = "success"
				break
		else:
			# Sumar al progreso de fallo
			current_failure_total += failure_step_size
			current_failure_total = min(current_failure_total, 1.0)  # No pasar de 1.0
			
			result.steps.append({
				"type": "failure",
				"current_step": current_failure_total,
				"step_size": failure_step_size
			})
			
			# Verificar si completamos el fallo
			if current_failure_total >= 1.0:
				result.final_success = false
				result.finished_by = "failure"
				break
	
	# Guardar totales finales
	result.total_success_steps = current_success_total
	result.total_failure_steps = current_failure_total
	
	# Si llegamos al límite de rolls sin terminar, decidir por el mayor
	if result.roll_count >= max_rolls and result.finished_by == "":
		var winner_type: String
		var step_size: float
		var current_step: float

		if current_success_total >= current_failure_total:
			result.final_success = true
			result.finished_by = "success"
			winner_type = "success"
			step_size = 1.0 - current_success_total
			current_step = 1.0
		else:
			result.final_success = false
			result.finished_by = "failure"
			winner_type = "failure"
			step_size = 1.0 - current_failure_total
			current_step = 1.0

		# Añadir último paso para completar la barra al 100%
		result.steps.append({
			"type": winner_type,
			"current_step": current_step,
			"step_size": step_size
		})
	
	if result.steps.size() > 0:
		var last_step = result.steps[-1]
		if last_step.current_step < 1.0:
			last_step.step_size = 1.0 - last_step.current_step
			last_step.current_step = 1.0
	
	return result

# Calcular tamaño de paso para éxitos según diferencia de niveles
func calculate_success_step_size(level_difference: int) -> float:
	# Ítems más fáciles = pasos más grandes (termina más rápido)
	# Ítems más difíciles = pasos más pequeños (toma más tiempo)
	# Progresión suave y gradual
	
	if level_difference <= -10:  # Ítem extremadamente fácil
		return 0.45  # Casi instantáneo
	elif level_difference <= -5:  # Ítem mucho más fácil
		return 0.35 + (abs(level_difference - (-5)) * 0.02)  # 0.35 a 0.45
	elif level_difference <= -1:  # Ítem un poco más fácil
		return 0.28 + (abs(level_difference) * 0.015)  # 0.28 a 0.34
	elif level_difference == 0:  # Mismo nivel
		return 0.25  # Paso base equilibrado
	elif level_difference <= 4:  # Progresión gradual hasta +4
		return 0.25 - (level_difference * 0.025)  # 0.225, 0.20, 0.175, 0.15
	elif level_difference <= 10:  # Progresión muy suave de +5 a +10
		# A partir de +5, la dificultad sube muy gradualmente
		var base_step = 0.15  # Step en nivel +4
		var reduction_per_level = 0.012  # Reducción muy suave
		return base_step - ((level_difference - 4) * reduction_per_level)  # +5: 0.138, +6: 0.126, +7: 0.114, +8: 0.102, +9: 0.090, +10: 0.078
	else:
		return 0.065  # Muy difícil pero no imposible

func calculate_failure_step_size(level_difference: int) -> float:
	# Ítems más fáciles = fallos dan pasos pequeños (es difícil fallar completamente)
	# Ítems más difíciles = fallos dan pasos grandes (fallas más rápido)
	# Progresión suave y gradual
	
	if level_difference <= -10:  # Ítem extremadamente fácil
		return 0.04  # Casi imposible fallar
	elif level_difference <= -5:  # Ítem mucho más fácil
		return 0.06 + (abs(level_difference - (-5)) * 0.008)  # 0.06 a 0.10
	elif level_difference <= -1:  # Ítem un poco más fácil
		return 0.09 + (abs(level_difference) * 0.015)  # 0.09 a 0.135
	elif level_difference == 0:  # Mismo nivel
		return 0.16  # Paso base de fallo
	elif level_difference <= 4:  # Progresión gradual hasta +4
		return 0.16 + (level_difference * 0.025)  # 0.185, 0.21, 0.235, 0.26
	elif level_difference <= 10:  # Progresión suave de +5 a +10
		# A partir de +5, el failure sube gradualmente pero no demasiado
		var base_step = 0.26  # Step en nivel +4
		var increase_per_level = 0.015  # Aumento gradual
		return base_step + ((level_difference - 4) * increase_per_level)  # +5: 0.275, +6: 0.29, +7: 0.305, +8: 0.32, +9: 0.335, +10: 0.35
	else:
		return 0.38  # Muy peligroso pero no imposiblee

# Método auxiliar para obtener un resumen legible del harvest
func get_harvest_summary(harvest_result: Dictionary) -> String:
	if not harvest_result.has("final_success"):
		return "Resultado inválido"
	
	if harvest_result.finished_by == "impossible":
		return "No se puede recolectar: nivel demasiado alto"
	
	var success_count = 0
	var failure_count = 0
	
	for step in harvest_result.steps:
		if step.type == "success":
			success_count += 1
		else:
			failure_count += 1
	
	var result_text = "ÉXITO" if harvest_result.final_success else "FALLO"
	var summary = "%s tras %d tiradas (%d éxitos, %d fallos)\n" % [result_text, harvest_result.roll_count, success_count, failure_count]
	summary += "Progreso final - Éxito: %.2f, Fallo: %.2f" % [harvest_result.total_success_steps, harvest_result.total_failure_steps]
	
	return summary

# Ejemplo de uso y testing
func test_stepped_harvest(character_level: int):
	#print("=== Prueba de Harvest por Pasos ===")
	#print("Ítem nivel %d vs Personaje nivel %d" % [level, character_level])
	#
	#var level_diff = level - character_level
	#print("Diferencia de niveles: %d" % level_diff)
	#print("Probabilidad base de éxito: %.1f%%" % calculate_success_rate(character_level))
	#print("Tamaño paso éxito: %.3f" % calculate_success_step_size(level_diff))
	#print("Tamaño paso fallo: %.3f" % calculate_failure_step_size(level_diff))
	
	var result = harvest(character_level)
	#print(get_harvest_summary(result))
	#print("-----------------------------------------")
	#print("\nDetalle de pasos:")
	#for i in range(min(result.steps.size(), 10)):  # Solo mostrar primeros 10
		#var step = result.steps[i]
		#print("Paso %d: %s (%.2f) - Roll: %.1f" % [i+1, step.type.to_upper(), step.current_step, step.roll])
	#
	#if result.steps.size() > 10:
		#print("... y %d pasos más" % (result.steps.size() - 10))
	
	#if result.finished_by != "failure":
		#print("Result = ", result.finished_by)
		#print("-----------------------------------------")
	return result
