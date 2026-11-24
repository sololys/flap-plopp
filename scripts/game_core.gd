class_name FlapPloppCore
extends RefCounted

# Flap & Plopp: The Fjord Shift — Core simulation built around:
#   1. T(T(s)) = s  (Involution: Sky <-> Sea via SHIFT)
#   2. C(t) < R     (Spark load C(t) must stay strictly below ceiling R = 100)
#   3. HOLD         (Reversible safe stasis; time alone never exits HOLD)
#   4. KILL         (Instant 0.00 V cutoff on C(t) >= R or collision, logged append-only)

const StoryDataScript = preload("res://scripts/story_data.gd")

const VIEW_W := 960.0
const VIEW_H := 640.0
const WATER_Y := 340.0
const PLAYER_X := 220.0
const PLAYER_R := 20.0

const AIR_GRAVITY := 1080.0
const AIR_FLAP_VEL := -370.0
const WATER_BUOYANCY := -860.0
const WATER_DIVE_VEL := 330.0
const SHIFT_PLUNGE_VEL := 440.0
const SHIFT_LAUNCH_VEL := -460.0

const BASE_SPEED := 245.0
const MAX_SPEED := 480.0

const CAPACITY_R := 100.0 # Hard ceiling R: C(t) must remain strictly < R
const IKS_PULSE_HZ := 11.2 # Architectural heartbeat frequency (visual phase lock)

enum Medium { SKY = 0, SEA = 1 }
enum Mode { TITLE, DIALOGUE, PLAYING, HOLD, CHAPTER_BANNER, KILL, VICTORY }

var mode: int = Mode.TITLE
var chapters: Array[Dictionary] = []
var chapter_index: int = 0
var chapter_start_score: int = 0
var endless_mode: bool = false

var dialogue_queue: Array[Dictionary] = []
var dialogue_idx: int = 0
var dialogue_chars: float = 0.0
var dialogue_after_mode: int = Mode.PLAYING
var banner_timer: float = 0.0

var player_y: float = 200.0
var player_vy: float = 0.0
var medium: int = Medium.SKY
var in_water: bool = false
var shift_cooldown: float = 0.0
var scroll_speed: float = BASE_SPEED
var distance: float = 0.0

# Core four-law state
var load_c: float = 12.0            # C(t) in [0, R]; C(t) >= R triggers KILL
var kill_reason: String = ""        # "OVERLOAD_C_GE_R", "COLLISION_BONK", or "COMMUTATOR_VIOLATION"
var shift_parity: int = 0           # Counts half-flips; every 2nd flip completes T(T(s)) = s
var involutions_completed: int = 0
var poincare_origin_y: float = -1.0 # Recorded y0 when leaving SKY/SEA on first half-flip
var poincare_returns: int = 0       # Completed T(T(s))=s returning within epsilon of y0
var pi_k_projected: bool = false    # Enforces [R, Pi_K] != 0: Pi_K must precede realization R
var cycle_tick: int = 0             # Monotonic integer cycle coordinate
var horizon_tick: int = 3600        # Epistemic horizon t* in discrete ticks (renewed on SHIFT/pickup)
var hold_entries: int = 0
var kill_count: int = 0
var witness_log: Array[Dictionary] = [] # Append-only log (never erased on retry)

const POINCARE_EPSILON_PX := 36.0

var score: int = 0
var best_score: int = 0
var combo: int = 1
var combo_timer: float = 0.0
var shifts_used: int = 0
var elapsed: float = 0.0

var spawn_timer: float = 0.0
var obstacles: Array[Dictionary] = []
var collectibles: Array[Dictionary] = []
var events: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()

func _init(seed_val: int = 0) -> void:
	if seed_val != 0:
		_rng.seed = seed_val
	else:
		_rng.randomize()
	chapters = StoryDataScript.get_chapters()
	reset_to_title()

# Exact IKS involution F(s) = 1 - s around fixed point 0.5: F(F(s)) == s (zero residual)
static func apply_involution_T(s: int) -> int:
	return 1 - s

func is_within_capacity() -> bool:
	return load_c < CAPACITY_R

# Four-indicator product: Pi = chi_HPIS * chi_TOR * chi_WORM * chi_RFM
func indicator_product(collision_free: bool = true) -> int:
	var chi_hpis := 1 if is_within_capacity() else 0
	var chi_tor := 1 if (apply_involution_T(apply_involution_T(medium)) == medium) else 0
	var chi_worm := 1 if (witness_log.size() >= 0) else 0
	var chi_rfm := 1 if collision_free else 0
	return chi_hpis * chi_tor * chi_worm * chi_rfm

# Enforces [R, Pi_K] != 0: calling realization R without prior Pi_K projection triggers KILL
func project_pi_k() -> bool:
	pi_k_projected = (indicator_product(true) == 1)
	return pi_k_projected

func realize_if_projected(delta_y: float) -> bool:
	if not pi_k_projected:
		_trigger_kill("COMMUTATOR_VIOLATION")
		return false
	pi_k_projected = false
	player_y += delta_y
	return true

# Document 176 Triadic Realization & Design Invalidity check (0 float ticks)
func eval_triadic_horizon(u_safe_nonempty: bool = true) -> int:
	if not u_safe_nonempty or not is_within_capacity():
		_trigger_kill("DESIGN_INVALIDITY_U_SAFE_EMPTY" if not u_safe_nonempty else "OVERLOAD_C_GE_R")
		return Mode.KILL
	if cycle_tick >= horizon_tick:
		action_hold()
		return Mode.HOLD
	return Mode.PLAYING

func _append_witness(event_name: String, detail: String = "") -> void:
	witness_log.append({
		"seq": witness_log.size(),
		"chapter": chapter_index + 1,
		"event": event_name,
		"medium": "SEA" if medium == Medium.SEA else "SKY",
		"load_c": int(round(load_c)),
		"limit_r": int(CAPACITY_R),
		"score": score,
		"detail": detail,
	})

func current_chapter() -> Dictionary:
	return chapters[clampi(chapter_index, 0, chapters.size() - 1)]

func current_dialogue_line() -> Dictionary:
	if dialogue_idx >= 0 and dialogue_idx < dialogue_queue.size():
		return dialogue_queue[dialogue_idx]
	return {}

func reset_to_title() -> void:
	mode = Mode.TITLE
	chapter_index = 0
	chapter_start_score = 0
	endless_mode = false
	dialogue_queue.clear()
	dialogue_idx = 0
	dialogue_chars = 0.0
	banner_timer = 0.0
	_reset_actor()
	score = 0
	combo = 1
	combo_timer = 0.0
	shifts_used = 0
	elapsed = 0.0
	events.clear()

func _reset_actor() -> void:
	player_y = 200.0
	player_vy = 0.0
	medium = Medium.SKY
	in_water = false
	shift_cooldown = 0.0
	load_c = 12.0
	kill_reason = ""
	shift_parity = 0
	poincare_origin_y = -1.0
	scroll_speed = BASE_SPEED + float(current_chapter()["speed_bonus"])
	spawn_timer = 0.95
	obstacles.clear()
	collectibles.clear()

func start_story() -> void:
	chapter_index = 0
	chapter_start_score = 0
	endless_mode = false
	score = 0
	combo = 1
	combo_timer = 0.0
	shifts_used = 0
	_reset_actor()
	_append_witness("STORY_START", "ch1")
	_begin_dialogue("intro", Mode.CHAPTER_BANNER)

func start_run(keep_chapter: bool = false) -> void:
	if not keep_chapter:
		chapter_index = 0
		chapter_start_score = 0
		endless_mode = false
		score = 0
		shifts_used = 0
	else:
		score = chapter_start_score
	combo = 1
	combo_timer = 0.0
	_reset_actor()
	mode = Mode.PLAYING
	player_vy = AIR_FLAP_VEL * 0.65
	_append_witness("OPEN_RUN", "retry_ch" if keep_chapter else "fresh")
	events.append({"type": "flap", "x": PLAYER_X, "y": player_y})

func start_endless() -> void:
	endless_mode = true
	chapter_index = chapters.size() - 1
	chapter_start_score = score
	_reset_actor()
	mode = Mode.PLAYING
	player_vy = AIR_FLAP_VEL * 0.65
	_append_witness("OPEN_ENDLESS", "aurora")
	events.append({"type": "flap", "x": PLAYER_X, "y": player_y})

# HOLD: enters reversible stasis (u = 0). Time alone never exits HOLD.
func action_hold() -> bool:
	if mode != Mode.PLAYING:
		return false
	mode = Mode.HOLD
	hold_entries += 1
	_append_witness("HOLD_ENTER", "reversible_stasis")
	events.append({"type": "hold_enter", "x": PLAYER_X, "y": player_y})
	return true

# Explicit release from HOLD -> PLAYING (requires player input + C(t) < R)
func release_hold() -> bool:
	if mode != Mode.HOLD or not is_within_capacity():
		return false
	mode = Mode.PLAYING
	_append_witness("HOLD_RELEASE_OPEN", "explicit_input")
	events.append({"type": "flap", "x": PLAYER_X, "y": player_y})
	return true

func _begin_dialogue(seq_id: String, after_mode: int) -> void:
	dialogue_queue = StoryDataScript.get_sequence(seq_id)
	dialogue_idx = 0
	dialogue_chars = 0.0
	dialogue_after_mode = after_mode
	mode = Mode.DIALOGUE
	events.append({"type": "dialogue_start", "seq": seq_id})

func advance_dialogue() -> void:
	if mode != Mode.DIALOGUE:
		return
	var line := current_dialogue_line()
	var full_len := str(line.get("text", "")).length()
	if int(dialogue_chars) < full_len:
		dialogue_chars = float(full_len)
		return
	dialogue_idx += 1
	dialogue_chars = 0.0
	if dialogue_idx >= dialogue_queue.size():
		if dialogue_after_mode == Mode.CHAPTER_BANNER:
			mode = Mode.CHAPTER_BANNER
			banner_timer = 1.65
			events.append({"type": "chapter_banner", "chapter": chapter_index})
		elif dialogue_after_mode == Mode.VICTORY:
			mode = Mode.VICTORY
			if score > best_score:
				best_score = score
			_append_witness("VICTORY_BEACON_LIT", "all_4_chapters")
			events.append({"type": "victory", "score": score})
		else:
			mode = Mode.PLAYING
			player_vy = AIR_FLAP_VEL * 0.65

func skip_dialogue() -> void:
	if mode != Mode.DIALOGUE:
		return
	dialogue_idx = dialogue_queue.size()
	dialogue_chars = 9999.0
	advance_dialogue()

func consume_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = events.duplicate()
	events.clear()
	return out

func action_flap_or_dive() -> void:
	if mode == Mode.TITLE:
		start_story()
		return
	if mode == Mode.DIALOGUE:
		advance_dialogue()
		return
	if mode == Mode.HOLD:
		release_hold()
		return
	if mode == Mode.CHAPTER_BANNER:
		banner_timer = 0.0
		mode = Mode.PLAYING
		player_vy = AIR_FLAP_VEL * 0.65
		events.append({"type": "flap", "x": PLAYER_X, "y": player_y})
		return
	if mode == Mode.KILL:
		start_run(true)
		return
	if mode == Mode.VICTORY:
		start_endless()
		return

	# Each flap/dive adds a small thermal spark pulse to C(t)
	load_c = minf(CAPACITY_R, load_c + 3.0)
	if not is_within_capacity():
		_trigger_kill("OVERLOAD_C_GE_R")
		return

	if in_water:
		player_vy = WATER_DIVE_VEL
		events.append({"type": "dive", "x": PLAYER_X, "y": player_y})
	else:
		player_vy = AIR_FLAP_VEL
		events.append({"type": "flap", "x": PLAYER_X, "y": player_y})

# SHIFT: applies exact involution T(s); every 2nd shift completes T(T(s)) = s!
# If the return altitude lands within POINCARE_EPSILON_PX of y0, awards a Poincare Return!
func action_shift() -> bool:
	if mode != Mode.PLAYING or shift_cooldown > 0.0:
		return false
	var y_before_shift := player_y
	medium = apply_involution_T(medium)
	in_water = (medium == Medium.SEA)
	shifts_used += 1
	shift_parity += 1
	shift_cooldown = 0.14

	var near_surface := absf(y_before_shift - WATER_Y) < 75.0
	if in_water:
		if player_y < WATER_Y + 18.0:
			player_y = WATER_Y + 18.0
		player_vy = SHIFT_PLUNGE_VEL
		events.append({"type": "plopp", "x": PLAYER_X, "y": WATER_Y, "near_surface": near_surface})
	else:
		if player_y > WATER_Y - 18.0:
			player_y = WATER_Y - 18.0
		player_vy = SHIFT_LAUNCH_VEL
		events.append({"type": "splash", "x": PLAYER_X, "y": WATER_Y, "near_surface": near_surface})

	# Clean SHIFT cools C(t); completing a full T(T(s)) = s loop checks Poincare Return!
	load_c = maxf(0.0, load_c - (12.0 if near_surface else 6.0))
	if shift_parity % 2 == 1:
		poincare_origin_y = y_before_shift
	else:
		involutions_completed += 1
		load_c = maxf(0.0, load_c - 10.0)
		var inv_pts := 10 * combo
		score += inv_pts
		events.append({
			"type": "involution",
			"x": PLAYER_X + 12.0,
			"y": WATER_Y - 38.0,
			"points": inv_pts,
		})
		if poincare_origin_y >= 0.0 and absf(y_before_shift - poincare_origin_y) <= POINCARE_EPSILON_PX:
			poincare_returns += 1
			load_c = maxf(0.0, load_c - 15.0)
			var p_pts := 30 * combo
			score += p_pts
			_append_witness("POINCARE_RETURN", "dy=%d" % int(round(absf(y_before_shift - poincare_origin_y))))
			events.append({
				"type": "poincare",
				"x": PLAYER_X + 24.0,
				"y": poincare_origin_y,
				"points": p_pts,
			})
		poincare_origin_y = -1.0

	if near_surface:
		combo = mini(combo + 1, 8)
		combo_timer = 4.0
		score += 5 * combo
		events.append({"type": "combo", "x": PLAYER_X, "y": WATER_Y - 18.0, "combo": combo, "points": 5 * combo})

	_check_chapter_goal()
	return true

func step(dt: float) -> void:
	elapsed += dt
	if mode == Mode.TITLE or mode == Mode.VICTORY:
		player_y = 200.0 + sin(elapsed * 3.4) * 14.0
		distance += 65.0 * dt
		return
	if mode == Mode.HOLD:
		# HOLD invariant: world freezes (u = 0), C(t) cools gently, time NEVER exits HOLD!
		load_c = maxf(0.0, load_c - 18.0 * dt)
		return
	if mode == Mode.DIALOGUE:
		player_y = 200.0 + sin(elapsed * 3.4) * 10.0
		distance += 50.0 * dt
		var line := current_dialogue_line()
		var full_len := str(line.get("text", "")).length()
		var prev_c := int(dialogue_chars)
		dialogue_chars = minf(float(full_len), dialogue_chars + 42.0 * dt)
		if int(dialogue_chars) > prev_c and int(dialogue_chars) % 3 == 0:
			events.append({"type": "blip", "pitch": float(line.get("pitch", 1.0))})
		return
	if mode == Mode.CHAPTER_BANNER:
		player_y = 200.0 + sin(elapsed * 4.0) * 10.0
		distance += 90.0 * dt
		banner_timer -= dt
		if banner_timer <= 0.0:
			mode = Mode.PLAYING
			player_vy = AIR_FLAP_VEL * 0.55
		return
	if mode != Mode.PLAYING:
		return

	if shift_cooldown > 0.0:
		shift_cooldown = maxf(0.0, shift_cooldown - dt)
	if combo_timer > 0.0:
		combo_timer -= dt
		if combo_timer <= 0.0:
			combo = 1

	# Continuous spark load C(t) rises over time; must stay < R via SHIFT/pickups/HOLD!
	var load_rate := float(current_chapter()["load_rate"])
	load_c += load_rate * dt
	if not is_within_capacity():
		load_c = CAPACITY_R
		_trigger_kill("OVERLOAD_C_GE_R")
		return

	var ch_bonus := float(current_chapter()["speed_bonus"])
	scroll_speed = minf(MAX_SPEED, BASE_SPEED + ch_bonus + float(score) * 0.20)
	distance += scroll_speed * dt

	if in_water:
		player_vy += WATER_BUOYANCY * dt
		player_vy = clampf(player_vy, -420.0, 480.0)
	else:
		player_vy += AIR_GRAVITY * dt
		player_vy = clampf(player_vy, -520.0, 560.0)
	if not project_pi_k():
		_trigger_kill("OVERLOAD_C_GE_R")
		return
	realize_if_projected(player_vy * dt)

	if not in_water:
		if player_y < 28.0:
			player_y = 28.0
			player_vy = maxf(player_vy, 40.0)
		elif player_y > WATER_Y - PLAYER_R:
			player_y = WATER_Y - PLAYER_R
			player_vy = -170.0
			events.append({"type": "skim", "x": PLAYER_X, "y": WATER_Y})
	else:
		if player_y < WATER_Y + PLAYER_R:
			player_y = WATER_Y + PLAYER_R
			player_vy = 110.0
		elif player_y > VIEW_H - 30.0:
			player_y = VIEW_H - 30.0
			player_vy = minf(player_vy, -80.0)

	spawn_timer -= dt
	if spawn_timer <= 0.0:
		_spawn_pattern()
		spawn_timer = clampf(1.52 - float(chapter_index) * 0.12 - float(score) * 0.0004, 0.90, 1.52)

	var kept_obs: Array[Dictionary] = []
	for obs in obstacles:
		obs["x"] = float(obs["x"]) - scroll_speed * dt
		if not bool(obs["passed"]) and float(obs["x"]) + float(obs["w"]) * 0.5 < PLAYER_X:
			obs["passed"] = true
			score += 10 * combo
			events.append({"type": "pass", "x": PLAYER_X, "y": player_y, "points": 10 * combo})
			if _check_chapter_goal():
				return
		if _hits_obstacle(obs):
			_trigger_kill("COLLISION_BONK")
			return
		if float(obs["x"]) + float(obs["w"]) > -60.0:
			kept_obs.append(obs)
	obstacles = kept_obs

	var kept_col: Array[Dictionary] = []
	for col in collectibles:
		col["x"] = float(col["x"]) - scroll_speed * dt
		var dx := float(col["x"]) - PLAYER_X
		var dy := float(col["y"]) - player_y
		var hit_r := PLAYER_R + float(col["r"]) + 4.0
		if dx * dx + dy * dy <= hit_r * hit_r:
			combo = mini(combo + 1, 8)
			combo_timer = 4.5
			var pts := 15 * combo
			score += pts
			load_c = maxf(0.0, load_c - 18.0) # Stars & pearls cool C(t)
			events.append({
				"type": "pickup",
				"kind": col["kind"],
				"x": col["x"],
				"y": col["y"],
				"points": pts,
				"combo": combo,
			})
			if _check_chapter_goal():
				return
			continue
		if float(col["x"]) > -40.0:
			kept_col.append(col)
	collectibles = kept_col

func _check_chapter_goal() -> bool:
	if endless_mode or mode != Mode.PLAYING:
		return false
	var target := int(current_chapter()["target_score"])
	if score < target:
		return false
	obstacles.clear()
	collectibles.clear()
	medium = Medium.SKY
	in_water = false
	player_y = 200.0
	player_vy = 0.0
	load_c = 10.0
	_append_witness("CHAPTER_CLEAR", "ch%d" % (chapter_index + 1))
	events.append({"type": "fanfare", "chapter": chapter_index})
	if chapter_index + 1 < chapters.size():
		chapter_index += 1
		chapter_start_score = score
		var seq_names := ["intro", "ch2_intro", "ch3_intro", "ch4_intro"]
		_begin_dialogue(seq_names[chapter_index], Mode.CHAPTER_BANNER)
	else:
		_begin_dialogue("finale", Mode.VICTORY)
	return true

func _spawn_pattern() -> void:
	var spawn_x := VIEW_W + 70.0
	var roll := _rng.randi_range(0, 2)
	if roll == 0:
		obstacles.append({
			"kind": "buoy",
			"x": spawn_x,
			"y": WATER_Y - 125.0,
			"w": 46.0,
			"h": 210.0,
			"passed": false,
		})
		collectibles.append({
			"kind": "pearl",
			"x": spawn_x + 10.0,
			"y": _rng.randf_range(WATER_Y + 95.0, VIEW_H - 95.0),
			"r": 14.0,
		})
	elif roll == 1:
		obstacles.append({
			"kind": "jelly",
			"x": spawn_x,
			"y": WATER_Y + 125.0,
			"w": 52.0,
			"h": 190.0,
			"passed": false,
		})
		collectibles.append({
			"kind": "star",
			"x": spawn_x + 10.0,
			"y": _rng.randf_range(85.0, WATER_Y - 95.0),
			"r": 14.0,
		})
	else:
		var air_high := _rng.randi_range(0, 1) == 0
		if air_high:
			obstacles.append({
				"kind": "buoy",
				"x": spawn_x,
				"y": 115.0,
				"w": 44.0,
				"h": 170.0,
				"passed": false,
			})
			collectibles.append({
				"kind": "star",
				"x": spawn_x + 6.0,
				"y": WATER_Y - 62.0,
				"r": 14.0,
			})
		else:
			obstacles.append({
				"kind": "jelly",
				"x": spawn_x,
				"y": VIEW_H - 105.0,
				"w": 50.0,
				"h": 170.0,
				"passed": false,
			})
			collectibles.append({
				"kind": "pearl",
				"x": spawn_x + 6.0,
				"y": WATER_Y + 72.0,
				"r": 14.0,
			})

func _hits_obstacle(obs: Dictionary) -> bool:
	var half_w := float(obs["w"]) * 0.5 - 4.0
	var half_h := float(obs["h"]) * 0.5 - 4.0
	var closest_x := clampf(PLAYER_X, float(obs["x"]) - half_w, float(obs["x"]) + half_w)
	var closest_y := clampf(player_y, float(obs["y"]) - half_h, float(obs["y"]) + half_h)
	var dx := PLAYER_X - closest_x
	var dy := player_y - closest_y
	var r := PLAYER_R - 3.0
	return dx * dx + dy * dy < r * r

func _trigger_kill(reason: String) -> void:
	mode = Mode.KILL
	kill_reason = reason
	kill_count += 1
	player_vy = 0.0
	if score > best_score:
		best_score = score
	_append_witness("KILL_0V_CUT", reason)
	events.append({"type": "kill", "reason": reason, "x": PLAYER_X, "y": player_y})
