class_name StoryData
extends RefCounted

# Flap & Plopp: The Fjord Shift
# Narrative built around four playful, rock-solid laws:
#   T(T(s)) = s (Sky <-> Sea involution), C(t) < R (thermal/spark load bound),
#   HOLD (safe reversible bubble), and KILL (instant 0.00 V cutoff).

static func get_chapters() -> Array[Dictionary]:
	return [
		{
			"id": 0,
			"name": "CH 1: MORNING PIER",
			"subtitle": "Law I: T(T(s)) = s  (Sky <-> Sea)",
			"target_score": 160,
			"speed_bonus": 0.0,
			"load_rate": 7.5,
			"sky_top": Color(0.56, 0.86, 0.99),
			"sky_low": Color(0.80, 0.96, 1.0),
			"sea_top": Color(0.08, 0.58, 0.78),
			"sea_deep": Color(0.04, 0.38, 0.58),
			"sun_color": Color(1.0, 0.90, 0.34),
			"aurora": false,
		},
		{
			"id": 1,
			"name": "CH 2: JELLYFISH COVE",
			"subtitle": "Law II: Keep C(t) < R",
			"target_score": 420,
			"speed_bonus": 32.0,
			"load_rate": 9.5,
			"sky_top": Color(0.98, 0.76, 0.44),
			"sky_low": Color(1.0, 0.90, 0.66),
			"sea_top": Color(0.07, 0.52, 0.62),
			"sea_deep": Color(0.03, 0.30, 0.42),
			"sun_color": Color(1.0, 0.68, 0.24),
			"aurora": false,
		},
		{
			"id": 2,
			"name": "CH 3: TWILIGHT REEF",
			"subtitle": "Law III: HOLD preserves",
			"target_score": 760,
			"speed_bonus": 62.0,
			"load_rate": 11.5,
			"sky_top": Color(0.42, 0.26, 0.56),
			"sky_low": Color(0.95, 0.52, 0.54),
			"sea_top": Color(0.11, 0.32, 0.56),
			"sea_deep": Color(0.05, 0.16, 0.36),
			"sun_color": Color(1.0, 0.46, 0.36),
			"aurora": false,
		},
		{
			"id": 3,
			"name": "CH 4: NORTHERN LIGHTHOUSE",
			"subtitle": "Law IV: KILL protects (0.00 V)",
			"target_score": 1150,
			"speed_bonus": 88.0,
			"load_rate": 13.0,
			"sky_top": Color(0.07, 0.10, 0.24),
			"sky_low": Color(0.16, 0.24, 0.42),
			"sea_top": Color(0.05, 0.22, 0.38),
			"sea_deep": Color(0.02, 0.10, 0.22),
			"sun_color": Color(0.96, 0.97, 0.82),
			"aurora": true,
		},
	]

static func get_sequence(seq_id: String) -> Array[Dictionary]:
	match seq_id:
		"intro":
			return [
				{
					"speaker": "Captain Klabb",
					"portrait": "klabb",
					"pitch": 0.72,
					"text": "Ahoy, Pip! The fjord lighthouse went dark. Carry this spark across the waves — and remember the Flip Law: T(T(s)) = s!",
				},
				{
					"speaker": "Pip",
					"portrait": "pip",
					"pitch": 1.34,
					"text": "T of T of s equals s! One SHIFT plops me from Sky to Sea, and a second SHIFT splashes me right back home!",
				},
				{
					"speaker": "Captain Klabb",
					"portrait": "klabb",
					"pitch": 0.74,
					"text": "Spot on! Keep your spark load C(t) < R, press H for a safe HOLD bubble anytime, and if C(t) hits R, KILL cuts power to 0.00 V!",
				},
			]
		"ch2_intro":
			return [
				{
					"speaker": "Lumina",
					"portrait": "lumina",
					"pitch": 1.54,
					"text": "Bloop-hello, Pip! Welcome to Jellyfish Cove! Watch your C(t) < R meter — glowing pearls and clean T(T(s))=s flips cool your spark right down!",
				},
				{
					"speaker": "Pip",
					"portrait": "pip",
					"pitch": 1.36,
					"text": "Got it! Stay below R, weave under the waves, and keep the rhythm crisp!",
				},
			]
		"ch3_intro":
			return [
				{
					"speaker": "Captain Klabb",
					"portrait": "klabb",
					"pitch": 0.72,
					"text": "Twilight Reef ahead! If the tide gets wild, tap H to enter HOLD — the fjord pauses safely and never opens on its own until YOU press SPACE!",
				},
				{
					"speaker": "Pip",
					"portrait": "pip",
					"pitch": 1.35,
					"text": "HOLD preserves, SPACE releases! My wings and flippers are ready!",
				},
			]
		"ch4_intro":
			return [
				{
					"speaker": "Keeper Sol",
					"portrait": "sol",
					"pitch": 0.92,
					"text": "Almost home, little puffin! The northern lights are out — respect the KILL boundary at C(t) = R and bring that spark to the lantern!",
				},
				{
					"speaker": "Lumina",
					"portrait": "lumina",
					"pitch": 1.52,
					"text": "T(T(s)) = s, C(t) < R, HOLD and KILL — you've mastered all four! Go light the beacon!",
				},
			]
		"finale":
			return [
				{
					"speaker": "Keeper Sol",
					"portrait": "sol",
					"pitch": 0.95,
					"text": "The beacon is lit! Every clean T(T(s))=s shift and every C(t) < R margin held true across the whole fjord!",
				},
				{
					"speaker": "Captain Klabb",
					"portrait": "klabb",
					"pitch": 0.76,
					"text": "Not a single unlogged glitch — and our little puffin did it with style! Fish cakes on the pier!",
				},
				{
					"speaker": "Pip",
					"portrait": "pip",
					"pitch": 1.38,
					"text": "Chirp! Ready to surf the aurora in Endless Mode?",
				},
			]
		_:
			return []
