class_name FlapPloppCore
extends RefCounted

# Flap & Plopp — Core arcade simulation (Godot 4.3)
# Air: gravity pulls down, SPACE flaps UP.
# SHIFT: PLOPP into water / SPLASH back into air.
# Water: buoyancy lifts up, SPACE dives DOWN.

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

const BASE_SPEED := 250.0
const MAX_SPEED := 460.0

enum Mode { TITLE, PLAYING, GAME_OVER }

var mode: int = Mode.TITLE
var player_y: float = 210.0
var player_vy: float = 0.0
var in_water: bool = false
var shift_cooldown: float = 0.0
var scroll_speed: float = BASE_SPEED
var distance: float = 0.0

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
	reset_to_title()

func reset_to_title() -> void:
	mode = Mode.TITLE
	player_y = 200.0
	player_vy = 0.0
	in_water = false
	shift_cooldown = 0.0
	scroll_speed = BASE_SPEED
	distance = 0.0
	score = 0
	combo = 1
	combo_timer = 0.0
	shifts_used = 0
	elapsed = 0.0
	spawn_timer = 0.9
	obstacles.clear()
	collectibles.clear()
	events.clear()

func start_run() -> void:
	mode = Mode.PLAYING
	player_y = 200.0
	player_vy = AIR_FLAP_VEL * 0.65
	in_water = false
	shift_cooldown = 0.0
	scroll_speed = BASE_SPEED
	distance = 0.0
	score = 0
	combo = 1
	combo_timer = 0.0
	shifts_used = 0
	elapsed = 0.0
	spawn_timer = 0.85
	obstacles.clear()
	collectibles.clear()
	events.clear()
	events.append({"type": "flap", "x": PLAYER_X, "y": player_y})

func consume_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = events.duplicate()
	events.clear()
	return out

func action_flap_or_dive() -> void:
	if mode != Mode.PLAYING:
		start_run()
		return
	if in_water:
		player_vy = WATER_DIVE_VEL
		events.append({"type": "dive", "x": PLAYER_X, "y": player_y})
	else:
		player_vy = AIR_FLAP_VEL
		events.append({"type": "flap", "x": PLAYER_X, "y": player_y})

func action_shift() -> bool:
	if mode != Mode.PLAYING or shift_cooldown > 0.0:
		return false
	in_water = not in_water
	shifts_used += 1
	shift_cooldown = 0.14
	var near_surface := absf(player_y - WATER_Y) < 75.0
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
	if near_surface:
		combo = mini(combo + 1, 8)
		combo_timer = 4.0
		score += 5 * combo
		events.append({"type": "combo", "x": PLAYER_X, "y": WATER_Y - 24.0, "combo": combo, "points": 5 * combo})
	return true

func step(dt: float) -> void:
	elapsed += dt
	if mode == Mode.TITLE:
		player_y = 200.0 + sin(elapsed * 3.6) * 14.0
		return
	if mode != Mode.PLAYING:
		return

	if shift_cooldown > 0.0:
		shift_cooldown = maxf(0.0, shift_cooldown - dt)
	if combo_timer > 0.0:
		combo_timer -= dt
		if combo_timer <= 0.0:
			combo = 1

	scroll_speed = minf(MAX_SPEED, BASE_SPEED + float(score) * 0.45)
	distance += scroll_speed * dt

	# Vertical physics: air pulls down, water lifts up
	if in_water:
		player_vy += WATER_BUOYANCY * dt
		player_vy = clampf(player_vy, -420.0, 480.0)
	else:
		player_vy += AIR_GRAVITY * dt
		player_vy = clampf(player_vy, -520.0, 560.0)
	player_y += player_vy * dt

	# Keep inside current medium unless player actively SHIFTs
	if not in_water:
		if player_y < 28.0:
			player_y = 28.0
			player_vy = maxf(player_vy, 40.0)
		elif player_y > WATER_Y - PLAYER_R:
			# Skimming the water surface gently bounces up (forgiving & cute)
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

	# Spawn wave patterns that reward SHIFTing between air & water
	spawn_timer -= dt
	if spawn_timer <= 0.0:
		_spawn_pattern()
		spawn_timer = clampf(1.55 - float(score) * 0.002, 0.92, 1.55)

	# Move obstacles & check collisions / passes
	var kept_obs: Array[Dictionary] = []
	for obs in obstacles:
		obs["x"] = float(obs["x"]) - scroll_speed * dt
		if not bool(obs["passed"]) and float(obs["x"]) + float(obs["w"]) * 0.5 < PLAYER_X:
			obs["passed"] = true
			score += 10 * combo
			events.append({"type": "pass", "x": PLAYER_X, "y": player_y, "points": 10 * combo})
		if _hits_obstacle(obs):
			_trigger_game_over()
			return
		if float(obs["x"]) + float(obs["w"]) > -60.0:
			kept_obs.append(obs)
	obstacles = kept_obs

	# Move collectibles & check pickups
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
			events.append({
				"type": "pickup",
				"kind": col["kind"],
				"x": col["x"],
				"y": col["y"],
				"points": pts,
				"combo": combo,
			})
			continue
		if float(col["x"]) > -40.0:
			kept_col.append(col)
	collectibles = kept_col

func _spawn_pattern() -> void:
	var spawn_x := VIEW_W + 70.0
	var roll := _rng.randi_range(0, 2)
	if roll == 0:
		# Air buoy + underwater pearl -> encourages PLOPP!
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
		# Underwater jelly/log + sky star -> encourages SPLASH!
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
		# High cloud post OR deep kelp, leaving a clear gap + bonus pickup
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

func _trigger_game_over() -> void:
	mode = Mode.GAME_OVER
	if score > best_score:
		best_score = score
	events.append({"type": "bonk", "x": PLAYER_X, "y": player_y})
