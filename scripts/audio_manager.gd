class_name NeonAudio
extends Node

const MIX_RATE := 22050

func _ready() -> void:
	add_to_group("neon_audio")

func play_shot(weapon_index: int) -> void:
	var frequency: float = 680.0
	if weapon_index == 1:
		frequency = 180.0
	elif weapon_index == 2:
		frequency = 940.0
	_play_tone(frequency, 0.055, -12.0)

func play_reload() -> void:
	_play_tone(320.0, 0.12, -16.0)

func play_pickup() -> void:
	_play_tone(1120.0, 0.10, -14.0)

func play_enemy_down() -> void:
	_play_tone(120.0, 0.13, -18.0)

func play_lockdown() -> void:
	_play_tone(150.0, 0.16, -14.0)
	_queue_tone(0.11, 92.0, 0.20, -13.0)


func play_reinforcement() -> void:
	_play_tone(620.0, 0.10, -15.0)
	_queue_tone(0.10, 820.0, 0.10, -14.0)
	_queue_tone(0.20, 1040.0, 0.14, -13.0)


func play_objective_destroyed() -> void:
	_play_tone(260.0, 0.10, -15.0)
	_queue_tone(0.08, 520.0, 0.11, -14.0)
	_queue_tone(0.16, 920.0, 0.14, -12.0)


func play_uplink_complete() -> void:
	_play_tone(420.0, 0.12, -15.0)
	_queue_tone(0.10, 680.0, 0.12, -14.0)
	_queue_tone(0.20, 980.0, 0.18, -12.0)


func play_boss_phase() -> void:
	_play_tone(110.0, 0.22, -12.0)
	_queue_tone(0.10, 165.0, 0.26, -11.0)


func play_extraction_ready() -> void:
	_play_tone(540.0, 0.13, -14.0)
	_queue_tone(0.12, 760.0, 0.14, -13.0)
	_queue_tone(0.24, 1080.0, 0.22, -11.0)


func play_victory() -> void:
	_play_tone(880.0, 0.32, -10.0)

func play_defeat() -> void:
	_play_tone(92.0, 0.38, -10.0)

func _queue_tone(delay: float, frequency: float, duration: float, volume_db: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var timer := get_tree().create_timer(maxf(0.0, delay))
	timer.timeout.connect(_play_tone.bind(frequency, duration, volume_db))


func _play_tone(frequency: float, duration: float, volume_db: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	var sample_count: int = maxi(1, int(duration * float(MIX_RATE)))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var envelope: float = 1.0 - float(i) / float(sample_count)
		var sample_value: int = int(sin(TAU * frequency * t) * envelope * 0.24 * 32767.0)
		bytes.encode_s16(i * 2, clampi(sample_value, -32768, 32767))
	stream.data = bytes
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
