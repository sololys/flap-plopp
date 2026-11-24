extends SceneTree

# Headless verification for Flap & Plopp core mechanics (Godot 4.3)

const FlapPloppCore = preload("res://scripts/game_core.gd")
const SoundSynth = preload("res://scripts/sound_synth.gd")

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		quit(1)

func _initialize() -> void:
	var core = FlapPloppCore.new(1337)
	_assert(core.mode == FlapPloppCore.Mode.TITLE, "Starts in TITLE mode")

	# 1. Start run & flap in air
	core.start_run()
	_assert(core.mode == FlapPloppCore.Mode.PLAYING, "Transitions to PLAYING")
	_assert(not core.in_water, "Starts in air")
	var y_before: float = core.player_y
	core.action_flap_or_dive()
	core.step(0.05)
	_assert(core.player_y < y_before, "Flap moves puffin upward in air")

	# 2. SHIFT -> PLOPP into water
	var shifted: bool = core.action_shift()
	_assert(shifted and core.in_water, "SHIFT plunges puffin into water")
	_assert(core.shifts_used == 1, "Shift counter incremented")
	_assert(core.player_y > FlapPloppCore.WATER_Y, "Puffin is below water surface")

	# 3. Buoyancy lifts upward underwater; SPACE dives downward
	core.player_y = 500.0
	core.player_vy = 0.0
	core.step(0.10)
	_assert(core.player_vy < 0.0, "Underwater buoyancy pushes upward")
	core.action_flap_or_dive()
	_assert(core.player_vy > 0.0, "SPACE dives downward underwater")

	# 4. SHIFT back to sky near surface -> combo bonus!
	core.shift_cooldown = 0.0
	core.player_y = FlapPloppCore.WATER_Y + 30.0
	var score_before: int = core.score
	var back_up: bool = core.action_shift()
	_assert(back_up and not core.in_water, "SHIFT launches puffin back into sky")
	_assert(core.combo >= 2 and core.score > score_before, "Near-surface SHIFT awards combo bonus")

	# 5. Collectible pickup awards points & increments combo
	core.collectibles.clear()
	core.collectibles.append({
		"kind": "star",
		"x": FlapPloppCore.PLAYER_X + 2.0,
		"y": core.player_y,
		"r": 14.0,
	})
	var s2: int = core.score
	core.step(0.016)
	_assert(core.score > s2, "Picking up star increases score")

	# 6. Obstacle collision triggers GAME_OVER and updates best_score
	core.obstacles.clear()
	core.obstacles.append({
		"kind": "buoy",
		"x": FlapPloppCore.PLAYER_X,
		"y": core.player_y,
		"w": 46.0,
		"h": 180.0,
		"passed": false,
	})
	core.step(0.016)
	_assert(core.mode == FlapPloppCore.Mode.GAME_OVER, "Obstacle hit triggers GAME_OVER")
	_assert(core.best_score == core.score and core.best_score > 0, "Best score recorded")

	# 7. Procedural WAV synth builds all 5 sound effects cleanly
	_assert(SoundSynth.make_flap().data.size() > 0, "Flap WAV generated")
	_assert(SoundSynth.make_plopp().data.size() > 0, "Plopp WAV generated")
	_assert(SoundSynth.make_splash().data.size() > 0, "Splash WAV generated")
	_assert(SoundSynth.make_pickup().data.size() > 0, "Pickup WAV generated")
	_assert(SoundSynth.make_bonk().data.size() > 0, "Bonk WAV generated")

	print("FLAP_PLOPP_HEADLESS_PASS tests=7/7 score=%d best=%d shifts=%d" % [core.score, core.best_score, core.shifts_used])
	quit(0)
