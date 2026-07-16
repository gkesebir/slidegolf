extends Node

# AudioController singleton — generates simple SFX programmatically
# No external audio files needed!

var is_muted: bool = false

func _ready():
	pass

# ─── Helpers ───

func _generate_tone(freq: float, duration: float, volume_db: float = -6.0, wave: String = "sine") -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit = 2 bytes per sample

	for i in range(num_samples):
		var t := float(i) / sample_rate
		var envelope := 1.0 - (float(i) / num_samples)  # linear fade-out
		envelope = envelope * envelope  # quadratic fade for smoother decay
		var sample_f := 0.0

		if wave == "sine":
			sample_f = sin(TAU * freq * t) * envelope
		elif wave == "square":
			sample_f = (1.0 if sin(TAU * freq * t) >= 0 else -1.0) * envelope * 0.4
		elif wave == "noise":
			sample_f = randf_range(-1.0, 1.0) * envelope * 0.3

		var sample_i := clampi(int(sample_f * 32000), -32768, 32767)
		data[i * 2] = sample_i & 0xFF
		data[i * 2 + 1] = (sample_i >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func _play_stream(stream: AudioStreamWAV, volume_db: float = -6.0):
	if is_muted:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())

# ─── Sound Effects ───

func play_hit():
	# Cute short "tık" click — sharp high-freq tap
	var sample_rate := 22050
	var duration := 0.035
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in range(num_samples):
		var t := float(i) / sample_rate
		var progress := float(i) / num_samples
		var envelope := (1.0 - progress) * (1.0 - progress) * (1.0 - progress)  # cubic decay
		# Mix two frequencies for a woody "tık" character
		var sample_f := (sin(TAU * 1800.0 * t) * 0.6 + sin(TAU * 3200.0 * t) * 0.4) * envelope
		var sample_i := clampi(int(sample_f * 22000), -32768, 32767)
		data[i * 2] = sample_i & 0xFF
		data[i * 2 + 1] = (sample_i >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	_play_stream(stream, -8.0)

func play_gem():
	# Bright sparkle — two quick ascending tones
	var stream1 := _generate_tone(880.0, 0.06, -8.0, "sine")
	var stream2 := _generate_tone(1320.0, 0.08, -8.0, "sine")
	_play_stream(stream1, -8.0)
	# Delay second tone slightly
	var timer := get_tree().create_timer(0.07)
	timer.timeout.connect(func(): _play_stream(stream2, -8.0))

func play_hole():
	# Satisfying "drop in" — descending tone 440→220, 0.15s
	var sample_rate := 22050
	var duration := 0.15
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in range(num_samples):
		var t := float(i) / sample_rate
		var progress := float(i) / num_samples
		var freq := lerpf(440.0, 220.0, progress)
		var envelope := 1.0 - progress
		var sample_f := sin(TAU * freq * t) * envelope
		var sample_i := clampi(int(sample_f * 28000), -32768, 32767)
		data[i * 2] = sample_i & 0xFF
		data[i * 2 + 1] = (sample_i >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	_play_stream(stream, -4.0)

	# Applause — layered noise bursts to simulate small crowd clapping
	_play_applause()

func play_victory():
	# Quick cheerful jingle — 3 ascending notes + short noise burst for "applause feel"
	var notes := [523.0, 659.0, 784.0, 1047.0]  # C5, E5, G5, C6
	var delay := 0.0
	for note in notes:
		var stream := _generate_tone(note, 0.12, -6.0, "sine")
		if delay == 0.0:
			_play_stream(stream, -6.0)
		else:
			var d := delay
			var s := stream
			var timer := get_tree().create_timer(d)
			timer.timeout.connect(func(): _play_stream(s, -6.0))
		delay += 0.13

	# Add short "applause" noise burst after the jingle
	var applause_stream := _generate_tone(0.0, 0.4, -12.0, "noise")
	var applause_timer := get_tree().create_timer(delay)
	applause_timer.timeout.connect(func(): _play_stream(applause_stream, -12.0))

func _play_applause():
	# Simulate a small crowd clapping — multiple short noise bursts staggered
	var sample_rate := 22050
	var total_duration := 1.2
	var num_samples := int(sample_rate * total_duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	# Create rhythmic "clap" pattern with randomized timing
	var clap_times := []
	var t_pos := 0.05
	while t_pos < total_duration - 0.05:
		clap_times.append(t_pos)
		t_pos += randf_range(0.06, 0.14)  # irregular spacing like real clapping

	for i in range(num_samples):
		var t := float(i) / sample_rate
		var progress := float(i) / num_samples
		# Overall fade: rise quickly then fade out
		var master_env := 0.0
		if progress < 0.1:
			master_env = progress / 0.1
		else:
			master_env = 1.0 - ((progress - 0.1) / 0.9)
		master_env = maxf(master_env, 0.0)

		var sample_f := 0.0
		for clap_t in clap_times:
			var dt := t - clap_t
			if dt >= 0.0 and dt < 0.03:
				# Each clap is a very short noise burst with sharp attack
				var clap_env := (1.0 - dt / 0.03)
				clap_env = clap_env * clap_env
				sample_f += randf_range(-1.0, 1.0) * clap_env * 0.15

		sample_f *= master_env
		var sample_i := clampi(int(sample_f * 30000), -32768, 32767)
		data[i * 2] = sample_i & 0xFF
		data[i * 2 + 1] = (sample_i >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data

	# Slight delay after the hole drop sound
	var timer := get_tree().create_timer(0.2)
	timer.timeout.connect(func(): _play_stream(stream, -6.0))

func toggle_mute(mute: bool):
	is_muted = mute
	var bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, is_muted)
