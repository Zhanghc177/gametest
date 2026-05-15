extends CharacterBody2D

## 蜂后BOSS - 多阶段攻击
## 阶段1: 普通攻击 + 毒针
## 阶段2: 冲刺攻击 (HP<50%)
## 阶段3: 召唤小兵 (HP<30%)

const HP_MAX: float = 500.0
const ATK: float = 35.0
const SPEED: float = 120.0

## 冲刺参数
const DASH_SPEED: float = 400.0
const DASH_DURATION: float = 0.6
const DASH_COOLDOWN: float = 3.0

## 毒针参数
const POISON_DAMAGE: float = 8.0
const POISON_DURATION: float = 3.0
const POISON_INTERVAL: float = 0.5

## 召唤小兵参数
const SUMMON_COOLDOWN: float = 8.0

var hp: float = HP_MAX
var phase: int = 1  # 1=普通, 2=冲刺, 3=召唤

var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_cooldown: float = 0.0

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

var is_poisoning: bool = false
var poison_timer: float = 0.0
var poison_victim: Node2D = null

var summon_cooldown: float = 0.0

var invincible: float = 0.0

@onready var health_bar: ProgressBar = $HealthBar
@onready var warning_sprite: Sprite2D = $WarningSprite

var player: Node2D = null
var main: Node = null

signal boss_died()

func _ready() -> void:
	hp = HP_MAX
	health_bar.max_value = HP_MAX
	health_bar.value = hp
	warning_sprite.visible = false
	add_to_group("boss")
	add_to_group("enemies")

	main = get_tree().get_first_node_in_group("main")
	player = get_tree().get_first_node_in_group("player")

	# 随机选择初始攻击模式
	attack_cooldown = randf_range(1.0, 2.0)

func _physics_process(delta: float) -> void:
	if main and main.get("game_running") == false:
		velocity = Vector2.ZERO
		warning_sprite.visible = false
		return

	if invincible > 0:
		invincible -= delta
		modulate.a = 0.5 if fmod(invincible, 0.1) < 0.05 else 1.0
	else:
		modulate.a = 1.0

	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return

	# 检查玩家隐形状态
	if player.has_method("is_stealthed") and player.is_stealthed():
		return

	# 更新阶段
	update_phase()

	# 处理冲刺
	if is_dashing:
		process_dash(delta)
	elif dash_cooldown > 0:
		dash_cooldown -= delta

	# 处理毒针效果
	if is_poisoning and poison_victim != null:
		process_poison(delta)

	# 普通攻击逻辑
	if not is_dashing:
		process_normal_attack(delta)

	# 召唤冷却
	if summon_cooldown > 0:
		summon_cooldown -= delta

	# 更新警告动画
	if is_dashing:
		warning_sprite.visible = true
		rotation = dash_direction.angle()
	else:
		warning_sprite.visible = false

	# 面向玩家
	look_at(player.global_position)

func update_phase() -> void:
	var hp_ratio = hp / HP_MAX
	if hp_ratio < 0.3 and phase < 3:
		phase = 3
		spawn_phase_change_effect()
	elif hp_ratio < 0.5 and phase < 2:
		phase = 2
		spawn_phase_change_effect()

func process_dash(delta: float) -> void:
	dash_timer -= delta

	var dash_velocity = dash_direction * DASH_SPEED
	var collision = move_and_collide(dash_velocity * delta)

	# 检查碰撞
	if collision:
		var collider = collision.get_collider()
		if collider == player:
			player.take_damage(ATK * 1.5)
			spawn_hit_effect()

	if dash_timer <= 0:
		is_dashing = false
		dash_cooldown = DASH_COOLDOWN
		invincible = 0.3

func process_normal_attack(delta: float) -> void:
	var dist_to_player = global_position.distance_to(player.global_position)

	# 阶段2: 更频繁冲刺
	if phase >= 2 and dash_cooldown <= 0 and dist_to_player < 300:
		start_dash()
		return

	# 普通追击
	var dir = (player.global_position - global_position).normalized()
	global_position += dir * SPEED * delta * 0.5

	# 普通攻击
	if attack_cooldown <= 0 and dist_to_player < 80:
		perform_attack()

	if attack_cooldown > 0:
		attack_cooldown -= delta

func start_dash() -> void:
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_direction = (player.global_position - global_position).normalized()
	invincible = 0.2
	spawn_dash_wind_effect()

func perform_attack() -> void:
	attack_cooldown = 2.0 - (phase - 1) * 0.3  # 阶段越高攻击越快

	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player < 80:
		# 普通攻击
		player.take_damage(ATK)
		spawn_hit_effect()

	# 30%概率发射毒针
	if randf() < 0.3:
		fire_poison_needle()

	# 阶段3: 召唤小兵
	if phase >= 3 and summon_cooldown <= 0:
		summon_minions()
		summon_cooldown = SUMMON_COOLDOWN

func fire_poison_needle() -> void:
	if player == null:
		return

	# 创建毒针子弹
	var needle = Area2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8
	var collision = CollisionShape2D.new()
	collision.shape = shape
	needle.add_child(collision)

	var sprite = Sprite2D.new()
	sprite.modulate = Color(0.3, 0.8, 0.3, 0.8)
	needle.add_child(sprite)

	needle.global_position = global_position
	needle.add_to_group("poison_needle")
	needle.add_to_group("battle_effects")
	get_tree().root.add_child(needle)

	# 飞向玩家
	var _dir = (player.global_position - global_position).normalized()
	var target_pos = player.global_position

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(needle, "global_position", target_pos, 0.4)
	tween.set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func(): apply_poison(needle, target_pos))

	# 播放发射音效
	play_sound("poison_shot")

func apply_poison(needle: Area2D, target_pos: Vector2) -> void:
	needle.queue_free()

	# 检查玩家是否还在目标位置附近
	if player == null:
		return
	if player.global_position.distance_to(target_pos) < 50:
		start_poison(player)

func start_poison(target: Node2D) -> void:
	is_poisoning = true
	poison_victim = target
	poison_timer = POISON_DURATION
	play_sound("poison_hit")

func process_poison(delta: float) -> void:
	if poison_victim == null or not is_instance_valid(poison_victim):
		is_poisoning = false
		poison_timer = 0
		return

	poison_timer -= delta
	if poison_timer > 0:
		# 周期性伤害
		var interval_pos = POISON_DURATION - poison_timer
		if fmod(interval_pos, POISON_INTERVAL) < delta:
			if poison_victim.has_method("take_damage"):
				poison_victim.take_damage(POISON_DAMAGE * POISON_INTERVAL)
	else:
		is_poisoning = false
		poison_victim = null

func summon_minions() -> void:
	if main == null:
		main = get_tree().get_first_node_in_group("main")
	if main == null:
		return

	play_sound("summon")

	# 召唤2-3个小蜜蜂
	var minion_count = randi() % 2 + 2
	for i in range(minion_count):
		var pos = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		spawn_minion(pos)

	spawn_summon_effect()

func spawn_minion(pos: Vector2) -> void:
	# 创建小蜜蜂enemy
	var enemy_scene = preload("res://scenes/enemy.tscn")
	var minion = enemy_scene.instantiate()
	minion.position = pos
	minion.hp = 30  # 小兵血量较少
	minion.set_meta("is_boss_minion", true)

	if main.has_method("add_child"):
		main.add_child(minion)
	else:
		get_tree().root.add_child(minion)

func take_damage(dmg: float) -> void:
	if invincible > 0:
		return

	hp -= dmg
	invincible = 0.25
	health_bar.value = hp

	# 受击效果
	spawn_damage_popup(dmg)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:r", 2.0, 0.05)
	tween.tween_property(self, "modulate:g", 0.5, 0.05)
	tween.tween_property(self, "modulate:b", 0.5, 0.05)
	tween.chain().tween_property(self, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.chain().tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.1)

	# 击退
	var knock_dir = Vector2.ZERO
	if player:
		knock_dir = (global_position - player.global_position).normalized()
	global_position += knock_dir * 15

	if hp <= 0:
		die()

func spawn_damage_popup(dmg: float) -> void:
	var popup = Label.new()
	popup.text = str(int(dmg))
	popup.global_position = global_position + Vector2(-15, -40)
	popup.add_theme_font_size_override("font_size", 20)
	popup.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	popup.modulate = Color(1.0, 1.0, 1.0, 1.0)
	popup.add_to_group("battle_effects")
	get_tree().root.add_child(popup)

	var tween = popup.create_tween()
	tween.tween_property(popup, "position:y", popup.global_position.y - 50, 0.6)
	tween.chain().tween_property(popup, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(popup):
			popup.queue_free()
	)

func die() -> void:
	# 掉落大量资源
	spawn_resource_drop()

	# BOSS死亡特效
	spawn_death_effect()

	boss_died.emit()

	# 延迟删除
	await get_tree().create_timer(0.5).timeout
	queue_free()

func spawn_resource_drop() -> void:
	if main == null:
		main = get_tree().get_first_node_in_group("main")

	# 掉落5-8个蜜蜂残骸
	var drop_count = randi() % 4 + 5
	for i in range(drop_count):
		var pos = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		if main and main.has_method("spawn_resource"):
			main.spawn_resource(pos, "bee_remains")
		else:
			# 直接创建资源
			var resource_scene = preload("res://scenes/resource_pickup.tscn")
			var resource = resource_scene.instantiate()
			resource.position = pos
			resource.set_resource_type("bee_remains")
			resource.add_to_group("battle_effects")
			get_tree().root.add_child(resource)

func spawn_hit_effect() -> void:
	var effect = Polygon2D.new()
	var points = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8),
		Vector2(8, 8), Vector2(-8, 8)
	])
	effect.polygon = points
	effect.color = Color(1.0, 0.5, 0.0, 0.8)
	effect.global_position = global_position
	effect.add_to_group("battle_effects")
	get_tree().root.add_child(effect)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(2.0, 2.0), 0.15)
	tween.chain().tween_property(effect, "modulate:a", 0.0, 0.1)
	tween.chain().tween_callback(effect.queue_free)

func spawn_phase_change_effect() -> void:
	# 阶段转换时发出冲击波
	for i in range(16):
		var angle = 2 * PI * i / 16
		var dir = Vector2(cos(angle), sin(angle))

		var ring = Polygon2D.new()
		var ring_points = PackedVector2Array([
			Vector2(0, -5), Vector2(5, 0),
			Vector2(0, 5), Vector2(-5, 0)
		])
		ring.polygon = ring_points
		ring.color = Color(1.0, 0.8, 0.0, 0.8)
		ring.global_position = global_position + dir * 30
		ring.add_to_group("battle_effects")
		get_tree().root.add_child(ring)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(ring, "global_position", global_position + dir * 100, 0.4)
		tween.set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(ring, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(ring.queue_free)

func spawn_dash_wind_effect() -> void:
	for i in range(5):
		var wind = Polygon2D.new()
		var wind_points = PackedVector2Array([
			Vector2(-3, -4), Vector2(3, -4),
			Vector2(6, 0), Vector2(3, 4),
			Vector2(-3, 4)
		])
		wind.polygon = wind_points
		wind.color = Color(0.8, 0.9, 1.0, 0.5)
		wind.global_position = global_position - dash_direction * (20 + i * 15)
		wind.rotation = dash_direction.angle()
		wind.add_to_group("battle_effects")
		get_tree().root.add_child(wind)

		var tween = create_tween()
		tween.tween_property(wind, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(wind.queue_free)

func spawn_summon_effect() -> void:
	for i in range(12):
		var angle = 2 * PI * i / 12
		var pos = global_position + Vector2(cos(angle), sin(angle)) * 60

		var rune = Polygon2D.new()
		rune.color = Color(0.2, 1.0, 0.3, 0.7)
		var size = 8 + randf() * 8
		var points = PackedVector2Array([
			Vector2(0, -size), Vector2(size * 0.7, -size * 0.3),
			Vector2(size, 0), Vector2(size * 0.7, size * 0.3),
			Vector2(0, size), Vector2(-size * 0.7, size * 0.3),
			Vector2(-size, 0), Vector2(-size * 0.7, -size * 0.3)
		])
		rune.polygon = points
		rune.global_position = pos
		rune.add_to_group("battle_effects")
		get_tree().root.add_child(rune)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(rune, "global_position", global_position, 0.3)
		tween.set_ease(Tween.EASE_IN)
		tween.chain().tween_property(rune, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(rune.queue_free)

func spawn_death_effect() -> void:
	# 爆炸效果
	for i in range(30):
		var angle = randf() * TAU
		var dist = randf_range(30, 150)
		var target = global_position + Vector2(cos(angle), sin(angle)) * dist

		var particle = Polygon2D.new()
		var p_size = 5 + randf() * 10
		var p_points = PackedVector2Array([
			Vector2(-p_size, -p_size), Vector2(p_size, -p_size),
			Vector2(p_size, p_size), Vector2(-p_size, p_size)
		])
		particle.polygon = p_points
		particle.color = Color(
			0.8 + randf() * 0.2,
			0.6 + randf() * 0.2,
			0.0,
			1.0
		)
		particle.global_position = global_position
		particle.add_to_group("battle_effects")
		get_tree().root.add_child(particle)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", target, 0.4 + randf() * 0.3)
		tween.set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(particle.queue_free)

func play_sound(sound_name: String) -> void:
	var audio = get_tree().get_first_node_in_group("audio_manager")
	if audio and audio.has_method("play_sound"):
		audio.play_sound(sound_name)
