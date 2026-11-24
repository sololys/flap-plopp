class_name StoryData
extends RefCounted

# Flap & Plopp: The Fjord Shift — Chapters, palettes & dialogue sequences

static func get_chapters() -> Array[Dictionary]:
	return [
		{
			"id": 0,
			"name": "CH 1: MORNING PIER",
			"subtitle": "Warm sun, calm harbor",
			"target_score": 150,
			"speed_bonus": 0.0,
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
			"subtitle": "Golden afternoon glow",
			"target_score": 400,
			"speed_bonus": 32.0,
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
			"subtitle": "Rose dusk & glowing tide",
			"target_score": 720,
			"speed_bonus": 64.0,
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
			"subtitle": "Starlight & aurora shift",
			"target_score": 1100,
			"speed_bonus": 92.0,
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
					"text": "Ahoy, little Pip! The lighthouse lamp out on the reef went dark before nightfall.",
				},
				{
					"speaker": "Pip",
					"portrait": "pip",
					"pitch": 1.32,
					"text": "Chirp! I've got the golden star-spark right here! I'll fly it straight across the fjord!",
				},
				{
					"speaker": "Captain Klabb",
					"portrait": "klabb",
					"pitch": 0.74,
					"text": "Easy now! Use SPACE to flap in the sky — and hit SHIFT to PLOPP under the waves when buoys block the way!",
				},
				{
					"speaker": "Pip",
					"portrait": "pip",
					"pitch": 1.36,
					"text": "Flap in the sky, PLOPP in the sea — let's go!",
				},
			]
		"ch2_intro":
			return [
				{
					"speaker": "Lumina",
					"portrait": "lumina",
					"pitch": 1.55,
					"text": "Bloop-hello, speedy puffin! Welcome to Jellyfish Cove!",
				},
				{
					"speaker": "Pip",
					"portrait": "pip",
					"pitch": 1.32,
					"text": "Whoa, you glow! Sorry for making such a big splash!",
				},
				{
					"speaker": "Lumina",
					"portrait": "lumina",
					"pitch": 1.50,
					"text": "Don't be! Time your SHIFT right near the waves for shiny combo boosts — just don't bonk my sleepy cousins!",
				},
			]
		"ch3_intro":
			return [
				{
					"speaker": "Captain Klabb",
					"portrait": "klabb",
					"pitch": 0.72,
					"text": "You made it to Twilight Reef! The tide is picking up speed now, Pip!",
				},
				{
					"speaker": "Pip",
					"portrait": "pip",
					"pitch": 1.35,
					"text": "My wings are warmed up and my belly is ready to plopp! One more stretch to the lighthouse!",
				},
			]
		"ch4_intro":
			return [
				{
					"speaker": "Keeper Sol",
					"portrait": "sol",
					"pitch": 0.92,
					"text": "Little puffin! Look up — the northern lights are dancing above the reef!",
				},
				{
					"speaker": "Lumina",
					"portrait": "lumina",
					"pitch": 1.52,
					"text": "Bring that golden spark home, Pip! We're cheering from below the waves!",
				},
				{
					"speaker": "Pip",
					"portrait": "pip",
					"pitch": 1.40,
					"text": "Final stretch! Full flap, full plopp — here I come!",
				},
			]
		"finale":
			return [
				{
					"speaker": "Keeper Sol",
					"portrait": "sol",
					"pitch": 0.95,
					"text": "You did it, Pip! The great beacon is shining across the whole fjord again!",
				},
				{
					"speaker": "Captain Klabb",
					"portrait": "klabb",
					"pitch": 0.76,
					"text": "Hah! Best little flyer AND swimmer in the North Sea! Extra fish cakes for everyone!",
				},
				{
					"speaker": "Lumina",
					"portrait": "lumina",
					"pitch": 1.56,
					"text": "Bloop-hooray! Want to keep surfing the aurora waves in Endless Mode?",
				},
			]
		_:
			return []
