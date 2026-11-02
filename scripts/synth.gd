extends Node
## Small original synth soundtrack and game cues; no external audio assets.
var enabled := true
var music_enabled := true
var beat := 0.0
var step := 0
var cache: Dictionary = {}
const NOTES = [220.0, 0.0, 330.0, 440.0, 293.66, 0.0, 369.99, 440.0, 261.63, 0.0, 392.0, 523.25, 293.66, 369.99, 329.63, 0.0]

func _process(dt: float) -> void:
	beat -= dt
	if beat <= 0:
		beat = 0.235
		if music_enabled:
			if NOTES[step % NOTES.size()] > 0:
				tone(NOTES[step % NOTES.size()], 0.17, 0.055)
			if step % 4 == 0:
				tone([110.0, 146.83, 130.81, 146.83][(step / 4) as int % 4], 0.35, 0.07)
		step += 1

func tone(hz: float, duration: float = 0.1, volume: float = 0.18) -> void:
	if not enabled:
		return
	var key := "%s:%s" % [hz, duration]
	if not cache.has(key):
		var bytes := PackedByteArray()
		var count := int(22050 * duration)
		bytes.resize(count * 2)
		for i in range(count):
			var t := float(i) / 22050.0
			var envelope := minf(1.0, t * 120) * pow(1.0 - float(i) / count, 1.8)
			var sample := (sin(t * hz * TAU) + 0.22 * sin(t * hz * TAU * 2.0)) * envelope
			bytes.encode_s16(i * 2, int(sample * 24000))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		wav.data = bytes
		cache[key] = wav
	var p := AudioStreamPlayer.new()
	p.stream = cache[key]
	p.volume_db = linear_to_db(volume)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func cue(kind: String) -> void:
	match kind:
		"pick": tone(620, 0.08)
		"craft": tone(330, 0.22)
		"ready": tone(880, 0.22)
		"repair": tone(1046, 0.3)
		"parry": tone(1397, 0.25, 0.26)
		"hurt": tone(88, 0.3, 0.3)
		"jump": tone(440, 0.08, 0.08)
		"dash": tone(196, 0.12, 0.1)
		"win": tone(1318, 0.65)
		_: tone(250, 0.1, 0.12)
