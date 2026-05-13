extends Node

# AudioManager - 音频管理器单例类
# 管理背景音乐和音效播放

# 信号定义
signal bgm_fade_complete
signal sfx_played(sfx_name: String)

# 背景音乐节点
var _bgm_player: AudioStreamPlayer
var _bgm_fade_tween: Tween

# 音效播放器池
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 16

# 语音播放器节点
var _voice_player: AudioStreamPlayer

# 音量设置
var bgm_volume: float = 0.8
var sfx_volume: float = 1.0
var voice_volume: float = 1.0

# 静音设置
var bgm_muted: bool = false
var sfx_muted: bool = false
var voice_muted: bool = false

# 当前播放状态
var _current_bgm: String = ""
var _is_fading: bool = false

# BGM路径
const BGM_BASE: String = "res://audio/bgm/base.mp3"
const BGM_BATTLE: String = "res://audio/bgm/battle.mp3"
const BGM_EXTRACTION_SUCCESS: String = "res://audio/bgm/extraction_success.mp3"

# 10种核心音效枚举
enum SFX {
	ATTACK,          # 攻击音效
	ATTACK_HIT,      # 攻击命中
	MOVE,            # 移动音效
	RESOURCE_PICKUP, # 资源拾取
	ENEMY_DEATH,     # 敌人死亡
	BASE_DAMAGED,    # 基地受损
	EXTRACTION_START, # 撤离开始
	EXTRACTION_COMPLETE, # 撤离完成
	UI_CLICK,        # UI点击
	WARNING          # 警告
}

# 音效路径映射
var _sfx_paths: Dictionary = {
	SFX.ATTACK: "res://audio/sfx/attack.mp3",
	SFX.ATTACK_HIT: "res://audio/sfx/attack_hit.mp3",
	SFX.MOVE: "res://audio/sfx/move.mp3",
	SFX.RESOURCE_PICKUP: "res://audio/sfx/resource_pickup.mp3",
	SFX.ENEMY_DEATH: "res://audio/sfx/enemy_death.mp3",
	SFX.BASE_DAMAGED: "res://audio/sfx/base_damaged.mp3",
	SFX.EXTRACTION_START: "res://audio/sfx/extraction_start.mp3",
	SFX.EXTRACTION_COMPLETE: "res://audio/sfx/extraction_complete.mp3",
	SFX.UI_CLICK: "res://audio/sfx/ui_click.mp3",
	SFX.WARNING: "res://audio/sfx/warning.mp3"
}

# 缓存已加载的音效
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	# 确保只有一个AudioManager实例
	var managers = get_tree().get_nodes_in_group("audio_manager")
	if managers.size() > 1:
		queue_free()
		return

	add_to_group("audio_manager")

	# 初始化BGM播放器
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = linear_to_db(bgm_volume)
	add_child(_bgm_player)

	# 初始化音效播放器池
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = linear_to_db(sfx_volume)
		_sfx_players.append(player)
		add_child(player)

	# 初始化语音播放器
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "Master"
	_voice_player.volume_db = linear_to_db(voice_volume)
	add_child(_voice_player)

	# 连接BGM结束信号
	_bgm_player.finished.connect(_on_bgm_finished)

func _on_bgm_finished() -> void:
	# BGM播放完成时重新播放（如果需要循环）
	pass

# ==================== BGM管理 ====================

# 播放背景音乐
func play_bgm(bgm_name: String, fade_duration: float = 0.0) -> void:
	var path = _get_bgm_path(bgm_name)
	if path == "":
		return

	var stream = load_bgm(path)
	if stream == null:
		return

	# 淡入处理
	if fade_duration > 0 and _bgm_player.playing:
		_fade_bgm_to_new(path, fade_duration)
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = linear_to_db(bgm_volume)
		_bgm_player.play()
		_current_bgm = bgm_name

# 停止背景音乐
func stop_bgm(fade_duration: float = 0.0) -> void:
	if fade_duration > 0:
		_fade_out(fade_duration)
	else:
		_bgm_player.stop()
		_current_bgm = ""

# 暂停背景音乐
func pause_bgm() -> void:
	_bgm_player.stream_paused = true

# 恢复背景音乐
func resume_bgm() -> void:
	_bgm_player.stream_paused = false

# 获取当前BGM名称
func get_current_bgm() -> String:
	return _current_bgm

# 设置BGM音量
func set_bgm_volume(volume: float, mute: bool = false) -> void:
	bgm_volume = clamp(volume, 0.0, 1.0)
	bgm_muted = mute
	var effective_volume = 0.0 if bgm_muted else bgm_volume
	_bgm_player.volume_db = linear_to_db(effective_volume)

# 获取BGM音量
func get_bgm_volume() -> float:
	return bgm_volume

# 获取BGM静音状态
func is_bgm_muted() -> bool:
	return bgm_muted

# 设置BGM静音
func set_bgm_muted(muted: bool) -> void:
	bgm_muted = muted
	_bgm_player.volume_db = linear_to_db(0.0 if bgm_muted else bgm_volume)

# 淡入BGM
func fade_in_bgm(bgm_name: String, duration: float = 2.0) -> void:
	var path = _get_bgm_path(bgm_name)
	if path == "":
		return

	var stream = load_bgm(path)
	if stream == null:
		return

	_bgm_player.stream = stream
	_bgm_player.volume_db = linear_to_db(0.0)
	_bgm_player.play()

	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(_bgm_player, "volume_db", linear_to_db(bgm_volume), duration)
	_bgm_fade_tween.tween_callback(func(): bgm_fade_complete.emit())
	_current_bgm = bgm_name

# 淡出BGM
func fade_out_bgm(duration: float = 2.0) -> void:
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()

	_is_fading = true
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(_bgm_player, "volume_db", linear_to_db(0.0), duration)
	_bgm_fade_tween.tween_callback(_on_fade_out_complete)

func _on_fade_out_complete() -> void:
	_bgm_player.stop()
	_is_fading = false
	_current_bgm = ""
	bgm_fade_complete.emit()

func _fade_bgm_to_new(path: String, duration: float) -> void:
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()

	_is_fading = true
	var new_player = AudioStreamPlayer.new()
	new_player.bus = "Master"
	new_player.volume_db = linear_to_db(0.0)
	new_player.stream = load_bgm(path)
	add_child(new_player)
	new_player.play()

	# 旧播放器淡出
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(_bgm_player, "volume_db", linear_to_db(0.0), duration)
	_bgm_fade_tween.tween_callback(func(): _cleanup_old_bgm_player(new_player))

func _cleanup_old_bgm_player(new_player: AudioStreamPlayer) -> void:
	_bgm_player.stop()
	_bgm_player.queue_free()
	_bgm_player = new_player
	_current_bgm = ""
	_is_fading = false
	bgm_fade_complete.emit()

func _fade_out(duration: float) -> void:
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(_bgm_player, "volume_db", linear_to_db(0.0), duration)
	_bgm_fade_tween.tween_callback(_on_fade_out_complete)

func _get_bgm_path(bgm_name: String) -> String:
	match bgm_name:
		"base":
			return BGM_BASE
		"battle":
			return BGM_BATTLE
		"extraction_success":
			return BGM_EXTRACTION_SUCCESS
		_:
			return ""

func load_bgm(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		push_warning("AudioManager: BGM文件不存在: " + path)
		# 返回程序生成的循环 BGM 占位音效
		return _generate_bgm_placeholder()

	return load(path)

# 生成循环 BGM 占位音效（简单的环境音）
func _generate_bgm_placeholder() -> AudioStream:
	var sample_rate = 22050
	var duration = 1.0  # 1秒循环
	var num_samples = int(sample_rate * duration)

	var data = PackedByteArray()
	data.resize(num_samples)

	# 生成柔和的低频音调作为占位 BGM
	for i in range(num_samples):
		var t = float(i) / sample_rate
		# 混合多个低频正弦波
		var sample = 0.0
		sample += sin(2.0 * PI * 110.0 * t) * 0.3  # A2
		sample += sin(2.0 * PI * 165.0 * t) * 0.2  # E3
		sample += sin(2.0 * PI * 220.0 * t) * 0.15  # A3
		sample = 127.5 + sample * 64.0
		data[i] = int(clamp(sample, 0, 255))

	var stream = AudioStreamWAV.new()
	stream.format = 0  # AudioStreamWAV.FORMAT_8BIT
	stream.stereo = false
	stream.mix_rate = sample_rate
	stream.data = data
	stream.loop = true
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	return stream

# ==================== SFX管理 ====================

# 播放音效
func play_sfx(sfx: SFX, volume_modifier: float = 1.0) -> void:
	var path = _sfx_paths.get(sfx, "")
	if path == "":
		return

	var stream = load_sfx(path)
	if stream == null:
		return

	# 查找空闲的播放器
	var player = _get_available_sfx_player()
	if player == null:
		return

	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume * volume_modifier)
	player.play()
	sfx_played.emit(str(sfx))

# 播放音效（通过名称）
func play_sfx_by_name(sfx_name: String, volume_modifier: float = 1.0) -> void:
	for key in _sfx_paths.keys():
		if str(key) == sfx_name or str(SFX[key]) == sfx_name:
			play_sfx(key as SFX, volume_modifier)
			return

# 停止所有音效
func stop_all_sfx() -> void:
	for player in _sfx_players:
		player.stop()

# 设置SFX音量
func set_sfx_volume(volume: float, mute: bool = false) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	sfx_muted = mute
	var effective_volume = 0.0 if sfx_muted else sfx_volume
	for player in _sfx_players:
		player.volume_db = linear_to_db(effective_volume)

# 获取SFX音量
func get_sfx_volume() -> float:
	return sfx_volume

# 获取SFX静音状态
func is_sfx_muted() -> bool:
	return sfx_muted

# 设置SFX静音
func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	var effective_volume = 0.0 if sfx_muted else sfx_volume
	for player in _sfx_players:
		player.volume_db = linear_to_db(effective_volume)

# ==================== 语音管理 ====================

# 设置语音音量
func set_voice_volume(volume: float, mute: bool = false) -> void:
	voice_volume = clamp(volume, 0.0, 1.0)
	voice_muted = mute
	var effective_volume = 0.0 if voice_muted else voice_volume
	_voice_player.volume_db = linear_to_db(effective_volume)

# 获取语音音量
func get_voice_volume() -> float:
	return voice_volume

# 获取语音静音状态
func is_voice_muted() -> bool:
	return voice_muted

# 设置语音静音
func set_voice_muted(muted: bool) -> void:
	voice_muted = muted
	_voice_player.volume_db = linear_to_db(0.0 if voice_muted else voice_volume)

# 播放语音
func play_voice(voice_path: String) -> void:
	if voice_muted:
		return
	if not FileAccess.file_exists(voice_path):
		push_warning("AudioManager: 语音文件不存在: " + voice_path)
		return
	_voice_player.stream = load(voice_path)
	_voice_player.volume_db = linear_to_db(voice_volume)
	_voice_player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:
	# 优先查找空闲的播放器
	for player in _sfx_players:
		if not player.playing:
			return player
	# 如果没有空闲的，复用第一个
	return _sfx_players[0]

func load_sfx(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		push_warning("AudioManager: SFX文件不存在: " + path)
		# 返回程序生成的 beep 占位音效
		return _generate_beep_sfx()

	if _sfx_cache.has(path):
		return _sfx_cache[path]

	var stream = load(path)
	_sfx_cache[path] = stream
	return stream

# 生成简短的 beep 音效作为占位
func _generate_beep_sfx() -> AudioStream:
	var sample_rate = 22050
	var duration = 0.05  # 50ms
	var num_samples = int(sample_rate * duration)

	# 创建 8 位单声道 PCM WAV 数据
	var data = PackedByteArray()
	data.resize(num_samples)

	# 生成 440Hz 正弦波 beep
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var sample = int(127.5 + 127.5 * sin(2.0 * PI * 440.0 * t) * 0.3)
		data[i] = sample

	var stream = AudioStreamWAV.new()
	stream.format = 0  # AudioStreamWAV.FORMAT_8BIT
	stream.stereo = false
	stream.mix_rate = sample_rate
	stream.data = data

	return stream

# ==================== 便捷方法 ====================

# 播放战斗BGM
func play_battle_bgm(fade_duration: float = 1.0) -> void:
	play_bgm("battle", fade_duration)

# 播放基地BGM
func play_base_bgm(fade_duration: float = 1.0) -> void:
	play_bgm("base", fade_duration)

# 播放撤离成功BGM
func play_extraction_success_bgm(fade_duration: float = 2.0) -> void:
	play_bgm("extraction_success", fade_duration)

# 播放攻击音效
func sfx_attack() -> void:
	play_sfx(SFX.ATTACK)

# 播放受伤音效
func sfx_hurt() -> void:
	play_sfx(SFX.ATTACK_HIT)

# 播放攻击命中音效
func sfx_attack_hit() -> void:
	play_sfx(SFX.ATTACK_HIT)

# 播放移动音效
func sfx_move() -> void:
	play_sfx(SFX.MOVE)

# 播放资源拾取音效
func sfx_resource_pickup() -> void:
	play_sfx(SFX.RESOURCE_PICKUP)

# 播放敌人死亡音效
func sfx_enemy_death() -> void:
	play_sfx(SFX.ENEMY_DEATH)

# 播放基地受损音效
func sfx_base_damaged() -> void:
	play_sfx(SFX.BASE_DAMAGED)

# 播放撤离开始音效
func sfx_extraction_start() -> void:
	play_sfx(SFX.EXTRACTION_START)

# 播放撤离完成音效
func sfx_extraction_complete() -> void:
	play_sfx(SFX.EXTRACTION_COMPLETE)

# 播放UI点击音效
func sfx_ui_click() -> void:
	play_sfx(SFX.UI_CLICK)

# 播放警告音效
func sfx_warning() -> void:
	play_sfx(SFX.WARNING)