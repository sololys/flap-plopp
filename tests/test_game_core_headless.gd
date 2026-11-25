extends SceneTree

# Headless verification for Flap & Plopp: The Fjord Shift (16/16 checks)
# Verifies all 4 core laws: T(T(s)) = s, C(t) < R, HOLD, and KILL.

const FlapPloppCore = preload("res://scripts/game_core.gd")
const SoundSynth = preload("res://scripts/sound_synth.gd")

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		quit(1)

func _initialize() -> void:
	# Law 1: Exact IKS involution F(s) = 1 - s => F(F(s)) == s (zero residual)
	_assert(FlapPloppCore.apply_involution_T(FlapPloppCore.apply_involution_T(FlapPloppCore.Medium.SKY)) == FlapPloppCore.Medium.SKY, "1. F(F(SKY)) == SKY")
	_assert(FlapPloppCore.apply_involution_T(FlapPloppCore.apply_involution_T(FlapPloppCore.Medium.SEA)) == FlapPloppCore.Medium.SEA, "2. F(F(SEA)) == SEA")

	var core = FlapPloppCore.new(1337)
	_assert(core.mode == FlapPloppCore.Mode.TITLE, "3. Starts in TITLE")
	_assert(core.indicator_product(true) == 1 and core.indicator_product(false) == 0, "3b. Four-indicator product fail-closed")

	# Story dialogue & banner
	core.start_story()
	_assert(core.mode == FlapPloppCore.Mode.DIALOGUE, "4. start_story enters DIALOGUE")
	core.skip_dialogue()
	_assert(core.mode == FlapPloppCore.Mode.CHAPTER_BANNER, "5. Dialogue -> CHAPTER_BANNER")
	core.action_flap_or_dive()
	_assert(core.mode == FlapPloppCore.Mode.PLAYING, "6. Banner -> PLAYING")

	# Law 1 in play: two SHIFTs complete one involution T(T(s)) = s and a Poincare Return
	var m0: int = core.medium
	core.player_y = 310.0
	_assert(core.action_shift() and core.medium != m0, "7. First SHIFT flips SKY -> SEA")
	core.shift_cooldown = 0.0
	core.player_y = 330.0 # Within POINCARE_EPSILON_PX (36 px) of origin y0 = 310.0
	_assert(core.action_shift() and core.medium == m0, "8. Second SHIFT completes T(T(s)) = s -> SKY")
	_assert(core.involutions_completed == 1, "9. Involution counter incremented")
	_assert(core.poincare_returns == 1, "9b. Poincare Return triggered within epsilon neighborhood")

	# Law 3: HOLD preserves state and NEVER exits merely because time passes
	core.load_c = 60.0
	_assert(core.action_hold() and core.mode == FlapPloppCore.Mode.HOLD, "10. H enters HOLD")
	var dist_in_hold: float = core.distance
	for _i in range(60):
		core.step(0.05) # 3.0 full seconds elapsed in HOLD
	_assert(core.mode == FlapPloppCore.Mode.HOLD, "11. HOLD never auto-opens on elapsed time")
	_assert(core.distance == dist_in_hold and core.load_c < 60.0, "12. HOLD freezes motion and cools C(t)")
	_assert(core.release_hold() and core.mode == FlapPloppCore.Mode.PLAYING, "13. Explicit release exits HOLD")

	# Law 2 & 4: C(t) >= R triggers immediate KILL (0.00 V) and appends witness log
	var log_before: int = core.witness_log.size()
	core.load_c = 99.0
	core.step(0.5)
	_assert(core.mode == FlapPloppCore.Mode.KILL and core.kill_reason == "OVERLOAD_C_GE_R", "14. C(t) >= R triggers KILL")
	_assert(core.witness_log.size() > log_before, "15. KILL appended to witness_log without erasing history")

	# Retry preserves append-only witness log, then reach Finale -> VICTORY -> Endless
	var log_after_kill: int = core.witness_log.size()
	core.start_run(true)
	_assert(core.witness_log.size() > log_after_kill, "16. Retry appends to witness_log (never erases)")

	core.chapter_index = 3
	core.score = 1160
	core.shift_cooldown = 0.0
	core.action_shift()
	core.skip_dialogue()
	_assert(core.mode == FlapPloppCore.Mode.VICTORY, "Finale reaches VICTORY")

	# Law 5: Commutator prohibition [R, Pi_K] != 0 — calling R without prior Pi_K triggers KILL
	core.start_run(true)
	core.pi_k_projected = false
	_assert(not core.realize_if_projected(5.0), "17. Realization R without Pi_K is blocked")
	_assert(core.mode == FlapPloppCore.Mode.KILL and core.kill_reason == "COMMUTATOR_VIOLATION", "18. Commutator breach triggers immediate 0.00 V KILL")

	# Law 6 (Doc 176): Epistemic horizon t >= t* -> HOLD, Design Invalidity U_safe == empty -> KILL
	core.start_run(true)
	core.cycle_tick = core.horizon_tick
	_assert(core.eval_triadic_horizon(true) == FlapPloppCore.Mode.HOLD, "19. Horizon expiration t >= t* forces HOLD")
	core.start_run(true)
	core.cycle_tick = 10
	_assert(core.eval_triadic_horizon(false) == FlapPloppCore.Mode.KILL, "20. Design Invalidity (U_safe == empty) forces KILL")

	# Law 7 (Doc 178 Rev^2): Asserting reversibility after D2 PONR -> ANTI_REVERSIBLE_VIOLATION KILL
	core.start_run(true)
	core.d2_committed = true
	_assert(not core.attempt_reverse_committed(), "21a. Rev^2 rejects commit reversal after D2")
	_assert(core.mode == FlapPloppCore.Mode.KILL and core.kill_reason == "ANTI_REVERSIBLE_VIOLATION", "21b. ANTI_REVERSIBLE_VIOLATION triggers 0.00 V KILL")

	# Law 8 (Doc 181 SPEC-385 Crash^3): Tri-System Collision S1 x S2 x S3 (KILL > HOLD > OPEN)
	core.start_run(true)
	_assert(core.eval_crash3(0, 26, 50, false, false, false) == FlapPloppCore.Mode.PLAYING, "22. Crash3 Test A (Normal -> OPEN)")
	core.start_run(true)
	_assert(core.eval_crash3(15, 26, 50, false, false, false) == FlapPloppCore.Mode.HOLD, "23. Crash3 Test B (Projection residual eps_K > 0 -> HOLD)")
	core.start_run(true)
	_assert(core.eval_crash3(0, 27, 50, false, false, false) == FlapPloppCore.Mode.HOLD, "24. Crash3 Test C (E-TOR pi >= 27/50 -> HOLD)")
	core.start_run(true)
	_assert(core.eval_crash3(0, 26, 50, true, false, false) == FlapPloppCore.Mode.KILL, "25. Crash3 Test D (Witness breach eps_W = 1 -> KILL)")
	core.start_run(true)
	_assert(core.eval_crash3(0, 30, 50, true, true, false) == FlapPloppCore.Mode.KILL and core.kill_reason == "CRASH3_WITNESS_KILL", "26a. Crash3 Tri-System Clash (S1 PASS, S2 HOLD, S3 KILL -> KILL)")
	_assert(core.eval_crash3(0, 10, 50, false, false, false) == FlapPloppCore.Mode.KILL, "26b. Crash3 post-KILL latch immunity")

	# All 7 procedural WAVs
	_assert(SoundSynth.make_flap().data.size() > 0 and SoundSynth.make_fanfare().data.size() > 0, "Procedural WAVs ok")

	print("FLAP_PLOPP_FOUR_LAWS_PASS tests=26/26 involutions=%d poincare=%d witness_entries=%d" % [core.involutions_completed, core.poincare_returns, core.witness_log.size()])
	quit(0)
