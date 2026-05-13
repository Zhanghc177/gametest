extends CharacterBody2D

## Player Ant - Charge attack melee character

signal player_dead

# Animation state machine
enum AnimState { IDLE, WALK, ATTACK, CHARGE, DEAD }
var current_animation: AnimState = AnimState.IDLE
var animation_finished: bool = true

# Animation frame tracking
var anim_frame: int = 0
var anim_timer: float = 0.0
const ANIM_FRAME_TIME: float = 0.15

const SPEED: float = 300.0
## 装备系统
const EQUIP_SLOTS = ["weapon", "armor", "accessory"]
var equipment_slots: Dictionary = {
	"weapon": null,
	"armor": null,
	"accessory": null
}

## 装备属性加成
var equipment_bonus_atk: float = 0.0
var equipment_bonus_def: float = 0.0

## 武器切换系统
const WEAPON_LIST = ["bite", "stinger", "acid"]
var current_weapon_index: int = 0
var current_weapon: String = "bite"

## 属性
const DEF_BASE: float = 5.0

const HP_MAX: float = 100.0
const ATK_BASE: float = 15.0
const ATK_FULL: float = 38.0
const CHARGE_TIME: float = 1.0
const ATK_RANGE_MIN: float = 50.0
const ATK_RANGE_MAX: float = 130.0
const ATK_ANGLE: float = PI / 2.2
const ATK_BOOST_AMOUNT: float = 0.10
const ATK_BOOST_DURATION: float = 20.0
const ATTACK_COOLDOWN_AFTER: float = 0.1

## 冲刺技能
const DASH_SPEED: float = 600.0
const DASH_DURATION: float = 0.15
const DODGE_INVINCIBLE_TIME: float = 0.2

## 手感优化参数
const JOYSTICK_DEADZONE: float = 0.15
const GAMEPAD_DEADZONE: float = 0.1

var hp: float = HP_MAX
var move_direction: Vector2 = Vector2.ZERO
var attack_direction: float = 0.0
var is_charging: bool = false
var charge_power: float = 0.0
var attack_cooldown: float = 0.0
var invincible: float = 0.0
var attack_range: float = 0.0
var attack_fan_angle: float = 0.0
var atk_boost: float = 0.0
var atk_boost_timer: float = 0.0
var temporary_abilities: Array = []
var temporary_ability_timers: Dictionary = {}
var footstep_timer: float = 0.0

## 冲刺/闪避状态
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var can_dodge: bool = true

const FOOTSTEP_INTERVAL: float = 0.15

const TEMPORARY_ABILITY_DURATION: float = 60.0
var evolution_color: Color = Color(1.0, 1.0, 1.0, 1.0)

## 性能优化配置
const MAX_ATTACK_PARTICLES: int = 5
const MAX_FOOTSTEPS: int = 20
var _active_footstep_count: int = 0

## 动画状态机更新
func _update_animation(delta: float) -> void:
	anim_timer += delta
	if anim_timer >= ANIM_FRAME_TIME:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 4

	var new_state = AnimState.IDLE
	var is_moving = velocity.length() > 0
	var is_charging_or_attacking = is_charging or attack_cooldown > 0.05

	if is_moving and not is_charging_or_attacking:
		new_state = AnimState.WALK
	elif is_charging:
		new_state = AnimState.CHARGE
	elif attack_cooldown > 0.05:
		new_state = AnimState.ATTACK
	elif hp <= 0:
		new_state = AnimState.DEAD

	if new_state != current_animation:
		current_animation = new_state
		anim_frame = 0
		anim_timer = 0.0
		_apply_animation_state()

func _apply_animation_state() -> void:
	match current_animation:
		AnimState.IDLE:
			_apply_idle_animation()
		AnimState.WALK:
			_apply_walk_animation()
		AnimState.ATTACK:
			_apply_attack_animation()
		AnimState.CHARGE:
			_apply_charge_animation()
		AnimState.DEAD:
			_apply_dead_animation()

func _apply_idle_animation() -> void:
	var scale_y = 1.0 + sin(anim_frame * PI / 2) * 0.02
	ant_body.scale = Vector2(1.0, scale_y)

func _apply_walk_animation() -> void:
	var wobble = sin(anim_frame * PI / 2) * 0.1
	ant_body.rotation = wobble
	ant_body.scale = Vector2(1.0 + abs(wobble) * 0.1, 1.0 - abs(wobble) * 0.05)

func _apply_attack_animation() -> void:
	var scale_x = 1.0 + (1.0 - float(anim_frame) / 4) * 0.3
	var scale_y = 1.0 - float(anim_frame) / 4 * 0.2
	ant_body.scale = Vector2(scale_x, scale_y)

func _apply_charge_animation() -> void:
	var power = 0.5 + charge_power * 0.5
	var scale_x = 1.0 + anim_frame * 0.05 * power
	var scale_y = 1.0 + anim_frame * 0.03 * power
	ant_body.scale = Vector2(scale_x, scale_y)

	var target_angle = attack_direction - PI/2
	ant_body.rotation = lerp_angle(ant_body.rotation, target_angle * 0.3, 0.2)

func _apply_dead_animation() -> void:
	var fade = 1.0 - float(anim_frame) / 4
	modulate.a = fade
	ant_body.scale = Vector2(1.0 - float(anim_frame) / 4 * 0.5, 1.0 - float(anim_frame) / 4 * 0.5)

func _lerp_angle(from: float, to: float, weight: float) -> float:
	var diff = fmod(to - from + PI, TAU) - PI
	return from + diff * weight

## Buff系统
const BUFF_TYPES = {
	"heal": {"icon": "res://assets/icons/heal.png", "color": Color(0.2, 1.0, 0.2, 0.8)},
	"attack": {"icon": "res://assets/icons/attack.png", "color": Color(1.0, 0.3, 0.3, 0.8)},
	"speed": {"icon": "res://assets/icons/speed.png", "color": Color(0.3, 0.7, 1.0, 0.8)},
	"shield": {"icon": "res://assets/icons/shield.png", "color": Color(0.6, 0.6, 1.0, 0.8)},
	"stealth": {"icon": "res://assets/icons/stealth.png", "color": Color(0.5, 0.5, 0.8, 0.8)}
}

var active_buffs: Dictionary = {}
var buff_icons: Node2D
var buff_effects: Node2D

@onready var charge_timer: Timer = $ChargeTimer
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var health_bar: ProgressBar = $HealthBar
@onready var ant_body: Node2D = $AntBody
@onready var attack_fan: Polygon2D = $AttackFan

func _ready() -> void:
	health_bar.max_value = HP_MAX
	health_bar.value = hp
	charge_timer.timeout.connect(_on_charge_timeout)
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	attack_fan.visible = false

	buff_icons = Node2D.new()
	buff_icons.name = "BuffIcons"
	add_child(buff_icons)

	buff_effects = Node2D.new()
	buff_effects.name = "BuffEffects"
	add_child(buff_effects)

func _physics_process(delta: float) -> void:
	_update_animation(delta)
	apply_buff_effects(delta)

	if is_dashing:
		velocity = dash_direction * DASH_SPEED
		dash_timer -= delta
		invincible = DODGE_INVINCIBLE_TIME
		if dash_timer <= 0:
			is_dashing = false
			velocity = Vector2.ZERO
		move_and_slide()
		return

	if invincible > 0:
		invincible -= delta
		modulate.a = 0.5 if fmod(invincible, 0.1) < 0.05 else 1.0
	else:
		modulate.a = 1.0

	if atk_boost_timer > 0:
		atk_boost_timer -= delta
		if atk_boost_timer <= 0:
			atk_boost = 0.0

	for ability in temporary_abilities:
		if temporary_ability_timers.has(ability):
			temporary_ability_timers[ability] -= delta
			if temporary_ability_timers[ability] <= 0:
				remove_temporary_ability(ability)

	handle_input()
	move_and_slide()

	if velocity.length() > 0:
		footstep_timer -= delta
		if footstep_timer <= 0:
			spawn_footstep()
			footstep_timer = FOOTSTEP_INTERVAL

	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		if obstacle is StaticBody2D:
			var collision = obstacle.get_child(0) as CollisionShape2D
			if collision and collision.shape is CircleShape2D:
				var center = obstacle.global_position
				var radius = (collision.shape as CircleShape2D).radius
				var d = global_position.distance_to(center)
				var min_dist = 24 + radius
				if d < min_dist:
					var push_dir = (global_position - center).normalized()
					global_position = center + push_dir * min_dist

	if attack_cooldown > 0:
		attack_cooldown -= delta

	if is_charging:
		var params = get_attack_params()
		update_attack_fan(params)
		attack_fan.visible = true
	else:
		attack_fan.visible = false

func handle_input() -> void:
	var input_dir = Vector2.ZERO
	var main = get_tree().get_first_node_in_group("main")

	var gamepad_connected = main and main.has_method("is_gamepad_connected") and main.is_gamepad_connected()

	if gamepad_connected:
		var leftstick = main.get_gamepad_leftstick()
		if leftstick.length() > GAMEPAD_DEADZONE:
			input_dir = leftstick

	if input_dir == Vector2.ZERO and main and main.has_method("get_joystick_input"):
		var joystick = main.get_joystick_input()
		if joystick != Vector2.ZERO:
			input_dir = joystick

	if input_dir == Vector2.ZERO:
		if Input.is_action_pressed("move_left"):
			input_dir.x -= 1
		if Input.is_action_pressed("move_right"):
			input_dir.x += 1
		if Input.is_action_pressed("move_up"):
			input_dir.y -= 1
		if Input.is_action_pressed("move_down"):
			input_dir.y += 1

		if input_dir != Vector2.ZERO:
			input_dir = input_dir.normalized()
			var dash_pressed = Input.is_action_pressed("dash")
			if main and main.has_method("is_dash_button_down"):
				dash_pressed = dash_pressed or main.is_dash_button_down()
			if dash_pressed and can_dodge and not is_charging:
				start_dodge(input_dir)
			else:
				velocity = input_dir * get_current_speed()
				move_direction = input_dir
		else:
			velocity = Vector2.ZERO

	if gamepad_connected:
		var rightstick = main.get_gamepad_rightstick()
		if rightstick.length() > GAMEPAD_DEADZONE:
			attack_direction = rightstick.angle()

	if Input.is_action_pressed("rotate_left"):
		attack_direction -= 3.0 * get_process_delta_time()
	if Input.is_action_pressed("rotate_right"):
		attack_direction += 3.0 * get_process_delta_time()

	var attack_button_down = false
	if main and main.has_method("is_attack_button_down"):
		attack_button_down = main.is_attack_button_down()

	var trigger_down = false
	if gamepad_connected and main and main.has_method("get_gamepad_trigger"):
		trigger_down = main.get_gamepad_trigger() > 0.1

	if (trigger_down or attack_button_down or Input.is_action_pressed("attack_charge")) and attack_cooldown <= 0:
		start_charge()

func start_charge() -> void:
	if is_charging:
		charge_power = min(1.0, charge_power + get_process_delta_time() / CHARGE_TIME)
	else:
		is_charging = true
		charge_power = 0.0
		charge_timer.start()

func start_dodge(dir: Vector2) -> void:
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_direction = dir
	can_dodge = false
	attack_direction = dir.angle()
	spawn_dodge_effect()

func spawn_dodge_effect() -> void:
	var trail = Polygon2D.new()
	var points = PackedVector2Array([
		Vector2(-10, -8), Vector2(10, -8),
		Vector2(10, 8), Vector2(-10, 8)
	])
	trail.polygon = points
	trail.color = Color(0.5, 0.8, 1.0, 0.6)
	trail.global_position = global_position
	trail.rotation = dash_direction.angle()
	get_tree().root.add_child(trail)

	var tween = create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(trail.queue_free)

func _on_charge_timeout() -> void:
	perform_attack()
	is_charging = false
	charge_power = 0.0
	attack_cooldown = ATTACK_COOLDOWN_AFTER
	cooldown_timer.start()

func _on_cooldown_timeout() -> void:
	attack_cooldown = 0.0
	can_dodge = true

func perform_attack() -> void:
	var params = get_attack_params()
	attack_range = params.range
	attack_fan_angle = params.fan_angle

	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if enemy.has_method("take_damage") and is_in_attack_fan(enemy.global_position, params):
			enemy.take_damage(params.damage)
			hit_count += 1

	if hit_count > 0:
		var tween = create_tween()
		tween.tween_property(self, "modulate:b", 0.3, 0.03)
		tween.chain().tween_property(self, "modulate:b", 1.0, 0.03)

	spawn_attack_effect(params)
	attack_fan.visible = false

	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.sfx_attack()

	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("vibrate"):
		main.vibrate(0)

func is_in_attack_fan(target_pos: Vector2, params: Dictionary) -> bool:
	var to_target = target_pos - global_position
	var d = to_target.length()
	if d > params.range + 30:
		return false

	var angle_to_target = Vector2.RIGHT.angle_to(to_target)
	var angle_diff = abs(angle_to_target - params.angle)
	if angle_diff > PI:
		angle_diff = 2 * PI - angle_diff

	return angle_diff < params.fan_angle / 2

func get_attack_params() -> Dictionary:
	var p = charge_power
	var exp_p = pow(p, 0.8)
	var total_atk = get_total_atk()
	var base_dmg = total_atk + (ATK_FULL - ATK_BASE) * p * p
	return {
		"range": ATK_RANGE_MIN + (ATK_RANGE_MAX - ATK_RANGE_MIN) * exp_p,
		"damage": base_dmg * get_attack_multiplier(),
		"angle": attack_direction,
		"fan_angle": ATK_ANGLE * (0.7 + 0.3 * p)
	}

func update_attack_fan(params: Dictionary) -> void:
	var angle = params.angle
	var fan_angle = params.fan_angle
	var range_val = params.range

	var points = PackedVector2Array()
	points.append(Vector2.ZERO)

	var segments = 12
	for i in range(segments + 1):
		var a = angle - fan_angle / 2 + fan_angle * i / segments
		points.append(Vector2(cos(a), sin(a)) * range_val)

	attack_fan.polygon = points

	var alpha = 0.2 + charge_power * 0.3
	attack_fan.color = Color(0.29, 0.87, 0.31, alpha)

func apply_attack_boost() -> void:
	atk_boost = ATK_BOOST_AMOUNT
	atk_boost_timer = ATK_BOOST_DURATION

func apply_temporary_ability(ability_type: String, ability_color: Color) -> void:
	if temporary_abilities.has(ability_type):
		temporary_ability_timers[ability_type] = TEMPORARY_ABILITY_DURATION
		print("Player: Refresh ability ", ability_type)
		return

	temporary_abilities.append(ability_type)
	temporary_ability_timers[ability_type] = TEMPORARY_ABILITY_DURATION

	var current_modulate = modulate
	modulate = current_modulate * ability_color.lightened(0.4)

	flash_effect(ability_color)

	print("Player: Apply ability ", ability_type, " for ", TEMPORARY_ABILITY_DURATION, " seconds")

func remove_temporary_ability(ability_type: String) -> void:
	if not temporary_abilities.has(ability_type):
		return

	temporary_abilities.erase(ability_type)
	temporary_ability_timers.erase(ability_type)

	print("Player: Ability removed ", ability_type)

func flash_effect(color: Color) -> void:
	var original_modulate = modulate
	var tween = create_tween()
	tween.tween_property(self, "modulate", color, 0.1)
	tween.chain().tween_property(self, "modulate", original_modulate * 1.5, 0.1)
	tween.chain().tween_property(self, "modulate", original_modulate, 0.1)

func spawn_attack_effect(params: Dictionary) -> void:
	var shockwave = Polygon2D.new()
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)

	var segments = 12
	for i in range(segments + 1):
		var a = params.angle - params.fan_angle / 2 + params.fan_angle * i / segments
		points.append(Vector2(cos(a), sin(a)) * params.range)

	shockwave.polygon = points
	shockwave.color = Color(1.0, 0.8, 0.3, 0.7)
	shockwave.global_position = global_position
	get_tree().root.add_child(shockwave)

	var tween = create_tween()
	tween.tween_property(shockwave, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(shockwave.queue_free)

	var ring = Polygon2D.new()
	var ring_points = PackedVector2Array()
	for i in range(32):
		var a = 2 * PI * i / 32
		ring_points.append(Vector2(cos(a), sin(a)) * 20)
	ring.polygon = ring_points
	ring.color = Color(1.0, 0.6, 0.1, 0.8)
	ring.global_position = global_position
	get_tree().root.add_child(ring)

	var ring_tween = create_tween()
	ring_tween.tween_property(ring, "scale", Vector2(params.range / 20.0, params.range / 20.0), 0.2)
	ring_tween.chain().tween_property(ring, "modulate:a", 0.0, 0.15)
	ring_tween.chain().tween_callback(ring.queue_free)

	for i in range(MAX_ATTACK_PARTICLES):
		var particle = Polygon2D.new()
		var p_points = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -3),
			Vector2(3, 3), Vector2(-3, 3)
		])
		particle.polygon = p_points
		particle.color = Color(1.0, 0.7, 0.2, 0.9)
		particle.global_position = global_position

		var dir = Vector2.RIGHT.rotated(params.angle + randf_range(-params.fan_angle/2, params.fan_angle/2))
		var dist = randf_range(30, params.range * 0.8)
		var target_pos = global_position + dir * dist

		get_tree().root.add_child(particle)

		var p_tween = create_tween()
		p_tween.tween_property(particle, "global_position", target_pos, 0.15)
		p_tween.chain().tween_property(particle, "modulate:a", 0.0, 0.1)
		p_tween.chain().tween_callback(particle.queue_free)

func spawn_footstep() -> void:
	if _active_footstep_count >= MAX_FOOTSTEPS:
		var all_nodes = get_tree().get_nodes_in_group("footprints")
		if all_nodes.size() > 0:
			all_nodes[0].queue_free()
	else:
		_active_footstep_count += 1

	var footprint = Polygon2D.new()
	var points = PackedVector2Array([
		Vector2(-4, -2), Vector2(4, -2),
		Vector2(4, 2), Vector2(-4, 2)
	])
	footprint.polygon = points
	footprint.color = Color(0.4, 0.35, 0.3, 0.5)
	footprint.global_position = global_position + Vector2(0, 15)
	footprint.rotation = randf() * TAU
	footprint.add_to_group("footprints")
	get_tree().root.add_child(footprint)

	var tween = create_tween()
	tween.tween_property(footprint, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(_on_footstep_expired.bind(footprint))

func _on_footstep_expired(footprint: Polygon2D) -> void:
	if is_instance_valid(footprint):
		_active_footstep_count = max(0, _active_footstep_count - 1)

func take_damage(dmg: float) -> void:
	if invincible > 0:
		return

	if has_shield():
		consume_shield()
		print("Player: Shield blocked attack")
		spawn_shield_break_effect()
		return

	var final_damage = max(1.0, dmg - get_total_def())
	hp -= final_damage
	invincible = 0.5
	health_bar.value = hp

	spawn_damage_vignette()

	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.sfx_hurt()

	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("vibrate"):
		main.vibrate(1)

	if hp <= 0:
		hp = 0
		die()

func spawn_damage_vignette() -> void:
	var vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.8, 0.1, 0.1, 0.4)
	get_tree().root.add_child(vignette)

	var tween = create_tween()
	tween.tween_property(vignette, "color:a", 0.0, 0.5)
	tween.chain().tween_callback(vignette.queue_free)

func spawn_shield_break_effect() -> void:
	var effect = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(6):
		var angle = 2 * PI * i / 6 - PI / 6
		points.append(Vector2(cos(angle), sin(angle)) * 35)

	effect.polygon = points
	effect.color = Color(0.6, 0.6, 1.0, 0.8)
	effect.global_position = global_position
	get_tree().root.add_child(effect)

	var tween = create_tween()
	tween.tween_property(effect, "scale", Vector2(1.5, 1.5), 0.2)
	tween.chain().tween_property(effect, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(effect.queue_free)

func die() -> void:
	emit_signal("player_dead")
	queue_free()

func apply_evolution_color(color: Color) -> void:
	evolution_color = color
	modulate = modulate.lightened(0.3) * color
	print("Player: Evolution color applied, color=", color)

func apply_buff(type: String, duration: float, value: float) -> void:
	if not BUFF_TYPES.has(type):
		print("Player: Unknown buff type ", type)
		return

	var buff_data = {
		"duration": duration,
		"remaining": duration,
		"value": value,
		"type": type
	}

	if active_buffs.has(type):
		active_buffs[type] = buff_data
	else:
		active_buffs[type] = buff_data
		add_buff_effect(type, BUFF_TYPES[type])

	print("Player: Apply buff ", type, " for ", duration, " seconds")

func remove_buff(type: String) -> void:
	if not active_buffs.has(type):
		return

	active_buffs.erase(type)
	remove_buff_effect(type)
	print("Player: Remove buff ", type)

func apply_buff_effects(delta: float) -> void:
	var types_to_remove = []

	for buff_type in active_buffs:
		var buff = active_buffs[buff_type]
		buff["remaining"] -= delta

		update_buff_icon_alpha(buff_type, buff["remaining"] / buff["duration"])

		if buff["remaining"] <= 0:
			types_to_remove.append(buff_type)
		else:
			match buff_type:
				"heal":
					hp = min(HP_MAX, hp + buff["value"] * delta)
					health_bar.value = hp
				"attack":
					pass
				"speed":
					pass
				"shield":
					pass
				"stealth":
					pass

	for buff_type in types_to_remove:
		remove_buff(buff_type)

func get_current_speed() -> float:
	var speed_mult = 1.0
	if active_buffs.has("speed"):
		speed_mult += active_buffs["speed"]["value"]
	return SPEED * speed_mult

func get_attack_multiplier() -> float:
	var atk_mult = 1.0
	if active_buffs.has("attack"):
		atk_mult += active_buffs["attack"]["value"]
	return atk_mult

func has_shield() -> bool:
	return active_buffs.has("shield")

func consume_shield() -> void:
	if active_buffs.has("shield"):
		remove_buff("shield")

func is_stealthed() -> bool:
	return active_buffs.has("stealth")

func add_buff_effect(type: String, buff_info: Dictionary) -> void:
	var icon = ColorRect.new()
	icon.name = type + "_icon"
	icon.custom_minimum_size = Vector2(24, 24)
	icon.color = buff_info["color"]
	icon.position = Vector2(active_buffs.size() * 28, -40)
	buff_icons.add_child(icon)

	var glow = Polygon2D.new()
	var points = PackedVector2Array([
		Vector2(-15, -15), Vector2(15, -15),
		Vector2(15, 15), Vector2(-15, 15)
	])
	glow.polygon = points
	glow.color = buff_info["color"]
	glow.modulate.a = 0.3
	glow.position = Vector2.ZERO
	glow.name = type + "_glow"

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(glow, "modulate:a", 0.1, 0.5)
	tween.chain().tween_property(glow, "modulate:a", 0.3, 0.5)
	tween.set_loops(-1)

	buff_effects.add_child(glow)

	match type:
		"heal":
			var ring = Polygon2D.new()
			var ring_points = PackedVector2Array()
			for i in range(32):
				var angle = 2 * PI * i / 32
				ring_points.append(Vector2(cos(angle), sin(angle)) * 30)
			ring.polygon = ring_points
			ring.color = Color(0.2, 1.0, 0.2, 0.2)
			ring.name = "heal_ring"
			buff_effects.add_child(ring)
		"shield":
			var shield = Polygon2D.new()
			var shield_points = PackedVector2Array()
			for i in range(6):
				var angle = 2 * PI * i / 6 - PI / 6
				shield_points.append(Vector2(cos(angle), sin(angle)) * 35)
			shield.polygon = shield_points
			shield.color = Color(0.6, 0.6, 1.0, 0.3)
			shield.name = "shield_shape"
			buff_effects.add_child(shield)
		"stealth":
			var stealth_fx = Polygon2D.new()
			var fx_points = PackedVector2Array([
				Vector2(-20, -20), Vector2(20, -20),
				Vector2(20, 20), Vector2(-20, 20)
			])
			stealth_fx.polygon = fx_points
			stealth_fx.color = Color(0.5, 0.5, 0.8, 0.2)
			stealth_fx.name = "stealth_fx"
			buff_effects.add_child(stealth_fx)

func remove_buff_effect(type: String) -> void:
	var icon = buff_icons.get_node_or_null(type + "_icon")
	if icon:
		icon.queue_free()

	for child in buff_effects.get_children():
		if child.name.begins_with(type) or (type == "heal" and child.name == "heal_ring") or (type == "shield" and child.name == "shield_shape") or (type == "stealth" and child.name == "stealth_fx"):
			child.queue_free()

func update_buff_icon_alpha(buff_type: String, ratio: float) -> void:
	var icon = buff_icons.get_node_or_null(buff_type + "_icon")
	if icon:
		var color = icon.color
		color.a = 0.5 + ratio * 0.5
		icon.color = color

func equip_item(item: Dictionary, slot: String) -> bool:
	if not slot in EQUIP_SLOTS:
		print("Player: Invalid equip slot ", slot)
		return false

	if equipment_slots[slot] != null:
		unequip_item(slot)

	equipment_slots[slot] = item
	_recalculate_equipment_bonus()
	print("Player: Equip ", item.get("name", "Unknown"), " to ", slot)
	return true

func unequip_item(slot: String) -> Dictionary:
	if not slot in EQUIP_SLOTS:
		print("Player: Invalid equip slot ", slot)
		return {}

	var item = equipment_slots[slot]
	if item == null:
		return {}

	equipment_slots[slot] = null
	_recalculate_equipment_bonus()
	print("Player: Unequip ", item.get("name", "Unknown"), " from ", slot)
	return item

func _recalculate_equipment_bonus() -> void:
	equipment_bonus_atk = 0.0
	equipment_bonus_def = 0.0

	for slot in EQUIP_SLOTS:
		var item = equipment_slots[slot]
		if item != null:
			equipment_bonus_atk += item.get("atk", 0.0)
			equipment_bonus_def += item.get("def", 0.0)

func get_total_atk() -> float:
	return ATK_BASE + equipment_bonus_atk

func get_total_def() -> float:
	return DEF_BASE + equipment_bonus_def

func get_equipment_info() -> Dictionary:
	var info = {}
	for slot in EQUIP_SLOTS:
		info[slot] = equipment_slots[slot]
	return info

func switch_weapon_next() -> void:
	if WEAPON_LIST.size() <= 1:
		return
	current_weapon_index = (current_weapon_index + 1) % WEAPON_LIST.size()
	current_weapon = WEAPON_LIST[current_weapon_index]
	_apply_weapon_bonus()
	print("Player: Switch to weapon ", current_weapon, " (", current_weapon_index + 1, "/", WEAPON_LIST.size(), ")")

func switch_weapon_previous() -> void:
	if WEAPON_LIST.size() <= 1:
		return
	current_weapon_index = (current_weapon_index - 1 + WEAPON_LIST.size()) % WEAPON_LIST.size()
	current_weapon = WEAPON_LIST[current_weapon_index]
	_apply_weapon_bonus()
	print("Player: Switch to weapon ", current_weapon, " (", current_weapon_index + 1, "/", WEAPON_LIST.size(), ")")

func _apply_weapon_bonus() -> void:
	match current_weapon:
		"bite":
			equipment_bonus_atk = 0.0
		"stinger":
			equipment_bonus_atk = 5.0
		"acid":
			equipment_bonus_atk = 2.0
