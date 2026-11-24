extends Node2D

# Flap & Plopp — Cute, energetic 2D renderer, juice, particles & input

const FlapPloppCore = preload("res://scripts/game_core.gd")
const SoundSynth = preload("res://scripts/sound_synth.gd")

var core
var particles: Array[Dictionary] = []
var popups: Array[Dictionary] = []

var squash_x: float = 1.0
var squash_y: float = 1.0
var wing_angle: float = 0.0
var shake_t: float = 0.0
var water_ripple_t: float = 0.0

var sfx_flap: AudioStreamPlayer
var sfx_plopp: AudioStreamPlayer
var sfx_splash: AudioStreamPlayer
var sfx_pickup: AudioStreamPlayer
var sfx_bonk: AudioStreamPlayer

func _ready() -> void:
	core = FlapPloppCore.new()
	sfx_flap = _make_player(SoundSynth.make_flap())
	sfx_plopp = _make_player(SoundSynth.make_plopp())
	sfx_splash = _make_player(SoundSynth.make_splash())
	sfx_pickup = _make_player(SoundSynth.make_pickup())
	sfx_bonk = _make_player(SoundSynth.make_bonk())

func _make_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_UP or event.keycode == KEY_W:
			core.action_flap_or_dive()
		elif event.keycode == KEY_SHIFT or event.keycode == KEY_DOWN or event.keycode == KEY_S:
			if core.mode != FlapPloppCore.Mode.PLAYING:
				core.start_run()
			else:
				core.action_shift()
		elif event.keycode == KEY_R and core.mode == FlapPloppCore.Mode.GAME_OVER:
			core.start_run()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			core.action_flap_or_dive()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if core.mode != FlapPloppCore.Mode.PLAYING:
				core.start_run()
			else:
				core.action_shift()

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	core.step(dt)
	_handle_events()
	_update_particles(dt)
	_update_popups(dt)

	squash_x = lerpf(squash_x, 1.0, dt * 11.0)
	squash_y = lerpf(squash_y, 1.0, dt * 11.0)
	wing_angle = lerpf(wing_angle, 0.0, dt * 9.0)
	if shake_t > 0.0:
		shake_t = maxf(0.0, shake_t - dt)
	if water_ripple_t > 0.0:
		water_ripple_t = maxf(0.0, water_ripple_t - dt)

	# Ambient bubbles when swimming underwater
	if core.mode == FlapPloppCore.Mode.PLAYING and core.in_water and randf() < dt * 14.0:
		particles.append({
			"kind": "bubble",
			"x": FlapPloppCore.PLAYER_X - 14.0 + randf_range(-6.0, 6.0),
			"y": core.player_y + randf_range(-6.0, 6.0),
			"vx": randf_range(-55.0, -20.0),
			"vy": randf_range(-95.0, -45.0),
			"r": randf_range(3.0, 7.0),
			"life": 0.75,
			"max_life": 0.75,
			"color": Color(0.86, 0.98, 1.0, 0.85),
		})

	queue_redraw()

func _handle_events() -> void:
	for ev in core.consume_events():
		var t: String = ev["type"]
		var ex: float = float(ev.get("x", FlapPloppCore.PLAYER_X))
		var ey: float = float(ev.get("y", core.player_y))
		match t:
			"flap":
				squash_x = 1.22
				squash_y = 0.80
				wing_angle = -0.85
				sfx_flap.pitch_scale = randf_range(0.95, 1.08)
				sfx_flap.play()
				_spawn_burst(ex - 10.0, ey + 8.0, 5, Color(1.0, 1.0, 1.0, 0.8), 90.0)
			"dive":
				squash_x = 0.82
				squash_y = 1.24
				wing_angle = 0.75
				sfx_flap.pitch_scale = randf_range(0.75, 0.86)
				sfx_flap.play()
				_spawn_burst(ex - 8.0, ey - 8.0, 6, Color(0.82, 0.97, 1.0, 0.9), 110.0)
			"plopp":
				squash_x = 0.72
				squash_y = 1.38
				water_ripple_t = 0.45
				sfx_plopp.pitch_scale = randf_range(0.96, 1.08)
				sfx_plopp.play()
				_spawn_burst(ex, ey, 14, Color(0.76, 0.96, 1.0, 0.95), 220.0)
				popups.append({"text": "PLOPP!", "x": ex, "y": ey - 18.0, "life": 0.65, "color": Color(0.10, 0.55, 0.82)})
			"splash":
				squash_x = 0.74
				squash_y = 1.35
				water_ripple_t = 0.45
				sfx_splash.pitch_scale = randf_range(0.96, 1.08)
				sfx_splash.play()
				_spawn_burst(ex, ey, 14, Color(0.92, 0.99, 1.0, 0.95), 240.0)
				popups.append({"text": "SPLASH!", "x": ex, "y": ey - 22.0, "life": 0.65, "color": Color(1.0, 0.52, 0.16)})
			"combo":
				popups.append({
					"text": "SHIFT x%d +%d" % [int(ev["combo"]), int(ev["points"])],
					"x": ex + 20.0,
					"y": ey - 42.0,
					"life": 0.9,
					"color": Color(1.0, 0.84, 0.14),
				})
			"pickup":
				sfx_pickup.pitch_scale = 0.92 + float(ev["combo"]) * 0.06
				sfx_pickup.play()
				var c := Color(1.0, 0.88, 0.22) if ev["kind"] == "star" else Color(0.96, 0.84, 1.0)
				_spawn_burst(ex, ey, 12, c, 190.0)
				popups.append({"text": "+%d" % int(ev["points"]), "x": ex, "y": ey - 12.0, "life": 0.75, "color": c})
			"skim":
				_spawn_burst(ex, ey, 4, Color(0.88, 0.98, 1.0, 0.85), 95.0)
			"bonk":
				shake_t = 0.25
				sfx_bonk.play()
				_spawn_burst(ex, ey, 18, Color(1.0, 0.42, 0.34, 0.95), 260.0)
				popups.append({"text": "BONK!", "x": ex, "y": ey - 24.0, "life": 1.0, "color": Color(1.0, 0.35, 0.28)})

func _spawn_burst(x: float, y: float, count: int, color: Color, speed: float) -> void:
	for i in range(count):
		var ang := randf() * TAU
		var spd := randf_range(speed * 0.35, speed)
		particles.append({
			"kind": "drop",
			"x": x,
			"y": y,
			"vx": cos(ang) * spd - 40.0,
			"vy": sin(ang) * spd - 45.0,
			"r": randf_range(3.0, 7.5),
			"life": randf_range(0.35, 0.65),
			"max_life": 0.65,
			"color": color,
		})

func _update_particles(dt: float) -> void:
	var kept: Array[Dictionary] = []
	for p in particles:
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) <= 0.0:
			continue
		p["x"] = float(p["x"]) + float(p["vx"]) * dt
		p["y"] = float(p["y"]) + float(p["vy"]) * dt
		if p["kind"] == "drop":
			p["vy"] = float(p["vy"]) + 380.0 * dt
		kept.append(p)
	particles = kept

func _update_popups(dt: float) -> void:
	var kept: Array[Dictionary] = []
	for pop in popups:
		pop["life"] = float(pop["life"]) - dt
		if float(pop["life"]) <= 0.0:
			continue
		pop["y"] = float(pop["y"]) - 52.0 * dt
		kept.append(pop)
	popups = kept

func _draw() -> void:
	var shake := Vector2.ZERO
	if shake_t > 0.0:
		shake = Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)) * (shake_t / 0.25)
	draw_set_transform(shake, 0.0, Vector2.ONE)

	_draw_sky_and_sea()
	_draw_obstacles()
	_draw_collectibles()
	_draw_puffin()
	_draw_water_surface()
	_draw_particles()
	_draw_popups()
	_draw_hud()

func _draw_sky_and_sea() -> void:
	# Bright Nordic summer sky
	draw_rect(Rect2(0, 0, 960, FlapPloppCore.WATER_Y), Color(0.62, 0.89, 0.99))
	draw_rect(Rect2(0, 210, 960, FlapPloppCore.WATER_Y - 210), Color(0.78, 0.95, 1.0, 0.65))

	# Cheerful sun
	var sun_pos := Vector2(815, 92)
	draw_circle(sun_pos, 52.0, Color(1.0, 0.94, 0.52, 0.35))
	draw_circle(sun_pos, 36.0, Color(1.0, 0.89, 0.32))

	# Soft drifting clouds
	for i in range(4):
		var cx := fmod(float(i) * 270.0 - core.distance * 0.12 + 1200.0, 1120.0) - 80.0
		var cy := 74.0 + float(i % 2) * 52.0
		draw_circle(Vector2(cx, cy), 24.0, Color(1.0, 1.0, 1.0, 0.88))
		draw_circle(Vector2(cx + 22.0, cy - 8.0), 28.0, Color(1.0, 1.0, 1.0, 0.88))
		draw_circle(Vector2(cx + 46.0, cy), 22.0, Color(1.0, 1.0, 1.0, 0.88))

	# Turquoise underwater world
	draw_rect(
		Rect2(0, FlapPloppCore.WATER_Y, 960, 640 - FlapPloppCore.WATER_Y),
		Color(0.08, 0.56, 0.76)
	)
	draw_rect(
		Rect2(0, FlapPloppCore.WATER_Y + 150, 960, 640 - (FlapPloppCore.WATER_Y + 150)),
		Color(0.05, 0.40, 0.60, 0.65)
	)
	# Gentle sunbeams under water
	for i in range(5):
		var bx := fmod(float(i) * 230.0 - core.distance * 0.25 + 1400.0, 1180.0) - 100.0
		var poly := PackedVector2Array([
			Vector2(bx, FlapPloppCore.WATER_Y),
			Vector2(bx + 54.0, FlapPloppCore.WATER_Y),
			Vector2(bx + 115.0, 640.0),
			Vector2(bx + 25.0, 640.0),
		])
		draw_colored_polygon(poly, Color(0.55, 0.92, 0.98, 0.11))

func _draw_water_surface() -> void:
	var pts := PackedVector2Array()
	var step := 16.0
	var x := 0.0
	while x <= 960.0 + step:
		var wave := sin(x * 0.025 + core.elapsed * 4.5) * 5.0
		if water_ripple_t > 0.0:
			var d := absf(x - FlapPloppCore.PLAYER_X)
			wave += sin(d * 0.08 - core.elapsed * 22.0) * maxf(0.0, 1.0 - d / 160.0) * 10.0 * (water_ripple_t / 0.45)
		pts.append(Vector2(x, FlapPloppCore.WATER_Y + wave))
		x += step
	draw_polyline(pts, Color(0.92, 0.99, 1.0, 0.95), 5.0, true)

func _draw_obstacles() -> void:
	for obs in core.obstacles:
		var ox := float(obs["x"])
		var oy := float(obs["y"])
		var ow := float(obs["w"])
		var oh := float(obs["h"])
		var rect := Rect2(ox - ow * 0.5, oy - oh * 0.5, ow, oh)
		if obs["kind"] == "buoy":
			# Striped red & white harbor buoy
			draw_rect(rect, Color(0.92, 0.28, 0.24))
			draw_rect(Rect2(rect.position.x, oy - 18.0, ow, 36.0), Color(0.98, 0.97, 0.94))
			draw_rect(Rect2(rect.position.x + 5.0, rect.position.y + 6.0, 8.0, oh - 12.0), Color(1.0, 1.0, 1.0, 0.25))
			draw_circle(Vector2(ox, rect.position.y), ow * 0.45, Color(0.98, 0.78, 0.22))
		else:
			# Cute glowing coral jellyfish barrier
			var pulse := sin(core.elapsed * 6.0 + ox * 0.03) * 4.0
			draw_rect(Rect2(rect.position.x + 6.0, rect.position.y + 24.0, ow - 12.0, oh - 24.0), Color(0.96, 0.44, 0.68, 0.78))
			draw_circle(Vector2(ox, rect.position.y + 26.0), ow * 0.56 + pulse * 0.4, Color(1.0, 0.52, 0.74))
			draw_circle(Vector2(ox - 9.0, rect.position.y + 24.0), 4.0, Color(0.15, 0.12, 0.20))
			draw_circle(Vector2(ox + 9.0, rect.position.y + 24.0), 4.0, Color(0.15, 0.12, 0.20))

func _draw_collectibles() -> void:
	for col in core.collectibles:
		var cx := float(col["x"])
		var cy := float(col["y"]) + sin(core.elapsed * 5.0 + cx * 0.04) * 5.0
		var r := float(col["r"])
		if col["kind"] == "star":
			draw_circle(Vector2(cx, cy), r + 4.0, Color(1.0, 0.92, 0.35, 0.32))
			var pts := PackedVector2Array()
			for i in range(10):
				var a := -PI * 0.5 + float(i) * PI / 5.0
				var rad := r if i % 2 == 0 else r * 0.48
				pts.append(Vector2(cx + cos(a) * rad, cy + sin(a) * rad))
			draw_colored_polygon(pts, Color(1.0, 0.86, 0.16))
		else:
			# Iridescent underwater pearl
			draw_circle(Vector2(cx, cy), r + 5.0, Color(0.86, 0.98, 1.0, 0.28))
			draw_circle(Vector2(cx, cy), r, Color(0.97, 0.92, 1.0))
			draw_circle(Vector2(cx - 4.0, cy - 4.0), r * 0.32, Color(1.0, 1.0, 1.0))

func _draw_puffin() -> void:
	var pos := Vector2(FlapPloppCore.PLAYER_X, core.player_y)
	var tilt := clampf(core.player_vy * 0.0011, -0.55, 0.65)
	draw_set_transform(pos, tilt, Vector2(squash_x, squash_y))

	# Cute round body (puffin black back + cream belly)
	draw_circle(Vector2.ZERO, 21.0, Color(0.14, 0.16, 0.22))
	draw_circle(Vector2(3.0, 5.0), 14.5, Color(0.98, 0.97, 0.94))

	# Colorful puffin beak
	var beak := PackedVector2Array([
		Vector2(16.0, -5.0),
		Vector2(33.0, 1.0),
		Vector2(16.0, 7.0),
	])
	draw_colored_polygon(beak, Color(1.0, 0.44, 0.16))
	draw_line(Vector2(22.0, -3.0), Vector2(22.0, 5.0), Color(1.0, 0.86, 0.22), 3.0)

	# Flapping wing
	var wy := sin(wing_angle * 2.0) * 8.0
	draw_circle(Vector2(-6.0, 2.0 + wy), 10.5, Color(0.20, 0.24, 0.32))

	# Expressive eye (big bright eye in air, cute swimming squint underwater)
	if core.in_water:
		draw_line(Vector2(6.0, -7.0), Vector2(13.0, -5.0), Color(0.10, 0.10, 0.14), 2.8)
		draw_line(Vector2(6.0, -3.0), Vector2(13.0, -5.0), Color(0.10, 0.10, 0.14), 2.8)
	else:
		draw_circle(Vector2(9.0, -6.0), 5.5, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(10.5, -6.0), 2.8, Color(0.10, 0.12, 0.18))
		draw_circle(Vector2(11.3, -7.2), 1.1, Color(1.0, 1.0, 1.0))

	# Rosy cheek
	draw_circle(Vector2(11.0, 1.5), 3.2, Color(1.0, 0.56, 0.62, 0.65))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_particles() -> void:
	for p in particles:
		var a := clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var c: Color = p["color"]
		c.a *= a
		if p["kind"] == "bubble":
			draw_arc(Vector2(float(p["x"]), float(p["y"])), float(p["r"]), 0.0, TAU, 16, c, 2.0)
		else:
			draw_circle(Vector2(float(p["x"]), float(p["y"])), float(p["r"]) * a, c)

func _draw_popups() -> void:
	var font := ThemeDB.fallback_font
	for pop in popups:
		var c: Color = pop["color"]
		c.a = clampf(float(pop["life"]) * 1.4, 0.0, 1.0)
		draw_string(font, Vector2(float(pop["x"]), float(pop["y"])), str(pop["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1, 20, c)

func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var mode_badge := "UNDERWATER (SPACE: DIVE)" if core.in_water else "IN THE SKY (SPACE: FLAP)"
	draw_rect(Rect2(16, 14, 928, 42), Color(0.08, 0.16, 0.24, 0.55))
	draw_string(font, Vector2(30, 41), "SCORE: %d" % core.score, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.96, 0.85))
	draw_string(font, Vector2(210, 41), "BEST: %d" % core.best_score, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.84, 0.94, 1.0))
	if core.combo > 1:
		draw_string(font, Vector2(370, 41), "COMBO x%d!" % core.combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.86, 0.20))
	draw_string(font, Vector2(560, 41), mode_badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.92, 0.98, 1.0))

	if core.mode == FlapPloppCore.Mode.TITLE:
		draw_rect(Rect2(210, 185, 540, 220), Color(0.08, 0.18, 0.28, 0.84))
		draw_string(font, Vector2(330, 245), "FLAP & PLOPP", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1.0, 0.88, 0.28))
		draw_string(font, Vector2(255, 295), "SPACE / Left-Click : Flap up (or Dive down in water)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.98, 1.0))
		draw_string(font, Vector2(255, 326), "SHIFT / Right-Click: PLOPP into water / SPLASH to sky!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.64, 0.94, 1.0))
		draw_string(font, Vector2(335, 372), "Press SPACE to take off!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.72, 0.34))
	elif core.mode == FlapPloppCore.Mode.GAME_OVER:
		draw_rect(Rect2(250, 205, 460, 190), Color(0.12, 0.14, 0.22, 0.88))
		draw_string(font, Vector2(375, 260), "BONK! NICE RUN!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.56, 0.42))
		draw_string(font, Vector2(335, 305), "SCORE: %d   |   BEST: %d   |   SHIFTS: %d" % [core.score, core.best_score, core.shifts_used], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.98, 1.0))
		draw_string(font, Vector2(330, 355), "Press SPACE or R to fly again!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.88, 0.30))
