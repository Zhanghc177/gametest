extends Area2D

## 撤离点 - 玩家停留3秒后触发撤离成功

const EXTRACT_DURATION: float = 2.5
const EXTRACT_RANGE: float = 80.0

signal extraction_started
signal extraction_progress(progress: float)
signal extraction_completed

var is_player_in_range: bool = false
var extract_progress: float = 0.0
var rotation_speed: float = 1.5

@onready var timer: Timer = $Timer
@onready var visual: Node2D = $Visual
@onready var visual_radius: ColorRect = $Visual/Radius

func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)
	timer.wait_time = 0.1
	timer.start()
	print("ExtractionPoint: ready, position=", global_position)

func _process(delta: float) -> void:
	visual.rotation += rotation_speed * delta

	var pulse = sin(Time.get_ticks_msec() / 200.0) * 0.1 + 0.9
	visual_radius.scale = Vector2(pulse, pulse) * 1.2

func reset_extraction() -> void:
	is_player_in_range = false
	extract_progress = 0.0
	extraction_progress.emit(0.0)
	if timer.is_stopped():
		timer.start()

func start_extraction() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dist = global_position.distance_to(player.global_position)
	if dist >= EXTRACT_RANGE:
		return

	if not is_player_in_range:
		is_player_in_range = true
		extract_progress = 0.0
		extraction_started.emit()
	if timer.is_stopped():
		timer.start()
	_on_timer_timeout()

func _on_timer_timeout() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dist = global_position.distance_to(player.global_position)
	var was_in_range = is_player_in_range
	is_player_in_range = dist < EXTRACT_RANGE

	if is_player_in_range and not was_in_range:
		print("ExtractionPoint: player entered range, dist=", dist)
		extract_progress = 0.0
		extraction_started.emit()
	elif not is_player_in_range and was_in_range:
		print("ExtractionPoint: player exited range, dist=", dist)
		extract_progress = 0.0
		extraction_progress.emit(0.0)

	if is_player_in_range:
		extract_progress += 0.1 / EXTRACT_DURATION
		extraction_progress.emit(extract_progress)

		if extract_progress >= 1.0:
			print("ExtractionPoint: extraction complete!")

			# 播放撤离成功音效
			var audio_manager = get_tree().get_first_node_in_group("audio_manager")
			if audio_manager:
				audio_manager.sfx_extraction_complete()

			extraction_completed.emit()
			timer.stop()
