extends Area2D

## Resource Pickup - Dropped by enemies, collected by player

signal picked_up

const PICKUP_RADIUS: float = 40.0
const LIFETIME: float = 30.0

var resource_type: String = "beetle_remains"
var bob_offset: float = 0.0
var lifetime: float = LIFETIME
var base_y: float = 0.0

# Collection animation state
enum CollectAnimState { IDLE, COLLECTING, DONE }
var collect_state: CollectAnimState = CollectAnimState.IDLE
var collect_timer: float = 0.0
var collect_progress: float = 0.0
var collecting: bool = false
var collect_target: Vector2 = Vector2.ZERO

# Idle animation
var idle_anim_frame: int = 0
var idle_anim_timer: float = 0.0
const IDLE_ANIM_SPEED: float = 0.1

func set_resource_type(type: String) -> void:
	resource_type = type

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var bob_timer: Timer = $BobTimer
@onready var visual: Node2D = $Visual

func _ready() -> void:
	var circle = CircleShape2D.new()
	circle.radius = PICKUP_RADIUS
	collision.shape = circle

	body_entered.connect(_on_body_entered)

	bob_timer.timeout.connect(_on_bob_timeout)
	bob_timer.wait_time = 0.05
	bob_timer.start()

	bob_offset = randf() * TAU
	base_y = position.y

func _process(delta: float) -> void:
	# 更新闲置动画帧
	idle_anim_timer += delta
	if idle_anim_timer >= IDLE_ANIM_SPEED:
		idle_anim_timer = 0.0
		idle_anim_frame = (idle_anim_frame + 1) % 4

	# 收集动画中
	if collecting:
		_update_collection_animation(delta)
		return

	lifetime -= delta
	if lifetime <= 0:
		queue_free()

	# 闲置动画 - 轻微上下浮动和发光脉冲
	var bob = sin(bob_offset) * 5
	visual.position.y = bob

	# 发光脉冲动画
	var glow = visual.get_node_or_null("Glow")
	if glow:
		var pulse = 0.3 + sin(idle_anim_frame * PI / 2) * 0.1
		glow.color.a = pulse

	# 淡出警告（最后5秒）
	if lifetime < 5.0:
		modulate.a = lifetime / 5.0

func _update_collection_animation(delta: float) -> void:
	collect_progress += delta * 5  # 快速收集
	if collect_progress >= 1.0:
		picked_up.emit(self, resource_type)
		queue_free()
		return

	# 向玩家飞去
	var player = get_tree().get_first_node_in_group("player")
	if player:
		collect_target = player.global_position

	var current_pos = global_position
	var dir = (collect_target - current_pos).normalized()
	global_position = current_pos + dir * 200 * delta

	# 收集时快速旋转和缩放
	visual.rotation += delta * 15
	var scale_factor = 1.0 - collect_progress * 0.8
	visual.scale = Vector2(scale_factor, scale_factor)

	# 收集时变为半透明
	modulate.a = 1.0 - collect_progress * 0.5

func _on_bob_timeout() -> void:
	bob_offset += 0.15

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not collecting:
		# 播放资源拾取音效
		var audio_manager = get_tree().get_first_node_in_group("audio_manager")
		if audio_manager:
			audio_manager.sfx_resource_pickup()

		# 开始收集动画
		_start_collect_animation()

## 开始收集动画
func _start_collect_animation() -> void:
	collecting = true
	collision.call_deferred("set", "disabled", true)  # 使用call_deferred避免在physics callback中修改状态

	# 停止浮动动画
	bob_timer.stop()

	# 播放收集音效
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager:
		audio_manager.sfx_resource_pickup()

	# 收集光环扩散效果
	spawn_collect_effect()

## 收集动画效果 - 在原地生成光环和粒子
func spawn_collect_effect() -> void:
	# 向玩家方向飞去的金色粒子
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	for i in range(6):
		var particle = Polygon2D.new()
		var p_points = PackedVector2Array([
			Vector2(-4, -4), Vector2(4, -4),
			Vector2(4, 4), Vector2(-4, 4)
		])
		particle.polygon = p_points
		particle.color = Color(1.0, 0.8, 0.2, 0.9)
		particle.global_position = global_position
		particle.add_to_group("battle_effects")
		get_tree().root.add_child(particle)

		var target_pos = player.global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		var tween = create_tween()
		tween.tween_property(particle, "global_position", target_pos, 0.2 + i * 0.03)
		tween.set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(particle, "modulate:a", 0.0, 0.1)
		tween.chain().tween_callback(particle.queue_free)

	# 收集光环扩散
	var ring = Polygon2D.new()
	var ring_points = PackedVector2Array()
	for j in range(16):
		var a = 2 * PI * j / 16
		ring_points.append(Vector2(cos(a), sin(a)) * 15)
	ring.polygon = ring_points
	ring.color = Color(1.0, 0.9, 0.3, 0.7)
	ring.global_position = global_position
	ring.add_to_group("battle_effects")
	get_tree().root.add_child(ring)

	var ring_tween = create_tween()
	ring_tween.tween_property(ring, "scale", Vector2(2.5, 2.5), 0.3)
	ring_tween.chain().tween_property(ring, "modulate:a", 0.0, 0.1)
	ring_tween.chain().tween_callback(ring.queue_free)
