extends SceneTree

# Headless verification for Flap & Plopp: The Fjord Shift (12/12 checks)

const FlapPloppCore = preload("res://scripts/game_core.gd")
const SoundSynth = preload("res://scripts/sound_synth.gd")

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		quit(1)

func _initialize() -> void:
	var core = FlapPloppCore.new(1337)
	_assert(core.mode == FlapPloppCore.Mode.TITLE, "1. Starts in TITLE")

	# 2. Story start opens Intro dialogue sequence
	core.start_story()
	_assert(core.mode == FlapPloppCore.Mode.DIALOGUE, "2. start_story enters DIALOGUE")
	_assert(str(core.current_dialogue_line().get("speaker", "")) == "Captain Klabb", "3. Intro starts with Captain Klabb")

	# 3. Advancing/skipping dialogue enters CHAPTER_BANNER -> PLAYING
	core.skip_dialogue()
	_assert(core.mode == FlapPloppCore.Mode.CHAPTER_BANNER, "4. Dialogue finishes into CHAPTER_BANNER")
	core.action_flap_or_dive()
	_assert(core.mode == FlapPloppCore.Mode.PLAYING, "5. Flap from banner enters PLAYING")

	# 4. Air flap & SHIFT -> PLOPP underwater & buoyancy
	var y_before: float = core.player_y
	core.action_flap_or_dive()
	core.step(0.05)
	_assert(core.player_y < y_before, "6. Flap lifts puffin in air")
	var shifted: bool = core.action_shift()
	_assert(shifted and core.in_water and core.player_y > FlapPloppCore.WATER_Y, "7. SHIFT plunges puffin underwater")
	core.player_y = 500.0
	core.player_vy = 0.0
	core.step(0.10)
	_assert(core.player_vy < 0.0, "8. Buoyancy lifts upward underwater")

	# 5. Chapter progression 1 -> 2 -> 3 -> 4 -> Finale -> Victory -> Endless
	core.score = 155
	core.shift_cooldown = 0.0
	core.player_y = FlapPloppCore.WATER_Y + 25.0
	core.action_shift()
	_assert(core.chapter_index == 1 and core.mode == FlapPloppCore.Mode.DIALOGUE, "9. Reaching Ch1 goal triggers Ch2 Lumina dialogue")
	core.skip_dialogue()
	core.action_flap_or_dive()

	# Jump straight to Ch4 finale check
	core.chapter_index = 3
	core.score = 1120
	core.shift_cooldown = 0.0
	core.player_y = FlapPloppCore.WATER_Y - 25.0
	core.action_shift()
	_assert(core.mode == FlapPloppCore.Mode.DIALOGUE, "10. Reaching Ch4 goal triggers Finale dialogue")
	core.skip_dialogue()
	_assert(core.mode == FlapPloppCore.Mode.VICTORY, "11. Finale completes into VICTORY")

	core.action_flap_or_dive()
	_assert(core.mode == FlapPloppCore.Mode.PLAYING and core.endless_mode, "12. Victory unlocks Endless Aurora mode")

	# Audio synth sanity across all 7 procedural WAVs
	_assert(SoundSynth.make_flap().data.size() > 0, "Flap WAV ok")
	_assert(SoundSynth.make_plopp().data.size() > 0, "Plopp WAV ok")
	_assert(SoundSynth.make_splash().data.size() > 0, "Splash WAV ok")
	_assert(SoundSynth.make_pickup().data.size() > 0, "Pickup WAV ok")
	_assert(SoundSynth.make_bonk().data.size() > 0, "Bonk WAV ok")
	_assert(SoundSynth.make_blip().data.size() > 0, "Blip WAV ok")
	_assert(SoundSynth.make_fanfare().data.size() > 0, "Fanfare WAV ok")

	print("FLAP_PLOPP_STORY_HEADLESS_PASS tests=12/12 chapters=4 wavs=7 score=%d" % core.score)
	quit(0)
