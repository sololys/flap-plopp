GODOT ?= godot

.PHONY: play verify

play:
	$(GODOT) --path .

verify:
	$(GODOT) --headless --path . -s tests/test_game_core_headless.gd
