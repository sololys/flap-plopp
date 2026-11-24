class_name SoundSynth
extends RefCounted

# Procedural 16-bit PCM WAV synthesizer for Flap & Plopp (zero external audio files)

const MIX_RATE := 22050

static func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = data
	return wav

static func make_flap() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.11)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var freq := lerpf(280.0, 560.0, t)
		phase += TAU * freq / float(MIX_RATE)
		var env := sin(t * PI) * 0.35
		s[i] = sin(phase) * env
	return _make_wav(s)

static func make_plopp() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.18)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var freq := 210.0 + 480.0 * (t * t)
		phase += TAU * freq / float(MIX_RATE)
		var env := pow(1.0 - t, 1.4) * sin(minf(t * 9.0, 1.0) * PI * 0.5) * 0.55
		s[i] = sin(phase) * env
	return _make_wav(s)

static func make_splash() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(n):
		var t := float(i) / float(n)
		var freq := lerpf(340.0, 820.0, t)
		phase += TAU * freq / float(MIX_RATE)
		var env := pow(1.0 - t, 1.3) * 0.42
		var fizz := rng.randf_range(-0.35, 0.35) * (1.0 - t)
		s[i] = (sin(phase) * 0.7 + fizz) * env
	return _make_wav(s)

static func make_pickup() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.19)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var freq := 660.0 if t < 0.45 else 990.0
		phase += TAU * freq / float(MIX_RATE)
		var env := pow(1.0 - t, 1.2) * 0.42
		s[i] = (sin(phase) + 0.25 * sin(phase * 2.0)) * env
	return _make_wav(s)

static func make_bonk() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.22)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var freq := lerpf(240.0, 95.0, t)
		phase += TAU * freq / float(MIX_RATE)
		var env := pow(1.0 - t, 1.1) * 0.5
		s[i] = sin(phase) * env
	return _make_wav(s)

static func make_blip() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.045)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var freq := lerpf(420.0, 520.0, t)
		phase += TAU * freq / float(MIX_RATE)
		var env := sin(t * PI) * 0.22
		s[i] = sin(phase) * env
	return _make_wav(s)

static func make_fanfare() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99, 1046.5] # C5-E5-G5-C6 joyful arpeggio
	var note_len := int(MIX_RATE * 0.11)
	var total := note_len * notes.size()
	var s := PackedFloat32Array()
	s.resize(total)
	var phase := 0.0
	for idx in range(notes.size()):
		var freq: float = notes[idx]
		for j in range(note_len):
			var t := float(j) / float(note_len)
			phase += TAU * freq / float(MIX_RATE)
			var env := sin(minf(t * 6.0, 1.0) * PI * 0.5) * pow(1.0 - t * 0.7, 1.2) * 0.36
			s[idx * note_len + j] = (sin(phase) + 0.3 * sin(phase * 2.0)) * env
	return _make_wav(s)
