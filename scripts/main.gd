extends Node2D

# Flap & Plopp: The Fjord Shift — Renderer for T(T(s))=s, C(t)<R, HOLD & KILL

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

var sky_top_cur: Color = Color(0.56, 0.86, 0.99)
var sky_low_cur: Color = Color(0.80, 0.96, 1.0)
var sea_top_cur: Color = Color(0.08, 0.58, 0.78)
var sea_deep_cur: Color = Color(0.04, 0.38, 0.58)
var sun_cur: Color = Color(1.0, 0.90, 0.34)

var sfx_flap: AudioStreamPlayer
var sfx_plopp: AudioStreamPlayer
var sfx_splash: AudioStreamPlayer
var sfx_pickup: AudioStreamPlayer
var sfx_bonk: AudioStreamPlayer
var sfx_blip: AudioStreamPlayer
var sfx_fanfare: AudioStreamPlayer

func _ready() -> void:
	core = FlapPloppCore.new()
	sfx_flap = _make_player(SoundSynth.make_flap())
	sfx_plopp = _make_player(SoundSynth.make_plopp())
	sfx_splash = _make_player(SoundSynth.make_splash())
	sfx_pickup = _make_player(SoundSynth.make_pickup())
	sfx_bonk = _make_player(SoundSynth.make_bonk())
	sfx_blip = _make_player(SoundSynth.make_blip())
	sfx_fanfare = _make_player(SoundSynth.make_fanfare())

func _make_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_UP or event.keycode == KEY_W or event.keycode == KEY_ENTER:
			core.action_flap_or_dive()
		elif event.keycode == KEY_H:
			if core.mode == FlapPloppCore.Mode.PLAYING:
				core.action_hold()
			elif core.mode == FlapPloppCore.Mode.HOLD:
				core.release_hold()
		elif event.keycode == KEY_SHIFT or event.keycode == KEY_DOWN or event.keycode == KEY_S:
			if core.mode == FlapPloppCore.Mode.PLAYING:
				core.action_shift()
			elif core.mode == FlapPloppCore.Mode.DIALOGUE:
				core.advance_dialogue()
			elif core.mode == FlapPloppCore.Mode.TITLE:
				core.start_story()
		elif event.keycode == KEY_ESCAPE and core.mode == FlapPloppCore.Mode.DIALOGUE:
			core.skip_dialogue()
		elif event.keycode == KEY_R and (core.mode == FlapPloppCore.Mode.KILL or core.mode == FlapPloppCore.Mode.VICTORY):
			core.start_story()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			core.action_flap_or_dive()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if core.mode == FlapPloppCore.Mode.PLAYING:
				core.action_shift()
			else:
				core.action_flap_or_dive()

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	core.step(dt)
	_handle_events()
	_update_particles(dt)
	_update_popups(dt)

	var ch: Dictionary = core.current_chapter()
	sky_top_cur = sky_top_cur.lerp(ch["sky_top"], dt * 2.5)
	sky_low_cur = sky_low_cur.lerp(ch["sky_low"], dt * 2.5)
	sea_top_cur = sea_top_cur.lerp(ch["sea_top"], dt * 2.5)
	sea_deep_cur = sea_deep_cur.lerp(ch["sea_deep"], dt * 2.5)
	sun_cur = sun_cur.lerp(ch["sun_color"], dt * 2.5)

	squash_x = lerpf(squash_x, 1.0, dt * 11.0)
	squash_y = lerpf(squash_y, 1.0, dt * 11.0)
	wing_angle = lerpf(wing_angle, 0.0, dt * 9.0)
	if shake_t > 0.0:
		shake_t = maxf(0.0, shake_t - dt)
	if water_ripple_t > 0.0:
		water_ripple_t = maxf(0.0, water_ripple_t - dt)

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

	if core.mode == FlapPloppCore.Mode.VICTORY and randf() < dt * 4.0:
		_spawn_burst(randf_range(180.0, 780.0), randf_range(70.0, 220.0), 14, Color(1.0, 0.88, 0.25), 180.0)

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
				popups.append({"text": "PLOPP! T(s)", "x": ex, "y": ey - 18.0, "life": 0.65, "color": Color(0.32, 0.82, 1.0)})
			"splash":
				squash_x = 0.74
				squash_y = 1.35
				water_ripple_t = 0.45
				sfx_splash.pitch_scale = randf_range(0.96, 1.08)
				sfx_splash.play()
				_spawn_burst(ex, ey, 14, Color(0.92, 0.99, 1.0, 0.95), 240.0)
				popups.append({"text": "SPLASH! T(s)", "x": ex, "y": ey - 22.0, "life": 0.65, "color": Color(1.0, 0.58, 0.20)})
			"involution":
				popups.append({
					"text": "T(T(s))=s  +%d" % int(ev["points"]),
					"x": ex,
					"y": ey,
					"life": 0.95,
					"color": Color(0.45, 1.0, 0.76),
				})
			"combo":
				popups.append({
					"text": "SHIFT x%d +%d" % [int(ev["combo"]), int(ev["points"])],
					"x": ex + 20.0,
					"y": ey - 42.0,
					"life": 0.9,
					"color": Color(1.0, 0.86, 0.18),
				})
			"pickup":
				sfx_pickup.pitch_scale = 0.92 + float(ev["combo"]) * 0.06
				sfx_pickup.play()
				var c := Color(1.0, 0.88, 0.22) if ev["kind"] == "star" else Color(0.96, 0.84, 1.0)
				_spawn_burst(ex, ey, 12, c, 190.0)
				popups.append({"text": "+%d COOL!" % int(ev["points"]), "x": ex, "y": ey - 12.0, "life": 0.75, "color": c})
			"hold_enter":
				popups.append({"text": "HOLD (0.00 V)", "x": ex, "y": ey - 32.0, "life": 0.8, "color": Color(1.0, 0.92, 0.52)})
			"skim":
				_spawn_burst(ex, ey, 4, Color(0.88, 0.98, 1.0, 0.85), 95.0)
			"kill":
				shake_t = 0.28
				sfx_bonk.play()
				_spawn_burst(ex, ey, 18, Color(1.0, 0.36, 0.28, 0.95), 260.0)
				var lbl := "KILL: C(t) >= R!" if str(ev.get("reason", "")) == "OVERLOAD_C_GE_R" else "KILL: BONK! (0.00 V)"
				popups.append({"text": lbl, "x": ex, "y": ey - 24.0, "life": 1.1, "color": Color(1.0, 0.35, 0.28)})
			"blip":
				sfx_blip.pitch_scale = float(ev.get("pitch", 1.0)) * randf_range(0.95, 1.05)
				sfx_blip.play()
			"fanfare":
				sfx_fanfare.play()
				_spawn_burst(480.0, 200.0, 24, Color(1.0, 0.88, 0.28), 260.0)

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
		shake = Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)) * (shake_t / 0.28)
	draw_set_transform(shake, 0.0, Vector2.ONE)

	_draw_sky_and_sea()
	_draw_lighthouse_if_finale()
	_draw_obstacles()
	_draw_collectibles()
	_draw_puffin()
	_draw_water_surface()
	_draw_particles()
	_draw_popups()
	_draw_hud()
	if core.mode == FlapPloppCore.Mode.DIALOGUE:
		_draw_dialogue_box()
	elif core.mode == FlapPloppCore.Mode.CHAPTER_BANNER:
		_draw_chapter_banner()

func _draw_sky_and_sea() -> void:
	var ch: Dictionary = core.current_chapter()
	draw_rect(Rect2(0, 0, 960, FlapPloppCore.WATER_Y), sky_top_cur)
	draw_rect(Rect2(0, 190, 960, FlapPloppCore.WATER_Y - 190), Color(sky_low_cur.r, sky_low_cur.g, sky_low_cur.b, 0.65))

	if bool(ch["aurora"]):
		for band in range(3):
			var pts := PackedVector2Array()
			var bx := 0.0
			while bx <= 960.0:
				var by := 85.0 + float(band) * 32.0 + sin(bx * 0.012 + core.elapsed * 1.4 + float(band)) * 18.0
				pts.append(Vector2(bx, by))
				bx += 24.0
			var ac := Color(0.28, 0.96, 0.68, 0.26) if band % 2 == 0 else Color(0.54, 0.56, 1.0, 0.22)
			draw_polyline(pts, ac, 18.0, true)

	var sun_pos := Vector2(815, 92)
	draw_circle(sun_pos, 52.0, Color(sun_cur.r, sun_cur.g, sun_cur.b, 0.28))
	draw_circle(sun_pos, 34.0, sun_cur)

	var cloud_alpha := 0.22 if bool(ch["aurora"]) else 0.85
	for i in range(4):
		var cx := fmod(float(i) * 270.0 - core.distance * 0.12 + 1200.0, 1120.0) - 80.0
		var cy := 74.0 + float(i % 2) * 52.0
		var cc := Color(1.0, 1.0, 1.0, cloud_alpha)
		draw_circle(Vector2(cx, cy), 24.0, cc)
		draw_circle(Vector2(cx + 22.0, cy - 8.0), 28.0, cc)
		draw_circle(Vector2(cx + 46.0, cy), 22.0, cc)

	draw_rect(Rect2(0, FlapPloppCore.WATER_Y, 960, 640 - FlapPloppCore.WATER_Y), sea_top_cur)
	draw_rect(Rect2(0, FlapPloppCore.WATER_Y + 150, 960, 640 - (FlapPloppCore.WATER_Y + 150)), Color(sea_deep_cur.r, sea_deep_cur.g, sea_deep_cur.b, 0.72))
	for i in range(5):
		var bx := fmod(float(i) * 230.0 - core.distance * 0.25 + 1400.0, 1180.0) - 100.0
		var poly := PackedVector2Array([
			Vector2(bx, FlapPloppCore.WATER_Y),
			Vector2(bx + 54.0, FlapPloppCore.WATER_Y),
			Vector2(bx + 115.0, 640.0),
			Vector2(bx + 25.0, 640.0),
		])
		draw_colored_polygon(poly, Color(0.55, 0.92, 0.98, 0.10))

func _draw_lighthouse_if_finale() -> void:
	if core.chapter_index < 3 and core.mode != FlapPloppCore.Mode.VICTORY:
		return
	var lx := 820.0
	var base_y := FlapPloppCore.WATER_Y + 4.0
	draw_circle(Vector2(lx, base_y + 10.0), 58.0, Color(0.24, 0.26, 0.32))
	draw_rect(Rect2(lx - 22.0, base_y - 145.0, 44.0, 145.0), Color(0.95, 0.94, 0.90))
	draw_rect(Rect2(lx - 22.0, base_y - 110.0, 44.0, 32.0), Color(0.88, 0.26, 0.22))
	draw_rect(Rect2(lx - 22.0, base_y - 48.0, 44.0, 32.0), Color(0.88, 0.26, 0.22))
	draw_rect(Rect2(lx - 18.0, base_y - 172.0, 36.0, 28.0), Color(1.0, 0.92, 0.45))
	if core.mode == FlapPloppCore.Mode.VICTORY or core.endless_mode:
		var beam_ang := sin(core.elapsed * 2.2) * 0.28
		var p0 := Vector2(lx, base_y - 158.0)
		var p1 := p0 + Vector2(-420.0, -90.0 + beam_ang * 220.0)
		var p2 := p0 + Vector2(-420.0, 70.0 + beam_ang * 220.0)
		draw_colored_polygon(PackedVector2Array([p0, p1, p2]), Color(1.0, 0.94, 0.45, 0.28))

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
			draw_rect(rect, Color(0.92, 0.28, 0.24))
			draw_rect(Rect2(rect.position.x, oy - 18.0, ow, 36.0), Color(0.98, 0.97, 0.94))
			draw_circle(Vector2(ox, rect.position.y), ow * 0.45, Color(0.98, 0.78, 0.22))
		else:
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
			draw_circle(Vector2(cx, cy), r + 5.0, Color(0.86, 0.98, 1.0, 0.28))
			draw_circle(Vector2(cx, cy), r, Color(0.97, 0.92, 1.0))
			draw_circle(Vector2(cx - 4.0, cy - 4.0), r * 0.32, Color(1.0, 1.0, 1.0))

func _draw_puffin() -> void:
	var pos := Vector2(FlapPloppCore.PLAYER_X, core.player_y)
	var tilt := clampf(core.player_vy * 0.0011, -0.55, 0.65)
	draw_set_transform(pos, tilt, Vector2(squash_x, squash_y))
	if core.mode == FlapPloppCore.Mode.HOLD:
		draw_circle(Vector2.ZERO, 34.0, Color(1.0, 0.92, 0.45, 0.24))
		draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, Color(1.0, 0.90, 0.35, 0.9), 3.0)
	draw_circle(Vector2.ZERO, 21.0, Color(0.14, 0.16, 0.22))
	draw_circle(Vector2(3.0, 5.0), 14.5, Color(0.98, 0.97, 0.94))
	draw_colored_polygon(PackedVector2Array([Vector2(16.0, -5.0), Vector2(33.0, 1.0), Vector2(16.0, 7.0)]), Color(1.0, 0.44, 0.16))
	draw_line(Vector2(22.0, -3.0), Vector2(22.0, 5.0), Color(1.0, 0.86, 0.22), 3.0)
	var wy := sin(wing_angle * 2.0) * 8.0
	draw_circle(Vector2(-6.0, 2.0 + wy), 10.5, Color(0.20, 0.24, 0.32))
	if core.in_water:
		draw_line(Vector2(6.0, -7.0), Vector2(13.0, -5.0), Color(0.10, 0.10, 0.14), 2.8)
		draw_line(Vector2(6.0, -3.0), Vector2(13.0, -5.0), Color(0.10, 0.10, 0.14), 2.8)
	else:
		draw_circle(Vector2(9.0, -6.0), 5.5, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(10.5, -6.0), 2.8, Color(0.10, 0.12, 0.18))
		draw_circle(Vector2(11.3, -7.2), 1.1, Color(1.0, 1.0, 1.0))
	draw_circle(Vector2(11.0, 1.5), 3.2, Color(1.0, 0.56, 0.62, 0.65))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_portrait(kind: String, center: Vector2) -> void:
	draw_circle(center, 38.0, Color(0.14, 0.24, 0.36))
	draw_arc(center, 38.0, 0.0, TAU, 32, Color(1.0, 0.88, 0.34), 3.0)
	match kind:
		"pip":
			draw_circle(center, 22.0, Color(0.14, 0.16, 0.22))
			draw_circle(center + Vector2(3, 5), 14.0, Color(0.98, 0.97, 0.94))
			draw_colored_polygon(PackedVector2Array([center + Vector2(14, -4), center + Vector2(30, 1), center + Vector2(14, 6)]), Color(1.0, 0.44, 0.16))
			draw_circle(center + Vector2(8, -6), 4.5, Color(1.0, 1.0, 1.0))
			draw_circle(center + Vector2(9, -6), 2.2, Color(0.1, 0.1, 0.15))
		"klabb":
			draw_circle(center + Vector2(0, 6), 20.0, Color(0.52, 0.58, 0.64))
			draw_colored_polygon(PackedVector2Array([center + Vector2(-24, -4), center + Vector2(24, -4), center + Vector2(14, -22), center + Vector2(-14, -22)]), Color(1.0, 0.80, 0.18))
			draw_circle(center + Vector2(-7, 2), 3.0, Color(0.1, 0.1, 0.14))
			draw_circle(center + Vector2(7, 2), 3.0, Color(0.1, 0.1, 0.14))
			draw_circle(center + Vector2(-6, 12), 7.0, Color(0.84, 0.86, 0.88))
			draw_circle(center + Vector2(6, 12), 7.0, Color(0.84, 0.86, 0.88))
		"lumina":
			draw_circle(center + Vector2(0, -4), 20.0, Color(1.0, 0.54, 0.78))
			draw_circle(center + Vector2(-7, -4), 3.5, Color(0.14, 0.12, 0.22))
			draw_circle(center + Vector2(7, -4), 3.5, Color(0.14, 0.12, 0.22))
			for tx in [-10, 0, 10]:
				draw_line(center + Vector2(tx, 10), center + Vector2(tx, 24), Color(0.98, 0.74, 0.90), 3.0)
		"sol":
			draw_rect(Rect2(center.x - 14, center.y - 18, 28, 36), Color(0.96, 0.94, 0.88))
			draw_rect(Rect2(center.x - 14, center.y - 2, 28, 12), Color(0.88, 0.26, 0.22))
			draw_circle(center + Vector2(0, -14), 10.0, Color(1.0, 0.90, 0.32))

func _draw_dialogue_box() -> void:
	var font := ThemeDB.fallback_font
	var line: Dictionary = core.current_dialogue_line()
	if line.is_empty():
		return
	var box := Rect2(70, 456, 820, 148)
	draw_rect(box, Color(0.06, 0.12, 0.20, 0.92))
	draw_rect(box, Color(1.0, 0.88, 0.34, 0.90), false, 3.0)
	_draw_portrait(str(line.get("portrait", "pip")), Vector2(132, 530))
	var speaker := str(line.get("speaker", ""))
	var full_text := str(line.get("text", ""))
	var shown := full_text.substr(0, mini(int(core.dialogue_chars), full_text.length()))
	draw_string(font, Vector2(194, 492), speaker.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.86, 0.28))
	draw_multiline_string(font, Vector2(194, 526), shown, HORIZONTAL_ALIGNMENT_LEFT, 660.0, 20, 3, Color(0.95, 0.98, 1.0))
	draw_string(font, Vector2(640, 592), "[SPACE: Next]   [ESC: Skip]", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.72, 0.86, 0.96))

func _draw_chapter_banner() -> void:
	var font := ThemeDB.fallback_font
	var ch: Dictionary = core.current_chapter()
	draw_rect(Rect2(190, 215, 580, 126), Color(0.06, 0.12, 0.22, 0.88))
	draw_rect(Rect2(190, 215, 580, 126), Color(1.0, 0.88, 0.34), false, 3.0)
	draw_string(font, Vector2(230, 266), str(ch["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.88, 0.28))
	draw_string(font, Vector2(230, 304), str(ch["subtitle"]) + "  |  Goal: %d pts" % int(ch["target_score"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.92, 0.97, 1.0))

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
	var ch: Dictionary = core.current_chapter()
	draw_rect(Rect2(16, 12, 928, 52), Color(0.06, 0.13, 0.22, 0.68))
	draw_string(font, Vector2(28, 36), "SCORE: %d" % core.score, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1.0, 0.96, 0.85))
	draw_string(font, Vector2(28, 56), "T(T(s))=s: %d" % core.involutions_completed, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.54, 0.98, 0.82))

	if core.combo > 1:
		draw_string(font, Vector2(170, 36), "x%d!" % core.combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.86, 0.20))

	# Live C(t) < R capacity bar
	var c_frac := clampf(core.load_c / FlapPloppCore.CAPACITY_R, 0.0, 1.0)
	var bar_col := Color(0.32, 0.92, 0.62) if c_frac < 0.65 else (Color(1.0, 0.80, 0.22) if c_frac < 0.85 else Color(1.0, 0.32, 0.26))
	draw_string(font, Vector2(240, 32), "C(t) < R: %d/%d" % [int(round(core.load_c)), int(FlapPloppCore.CAPACITY_R)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, bar_col)
	draw_rect(Rect2(240, 38, 170, 14), Color(0.16, 0.22, 0.30))
	draw_rect(Rect2(240, 38, 170.0 * c_frac, 14), bar_col)

	var label := "ENDLESS AURORA" if core.endless_mode else str(ch["name"])
	draw_string(font, Vector2(440, 34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.88, 0.96, 1.0))
	if not core.endless_mode:
		var target := float(ch["target_score"])
		var prev_t := float(core.chapter_start_score)
		var frac := clampf((float(core.score) - prev_t) / maxf(1.0, target - prev_t), 0.0, 1.0)
		draw_rect(Rect2(440, 42, 200, 10), Color(0.18, 0.28, 0.38))
		draw_rect(Rect2(440, 42, 200.0 * frac, 10), Color(1.0, 0.86, 0.24))

	var state_badge := "HOLD [SPACE]" if core.mode == FlapPloppCore.Mode.HOLD else ("SEA (DIVE)" if core.in_water else "SKY (FLAP)")
	draw_string(font, Vector2(680, 36), state_badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.76, 0.96, 1.0))
	draw_string(font, Vector2(680, 55), "[SHIFT: T(s)]  [H: HOLD]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.76, 0.86, 0.92))

	if core.mode == FlapPloppCore.Mode.TITLE:
		draw_rect(Rect2(170, 150, 620, 275), Color(0.06, 0.14, 0.24, 0.90))
		draw_rect(Rect2(170, 150, 620, 275), Color(1.0, 0.88, 0.32), false, 3.0)
		draw_string(font, Vector2(285, 208), "FLAP & PLOPP", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(1.0, 0.88, 0.28))
		draw_string(font, Vector2(255, 240), "T(T(s)) = s   ·   C(t) < R   ·   HOLD   ·   KILL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.56, 0.98, 0.82))
		draw_string(font, Vector2(215, 286), "SPACE / Left-Click : Flap up (Sky) or Dive down (Sea)", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.95, 0.98, 1.0))
		draw_string(font, Vector2(215, 314), "SHIFT / Right-Click: Involution T(s) — PLOPP / SPLASH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.64, 0.94, 1.0))
		draw_string(font, Vector2(215, 342), "H                  : Safe HOLD bubble (cools C(t) < R)", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.90, 0.56))
		draw_string(font, Vector2(290, 392), "Press SPACE to begin Pip's journey!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.74, 0.34))
	elif core.mode == FlapPloppCore.Mode.HOLD:
		draw_rect(Rect2(255, 215, 450, 145), Color(0.08, 0.16, 0.26, 0.88))
		draw_rect(Rect2(255, 215, 450, 145), Color(1.0, 0.90, 0.38), false, 3.0)
		draw_string(font, Vector2(355, 266), "HOLD — SAFE STASIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.90, 0.38))
		draw_string(font, Vector2(290, 302), "Cooling C(t) = %d / %d  (0.00 V)" % [int(round(core.load_c)), int(FlapPloppCore.CAPACITY_R)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.86, 0.98, 0.92))
		draw_string(font, Vector2(315, 336), "Press SPACE or H to release OPEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.92, 0.97, 1.0))
	elif core.mode == FlapPloppCore.Mode.KILL:
		draw_rect(Rect2(220, 188, 520, 210), Color(0.14, 0.08, 0.12, 0.92))
		draw_rect(Rect2(220, 188, 520, 210), Color(1.0, 0.36, 0.30), false, 3.0)
		var title := "KILL — C(t) >= R OVERLOAD (0.00 V)" if core.kill_reason == "OVERLOAD_C_GE_R" else "KILL — OBSTACLE BONK (0.00 V)"
		draw_string(font, Vector2(265, 244), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(1.0, 0.44, 0.36))
		draw_string(font, Vector2(270, 286), "%s  |  SCORE: %d  |  LOGGED: %d events" % [str(ch["name"]), core.score, core.witness_log.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.98, 1.0))
		draw_string(font, Vector2(275, 344), "SPACE: Retry this chapter   |   R: Restart story", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.88, 0.30))
	elif core.mode == FlapPloppCore.Mode.VICTORY:
		draw_rect(Rect2(210, 175, 540, 220), Color(0.06, 0.14, 0.26, 0.90))
		draw_rect(Rect2(210, 175, 540, 220), Color(1.0, 0.88, 0.32), false, 3.0)
		draw_string(font, Vector2(275, 234), "LIGHTHOUSE LIT! YOU WIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.90, 0.28))
		draw_string(font, Vector2(260, 280), "SCORE: %d  |  T(T(s))=s: %d  |  WITNESS LOG: %d" % [core.score, core.involutions_completed, core.witness_log.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.92, 0.98, 1.0))
		draw_string(font, Vector2(260, 344), "SPACE: Continue in Endless Aurora   |   R: Replay Story", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.68, 0.96, 0.80))
